// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC721Holder} from "openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Create2} from "openzeppelin-contracts/contracts/utils/Create2.sol";
import {INonfungiblePositionManager} from "./uniswap/INonfungiblePositionManager.sol";
import {IWETH} from "./uniswap/IWETH.sol";
import {TickMath} from "./uniswap/TickMath.sol";
import {ClankerToken} from "./ClankerToken.sol";

contract ClankerTokenFactory is Ownable, ERC721Holder {
    // Constants (Base mainnet)
    IWETH constant WETH = IWETH(0x4200000000000000000000000000000000000006);
    INonfungiblePositionManager constant UNISWAP_POSITION_MANAGER =
        INonfungiblePositionManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
    uint24 constant UNISWAP_FEE_TIER = 10000;
    int24 constant UNISWAP_TICK_SPACING = 200;

    // Protocol configuration
    uint8 public protocolFeePercentEth;
    uint8 public protocolFeePercentToken;
    address payable public protocolFeeRecipient;
    uint256 public totalSupply;
    int24 public initialTick;

    // State
    struct ClankerTokenState {
        address creator;
        uint8 protocolFeePercentEth;
        uint8 protocolFeePercentToken;
        uint256 positionTokenId;
    }

    mapping(address => ClankerTokenState) internal states; // Keep this internal to prevent snipers from being able to detect whether a newly deployed Uniswap pool is a clanker or not

    // Events
    event ClankerTokenDeployed(
        address indexed clanker, address creator, uint256 fid, string castHash, string name, string symbol, string image
    );
    event FeesClaimed(
        address indexed clanker,
        address indexed creator,
        uint256 creatorAmountEth,
        uint256 creatorAmountToken,
        uint256 protocolAmountEth,
        uint256 protocolAmountToken
    );

    constructor(
        address owner,
        uint8 protocolFeePercentEth_,
        uint8 protocolFeePercentToken_,
        address payable protocolFeeRecipient_,
        uint256 totalSupply_,
        int24 initialTick_
    ) Ownable(owner) {
        protocolFeePercentEth = protocolFeePercentEth_;
        protocolFeePercentToken = protocolFeePercentToken_;
        protocolFeeRecipient = protocolFeeRecipient_;
        totalSupply = totalSupply_;
        initialTick = initialTick_;
    }

    struct DeployParams {
        string name;
        string symbol;
        uint256 fid;
        address creator;
        string castHash;
        string image;
        bytes32 salt;
    }

    // TODO: consider restricting to clanker EOA
    function deploy(DeployParams calldata params) external returns (address token) {
        // Deploy token
        token = Create2.deploy(
            0,
            params.salt,
            abi.encodePacked(
                type(ClankerToken).creationCode,
                abi.encode(
                    params.name, params.symbol, params.fid, params.creator, params.castHash, params.image, totalSupply
                )
            )
        );

        require(token < address(WETH), "Invalid salt");

        // Create Uniswap pool
        UNISWAP_POSITION_MANAGER.createAndInitializePoolIfNecessary(
            token, address(WETH), UNISWAP_FEE_TIER, TickMath.getSqrtRatioAtTick(initialTick)
        );

        // Add liquidity
        ClankerToken(token).approve(address(UNISWAP_POSITION_MANAGER), totalSupply);
        (uint256 positionTokenId,,,) = UNISWAP_POSITION_MANAGER.mint(
            INonfungiblePositionManager.MintParams(
                token,
                address(WETH),
                UNISWAP_FEE_TIER,
                initialTick,
                (TickMath.MAX_TICK / UNISWAP_TICK_SPACING) * UNISWAP_TICK_SPACING,
                totalSupply,
                0,
                0,
                0,
                address(this),
                block.timestamp
            )
        );

        states[token] = ClankerTokenState({
            creator: params.creator,
            protocolFeePercentEth: protocolFeePercentEth,
            protocolFeePercentToken: protocolFeePercentToken,
            positionTokenId: positionTokenId
        });

        emit ClankerTokenDeployed(
            token, params.creator, params.fid, params.castHash, params.name, params.symbol, params.image
        );
    }

    // TODO: consider restricting to clanker EOA + creator
    function claimFees(address token) external {
        ClankerTokenState memory state = states[token];

        // This needs to succeed silently even if the token is not a clanker, so snipers can't use it to detect whether a token is a clanker or not
        if (state.creator == address(0)) return;

        // Claim fees
        (uint256 amountToken, uint256 amountETH) = UNISWAP_POSITION_MANAGER.collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: state.positionTokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // Calculate eth and token splits
        uint256 protocolAmountETH = (amountETH * protocolFeePercentEth) / 100;
        uint256 protocolAmountToken = (amountToken * protocolFeePercentToken) / 100;
        uint256 creatorAmountEth = amountETH - protocolAmountETH;
        uint256 creatorAmountToken = amountToken - protocolAmountToken;

        // Transfer fees
        WETH.withdraw(amountETH);

        if (protocolAmountETH > 0) {
            (bool sent,) = protocolFeeRecipient.call{value: protocolAmountETH}("");
            require(sent, "Failed to send ETH to protocol fee recipient");
        }

        if (creatorAmountEth > 0) {
            (bool sent,) = state.creator.call{value: creatorAmountEth}("");
            require(sent, "Failed to send ETH to creator");
        }

        if (protocolAmountToken > 0) {
            ClankerToken(token).transfer(protocolFeeRecipient, protocolAmountToken);
        }

        if (creatorAmountToken > 0) {
            ClankerToken(token).transfer(state.creator, creatorAmountToken);
        }

        emit FeesClaimed(
            token, state.creator, creatorAmountEth, creatorAmountToken, protocolAmountETH, protocolAmountToken
        );
    }

    function setProtocolFeePercentEth(uint8 protocolFeePercentEth_) external onlyOwner {
        protocolFeePercentEth = protocolFeePercentEth_;
    }

    function setProtocolFeePercentToken(uint8 protocolFeePercentToken_) external onlyOwner {
        protocolFeePercentToken = protocolFeePercentToken_;
    }

    function setProtocolFeeRecipient(address payable protocolFeeRecipient_) external onlyOwner {
        protocolFeeRecipient = protocolFeeRecipient_;
    }

    function setTotalSupply(uint256 totalSupply_) external onlyOwner {
        totalSupply = totalSupply_;
    }

    function setInitialTick(int24 initialTick_) external onlyOwner {
        initialTick = initialTick_;
    }

    function predictTokenAddress(DeployParams calldata params) external view returns (address) {
        return Create2.computeAddress(
            params.salt,
            keccak256(
                abi.encodePacked(
                    type(ClankerToken).creationCode,
                    abi.encode(
                        params.name,
                        params.symbol,
                        params.fid,
                        params.creator,
                        params.castHash,
                        params.image,
                        totalSupply
                    )
                )
            )
        );
    }
}

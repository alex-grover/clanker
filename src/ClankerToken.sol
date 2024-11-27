// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ClankerToken is ERC20 {
    uint256 public immutable fid;
    address public immutable creator;
    string public castHash;
    string public image;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 fid_,
        address creator_,
        string memory castHash_,
        string memory image_,
        uint256 totalSupply
    ) ERC20(name_, symbol_) {
        fid = fid_;
        creator = creator_;
        castHash = castHash_;
        image = image_;

        _mint(msg.sender, totalSupply);
    }
}

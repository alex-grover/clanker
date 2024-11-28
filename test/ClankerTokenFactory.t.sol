// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ClankerTokenFactory} from "../src/ClankerTokenFactory.sol";

contract ClankerTokenFactoryTest is Test {
    function test_constructor(
        address payable owner,
        uint8 protocolFeePercentEth,
        uint8 protocolFeePercentToken,
        uint256 totalSupply,
        int24 initialTick
    ) external {
        vm.assume(owner != address(0));

        ClankerTokenFactory factory =
            new ClankerTokenFactory(owner, protocolFeePercentEth, protocolFeePercentToken, totalSupply, initialTick);

        assertEq(factory.owner(), owner);
        assertEq(factory.protocolFeePercentEth(), protocolFeePercentEth);
        assertEq(factory.protocolFeePercentToken(), protocolFeePercentToken);
        assertEq(factory.totalSupply(), totalSupply);
        assertEq(factory.initialTick(), initialTick);
    }

    // TODO: test deploy
    // TODO: test claimFees
    // TODO: test setters
}

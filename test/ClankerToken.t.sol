// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {ClankerToken} from "../src/ClankerToken.sol";

contract ClankerTokenTest is Test {
    function test_constructor(string calldata name, string calldata symbol, uint256 totalSupply) external {
        ClankerToken token = new ClankerToken(name, symbol, totalSupply);

        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), totalSupply);
    }
}

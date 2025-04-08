// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/mocks/ERC20Minter.sol";
import "../src/mocks/ERC20MintableMinterWithdecimalForMinter.sol";

contract KayenMinter is Test {
    address[] tokens; // = new ERC20MintableMinter[](11);
    ERC20Minter minter;
    address user1 = address(11);
    address owner = address(13212);

    function setUp() public {
        vm.startPrank(owner);

        ERC20MintableMinter a = new ERC20MintableMinter("Token A", "TKNA", 0);
        ERC20MintableMinter b = new ERC20MintableMinter("Token B", "TKNB", 0);
        ERC20MintableMinter c = new ERC20MintableMinter("Token C", "TKNC", 0);
        ERC20MintableMinter d = new ERC20MintableMinter("Token D", "TKND", 0);
        ERC20MintableMinter e = new ERC20MintableMinter("Token E", "TKNE", 0);
        ERC20MintableMinter f = new ERC20MintableMinter("Token F", "TKNF", 0);
        ERC20MintableMinter g = new ERC20MintableMinter("Token G", "TKNG", 0);
        ERC20MintableMinter h = new ERC20MintableMinter("Token H", "TKNH", 0);
        ERC20MintableMinter i = new ERC20MintableMinter("Token I", "TKNI", 0);
        ERC20MintableMinter j = new ERC20MintableMinter("Token J", "TKNJ", 0);
        ERC20MintableMinter k = new ERC20MintableMinter("Token K", "TKNK", 0);
        ERC20MintableMinter l = new ERC20MintableMinter("Token L", "TKNL", 0);

        tokens.push(address(a));
        tokens.push(address(b));
        tokens.push(address(c));
        tokens.push(address(d));
        tokens.push(address(e));
        tokens.push(address(f));
        tokens.push(address(g));
        tokens.push(address(h));
        tokens.push(address(i));
        tokens.push(address(j));
        tokens.push(address(k));

        minter = new ERC20Minter(tokens);

        for (uint256 ii; ii < 11; ii++) {
            ERC20MintableMinter(tokens[ii]).addToWhitelist(address(minter));
        }

        ERC20Minter(minter).addToken(address(l));
        ERC20MintableMinter(address(l)).addToWhitelist(address(minter));
        tokens.push(address(l));

        vm.stopPrank();
    }

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    // function test_mint() public {
    //     minter.mintBatch(user1);
    //     for(uint256 i; i<4; i++){
    //         uint256 balance = ERC20MintableMinter(tokens[i]).balanceOf(user1);
    //         assertEq(balance, 100);
    //     }
    //     assertEq(minter.lastMinted(), 4);
    // }

    function test_mint8times() public {
        for (uint256 i; i < 8; i++) {
            minter.mintBatch(user1);
            // uint256 balance = ERC20MintableMinter(tokens[i]).balanceOf(user1);
            // console.log(balance);
        }
        vm.warp(86401);
        for (uint256 i; i < 8; i++) {
            minter.mintBatch(user1);
            // assertEq(balance, 100);
        }
        vm.warp(86401 * 2);
        for (uint256 i; i < 8; i++) {
            minter.mintBatch(user1);
            // assertEq(balance, 100);
        }
        for (uint256 i; i < 12; i++) {
            uint256 balance = ERC20MintableMinter(tokens[i]).balanceOf(user1);
            console.log(balance);
        }

        for (uint256 i; i < 12; i++) {
            uint256 balance = ERC20MintableMinter(tokens[i]).balanceOf(owner);
            console.log(balance);
        }
    }

    // function test_CreatePairZeroAddress() public {
    //     vm.expectRevert(IKayenFactory.ZeroAddress.selector);
    //     factory.createPair(address(0), address(token0));

    //     vm.expectRevert(IKayenFactory.ZeroAddress.selector);
    //     factory.createPair(address(token1), address(0));
    // }

    // function test_CreatePairPairExists() public {
    //     factory.createPair(address(token1), address(token0));

    //     vm.expectRevert(IKayenFactory.PairExists.selector);
    //     factory.createPair(address(token1), address(token0));
    // }

    // function test_CreatePairIdenticalTokens() public {
    //     vm.expectRevert(IKayenFactory.IdenticalAddresses.selector);
    //     factory.createPair(address(token0), address(token0));
    // }
}

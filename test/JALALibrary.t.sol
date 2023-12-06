// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../contracts/libraries/JALALibrary.sol";
import "../contracts/JALAFactory.sol";
import "../contracts/JALAPair.sol";
import "../contracts/mocks/ERC20Mintable.sol";

contract JALALibrary_Test is Test {
    address feeSetter = address(69);
    JALAFactory factory;
    JALAERC20 jala;

    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    ERC20Mintable tokenC;
    ERC20Mintable tokenD;

    JALAPair pair;
    JALAPair pair2;
    JALAPair pair3;

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function setUp() public {
        factory = new JALAFactory(feeSetter);

        tokenA = new ERC20Mintable("TokenA", "TKNA");
        tokenB = new ERC20Mintable("TokenB", "TKNB");
        tokenC = new ERC20Mintable("TokenC", "TKNC");
        tokenD = new ERC20Mintable("TokenD", "TKND");

        tokenA.mint(10 ether, address(this));
        tokenB.mint(10 ether, address(this));
        tokenC.mint(10 ether, address(this));
        tokenD.mint(10 ether, address(this));

        address pairAddress = factory.createPair(address(tokenA), address(tokenB));
        pair = JALAPair(pairAddress);

        pairAddress = factory.createPair(address(tokenB), address(tokenC));
        pair2 = JALAPair(pairAddress);

        pairAddress = factory.createPair(address(tokenC), address(tokenD));
        pair3 = JALAPair(pairAddress);
    }

    function test_GetReserves() public {
        tokenA.transfer(address(pair), 1.1 ether);
        tokenB.transfer(address(pair), 0.8 ether);

        JALAPair(address(pair)).mint(address(this));

        (uint256 reserve0, uint256 reserve1) = JALALibrary.getReserves(
            address(factory),
            address(tokenA),
            address(tokenB)
        );

        assertEq(reserve0, 1.1 ether);
        assertEq(reserve1, 0.8 ether);
    }

    function test_Quote() public {
        uint256 amountOut = JALALibrary.quote(1 ether, 1 ether, 1 ether);
        assertEq(amountOut, 1 ether);

        amountOut = JALALibrary.quote(1 ether, 2 ether, 1 ether);
        assertEq(amountOut, 0.5 ether);

        amountOut = JALALibrary.quote(1 ether, 1 ether, 2 ether);
        assertEq(amountOut, 2 ether);
    }

    function test_PairFor() public {
        address pairAddress = JALALibrary.pairFor(address(factory), address(tokenA), address(tokenB));

        assertEq(pairAddress, factory.getPair(address(tokenA), address(tokenB)));
    }

    function test_PairForTokensSorting() public {
        address pairAddress = JALALibrary.pairFor(address(factory), address(tokenB), address(tokenA));

        assertEq(pairAddress, factory.getPair(address(tokenA), address(tokenB)));
    }

    function test_PairForNonexistentFactory() public {
        address pairAddress = JALALibrary.pairFor(address(0xaabbcc), address(tokenB), address(tokenA));

        assertEq(pairAddress, 0x83076b5Ae88DE7e1B187956bB69adEE497fFD77F);
    }

    function test_GetAmountOut() public {
        uint256 amountOut = JALALibrary.getAmountOut(1000, 1 ether, 1.5 ether);
        assertEq(amountOut, 1495);
    }

    function test_GetAmountOutZeroInputAmount() public {
        vm.expectRevert(JALALibrary.InsufficientInputAmount.selector);
        JALALibrary.getAmountOut(0, 1 ether, 1.5 ether);
    }

    function test_GetAmountOutZeroInputReserve() public {
        vm.expectRevert(JALALibrary.InsufficientLiquidity.selector);
        JALALibrary.getAmountOut(1000, 0, 1.5 ether);
    }

    function test_GetAmountOutZeroOutputReserve() public {
        vm.expectRevert(JALALibrary.InsufficientLiquidity.selector);
        JALALibrary.getAmountOut(1000, 1 ether, 0);
    }

    function test_GetAmountsOut() public {
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        tokenB.transfer(address(pair2), 1 ether);
        tokenC.transfer(address(pair2), 0.5 ether);
        pair2.mint(address(this));

        tokenC.transfer(address(pair3), 1 ether);
        tokenD.transfer(address(pair3), 2 ether);
        pair3.mint(address(this));

        address[] memory path = new address[](4);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        path[3] = address(tokenD);

        uint256[] memory amounts = JALALibrary.getAmountsOut(address(factory), 0.1 ether, path);

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 0.1 ether);
        assertEq(amounts[1], 0.181322178776029826 ether);
        assertEq(amounts[2], 0.076550452221167502 ether);
        assertEq(amounts[3], 0.141817942760565270 ether);
    }

    function test_GetAmountsOutInvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert(JALALibrary.InvalidPath.selector);
        JALALibrary.getAmountsOut(address(factory), 0.1 ether, path);
    }

    function test_GetAmountIn() public {
        uint256 amountIn = JALALibrary.getAmountIn(1495, 1 ether, 1.5 ether);
        assertEq(amountIn, 1000);
    }

    function test_GetAmountInZeroInputAmount() public {
        vm.expectRevert(JALALibrary.InsufficientOutputAmount.selector);
        JALALibrary.getAmountIn(0, 1 ether, 1.5 ether);
    }

    function test_GetAmountInZeroInputReserve() public {
        vm.expectRevert(JALALibrary.InsufficientLiquidity.selector);
        JALALibrary.getAmountIn(1000, 0, 1.5 ether);
    }

    function test_GetAmountInZeroOutputReserve() public {
        vm.expectRevert(JALALibrary.InsufficientLiquidity.selector);
        JALALibrary.getAmountIn(1000, 1 ether, 0);
    }

    function test_GetAmountsIn() public {
        tokenA.transfer(address(pair), 1 ether);
        tokenB.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        tokenB.transfer(address(pair2), 1 ether);
        tokenC.transfer(address(pair2), 0.5 ether);
        pair2.mint(address(this));

        tokenC.transfer(address(pair3), 1 ether);
        tokenD.transfer(address(pair3), 2 ether);
        pair3.mint(address(this));

        address[] memory path = new address[](4);
        path[0] = address(tokenA);
        path[1] = address(tokenB);
        path[2] = address(tokenC);
        path[3] = address(tokenD);

        uint256[] memory amounts = JALALibrary.getAmountsIn(address(factory), 0.1 ether, path);

        assertEq(amounts.length, 4);
        assertEq(amounts[0], 0.063113405152841847 ether);
        assertEq(amounts[1], 0.118398043685444580 ether);
        assertEq(amounts[2], 0.052789948793749671 ether);
        assertEq(amounts[3], 0.100000000000000000 ether);
    }

    function test_GetAmountsInInvalidPath() public {
        address[] memory path = new address[](1);
        path[0] = address(tokenA);

        vm.expectRevert(JALALibrary.InvalidPath.selector);
        JALALibrary.getAmountsIn(address(factory), 0.1 ether, path);
    }
}

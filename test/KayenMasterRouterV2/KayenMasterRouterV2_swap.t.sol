// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../contracts/KayenFactory.sol";
import "../../contracts/KayenPair.sol";
import "../../contracts/KayenRouter02.sol";
import "../../contracts/interfaces/IKayenRouter02.sol";
import "../../contracts/mocks/ERC20Mintable_decimal.sol";
import "../../contracts/mocks/MockWETH.sol";
import "../../contracts/KayenMasterRouterV2.sol";
import "../../contracts/utils/ChilizWrapperFactory.sol";
import "../../contracts/interfaces/IChilizWrapperFactory.sol";
import "../../contracts/libraries/KayenLibrary.sol";
import "../../contracts/libraries/Math.sol";

contract KayenMasterRouterSwap_Test is Test {
    address feeSetter = address(69);
    MockWETH public WETH;

    KayenRouter02 public router;
    KayenMasterRouterV2 public masterRouterV2;
    KayenFactory public factory;
    IChilizWrapperFactory public wrapperFactory;

    ERC20Mintable public tokenA_D0;
    ERC20Mintable public tokenB_D0;
    ERC20Mintable public tokenC_D0;

    ERC20Mintable public tokenA_D6;

    ERC20Mintable public tokenA_D18;
    ERC20Mintable public tokenB_D18;

    address user0 = vm.addr(0x01);
    address user1 = vm.addr(0x02);
    address user3 = vm.addr(0x03);

    function setUp() public {
        WETH = new MockWETH();

        factory = new KayenFactory(feeSetter);
        router = new KayenRouter02(address(factory), address(WETH));
        wrapperFactory = new ChilizWrapperFactory();
        masterRouterV2 = new KayenMasterRouterV2(address(factory), address(wrapperFactory), address(WETH));

        tokenA_D0 = new ERC20Mintable("Token A", "TKNA", 0);
        tokenB_D0 = new ERC20Mintable("Token B", "TKNB", 0);
        tokenC_D0 = new ERC20Mintable("Token C", "TKNC", 0);

        tokenA_D6 = new ERC20Mintable("Token A", "TKNA", 6);
        tokenA_D18 = new ERC20Mintable("Token B", "TKNA", 18);

        tokenB_D18 = new ERC20Mintable("Token A", "TKNA", 18);

        vm.deal(address(this), 2000000 ether);
        vm.deal(user0, 2000000 ether);
        vm.deal(user1, 2000000 ether);

        tokenA_D0.mint(1000000 ether, address(this));
        tokenB_D0.mint(1000000 ether, address(this));
        tokenC_D0.mint(1000000 ether, address(this));

        tokenA_D6.mint(2000000 * 1e6, address(this));
        tokenA_D18.mint(1000000 * 1e18, address(this));
        tokenB_D18.mint(1000000 * 1e18, address(this));

        tokenA_D0.mint(1000000, user0);
        tokenB_D0.mint(1000000, user0);
        tokenC_D0.mint(1000000, user0);

        tokenA_D6.mint(1000000 * 1e6, user0);
        tokenA_D18.mint(1000000 * 1e18, user0);
        tokenB_D18.mint(1000000 * 1e18, user0);

        tokenA_D0.mint(1000000, user1);
        tokenB_D0.mint(1000000, user1);
        tokenC_D0.mint(1000000, user1);

        tokenA_D6.mint(1000000 * 1e6, user1);
        tokenA_D18.mint(1000000 * 1e18, user1);
        tokenB_D18.mint(1000000 * 1e18, user1);
    }

    receive() external payable {}

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    /***********************
     ***      swap       ***
     ***********************/
    function test_SwapExactTokensForTokens_D0_D0() public {
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenA_D0));
        address wrappedTokenB = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenB_D0));

        uint256 approvalAmount = 100;
        tokenA_D0.approve(address(masterRouterV2), approvalAmount);
        tokenB_D0.approve(address(masterRouterV2), approvalAmount);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenB_D0),
            approvalAmount,
            approvalAmount,
            90,
            90,
            true,
            true,
            user0,
            block.timestamp
        );

        address pairAddress = factory.getPair(wrappedTokenA, wrappedTokenB);
        (uint112 initialReserve0, uint112 initialReserve1, ) = KayenPair(pairAddress).getReserves();

        uint256 initialBalanceA = tokenA_D0.balanceOf(user0);
        uint256 initialBalanceB = tokenB_D0.balanceOf(user0);

        address[] memory path = new address[](2);
        path[0] = wrappedTokenA;
        path[1] = wrappedTokenB;

        uint256 swapAmount = 50;
        vm.startPrank(user0);
        tokenA_D0.approve(address(masterRouterV2), swapAmount);
        uint256[] memory amounts = masterRouterV2.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            false,
            true,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        (uint112 finalReserve0, uint112 finalReserve1, ) = KayenPair(pairAddress).getReserves();

        // Assertions
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount * 1e18, "Incorrect input amount");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");
        assertGt(finalReserve0, initialReserve0, "Reserve0 should decrease");
        assertLt(finalReserve1, initialReserve1, "Reserve1 should increase");

        uint256 finalBalanceA = tokenA_D0.balanceOf(user0);
        uint256 finalBalanceB = tokenB_D0.balanceOf(user0);
        uint256 finalBalanceWrappedA = IERC20(wrappedTokenA).balanceOf(user0);
        uint256 finalBalanceWrappedB = IERC20(wrappedTokenB).balanceOf(user0);
        assertEq(finalBalanceA, initialBalanceA - amounts[0] / 1e18, "Incorrect final balance of tokenA");
        assertEq(finalBalanceB, initialBalanceB + amounts[1] / 1e18, "Incorrect final balance of tokenB");
        assertEq(finalBalanceWrappedA, amounts[0] % 1e18, "Incorrect final balance of wrapped tokenA");
        assertEq(finalBalanceWrappedB, amounts[1] % 1e18, "Incorrect final balance of wrapped tokenB");
    }

    function test_SwapExactTokensForTokens_D6_D0() public {
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenA_D0));

        uint256 approvalAmount = 100;
        tokenA_D0.approve(address(masterRouterV2), approvalAmount);
        tokenA_D6.approve(address(masterRouterV2), approvalAmount * 1e6);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenA_D6),
            approvalAmount,
            approvalAmount * 1e6,
            90,
            90 * 1e6,
            true,
            false,
            address(0),
            block.timestamp
        );

        address pairAddress = factory.getPair(wrappedTokenA, address(tokenA_D6));
        (uint112 initialReserve0, uint112 initialReserve1, ) = KayenPair(pairAddress).getReserves();

        uint256 initialBalanceA = tokenA_D0.balanceOf(user0);
        uint256 initialBalanceB = tokenA_D6.balanceOf(user0);

        address[] memory path = new address[](2);
        path[0] = address(tokenA_D6);
        path[1] = wrappedTokenA;

        uint256 swapAmount = 5e6;
        vm.startPrank(user0);
        tokenA_D6.approve(address(masterRouterV2), swapAmount);
        uint256[] memory amounts = masterRouterV2.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            false,
            true,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        (uint112 finalReserve0, uint112 finalReserve1, ) = KayenPair(pairAddress).getReserves();

        // Assertions
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount, "Incorrect input amount");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");

        // Check if the reserves have changed correctly
        assertLt(finalReserve0, initialReserve0, "Reserve0 should decrease");
        assertGt(finalReserve1, initialReserve1, "Reserve1 should increase");

        uint256 finalBalanceA = tokenA_D0.balanceOf(user0);
        uint256 finalBalanceB = tokenA_D6.balanceOf(user0);
        uint256 finalBalanceWrappedA = IERC20(wrappedTokenA).balanceOf(user0);

        assertEq(finalBalanceB, initialBalanceB - swapAmount, "Incorrect final balance of tokenB (D6)");
        assertEq(finalBalanceA, initialBalanceA + amounts[1] / 1e18, "Incorrect final balance of tokenA (D0)");
        assertEq(finalBalanceWrappedA, amounts[1] % 1e18, "Incorrect final balance of wrapped tokenA");

        // Check if the sum of unwrapped and wrapped tokens equals the output amount
        assertEq(
            (finalBalanceA - initialBalanceA) * 1e18 + finalBalanceWrappedA,
            amounts[1],
            "Sum of unwrapped and wrapped tokens should equal output amount"
        );
    }

    function test_SwapExactTokensForTokens_D0_D6() public {
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenA_D0));

        uint256 approvalAmount = 100;
        tokenA_D0.approve(address(masterRouterV2), approvalAmount);
        tokenA_D6.approve(address(masterRouterV2), approvalAmount * 1e6);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenA_D6),
            approvalAmount,
            approvalAmount * 1e6,
            90,
            90 * 1e6,
            true,
            false,
            address(0),
            block.timestamp
        );

        address pairAddress = factory.getPair(wrappedTokenA, address(tokenA_D6));
        (uint112 initialReserve0, uint112 initialReserve1, ) = KayenPair(pairAddress).getReserves();

        uint256 initialBalanceA = tokenA_D0.balanceOf(user0);
        uint256 initialBalanceB = tokenA_D6.balanceOf(user0);

        address[] memory path = new address[](2);
        path[0] = wrappedTokenA;
        path[1] = address(tokenA_D6);

        uint256 swapAmount = 5;
        vm.startPrank(user0);
        tokenA_D0.approve(address(masterRouterV2), swapAmount);
        uint256[] memory amounts = masterRouterV2.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            false,
            true,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        (uint112 finalReserve0, uint112 finalReserve1, ) = KayenPair(pairAddress).getReserves();

        // Assertions
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount * 1e18, "Incorrect input amount");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");
        assertGt(finalReserve0, initialReserve0, "Reserve0 should decrease");
        assertLt(finalReserve1, initialReserve1, "Reserve1 should increase");

        uint256 finalBalanceA = tokenA_D0.balanceOf(user0);
        uint256 finalBalanceB = tokenA_D6.balanceOf(user0);
        uint256 finalBalanceWrappedA = IERC20(wrappedTokenA).balanceOf(user0);
        assertEq(finalBalanceA, initialBalanceA - swapAmount, "Incorrect final balance of tokenA");
        assertEq(finalBalanceB, initialBalanceB + amounts[1], "Incorrect final balance of tokenB");
        assertEq(finalBalanceWrappedA, amounts[0] % 1e18, "Incorrect final balance of wrapped tokenA");
    }

    function test_SwapExactTokensForTokens_D6_D18() public {
        uint256 approvalAmount = 100 * 1e6;
        tokenA_D6.approve(address(masterRouterV2), approvalAmount);
        tokenA_D18.approve(address(masterRouterV2), approvalAmount * 1e12);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D6),
            address(tokenA_D18),
            approvalAmount,
            approvalAmount * 1e12,
            90 * 1e6,
            90 * 1e18,
            false,
            false,
            address(0),
            block.timestamp
        );

        address pairAddress = factory.getPair(address(tokenA_D6), address(tokenA_D18));
        (uint112 initialReserve0, uint112 initialReserve1, ) = KayenPair(pairAddress).getReserves();

        uint256 initialBalanceA = tokenA_D6.balanceOf(user0);
        uint256 initialBalanceB = tokenA_D18.balanceOf(user0);

        address[] memory path = new address[](2);
        path[0] = address(tokenA_D6);
        path[1] = address(tokenA_D18);

        uint256 swapAmount = 5 * 1e6;
        vm.startPrank(user0);
        tokenA_D6.approve(address(masterRouterV2), swapAmount);
        uint256[] memory amounts = masterRouterV2.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            false,
            false,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        (uint112 finalReserve0, uint112 finalReserve1, ) = KayenPair(pairAddress).getReserves();

        // Assertions
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount, "Incorrect input amount");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");
        assertGt(finalReserve0, initialReserve0, "Reserve0 should increase");
        assertLt(finalReserve1, initialReserve1, "Reserve1 should decrease");

        uint256 finalBalanceA = tokenA_D6.balanceOf(user0);
        uint256 finalBalanceB = tokenA_D18.balanceOf(user0);
        assertEq(finalBalanceA, initialBalanceA - amounts[0], "Incorrect final balance of tokenA_D6");
        assertEq(finalBalanceB, initialBalanceB + amounts[1], "Incorrect final balance of tokenA_D18");
    }

    function test_SwapExactTokensForTokens_D18_D6() public {
        uint256 approvalAmount = 100 * 1e6;
        tokenA_D6.approve(address(masterRouterV2), approvalAmount);
        tokenA_D18.approve(address(masterRouterV2), approvalAmount * 1e12);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D6),
            address(tokenA_D18),
            approvalAmount,
            approvalAmount * 1e12,
            90 * 1e6,
            90 * 1e18,
            false,
            false,
            address(0),
            block.timestamp
        );

        address pairAddress = factory.getPair(address(tokenA_D6), address(tokenA_D18));
        (uint112 initialReserve0, uint112 initialReserve1, ) = KayenPair(pairAddress).getReserves();

        uint256 initialBalanceA = tokenA_D18.balanceOf(user0);
        uint256 initialBalanceB = tokenA_D6.balanceOf(user0);

        address[] memory path = new address[](2);
        path[0] = address(tokenA_D18);
        path[1] = address(tokenA_D6);

        uint256 swapAmount = 5 * 1e18;
        vm.startPrank(user0);
        tokenA_D18.approve(address(masterRouterV2), swapAmount);
        uint256[] memory amounts = masterRouterV2.swapExactTokensForTokens(
            swapAmount,
            0,
            path,
            false,
            false,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        (uint112 finalReserve0, uint112 finalReserve1, ) = KayenPair(pairAddress).getReserves();

        // Assertions
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount, "Incorrect input amount");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");
        assertLt(finalReserve0, initialReserve0, "Reserve0 should decrease");
        assertGt(finalReserve1, initialReserve1, "Reserve1 should increase");

        uint256 finalBalanceA = tokenA_D18.balanceOf(user0);
        uint256 finalBalanceB = tokenA_D6.balanceOf(user0);
        assertEq(finalBalanceA, initialBalanceA - amounts[0], "Incorrect final balance of tokenA_D18");
        assertEq(finalBalanceB, initialBalanceB + amounts[1], "Incorrect final balance of tokenA_D6");
    }

    function test_swapExactETHForTokens_ETH_D0_ReceiveUnwrapped() public {
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenA_D0));

        // Add initial liquidity
        tokenA_D0.approve(address(masterRouterV2), 1000);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 100 ether
        }(address(tokenA_D0), 1000, 90, 0.9 ether, true, address(this), block.timestamp);

        address pairAddress = factory.getPair(wrappedTokenA, address(WETH));
        (address token0, address token1) = wrappedTokenA < address(WETH)
            ? (wrappedTokenA, address(WETH))
            : (address(WETH), wrappedTokenA);
        (uint112 initialReserve0, uint112 initialReserve1, ) = KayenPair(pairAddress).getReserves();

        uint256 initialBalanceToken = tokenA_D0.balanceOf(user0);
        uint256 initialBalanceETH = user0.balance;

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = wrappedTokenA;

        uint256 swapAmount = 0.1 ether;
        vm.startPrank(user0);
        uint256[] memory amounts = masterRouterV2.swapExactETHForTokens{value: swapAmount}(
            0,
            path,
            true,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        (uint112 finalReserve0, uint112 finalReserve1, ) = KayenPair(pairAddress).getReserves();

        // Assertions
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount, "Incorrect input amount");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");

        if (token0 == address(WETH)) {
            assertGt(finalReserve0, initialReserve0, "Reserve0 (WETH) should increase");
            assertLt(finalReserve1, initialReserve1, "Reserve1 (wrapped token) should decrease");
        } else {
            assertLt(finalReserve0, initialReserve0, "Reserve0 (wrapped token) should decrease");
            assertGt(finalReserve1, initialReserve1, "Reserve1 (WETH) should increase");
        }

        uint256 finalBalanceToken = tokenA_D0.balanceOf(user0);
        uint256 finalBalanceETH = user0.balance;
        uint256 finalBalanceWrappedToken = IERC20(wrappedTokenA).balanceOf(user0);
        assertEq(finalBalanceToken, initialBalanceToken + amounts[1] / 1e18, "Incorrect final balance of tokenA_D0");
        assertEq(finalBalanceETH, initialBalanceETH - swapAmount, "Incorrect final balance of ETH");
        assertEq(finalBalanceWrappedToken, amounts[1] % 1e18, "Incorrect final balance of wrapped token");
    }

    function test_swapExactETHForTokens_ETH_D0_ReceiveWrapped() public {
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenA_D0));

        // Add initial liquidity
        tokenA_D0.approve(address(masterRouterV2), 1000);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 100 ether
        }(address(tokenA_D0), 1000, 90, 0.9 ether, true, address(this), block.timestamp);

        address pairAddress = factory.getPair(wrappedTokenA, address(WETH));
        (address token0, address token1) = wrappedTokenA < address(WETH)
            ? (wrappedTokenA, address(WETH))
            : (address(WETH), wrappedTokenA);
        (uint112 initialReserve0, uint112 initialReserve1, ) = KayenPair(pairAddress).getReserves();

        uint256 initialBalanceToken = tokenA_D0.balanceOf(user0);
        uint256 initialBalanceETH = user0.balance;
        uint256 initialBalanceWrappedToken = IERC20(wrappedTokenA).balanceOf(user0);

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = wrappedTokenA;

        uint256 swapAmount = 0.1 ether;
        vm.startPrank(user0);
        uint256[] memory amounts = masterRouterV2.swapExactETHForTokens{value: swapAmount}(
            0,
            path,
            false,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        (uint112 finalReserve0, uint112 finalReserve1, ) = KayenPair(pairAddress).getReserves();

        // Assertions
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount, "Incorrect input amount");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");

        if (token0 == address(WETH)) {
            assertGt(finalReserve0, initialReserve0, "Reserve0 (WETH) should increase");
            assertLt(finalReserve1, initialReserve1, "Reserve1 (wrapped token) should decrease");
        } else {
            assertLt(finalReserve0, initialReserve0, "Reserve0 (wrapped token) should decrease");
            assertGt(finalReserve1, initialReserve1, "Reserve1 (WETH) should increase");
        }

        uint256 finalBalanceToken = tokenA_D0.balanceOf(user0);
        uint256 finalBalanceETH = user0.balance;
        uint256 finalBalanceWrappedToken = IERC20(wrappedTokenA).balanceOf(user0);
        assertEq(finalBalanceToken, initialBalanceToken, "Balance of tokenA_D0 should not change");
        assertEq(finalBalanceETH, initialBalanceETH - swapAmount, "Incorrect final balance of ETH");
        assertEq(
            finalBalanceWrappedToken,
            initialBalanceWrappedToken + amounts[1],
            "Incorrect final balance of wrapped token"
        );
    }

    function test_swapExactETHForTokens_ETH_D6_ReceiveUnwrapped() public {
        // Add initial liquidity
        tokenA_D6.approve(address(masterRouterV2), 1000000);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 100 ether
        }(address(tokenA_D6), 1000000, 900000, 0.9 ether, false, address(this), block.timestamp);

        address pairAddress = factory.getPair(address(tokenA_D6), address(WETH));
        (address token0, address token1) = address(tokenA_D6) < address(WETH)
            ? (address(tokenA_D6), address(WETH))
            : (address(WETH), address(tokenA_D6));
        (uint112 initialReserve0, uint112 initialReserve1, ) = KayenPair(pairAddress).getReserves();

        uint256 initialBalanceToken = tokenA_D6.balanceOf(user0);
        uint256 initialBalanceETH = user0.balance;

        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(tokenA_D6);

        uint256 swapAmount = 0.1 ether;
        vm.startPrank(user0);
        uint256[] memory amounts = masterRouterV2.swapExactETHForTokens{value: swapAmount}(
            0,
            path,
            false,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        (uint112 finalReserve0, uint112 finalReserve1, ) = KayenPair(pairAddress).getReserves();

        // Assertions
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount, "Incorrect input amount");
        assertGt(amounts[1], 0, "Output amount should be greater than 0");

        if (token0 == address(WETH)) {
            assertGt(finalReserve0, initialReserve0, "Reserve0 (WETH) should increase");
            assertLt(finalReserve1, initialReserve1, "Reserve1 (tokenA_D6) should decrease");
        } else {
            assertLt(finalReserve0, initialReserve0, "Reserve0 (tokenA_D6) should decrease");
            assertGt(finalReserve1, initialReserve1, "Reserve1 (WETH) should increase");
        }

        uint256 finalBalanceToken = tokenA_D6.balanceOf(user0);
        uint256 finalBalanceETH = user0.balance;
        assertEq(finalBalanceToken, initialBalanceToken + amounts[1], "Incorrect final balance of tokenA_D6");
        assertEq(finalBalanceETH, initialBalanceETH - swapAmount, "Incorrect final balance of ETH");
    }

    function test_swapExactTokensForETH_D0_ETH() public {
        // 1. Add initial liquidity
        tokenA_D0.approve(address(masterRouterV2), 1000000);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 100 ether
        }(address(tokenA_D0), 1000000, 900000, 0.9 ether, true, address(this), block.timestamp);

        // 2. Prepare for swap
        address[] memory path = new address[](2);
        path[0] = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenA_D0));
        path[1] = address(WETH);

        uint256 swapAmount = 100000; // Amount of tokenA_D0 to swap
        uint256 expectedMinETH = 0.09 ether; // Minimum amount of ETH expected
        uint256 initialTokenBalance = tokenA_D0.balanceOf(user0);

        vm.startPrank(user0);
        tokenA_D0.approve(address(masterRouterV2), swapAmount);
        uint256 initialETHBalance = user0.balance;

        // 3. Execute swapExactTokensForETH
        uint256[] memory amounts = masterRouterV2.swapExactTokensForETH(
            swapAmount,
            expectedMinETH,
            path,
            false,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // 4. Assert
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount * 1e18, "Incorrect input amount");
        assertGt(amounts[1], expectedMinETH, "Output ETH amount should be greater than minimum expected");

        assertEq(
            tokenA_D0.balanceOf(user0),
            initialTokenBalance - swapAmount,
            "User should have the correct amount of tokenA_D0 left"
        );
        assertGt(user0.balance, initialETHBalance, "User's ETH balance should have increased");
        assertEq(
            user0.balance,
            initialETHBalance + amounts[1],
            "User's ETH balance increase should match the swap output"
        );
    }

    function test_swapExactTokensForETH_D6_ETH() public {
        // 1. Add initial liquidity
        tokenA_D6.approve(address(masterRouterV2), 1000000 * 1e6);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 100 ether
        }(address(tokenA_D6), 1000000 * 1e6, 900000 * 1e6, 0.9 ether, false, address(this), block.timestamp);

        // 2. Prepare for swap
        address[] memory path = new address[](2);
        path[0] = address(tokenA_D6);
        path[1] = address(WETH);

        uint256 swapAmount = 100000 * 1e6; // Amount of tokenA_D6 to swap
        uint256 expectedMinETH = 0.09 ether; // Minimum amount of ETH expected
        uint256 initialTokenBalance = tokenA_D6.balanceOf(user0);

        vm.startPrank(user0);
        tokenA_D6.approve(address(masterRouterV2), swapAmount);
        uint256 initialETHBalance = user0.balance;

        // 3. Execute swapExactTokensForETH
        uint256[] memory amounts = masterRouterV2.swapExactTokensForETH(
            swapAmount,
            expectedMinETH,
            path,
            false,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // 4. Assert
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount, "Incorrect input amount");
        assertGt(amounts[1], expectedMinETH, "Output ETH amount should be greater than minimum expected");

        assertEq(
            tokenA_D6.balanceOf(user0),
            initialTokenBalance - swapAmount,
            "User should have the correct amount of tokenA_D6 left"
        );
        assertGt(user0.balance, initialETHBalance, "User's ETH balance should have increased");
        assertEq(
            user0.balance,
            initialETHBalance + amounts[1],
            "User's ETH balance increase should match the swap output"
        );
    }

    function test_swapExactTokensForETH_D18_ETH() public {
        // 1. Add initial liquidity
        tokenA_D18.approve(address(masterRouterV2), 1000000 * 1e18);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 100 ether
        }(address(tokenA_D18), 1000000 * 1e18, 900000 * 1e18, 0.9 ether, false, address(this), block.timestamp);

        // 2. Prepare for swap
        address[] memory path = new address[](2);
        path[0] = address(tokenA_D18);
        path[1] = address(WETH);

        uint256 swapAmount = 100000 * 1e18; // Amount of tokenA_D18 to swap
        uint256 expectedMinETH = 0.09 ether; // Minimum amount of ETH expected
        uint256 initialTokenBalance = tokenA_D18.balanceOf(user0);

        vm.startPrank(user0);
        tokenA_D18.approve(address(masterRouterV2), swapAmount);
        uint256 initialETHBalance = user0.balance;

        // 3. Execute swapExactTokensForETH
        uint256[] memory amounts = masterRouterV2.swapExactTokensForETH(
            swapAmount,
            expectedMinETH,
            path,
            false,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // 4. Assert
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[0], swapAmount, "Incorrect input amount");
        assertGt(amounts[1], expectedMinETH, "Output ETH amount should be greater than minimum expected");

        assertEq(
            tokenA_D18.balanceOf(user0),
            initialTokenBalance - swapAmount,
            "User should have the correct amount of tokenA_D18 left"
        );
        assertGt(user0.balance, initialETHBalance, "User's ETH balance should have increased");
        assertEq(
            user0.balance,
            initialETHBalance + amounts[1],
            "User's ETH balance increase should match the swap output"
        );
    }

    function test_swapTokensForExactTokens_D0_D6() public {
        // test swapTokensForExactTokens. swap path: D0 -> D6
        // D0 should be wrapped, D6 should be unwrapped

        // 1. wraptokenandaddliquidity()
        uint256 approvalAmount = 1000000;
        tokenA_D0.approve(address(masterRouterV2), approvalAmount);
        tokenA_D6.approve(address(masterRouterV2), approvalAmount * 1e6);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenA_D6),
            approvalAmount,
            approvalAmount * 1e6,
            900000,
            900000 * 1e6,
            true,
            false,
            address(this),
            block.timestamp
        );

        // 2. swapTokensForExactTokens()
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenA_D0));
        address[] memory path = new address[](2);
        path[0] = wrappedTokenA;
        path[1] = address(tokenA_D6);

        uint256 amountOut = 50000 * 1e6; // Exact amount of tokenA_D6 we want to receive
        uint256 maxAmountIn = 60000 * 1e18; // Maximum amount of wrapped tokenA_D0 we're willing to spend

        uint256 initialBalanceA = tokenA_D0.balanceOf(user0);
        uint256 initialBalanceB = tokenA_D6.balanceOf(user0);

        vm.startPrank(user0);
        tokenA_D0.approve(address(masterRouterV2), maxAmountIn / 1e18);
        uint256[] memory amounts = masterRouterV2.swapTokensForExactTokens(
            amountOut,
            maxAmountIn,
            path,
            false,
            true,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // 3. assert
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[1], amountOut, "Incorrect output amount");
        assertLe(amounts[0], maxAmountIn * 1e18, "Input amount exceeds maximum");

        uint256 finalBalanceA = tokenA_D0.balanceOf(user0);
        uint256 finalBalanceB = tokenA_D6.balanceOf(user0);

        assertEq(finalBalanceA, initialBalanceA - (amounts[0] / 1e18 + 1), "Incorrect final balance of tokenA_D0");
        assertEq(finalBalanceB, initialBalanceB + amountOut, "Incorrect final balance of tokenA_D6");

        uint256 finalBalanceWrappedA = IERC20(wrappedTokenA).balanceOf(user0);
        assertEq(1e18 - (amounts[0] % 1e18), finalBalanceWrappedA, "Incorrect final balance of wrapped tokenA_D0");
    }

    function test_swapTokensForExactTokens_D6_D0() public {
        // test swapTokensForExactTokens. swap path: D6 -> D0
        // D6 should be unwrapped, D0 should be wrapped

        // 1. wraptokenandaddliquidity()
        uint256 approvalAmount = 1000000;
        tokenA_D0.approve(address(masterRouterV2), approvalAmount);
        tokenA_D6.approve(address(masterRouterV2), approvalAmount * 1e6);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenA_D6),
            approvalAmount,
            approvalAmount * 1e6,
            900000,
            900000 * 1e6,
            true,
            false,
            address(this),
            block.timestamp
        );

        // 2. swapTokensForExactTokens()
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenA_D0));
        address[] memory path = new address[](2);
        path[0] = address(tokenA_D6);
        path[1] = wrappedTokenA;

        uint256 amountOut = 50000 * 1e18; // Exact amount of wrapped tokenA_D0 we want to receive
        uint256 maxAmountIn = 60000 * 1e6; // Maximum amount of tokenA_D6 we're willing to spend

        uint256 initialBalanceA = tokenA_D0.balanceOf(user0);
        uint256 initialBalanceB = tokenA_D6.balanceOf(user0);

        vm.startPrank(user0);
        tokenA_D6.approve(address(masterRouterV2), maxAmountIn);
        uint256[] memory amounts = masterRouterV2.swapTokensForExactTokens(
            amountOut,
            maxAmountIn,
            path,
            false,
            true,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // 3. assert
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[1], amountOut, "Incorrect output amount");
        assertLe(amounts[0], maxAmountIn, "Input amount exceeds maximum");

        uint256 finalBalanceA = tokenA_D0.balanceOf(user0);
        uint256 finalBalanceB = tokenA_D6.balanceOf(user0);

        assertEq(finalBalanceB, initialBalanceB - amounts[0], "Incorrect final balance of tokenA_D6");
        assertEq(finalBalanceA, initialBalanceA + (amountOut / 1e18), "Incorrect final balance of tokenA_D0");

        uint256 finalBalanceWrappedA = IERC20(wrappedTokenA).balanceOf(user0);
        assertEq(amountOut % 1e18, finalBalanceWrappedA, "Incorrect final balance of wrapped tokenA_D0");
    }

    function test_swapTokensForExactETH_D0_ETH() public {
        // Test swapTokensForExactETH. Swap path: D0 -> ETH
        // D0 should be wrapped

        // 1. Add liquidity with wrapTokenAndaddLiquidityETH()
        uint256 tokenAmount = 1000000;
        uint256 ethAmount = 10 ether;
        tokenA_D0.approve(address(masterRouterV2), tokenAmount);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: ethAmount
        }(
            address(tokenA_D0),
            tokenAmount,
            (tokenAmount * 9) / 10,
            (ethAmount * 9) / 10,
            true,
            address(this),
            block.timestamp
        );

        // 2. Prepare for swap
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(address(tokenA_D0));
        address[] memory path = new address[](2);
        path[0] = wrappedTokenA;
        path[1] = address(WETH);

        uint256 ethOutAmount = 0.5 ether;
        uint256 maxTokensIn = 60000 * 1e18;

        uint256 initialTokenBalance = tokenA_D0.balanceOf(user0);
        uint256 initialEthBalance = user0.balance;

        // 3. Execute swapTokensForExactETH
        vm.startPrank(user0);
        tokenA_D0.approve(address(masterRouterV2), maxTokensIn);
        uint256[] memory amounts = masterRouterV2.swapTokensForExactETH(
            ethOutAmount,
            maxTokensIn,
            path,
            false,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // 4. Assert
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[1], ethOutAmount, "Incorrect ETH output amount");
        assertLe(amounts[0], maxTokensIn * 1e18, "Input amount exceeds maximum");

        uint256 finalTokenBalance = tokenA_D0.balanceOf(user0);
        uint256 finalEthBalance = user0.balance;

        assertEq(
            finalTokenBalance,
            initialTokenBalance - (amounts[0] / 1e18 + 1),
            "Incorrect final balance of tokenA_D0"
        );
        assertEq(finalEthBalance, initialEthBalance + ethOutAmount, "Incorrect final ETH balance");

        uint256 finalWrappedTokenBalance = IERC20(wrappedTokenA).balanceOf(user0);
        assertEq(1e18 - (amounts[0] % 1e18), finalWrappedTokenBalance, "Incorrect final balance of wrapped tokenA_D0");
    }

    function test_swapTokensForExactETH_D18_ETH() public {
        // Test swapTokensForExactETH. Swap path: D18 -> ETH
        // D18 should not be wrapped

        // 1. Add liquidity with addLiquidityETH()
        uint256 tokenAmount = 1000 ether; // 1000 tokens with 18 decimals
        uint256 ethAmount = 10 ether;
        tokenA_D18.approve(address(masterRouterV2), tokenAmount);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: ethAmount
        }(
            address(tokenA_D18),
            tokenAmount,
            (tokenAmount * 9) / 10,
            (ethAmount * 9) / 10,
            false, // wrapToken should be false for D18 tokens
            address(this),
            block.timestamp
        );
        // 2. Prepare for swap
        address[] memory path = new address[](2);
        path[0] = address(tokenA_D18);
        path[1] = address(WETH);

        uint256 ethOutAmount = 0.5 ether;
        uint256 maxTokensIn = 600 ether;

        uint256 initialTokenBalance = tokenA_D18.balanceOf(user0);
        uint256 initialEthBalance = user0.balance;

        // 3. Execute swapTokensForExactETH
        vm.startPrank(user0);
        tokenA_D18.approve(address(masterRouterV2), maxTokensIn);
        uint256[] memory amounts = masterRouterV2.swapTokensForExactETH(
            ethOutAmount,
            maxTokensIn,
            path,
            false, // isTokenInWrapped is true for D18 tokens
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // 4. Assert
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[1], ethOutAmount, "Incorrect ETH output amount");
        assertLe(amounts[0], maxTokensIn, "Input amount exceeds maximum");

        uint256 finalTokenBalance = tokenA_D18.balanceOf(user0);
        uint256 finalEthBalance = user0.balance;

        assertEq(finalTokenBalance, initialTokenBalance - amounts[0], "Incorrect final balance of tokenA_D18");
        assertEq(finalEthBalance, initialEthBalance + ethOutAmount, "Incorrect final ETH balance");

        // No need to check wrapped token balance as D18 is not wrapped
    }

    function test_swapETHForExactTokens_ETH_D0() public {
        // Test swapETHForExactTokens. Swap path: ETH -> D0
        // D0 should be wrapped

        // 1. Add liquidity with wrapTokenAndaddLiquidityETH()
        uint256 tokenAmount = 1000; // 1000 tokens with 0 decimals
        uint256 ethAmount = 10 ether;
        tokenA_D0.approve(address(masterRouterV2), tokenAmount);
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: ethAmount
        }(
            address(tokenA_D0),
            tokenAmount,
            (tokenAmount * 9) / 10,
            (ethAmount * 9) / 10,
            true, // wrapToken should be true for D0 tokens
            address(this),
            block.timestamp
        );
        // 2. Prepare for swap
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        address wrappedTokenA_D0 = IChilizWrapperFactory(wrapperFactory).underlyingToWrapped(address(tokenA_D0));
        path[1] = wrappedTokenA_D0;

        uint256 tokenOutAmount = 50e18 + 1; // 50 tokens with 0 decimals
        uint256 maxEthIn = 1 ether;

        uint256 initialTokenBalance = tokenA_D0.balanceOf(user0);
        uint256 initialEthBalance = user0.balance;

        // 3. Execute swapETHForExactTokens
        vm.startPrank(user0);
        uint256[] memory amounts = masterRouterV2.swapETHForExactTokens{value: maxEthIn}(
            tokenOutAmount,
            path,
            true, // receiveUnwrappedToken should be true to get D0 tokens
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // 4. Assert
        assertEq(amounts.length, 2, "Incorrect number of amounts returned");
        assertEq(amounts[1], tokenOutAmount, "Incorrect token output amount");
        assertLe(amounts[0], maxEthIn, "Input amount exceeds maximum");

        uint256 finalTokenBalance = tokenA_D0.balanceOf(user0);
        uint256 finalEthBalance = user0.balance;

        assertEq(
            finalTokenBalance,
            initialTokenBalance + tokenOutAmount / 1e18,
            "Incorrect final balance of tokenA_D0"
        );
        assertEq(finalEthBalance, initialEthBalance - amounts[0], "Incorrect final ETH balance");

        // Check that no wrapped tokens are left in the user's balance
        wrappedTokenA_D0 = IChilizWrapperFactory(wrapperFactory).underlyingToWrapped(address(tokenA_D0));
        assertEq(IERC20(wrappedTokenA_D0).balanceOf(user0), 1, "User should not have any wrapped tokens");
    }
}

// forge test --match-path test/KayenMasterRouterV2/KayenMasterRouterV2_swap.t.sol -vvvv

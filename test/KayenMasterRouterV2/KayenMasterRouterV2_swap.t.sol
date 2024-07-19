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

contract KayenMasterRouterRemoveLiquidity_Test is Test {
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
        masterRouterV2 = new KayenMasterRouterV2(
            address(factory),
            address(wrapperFactory),
            address(router),
            address(WETH)
        );

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
        assertGt(finalReserve0, initialReserve0, "Reserve0 should increase");
        assertLt(finalReserve1, initialReserve1, "Reserve1 should decrease");

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
        assertGt(finalReserve0, initialReserve0, "Reserve0 should increase");
        assertLt(finalReserve1, initialReserve1, "Reserve1 should decrease");

        uint256 finalBalanceA = tokenA_D0.balanceOf(user0);
        uint256 finalBalanceB = tokenA_D6.balanceOf(user0);
        uint256 finalBalanceWrappedA = IERC20(wrappedTokenA).balanceOf(user0);
        assertEq(finalBalanceA, initialBalanceA + amounts[1] / 1e18, "Incorrect final balance of tokenA");
        assertEq(finalBalanceB, initialBalanceB - amounts[0], "Incorrect final balance of tokenB");
        assertEq(finalBalanceWrappedA, amounts[1] % 1e18, "Incorrect final balance of wrapped tokenA");
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
        assertLt(finalReserve0, initialReserve0, "Reserve0 should decrease");
        assertGt(finalReserve1, initialReserve1, "Reserve1 should increase");

        uint256 finalBalanceA = tokenA_D0.balanceOf(user0);
        uint256 finalBalanceB = tokenA_D6.balanceOf(user0);
        uint256 finalBalanceWrappedA = IERC20(wrappedTokenA).balanceOf(user0);
        assertEq(finalBalanceA, initialBalanceA - amounts[0] / 1e18, "Incorrect final balance of tokenA");
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
}

// forge test --match-path test/KayenMasterRouterV2/KayenMasterRouterV2_swap.t.sol -vvvv

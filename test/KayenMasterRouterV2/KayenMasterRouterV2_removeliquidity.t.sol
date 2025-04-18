// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/KayenFactory.sol";
import "../../src/KayenPair.sol";
import "../../src/KayenRouter02.sol";
import "../../src/interfaces/IKayenRouter02.sol";
import "../../src/mocks/ERC20Mintable_decimal.sol";
import "../../src/mocks/MockWETH.sol";
import "../../src/KayenMasterRouterV2.sol";
import "../../src/utils/ChilizWrapperFactory.sol";
import "../../src/interfaces/IChilizWrapperFactory.sol";
import "../../src/libraries/KayenLibrary.sol";
import "../../src/libraries/Math.sol";

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
     *** RemoveLiquidity ***
     ***********************/

    function test_RemoveLiquidityAndUnwrapToken_D0_D6() public {
        uint256 initialLiquidityA = 100000; // 100000*1e18 for wrapped token
        uint256 initialLiquidityB = 200000;

        // Approve tokens for adding liquidity
        tokenA_D0.approve(address(masterRouterV2), initialLiquidityA);
        tokenA_D6.approve(address(masterRouterV2), initialLiquidityB);

        // Add initial liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenA_D6),
            initialLiquidityA,
            initialLiquidityB,
            0,
            0,
            true,
            false,
            address(this),
            block.timestamp
        );
        address wrappedTokenA = wrapperFactory.wrappedTokenFor(address(tokenA_D0));

        // Get pair address
        address pairAddress = factory.getPair(wrappedTokenA, address(tokenA_D6));

        // Approve liquidity tokens for removal
        KayenPair(pairAddress).approve(address(masterRouterV2), liquidity);

        // Check if the user received the correct amount of tokens
        uint256 tokenA_D0_BalanceBefore = tokenA_D0.balanceOf(address(this));
        uint256 tokenA_D6_BalanceBefore = tokenA_D6.balanceOf(address(this));
        uint256 wrappedTokenABalanceBefore = IERC20(wrappedTokenA).balanceOf(address(this));

        // Remove all liquidity
        (uint256 removedAmountA, uint256 removedAmountB) = masterRouterV2.removeLiquidityAndUnwrapToken(
            wrappedTokenA,
            address(tokenA_D6),
            liquidity,
            0,
            0,
            true, // isTokenAWrapped
            false, // isTokenBWrapped
            address(this),
            block.timestamp
        );

        // Check if removed amounts are within acceptable range (considering potential rounding errors)
        assertApproxEqRel(removedAmountA, amountA, 1e15, "Removed amount A should be close to initial liquidity A");
        assertApproxEqRel(removedAmountB, amountB, 1e15, "Removed amount B should be close to initial liquidity B");

        // Check if the pair's balance is nearly zero
        uint256 remainingWrappedTokenA = IERC20(wrappedTokenA).balanceOf(pairAddress);
        uint256 remainingTokenB = tokenA_D6.balanceOf(pairAddress);

        assertLe(
            remainingWrappedTokenA,
            amountA - removedAmountA,
            "Remaining wrapped token A should be less than or equal to the difference between added and removed amounts"
        );
        assertLe(
            remainingTokenB,
            amountB - removedAmountB,
            "Remaining token B should be less than or equal to the difference between added and removed amounts"
        );

        // For wrapped tokens, we need to consider the decimal offset
        uint256 decimalsOffsetA = IChilizWrappedERC20(wrapperFactory.wrappedTokenFor(address(tokenA_D0)))
            .getDecimalsOffset();

        // Check unwrapped token A balance
        assertEq(
            tokenA_D0.balanceOf(address(this)) - tokenA_D0_BalanceBefore,
            removedAmountA / decimalsOffsetA,
            "User should have received the correct amount of unwrapped token A"
        );

        // Check token B balance
        assertEq(
            tokenA_D6.balanceOf(address(this)) - tokenA_D6_BalanceBefore,
            removedAmountB,
            "User should have received the correct amount of token B"
        );

        // Check if user received dust of wrapped token correctly
        uint256 wrappedTokenABalanceAfter = IERC20(wrappedTokenA).balanceOf(address(this));
        uint256 wrappedTokenADust = wrappedTokenABalanceAfter - wrappedTokenABalanceBefore;
        assertEq(
            wrappedTokenADust,
            removedAmountA - ((removedAmountA / decimalsOffsetA) * decimalsOffsetA),
            "User should have received less than 1 unit of wrapped token A as dust"
        );
    }

    function test_RemoveLiquidityAndUnwrapToken_D0_D6_Partial() public {
        uint256 initialLiquidityA = 100000; // 100000*1e18 for wrapped token
        uint256 initialLiquidityB = 200000;

        // Approve tokens for adding liquidity
        tokenA_D0.approve(address(masterRouterV2), initialLiquidityA);
        tokenA_D6.approve(address(masterRouterV2), initialLiquidityB);

        // Add initial liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenA_D6),
            initialLiquidityA,
            initialLiquidityB,
            0,
            0,
            true,
            false,
            address(this),
            block.timestamp
        );
        address wrappedTokenA = wrapperFactory.wrappedTokenFor(address(tokenA_D0));

        // Get pair address
        address pairAddress = factory.getPair(wrappedTokenA, address(tokenA_D6));

        // Approve liquidity tokens for removal
        KayenPair(pairAddress).approve(address(masterRouterV2), liquidity);

        // Check if the user received the correct amount of tokens
        uint256 tokenA_D0_BalanceBefore = tokenA_D0.balanceOf(address(this));
        uint256 tokenA_D6_BalanceBefore = tokenA_D6.balanceOf(address(this));
        uint256 wrappedTokenABalanceBefore = IERC20(wrappedTokenA).balanceOf(address(this));

        // Remove 50% of liquidity
        uint256 liquidityToRemove = liquidity / 2;
        KayenPair(pairAddress).approve(address(masterRouterV2), liquidityToRemove);

        (uint256 removedAmountA, uint256 removedAmountB) = masterRouterV2.removeLiquidityAndUnwrapToken(
            wrappedTokenA,
            address(tokenA_D6),
            liquidityToRemove,
            0,
            0,
            true,
            false,
            address(this),
            block.timestamp
        );

        // Check remaining liquidity
        assertEq(
            KayenPair(pairAddress).totalSupply(),
            liquidity + 1000 - liquidityToRemove,
            "Incorrect remaining liquidity"
        );

        // For wrapped tokens, we need to consider the decimal offset
        uint256 decimalsOffsetA = IChilizWrappedERC20(wrapperFactory.wrappedTokenFor(address(tokenA_D0)))
            .getDecimalsOffset();

        // Check unwrapped token A balance
        assertEq(
            tokenA_D0.balanceOf(address(this)) - tokenA_D0_BalanceBefore,
            removedAmountA / decimalsOffsetA,
            "User should have received the correct amount of unwrapped token A"
        );

        // Check token B balance
        assertEq(
            tokenA_D6.balanceOf(address(this)) - tokenA_D6_BalanceBefore,
            removedAmountB,
            "User should have received the correct amount of token B"
        );

        // Check if user received dust of wrapped token correctly
        uint256 wrappedTokenABalanceAfter = IERC20(wrappedTokenA).balanceOf(address(this));
        uint256 wrappedTokenADust = wrappedTokenABalanceAfter - wrappedTokenABalanceBefore;
        assertEq(
            wrappedTokenADust,
            removedAmountA - ((removedAmountA / decimalsOffsetA) * decimalsOffsetA),
            "User should have received less than 1 unit of wrapped token A as dust"
        );

        // Check if removed amounts are approximately half of initial amounts
        assertApproxEqRel(
            removedAmountA,
            amountA / 2,
            1e15,
            "Removed amount A should be close to half of initial liquidity A"
        );
        assertApproxEqRel(
            removedAmountB,
            amountB / 2,
            1e15,
            "Removed amount B should be close to half of initial liquidity B"
        );
    }

    function test_RemoveLiquidityAndUnwrapToken_D0_D18_Partial() public {
        uint256 initialLiquidityA = 100000; // D0 token
        uint256 initialLiquidityB = 200000 * 1e18; // D18 token

        // Approve tokens for adding liquidity
        tokenA_D0.approve(address(masterRouterV2), initialLiquidityA);
        tokenB_D18.approve(address(masterRouterV2), initialLiquidityB);

        // Add initial liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenB_D18),
            initialLiquidityA,
            initialLiquidityB,
            0,
            0,
            true,
            false,
            address(this),
            block.timestamp
        );

        address wrappedTokenA = wrapperFactory.wrappedTokenFor(address(tokenA_D0));
        address pairAddress = factory.getPair(wrappedTokenA, address(tokenB_D18));

        // Check initial pool liquidity
        assertEq(KayenPair(pairAddress).totalSupply(), liquidity + 1000, "Initial liquidity mismatch");

        // Remove 50% of liquidity
        uint256 liquidityToRemove = liquidity / 2;
        KayenPair(pairAddress).approve(address(masterRouterV2), liquidityToRemove);

        uint256 tokenA_D0_BalanceBefore = tokenA_D0.balanceOf(address(this));
        uint256 tokenB_D18_BalanceBefore = tokenB_D18.balanceOf(address(this));
        uint256 wrappedTokenABalanceBefore = IERC20(wrappedTokenA).balanceOf(address(this));

        (uint256 removedAmountA, uint256 removedAmountB) = masterRouterV2.removeLiquidityAndUnwrapToken(
            wrappedTokenA,
            address(tokenB_D18),
            liquidityToRemove,
            0,
            0,
            true,
            false,
            address(this),
            block.timestamp
        );

        // Check remaining liquidity
        assertEq(
            KayenPair(pairAddress).totalSupply(),
            liquidity + 1000 - liquidityToRemove,
            "Incorrect remaining liquidity"
        );

        // For wrapped tokens, we need to consider the decimal offset
        uint256 decimalsOffsetA = IChilizWrappedERC20(wrappedTokenA).getDecimalsOffset();

        // Check unwrapped token A balance
        assertEq(
            tokenA_D0.balanceOf(address(this)) - tokenA_D0_BalanceBefore,
            removedAmountA / decimalsOffsetA,
            "User should have received the correct amount of unwrapped token A"
        );

        // Check token B balance
        assertEq(
            tokenB_D18.balanceOf(address(this)) - tokenB_D18_BalanceBefore,
            removedAmountB,
            "User should have received the correct amount of token B"
        );

        // Check if user received dust of wrapped token correctly
        uint256 wrappedTokenABalanceAfter = IERC20(wrappedTokenA).balanceOf(address(this));
        uint256 wrappedTokenADust = wrappedTokenABalanceAfter - wrappedTokenABalanceBefore;
        assertEq(
            wrappedTokenADust,
            removedAmountA - ((removedAmountA / decimalsOffsetA) * decimalsOffsetA),
            "User should have received less than 1 unit of wrapped token A as dust"
        );

        // Check if removed amounts are approximately half of initial amounts
        assertApproxEqRel(
            removedAmountA,
            amountA / 2,
            1e15,
            "Removed amount A should be close to half of initial liquidity A"
        );
        assertApproxEqRel(
            removedAmountB,
            amountB / 2,
            1e15,
            "Removed amount B should be close to half of initial liquidity B"
        );
    }

    function test_RemoveLiquidityETHAndUnwrap_D0() public {
        uint256 initialLiquidityToken = 100000; // 100000 for D0 token
        uint256 initialLiquidityETH = 1 ether;

        // Get wrapped token address
        address wrappedToken = wrapperFactory.wrappedTokenFor(address(tokenA_D0));

        // Approve tokens for adding liquidity
        tokenA_D0.approve(address(masterRouterV2), initialLiquidityToken);

        // Add initial liquidity
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: initialLiquidityETH
        }(address(tokenA_D0), initialLiquidityToken, 0, 0, true, address(this), block.timestamp);

        // Get pair address
        address pairAddress = factory.getPair(wrappedToken, address(WETH));

        // Approve liquidity tokens for removal
        KayenPair(pairAddress).approve(address(masterRouterV2), liquidity);

        // Calculate minimum amounts with 0.5% slippage
        uint256 amountTokenMin = (amountToken * 990) / 1000;
        uint256 amountETHMin = (amountETH * 990) / 1000;

        // Check balances before removal
        uint256 tokenA_D0_BalanceBefore = tokenA_D0.balanceOf(address(this));
        uint256 ethBalanceBefore = address(this).balance;
        uint256 wrappedTokenBalanceBefore = IERC20(wrappedToken).balanceOf(address(this));

        // Remove all liquidity
        (uint256 removedAmountToken, uint256 removedAmountETH) = masterRouterV2.removeLiquidityETHAndUnwrap(
            wrappedToken,
            liquidity,
            amountTokenMin,
            amountETHMin,
            true, // receiveUnwrappedToken
            address(this),
            block.timestamp
        );

        // Check if removed amounts are within acceptable range
        assertApproxEqRel(
            removedAmountToken,
            amountToken,
            1e15,
            "Removed amount token should be close to initial liquidity token"
        );
        assertApproxEqRel(
            removedAmountETH,
            amountETH,
            1e15,
            "Removed amount ETH should be close to initial liquidity ETH"
        );

        // Check if the pair's balance is nearly zero
        uint256 remainingWrappedToken = IERC20(wrappedToken).balanceOf(pairAddress);
        uint256 remainingWETH = WETH.balanceOf(pairAddress);

        assertLe(
            remainingWrappedToken,
            amountToken - removedAmountToken,
            "Remaining wrapped token should be less than or equal to the difference between added and removed amounts"
        );
        assertLe(
            remainingWETH,
            amountETH - removedAmountETH,
            "Remaining WETH should be less than or equal to the difference between added and removed amounts"
        );

        // For wrapped tokens, we need to consider the decimal offset
        uint256 decimalsOffset = IChilizWrappedERC20(wrappedToken).getDecimalsOffset();

        // Check unwrapped token balance
        assertEq(
            tokenA_D0.balanceOf(address(this)) - tokenA_D0_BalanceBefore,
            removedAmountToken / decimalsOffset,
            "User should have received the correct amount of unwrapped token"
        );

        // Check ETH balance
        assertEq(
            address(this).balance - ethBalanceBefore,
            removedAmountETH,
            "User should have received the correct amount of ETH"
        );

        // Check if user received dust of wrapped token correctly
        uint256 wrappedTokenBalanceAfter = IERC20(wrappedToken).balanceOf(address(this));
        uint256 wrappedTokenDust = wrappedTokenBalanceAfter - wrappedTokenBalanceBefore;
        assertEq(
            wrappedTokenDust,
            removedAmountToken - ((removedAmountToken / decimalsOffset) * decimalsOffset),
            "User should have received less than 1 unit of wrapped token as dust"
        );
    }

    function test_RemoveLiquidityETHAndUnwrap_D0_Partial() public {
        uint256 initialLiquidityToken = 100000; // 100000 for D0 token
        uint256 initialLiquidityETH = 1 ether;

        // Get wrapped token address
        address wrappedToken = wrapperFactory.wrappedTokenFor(address(tokenA_D0));

        // Approve tokens for adding liquidity
        tokenA_D0.approve(address(masterRouterV2), initialLiquidityToken);

        // Add initial liquidity
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: initialLiquidityETH
        }(address(tokenA_D0), initialLiquidityToken, 0, 0, true, address(this), block.timestamp);

        // Get pair address
        address pairAddress = factory.getPair(wrappedToken, address(WETH));

        // Approve liquidity tokens for removal
        KayenPair(pairAddress).approve(address(masterRouterV2), liquidity);

        // Remove 50% of liquidity
        uint256 liquidityToRemove = liquidity / 2;

        // Check balances before removal
        uint256 tokenA_D0_BalanceBefore = tokenA_D0.balanceOf(address(this));
        uint256 ethBalanceBefore = address(this).balance;
        uint256 wrappedTokenBalanceBefore = IERC20(wrappedToken).balanceOf(address(this));

        // Calculate minimum amounts with 0.5% slippage
        uint256 amountTokenMin = (amountToken * 990) / 2000; // Half of the initial amount with 0.5% slippage
        uint256 amountETHMin = (amountETH * 990) / 2000; // Half of the initial amount with 0.5% slippage

        (uint256 removedAmountToken, uint256 removedAmountETH) = masterRouterV2.removeLiquidityETHAndUnwrap(
            wrappedToken,
            liquidityToRemove,
            amountTokenMin,
            amountETHMin,
            true,
            address(this),
            block.timestamp
        );

        // Check remaining liquidity
        assertEq(
            KayenPair(pairAddress).totalSupply(),
            liquidity + 1000 - liquidityToRemove,
            "Incorrect remaining liquidity"
        );

        // For wrapped tokens, we need to consider the decimal offset
        uint256 decimalsOffset = IChilizWrappedERC20(wrappedToken).getDecimalsOffset();

        // Check unwrapped token balance
        assertEq(
            tokenA_D0.balanceOf(address(this)) - tokenA_D0_BalanceBefore,
            removedAmountToken / decimalsOffset,
            "User should have received the correct amount of unwrapped token"
        );

        // Check ETH balance
        assertEq(
            address(this).balance - ethBalanceBefore,
            removedAmountETH,
            "User should have received the correct amount of ETH"
        );

        // Check if user received dust of wrapped token correctly
        uint256 wrappedTokenBalanceAfter = IERC20(wrappedToken).balanceOf(address(this));
        uint256 wrappedTokenDust = wrappedTokenBalanceAfter - wrappedTokenBalanceBefore;
        assertEq(
            wrappedTokenDust,
            removedAmountToken - ((removedAmountToken / decimalsOffset) * decimalsOffset),
            "User should have received less than 1 unit of wrapped token as dust"
        );

        // Check if removed amounts are approximately half of initial amounts
        assertApproxEqRel(
            removedAmountToken,
            amountToken / 2,
            1e15,
            "Removed amount token should be close to half of initial liquidity token"
        );
        assertApproxEqRel(
            removedAmountETH,
            amountETH / 2,
            1e15,
            "Removed amount ETH should be close to half of initial liquidity ETH"
        );

        // Check if the pair's balance is nearly half of the initial amounts
        uint256 remainingWrappedToken = IERC20(wrappedToken).balanceOf(pairAddress);
        uint256 remainingWETH = WETH.balanceOf(pairAddress);

        assertApproxEqRel(
            remainingWrappedToken,
            amountToken / 2,
            1e15,
            "Remaining wrapped token should be close to half of initial liquidity token"
        );
        assertApproxEqRel(
            remainingWETH,
            amountETH / 2,
            1e15,
            "Remaining WETH should be close to half of initial liquidity ETH"
        );
    }
}

// forge test --match-path test/KayenMasterRouterV2/KayenMasterRouterV2_removeliquidity.t.sol -vvvv

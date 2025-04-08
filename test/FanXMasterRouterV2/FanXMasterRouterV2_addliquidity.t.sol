// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../src/FanXFactory.sol";
import "../../src/FanXPair.sol";
import "../../src/FanXRouter02.sol";
import "../../src/interfaces/IFanXRouter02.sol";
import "../../src/mocks/ERC20Mintable_decimal.sol";
import "../../src/mocks/MockWETH.sol";
import "../../src/FanXMasterRouterV2.sol";
import "../../src/utils/WrapperFactory.sol";
import "../../src/interfaces/IWrapperFactory.sol";
import "../../src/libraries/FanXLibrary.sol";
import "../../src/libraries/Math.sol";

// @add assertions
contract FanXMasterRouter_Test is Test {
    address feeSetter = address(69);
    MockWETH public WETH;

    FanXRouter02 public router;
    FanXMasterRouterV2 public masterRouterV2;
    FanXFactory public factory;
    IWrapperFactory public wrapperFactory;

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

        factory = new FanXFactory(feeSetter);
        router = new FanXRouter02(address(factory), address(WETH));
        wrapperFactory = new WrapperFactory();
        masterRouterV2 = new FanXMasterRouterV2(address(factory), address(wrapperFactory), address(WETH));

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

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    /**********************
     **** AddLiquidity ****
     **********************/
    function test_AddLiquidityCreatesPair() public {
        tokenA_D0.approve(address(masterRouterV2), 10000000);
        tokenB_D0.approve(address(masterRouterV2), 10000000);

        masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenB_D0),
            1,
            1,
            0,
            0,
            true,
            true,
            user0,
            block.timestamp
        );
        address pairAddress = factory.getPair(
            wrapperFactory.wrappedTokenFor(address(tokenA_D0)),
            wrapperFactory.wrappedTokenFor(address(tokenB_D0))
        );
        uint256 liquidity = FanXPair(pairAddress).balanceOf(user0);
        console.logUint(liquidity);
        assertEq(liquidity, 1 ether - 1000);
    }

    function test_AddLiquidityETH() public {
        tokenA_D0.approve(address(masterRouterV2), 1 ether);

        masterRouterV2.wrapTokenAndaddLiquidityETH{value: 1 ether}(
            address(tokenA_D0),
            1,
            1,
            1,
            true,
            user0,
            block.timestamp
        );

        address pairAddress = factory.getPair(wrapperFactory.wrappedTokenFor(address(tokenA_D0)), address(WETH));
        uint256 liquidity = FanXPair(pairAddress).balanceOf(user0);
        console.logUint(liquidity);
        assertEq(liquidity, 1 ether - 1000);
    }

    function test_WrapTokensAndAddLiquidity_BothTokensWrapped() public {
        tokenA_D0.approve(address(masterRouterV2), 100);
        tokenB_D0.approve(address(masterRouterV2), 100);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenB_D0),
            100,
            100,
            90,
            90,
            true,
            true,
            user0,
            block.timestamp
        );

        assertEq(amountA, 100 * 1e18);
        assertEq(amountB, 100 * 1e18);
        assertGt(liquidity, 0);

        address pairAddress = factory.getPair(
            wrapperFactory.wrappedTokenFor(address(tokenA_D0)),
            wrapperFactory.wrappedTokenFor(address(tokenB_D0))
        );
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);
    }

    function test_WrapTokensAndAddLiquidity_OneTokenWrapped() public {
        tokenA_D0.approve(address(masterRouterV2), 100);
        tokenB_D18.approve(address(masterRouterV2), 100 * 1e18);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenB_D18),
            100,
            100 * 1e18,
            90,
            90 * 1e18,
            true,
            false,
            user0,
            block.timestamp
        );

        assertEq(amountA, 100 * 1e18);
        assertEq(amountB, 100 * 1e18);
        assertGt(liquidity, 0);

        address pairAddress = factory.getPair(wrapperFactory.wrappedTokenFor(address(tokenA_D0)), address(tokenB_D18));
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);
    }

    function test_WrapTokensAndAddLiquidity_InsufficientAllowance() public {
        tokenA_D0.approve(address(masterRouterV2), 50);
        tokenB_D0.approve(address(masterRouterV2), 100);

        vm.expectRevert(0x7939f424);
        masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenB_D0),
            100,
            100,
            90,
            90,
            true,
            true,
            user0,
            block.timestamp
        );
    }

    function test_AddLiquidity_D6_and_D0_Wrapped() public {
        tokenA_D6.approve(address(masterRouterV2), 1000000 * 1e6);
        tokenA_D0.approve(address(masterRouterV2), 1000);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D6),
            address(tokenA_D0),
            1000000 * 1e6,
            1000,
            900000 * 1e6,
            900,
            false,
            true,
            user0,
            block.timestamp
        );

        assertEq(amountA, 1000000 * 1e6);
        assertEq(amountB, 1000 * 1e18); // 1000 tokens with 0 decimals wrapped to 18 decimals
        assertGt(liquidity, 0);

        address pairAddress = factory.getPair(address(tokenA_D6), wrapperFactory.wrappedTokenFor(address(tokenA_D0)));
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);
        // Check expected liquidity amount
        uint256 expectedLiquidity = Math.sqrt(amountA * amountB) - FanXPair(pairAddress).MINIMUM_LIQUIDITY();

        // Check actual liquidity amount user has
        uint256 actualLiquidity = FanXPair(pairAddress).balanceOf(user0);

        // Assert that the actual liquidity is equal to the expected liquidity
        assertEq(actualLiquidity, expectedLiquidity, "Actual liquidity does not match expected liquidity");

        // Optionally, you can add a more detailed check
        assertGt(actualLiquidity, 0, "Liquidity should be greater than zero");

        // Check balances
        assertEq(tokenA_D6.balanceOf(pairAddress), 1000000 * 1e6);
        assertEq(tokenA_D0.balanceOf(pairAddress), 0); // Should be 0 as it's wrapped
        assertEq(IERC20(wrapperFactory.wrappedTokenFor(address(tokenA_D0))).balanceOf(pairAddress), 1000 * 1e18);
    }

    function test_AddLiquidity_D6_and_D0_Unwrapped() public {
        tokenA_D6.approve(address(masterRouterV2), 1000000 * 1e6);
        tokenA_D0.approve(address(masterRouterV2), 1000);

        vm.expectRevert();
        masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D6),
            address(tokenA_D0),
            1000000 * 1e6,
            1000,
            900000 * 1e6,
            900,
            false,
            false,
            user0,
            block.timestamp
        );
    }

    function test_AddLiquidity_D6_and_D0_DifferentAmounts() public {
        tokenA_D6.approve(address(masterRouterV2), 2000000 * 1e6);
        tokenA_D0.approve(address(masterRouterV2), 1000);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D6),
            address(tokenA_D0),
            2000000 * 1e6,
            1000,
            1900000 * 1e6,
            950,
            false,
            true,
            user0,
            block.timestamp
        );

        assertEq(amountA, 2000000 * 1e6);
        assertEq(amountB, 1000 * 1e18); // 1000 tokens with 0 decimals wrapped to 18 decimals
        assertGt(liquidity, 0);

        address pairAddress = factory.getPair(address(tokenA_D6), wrapperFactory.wrappedTokenFor(address(tokenA_D0)));
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);

        // Calculate expected liquidity
        uint256 expectedLiquidity = Math.sqrt(amountA * amountB) - FanXPair(pairAddress).MINIMUM_LIQUIDITY();

        // Check if actual liquidity matches expected liquidity
        assertEq(liquidity, expectedLiquidity, "Actual liquidity does not match expected liquidity");

        // Additional checks
        assertGt(liquidity, 0, "Liquidity should be greater than zero");
        assertLt(liquidity, Math.sqrt(amountA * amountB), "Liquidity should be less than sqrt(amountA * amountB)");

        // Check balances
        assertEq(tokenA_D6.balanceOf(pairAddress), 2000000 * 1e6);
        assertEq(tokenA_D0.balanceOf(pairAddress), 0); // Should be 0 as it's wrapped
        assertEq(IERC20(wrapperFactory.wrappedTokenFor(address(tokenA_D0))).balanceOf(pairAddress), 1000 * 1e18);
    }

    function test_AddLiquidity_D18_and_D0() public {
        tokenA_D18.approve(address(masterRouterV2), 1000 * 1e18);
        tokenA_D0.approve(address(masterRouterV2), 500);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D18),
            address(tokenA_D0),
            1000 * 1e18,
            500,
            950 * 1e18,
            450,
            false,
            true,
            user0,
            block.timestamp
        );

        assertEq(amountA, 1000 * 1e18);
        assertEq(amountB, 500 * 1e18); // 500 tokens with 0 decimals wrapped to 18 decimals
        assertGt(liquidity, 0);

        address pairAddress = factory.getPair(address(tokenA_D18), wrapperFactory.wrappedTokenFor(address(tokenA_D0)));
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);

        // Check balances
        assertEq(tokenA_D18.balanceOf(pairAddress), 1000 * 1e18);
        assertEq(tokenA_D0.balanceOf(pairAddress), 0); // Should be 0 as it's wrapped
        assertEq(IERC20(wrapperFactory.wrappedTokenFor(address(tokenA_D0))).balanceOf(pairAddress), 500 * 1e18);
    }

    function test_AddLiquidity_D18_and_D6() public {
        tokenA_D18.approve(address(masterRouterV2), 2000 * 1e18);
        tokenA_D6.approve(address(masterRouterV2), 1000 * 1e6);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D18),
            address(tokenA_D6),
            2000 * 1e18,
            1000 * 1e6,
            1900 * 1e18,
            950 * 1e6,
            false,
            true,
            user0,
            block.timestamp
        );

        assertEq(amountA, 2000 * 1e18);
        assertEq(amountB, 1000 * 1e18);
        assertGt(liquidity, 0);
        address pairAddress = factory.getPair(address(tokenA_D18), wrapperFactory.wrappedTokenFor(address(tokenA_D6)));
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);

        // Check balances
        assertEq(tokenA_D18.balanceOf(pairAddress), 2000 * 1e18);
        assertEq(IERC20(wrapperFactory.wrappedTokenFor(address(tokenA_D6))).balanceOf(pairAddress), 1000 * 1e18);
    }

    function test_MultipleAddLiquidity_DifferentAccounts() public {
        // Setup for user0
        vm.startPrank(user0);
        tokenA_D18.approve(address(masterRouterV2), 1000 * 1e18);
        tokenA_D6.approve(address(masterRouterV2), 500 * 1e6);
        masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D18),
            address(tokenA_D6),
            1000 * 1e18,
            500 * 1e6,
            950 * 1e18,
            450 * 1e6,
            false,
            true,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // Setup for user1
        vm.startPrank(user1);
        tokenA_D18.approve(address(masterRouterV2), 500 * 1e18);
        tokenA_D6.approve(address(masterRouterV2), 250 * 1e6);
        masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D18),
            address(tokenA_D6),
            500 * 1e18,
            250 * 1e6,
            450 * 1e18,
            225 * 1e6,
            false,
            true,
            user1,
            block.timestamp
        );
        vm.stopPrank();

        address pairAddress = factory.getPair(address(tokenA_D18), wrapperFactory.wrappedTokenFor(address(tokenA_D6)));

        // Check balances
        assertEq(tokenA_D18.balanceOf(pairAddress), 1500 * 1e18);
        assertEq(IERC20(wrapperFactory.wrappedTokenFor(address(tokenA_D6))).balanceOf(pairAddress), 750 * 1e18);
        // Check liquidity tokens
        assertGt(FanXPair(pairAddress).balanceOf(user0), 0);
        assertGt(FanXPair(pairAddress).balanceOf(user1), 0);
        assertGt(FanXPair(pairAddress).balanceOf(user0), FanXPair(pairAddress).balanceOf(user1));

        // Calculate expected liquidity tokens for user0 and user1
        uint256 expectedLiquidityUser0 = Math.sqrt(1000 * 1e18 * 500 * 1e18) -
            FanXPair(pairAddress).MINIMUM_LIQUIDITY();
        uint256 expectedLiquidityUser1 = Math.sqrt(500 * 1e18 * 250 * 1e18);

        // Check MINIMUM_LIQUIDITY
        assertEq(
            FanXPair(pairAddress).totalSupply(),
            expectedLiquidityUser0 + expectedLiquidityUser1 + FanXPair(pairAddress).MINIMUM_LIQUIDITY(),
            "Total supply should include MINIMUM_LIQUIDITY"
        );

        // Compare expected and actual liquidity balances
        assertEq(FanXPair(pairAddress).balanceOf(user0), expectedLiquidityUser0, "User0 liquidity balance mismatch");
        assertEq(FanXPair(pairAddress).balanceOf(user1), expectedLiquidityUser1, "User1 liquidity balance mismatch");

        // Verify that user0 has more liquidity tokens than user1
        assertGt(expectedLiquidityUser0, expectedLiquidityUser1, "User0 should have more liquidity tokens than User1");

        // Calculate the ratio of liquidity tokens
        uint256 liquidityRatio = (expectedLiquidityUser0 * 1e18) / expectedLiquidityUser1;

        // The ratio should be close to 2:1 (2000:1000), allowing for some small rounding errors
        assertApproxEqRel(liquidityRatio, 2e18, 0.01e18, "Liquidity ratio should be close to 2:1");
    }

    function test_UnwrappedD6AndD18_MultiAddressAddLiquidity() public {
        // Setup initial balances and approvals
        uint256 amountA = 1000 * 1e6; // D6 token
        uint256 amountB = 500 * 1e18; // D18 token

        deal(address(tokenA_D6), user0, amountA);
        deal(address(tokenB_D18), user0, amountB);

        vm.startPrank(user0);
        tokenA_D6.approve(address(masterRouterV2), amountA);
        tokenB_D18.approve(address(masterRouterV2), amountB);

        // Add liquidity
        (uint256 amountAUsed, uint256 amountBUsed, uint256 liquidityUser0) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D6),
            address(tokenB_D18),
            amountA,
            amountB,
            0,
            0,
            false, // tokenA_D6 is not wrapped
            false, // tokenB_D18 is not wrapped
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // Setup for second user
        uint256 amountA2 = 500 * 1e6; // D6 token
        uint256 amountB2 = 250 * 1e18; // D18 token

        deal(address(tokenA_D6), user1, amountA2);
        deal(address(tokenB_D18), user1, amountB2);

        vm.startPrank(user1);
        tokenA_D6.approve(address(masterRouterV2), amountA2);
        tokenB_D18.approve(address(masterRouterV2), amountB2);

        // Add liquidity for second user
        (uint256 amountA2Used, uint256 amountB2Used, uint256 liquidityUser1) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D6),
            address(tokenB_D18),
            amountA2,
            amountB2,
            0,
            0,
            false, // tokenA_D6 is not wrapped
            false, // tokenB_D18 is not wrapped
            user1,
            block.timestamp
        );
        vm.stopPrank();

        // Get pair address
        address pairAddress = factory.getPair(address(tokenA_D6), address(tokenB_D18));

        // Assertions
        assertEq(tokenA_D6.balanceOf(pairAddress), amountAUsed + amountA2Used, "Incorrect tokenA balance in pair");
        assertEq(tokenB_D18.balanceOf(pairAddress), amountBUsed + amountB2Used, "Incorrect tokenB balance in pair");

        assertGt(liquidityUser0, 0, "User0 should have received liquidity tokens");
        assertGt(liquidityUser1, 0, "User1 should have received liquidity tokens");
        assertGt(liquidityUser0, liquidityUser1, "User0 should have more liquidity tokens than User1");

        // Calculate expected liquidity tokens
        uint256 expectedLiquidityUser0 = Math.sqrt(amountAUsed * amountBUsed) -
            FanXPair(pairAddress).MINIMUM_LIQUIDITY();
        uint256 expectedLiquidityUser1 = Math.sqrt(amountA2Used * amountB2Used);

        assertEq(FanXPair(pairAddress).balanceOf(user0), expectedLiquidityUser0, "User0 liquidity balance mismatch");
        assertEq(FanXPair(pairAddress).balanceOf(user1), expectedLiquidityUser1, "User1 liquidity balance mismatch");

        // Verify total supply
        assertEq(
            FanXPair(pairAddress).totalSupply(),
            expectedLiquidityUser0 + expectedLiquidityUser1 + FanXPair(pairAddress).MINIMUM_LIQUIDITY(),
            "Incorrect total supply"
        );

        // Check liquidity ratio
        uint256 liquidityRatio = (liquidityUser0 * 1e18) / liquidityUser1;
        assertApproxEqRel(liquidityRatio, 2e18, 0.01e18, "Liquidity ratio should be close to 2:1");
    }

    function test_AddLiquidityAmountBOptimalIsOk_D0_D6() public {
        // Wrap tokenA_D0
        tokenA_D0.approve(address(wrapperFactory), 1);
        address wrappedTokenA_D0 = wrapperFactory.wrap(address(this), address(tokenA_D0), 1);

        address pairAddress = factory.createPair(wrappedTokenA_D0, address(tokenA_D6));

        FanXPair pair = FanXPair(pairAddress);

        // Determine token order
        address token0 = pair.token0();
        address token1 = pair.token1();

        // Approve tokens for wrapping
        tokenA_D0.approve(address(wrapperFactory), 1000);

        // Wrap tokenA_D0 and transfer to pair
        wrapperFactory.wrap(pairAddress, address(tokenA_D0), 1000);

        // Transfer tokenA_D6 directly to the pair
        tokenA_D6.transfer(pairAddress, 2000000);

        // Mint initial liquidity
        pair.mint(address(this));
        // Check initial liquidity
        uint256 initialLiquidity = pair.totalSupply();
        assertGt(initialLiquidity, 0, "Initial liquidity should be greater than 0");

        // Approve tokens for masterRouterV2
        tokenA_D0.approve(address(masterRouterV2), 1000);
        tokenA_D6.approve(address(masterRouterV2), 2000000);

        // Calculate expected wrapped amount for tokenA_D0
        uint256 expectedWrappedAmountA = 1000 * 1e18; // Assuming 18 decimal places for wrapped token

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D0),
            address(tokenA_D6),
            1000,
            2000000,
            1000 * 1e18, // Wrapped amount for tokenA_D0 (0 to 18 decimals)
            1900000, // tokenA_D6 already has 6 decimals
            true,
            false,
            address(this),
            block.timestamp
        );

        // Check balances based on token order
        if (token0 == wrappedTokenA_D0) {
            assertEq(
                IERC20(wrappedTokenA_D0).balanceOf(pairAddress),
                expectedWrappedAmountA + 1000 * 1e18,
                "Incorrect wrapped tokenA balance in pair"
            );
            assertEq(tokenA_D6.balanceOf(pairAddress), 4000000, "Incorrect tokenB balance in pair");
            assertEq(amountA, 2000000, "Incorrect wrapped amount for tokenA");
            assertEq(amountB, expectedWrappedAmountA, "Incorrect amount for tokenB");
        } else {
            assertEq(tokenA_D6.balanceOf(pairAddress), 4000000, "Incorrect tokenA balance in pair");
            assertEq(
                IERC20(wrappedTokenA_D0).balanceOf(pairAddress),
                expectedWrappedAmountA + 1000 * 1e18,
                "Incorrect wrapped tokenB balance in pair"
            );
            assertEq(amountA, expectedWrappedAmountA, "Incorrect amount for tokenA");
            assertEq(amountB, 2000000, "Incorrect wrapped amount for tokenB");
        }

        // Calculate expected liquidity
        uint256 expectedLiquidity = Math.sqrt(amountA * amountB);
        assertApproxEqRel(liquidity, expectedLiquidity, 1e15, "Liquidity not within 0.1% tolerance");

        // Additional checks
        assertEq(tokenA_D0.balanceOf(pairAddress), 0, "Original tokenA should not be in the pair");
    }

    function test_AddLiquidityAmountBOptimalIsOk_D6_D18() public {
        address pairAddress = factory.createPair(address(tokenA_D6), address(tokenB_D18));

        FanXPair pair = FanXPair(pairAddress);

        // Transfer tokens directly to the pair
        tokenA_D6.transfer(pairAddress, 1000000);
        tokenB_D18.transfer(pairAddress, 2 ether);

        // Mint initial liquidity
        pair.mint(user0);
        // Check initial liquidity
        uint256 initialLiquidity = pair.totalSupply();
        assertGt(initialLiquidity, 0, "Initial liquidity should be greater than 0");

        // Approve tokens for masterRouterV2
        tokenA_D6.approve(address(masterRouterV2), 1000000);
        tokenB_D18.approve(address(masterRouterV2), 2 ether);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = masterRouterV2.wrapTokensAndaddLiquidity(
            address(tokenA_D6),
            address(tokenB_D18),
            1000000,
            2 ether,
            1000000,
            1.9 ether,
            false,
            false,
            address(this),
            block.timestamp
        );

        assertEq(amountA, 1000000, "Incorrect amount for tokenA");
        assertEq(amountB, 2 ether, "Incorrect amount for tokenB");
        // Calculate expected liquidity
        uint256 expectedLiquidity = Math.sqrt(amountA * amountB);
        assertApproxEqRel(liquidity, expectedLiquidity, 1e15, "Liquidity not within 0.1% tolerance");

        // Additional checks
        assertEq(tokenA_D6.balanceOf(pairAddress), 2000000, "Incorrect tokenA balance in pair");
        assertEq(tokenB_D18.balanceOf(pairAddress), 4 ether, "Incorrect tokenB balance in pair");
    }

    /**********************
     ** AddLiquidity ETH **
     **********************/
    function test_AddLiquidityETH_CreatesPair() public {
        tokenA_D6.approve(address(masterRouterV2), 1000000);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 1 ether
        }(address(tokenA_D6), 1000000, 900000, 0.9 ether, false, user0, block.timestamp);

        address pairAddress = factory.getPair(address(tokenA_D6), address(WETH));
        uint256 userLiquidity = FanXPair(pairAddress).balanceOf(user0);

        console.log("Amount Token:", amountToken);
        console.log("Amount ETH:", amountETH);
        console.log("Liquidity:", liquidity);
        console.log("User Liquidity:", userLiquidity);

        assertGt(userLiquidity, 0, "User should have received liquidity tokens");

        assertEq(tokenA_D6.balanceOf(pairAddress), amountToken, "Incorrect tokenA balance in pair");
        assertEq(WETH.balanceOf(pairAddress), amountETH, "Incorrect WETH balance in pair");

        uint256 expectedLiquidity = Math.sqrt(amountToken * amountETH);
        assertApproxEqRel(liquidity, expectedLiquidity, 1e15, "Liquidity not within 0.1% tolerance of expected value");
    }

    function test_AddLiquidityETH_D0_Wrapped() public {
        tokenA_D0.approve(address(masterRouterV2), 100);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 1 ether
        }(address(tokenA_D0), 100, 90, 0.9 ether, true, user0, block.timestamp);

        assertEq(amountToken, 100 * 1e18);
        assertEq(amountETH, 1 ether);
        assertGt(liquidity, 0);

        address pairAddress = factory.getPair(wrapperFactory.wrappedTokenFor(address(tokenA_D0)), address(WETH));
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);
    }

    function test_AddLiquidityETH_D6_Unwrapped() public {
        tokenA_D6.approve(address(masterRouterV2), 1000000);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 1 ether
        }(address(tokenA_D6), 1000000, 900000, 0.9 ether, false, user0, block.timestamp);

        assertEq(amountToken, 1000000);
        assertEq(amountETH, 1 ether);
        assertGt(liquidity, 0);

        address pairAddress = factory.getPair(address(tokenA_D6), address(WETH));
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);
    }

    function test_AddLiquidityETH_InsufficientAllowance() public {
        tokenA_D6.approve(address(masterRouterV2), 500000);

        vm.expectRevert(0x7939f424);
        masterRouterV2.wrapTokenAndaddLiquidityETH{value: 1 ether}(
            address(tokenA_D6),
            1000000,
            900000,
            0.9 ether,
            false,
            user0,
            block.timestamp
        );
    }

    function test_AddLiquidityETH_D0_DifferentAmounts() public {
        tokenA_D0.approve(address(masterRouterV2), 1000);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 2 ether
        }(address(tokenA_D0), 1000, 900, 1.8 ether, true, user0, block.timestamp);

        assertEq(amountToken, 1000 * 1e18);
        assertEq(amountETH, 2 ether);
        assertGt(liquidity, 0);

        address pairAddress = factory.getPair(wrapperFactory.wrappedTokenFor(address(tokenA_D0)), address(WETH));
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);

        uint256 expectedLiquidity = Math.sqrt(amountToken * amountETH) - FanXPair(pairAddress).MINIMUM_LIQUIDITY();
        assertEq(liquidity, expectedLiquidity, "Actual liquidity does not match expected liquidity");

        assertEq(IERC20(wrapperFactory.wrappedTokenFor(address(tokenA_D0))).balanceOf(pairAddress), 1000 * 1e18);
        assertEq(WETH.balanceOf(pairAddress), 2 ether);
    }

    function test_AddLiquidityETH_D6_DifferentAmounts() public {
        tokenA_D6.approve(address(masterRouterV2), 2000000);

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 1 ether
        }(address(tokenA_D6), 2000000, 1900000, 0.9 ether, false, user0, block.timestamp);

        assertEq(amountToken, 2000000);
        assertEq(amountETH, 1 ether);
        assertGt(liquidity, 0);

        address pairAddress = factory.getPair(address(tokenA_D6), address(WETH));
        assertEq(FanXPair(pairAddress).balanceOf(user0), liquidity);

        uint256 expectedLiquidity = Math.sqrt(amountToken * amountETH) - FanXPair(pairAddress).MINIMUM_LIQUIDITY();
        assertEq(liquidity, expectedLiquidity, "Actual liquidity does not match expected liquidity");

        assertEq(tokenA_D6.balanceOf(pairAddress), 2000000);
        assertEq(WETH.balanceOf(pairAddress), 1 ether);
    }

    function test_MultipleAddLiquidityETH_DifferentAccounts() public {
        // Setup for user0
        vm.startPrank(user0);
        tokenA_D6.approve(address(masterRouterV2), 1000000);
        masterRouterV2.wrapTokenAndaddLiquidityETH{value: 1 ether}(
            address(tokenA_D6),
            1000000,
            900000,
            0.9 ether,
            false,
            user0,
            block.timestamp
        );
        vm.stopPrank();

        // Setup for user1
        vm.startPrank(user1);
        tokenA_D6.approve(address(masterRouterV2), 500000);
        masterRouterV2.wrapTokenAndaddLiquidityETH{value: 0.5 ether}(
            address(tokenA_D6),
            500000,
            450000,
            0.45 ether,
            false,
            user1,
            block.timestamp
        );
        vm.stopPrank();

        address pairAddress = factory.getPair(address(tokenA_D6), address(WETH));

        assertEq(tokenA_D6.balanceOf(pairAddress), 1500000);
        assertEq(WETH.balanceOf(pairAddress), 1.5 ether);

        assertGt(FanXPair(pairAddress).balanceOf(user0), 0);
        assertGt(FanXPair(pairAddress).balanceOf(user1), 0);
        assertGt(FanXPair(pairAddress).balanceOf(user0), FanXPair(pairAddress).balanceOf(user1));

        uint256 expectedLiquidityUser0 = Math.sqrt(1000000 * 1 ether) - FanXPair(pairAddress).MINIMUM_LIQUIDITY();
        uint256 expectedLiquidityUser1 = Math.sqrt(500000 * 0.5 ether);

        assertEq(FanXPair(pairAddress).balanceOf(user0), expectedLiquidityUser0, "User0 liquidity balance mismatch");
        assertEq(FanXPair(pairAddress).balanceOf(user1), expectedLiquidityUser1, "User1 liquidity balance mismatch");

        uint256 liquidityRatio = (expectedLiquidityUser0 * 1e18) / expectedLiquidityUser1;
        assertApproxEqRel(liquidityRatio, 2e18, 0.01e18, "Liquidity ratio should be close to 2:1");
    }

    function test_AddLiquidityETH_AmountETHOptimalIsOk_D0() public {
        tokenA_D0.approve(address(masterRouterV2), 1000);

        tokenA_D0.approve(address(wrapperFactory), 1000);
        address wrappedTokenA_D0 = wrapperFactory.wrap(address(this), address(tokenA_D0), 1000);
        address pairAddress = factory.createPair(wrappedTokenA_D0, address(WETH));

        FanXPair pair = FanXPair(pairAddress);

        // Transfer tokens and mint initial liquidity for testing purposes
        IERC20(wrappedTokenA_D0).transfer(pairAddress, 1000 * 1e18);
        WETH.deposit{value: 2 ether}();
        WETH.transfer(pairAddress, 2 ether);
        // Mint initial liquidity to user0
        pair.mint(user0);

        // Check initial liquidity
        uint256 initialLiquidity = pair.totalSupply();
        assertGt(initialLiquidity, 0, "Initial liquidity should be greater than 0");

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 2 ether
        }(address(tokenA_D0), 1000, 900, 1.8 ether, true, address(this), block.timestamp);

        assertEq(amountToken, 1000 * 1e18, "Incorrect wrapped amount for tokenA");
        assertEq(amountETH, 2 ether, "Incorrect amount for ETH");

        uint256 expectedLiquidity = Math.sqrt(amountToken * amountETH);
        assertApproxEqRel(liquidity, expectedLiquidity, 1e15, "Liquidity not within 0.1% tolerance");

        assertEq(
            IERC20(wrappedTokenA_D0).balanceOf(pairAddress),
            2000 * 1e18,
            "Incorrect wrapped tokenA balance in pair"
        );
        assertEq(WETH.balanceOf(pairAddress), 4 ether, "Incorrect WETH balance in pair");
    }

    function test_AddLiquidityETH_AmountETHOptimalIsOk_D6() public {
        tokenA_D6.approve(address(masterRouterV2), 1000000);

        address pairAddress = factory.createPair(address(tokenA_D6), address(WETH));

        FanXPair pair = FanXPair(pairAddress);

        assertEq(pair.token0(), address(tokenA_D6));
        assertEq(pair.token1(), address(WETH));

        // Transfer tokens and mint initial liquidity for testing purposes
        tokenA_D6.transfer(pairAddress, 1000000);
        WETH.deposit{value: 2 ether}();
        WETH.transfer(pairAddress, 2 ether);

        // Mint initial liquidity to user0
        pair.mint(user0);

        // Check initial liquidity
        uint256 initialLiquidity = pair.totalSupply();
        assertGt(initialLiquidity, 0, "Initial liquidity should be greater than 0");

        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 2 ether
        }(address(tokenA_D6), 1000000, 900000, 1.8 ether, false, address(this), block.timestamp);

        assertEq(amountToken, 1000000, "Incorrect amount for tokenA");
        assertEq(amountETH, 2 ether, "Incorrect amount for ETH");

        uint256 expectedLiquidity = Math.sqrt(amountToken * amountETH);
        assertApproxEqRel(liquidity, expectedLiquidity, 1e15, "Liquidity not within 0.1% tolerance");

        assertEq(tokenA_D6.balanceOf(pairAddress), 1000000 * 2, "Incorrect tokenA balance in pair");
        assertEq(WETH.balanceOf(pairAddress), 2 ether * 2, "Incorrect WETH balance in pair");
    }
}

// forge test --match-path test/FanXMasterRouterV2/FanXMasterRouterV2_addliquidity.t.sol -vvvv

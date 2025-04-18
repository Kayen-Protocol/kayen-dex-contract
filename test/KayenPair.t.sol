// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/KayenFactory.sol";
import "../src/tokens/KayenERC20.sol";
import "../src/KayenPair.sol";
import "../src/libraries/UQ112x112.sol";
import "../src/mocks/ERC20Mintable.sol";

contract KayenPair_Test is Test {
    address feeSetter = address(69);
    KayenERC20 Kayen;

    ERC20Mintable token0;
    ERC20Mintable token1;
    KayenFactory factory;
    KayenPair pair;
    TestUser testUser;

    function setUp() public {
        testUser = new TestUser();

        token0 = new ERC20Mintable("Token A", "TKNA");
        token1 = new ERC20Mintable("Token B", "TKNB");

        factory = new KayenFactory(feeSetter);
        address pairAddress = factory.createPair(address(token0), address(token1));
        pair = KayenPair(pairAddress);

        token0.mint(10 ether, address(this));
        token1.mint(10 ether, address(this));

        token0.mint(10 ether, address(testUser));
        token1.mint(10 ether, address(testUser));
    }

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function encodeError(string memory error, uint256 a) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error, a);
    }

    function assertReserves(uint112 expectedReserve0, uint112 expectedReserve1) internal {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        assertEq(reserve0, expectedReserve0, "unexpected reserve0");
        assertEq(reserve1, expectedReserve1, "unexpected reserve1");
    }

    function assertCumulativePrices(uint256 expectedPrice0, uint256 expectedPrice1) internal {
        assertEq(pair.price0CumulativeLast(), expectedPrice0, "unexpected cumulative price 0");
        assertEq(pair.price1CumulativeLast(), expectedPrice1, "unexpected cumulative price 1");
    }

    function calculateCurrentPrice() internal view returns (uint256 price0, uint256 price1) {
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        price0 = reserve0 > 0 ? (reserve1 * uint256(UQ112x112.Q112)) / reserve0 : 0;
        price1 = reserve1 > 0 ? (reserve0 * uint256(UQ112x112.Q112)) / reserve1 : 0;
    }

    function assertBlockTimestampLast(uint32 expected) internal {
        (, , uint32 blockTimestampLast) = pair.getReserves();

        assertEq(blockTimestampLast, expected, "unexpected blockTimestampLast");
    }

    function test_MintBootstrap() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this));

        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
    }

    function test_MintWhenTheresLiquidity() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); // + 1 LP

        vm.warp(37);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 2 ether);

        pair.mint(address(this)); // + 2 LP

        assertEq(pair.balanceOf(address(this)), 3 ether - 1000);
        assertEq(pair.totalSupply(), 3 ether);
        assertReserves(3 ether, 3 ether);
    }

    function test_MintUnbalanced() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 1 ether - 1000);
        assertReserves(1 ether, 1 ether);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); // + 1 LP
        assertEq(pair.balanceOf(address(this)), 2 ether - 1000);
        assertReserves(3 ether, 2 ether);
    }

    function test_MintLiquidityUnderflow() public {
        // 0x11: If an arithmetic operation results in underflow or overflow outside of an unchecked { ... } block.
        vm.expectRevert(encodeError("Panic(uint256)", 0x11));
        pair.mint(address(this));
    }

    function test_MintZeroLiquidity() public {
        token0.transfer(address(pair), 1000);
        token1.transfer(address(pair), 1000);

        vm.expectRevert(KayenPair.InsufficientLiquidityMinted.selector);
        pair.mint(address(this));
    }

    function test_Burn() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this));

        uint256 liquidity = pair.balanceOf(address(this));
        pair.transfer(address(pair), liquidity);
        pair.burn(address(this));

        assertEq(pair.balanceOf(address(this)), 0);
        assertReserves(1000, 1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(token0.balanceOf(address(this)), 10 ether - 1000);
        assertEq(token1.balanceOf(address(this)), 10 ether - 1000);
    }

    function test_BurnUnbalanced() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this));

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); // + 1 LP

        uint256 liquidity = pair.balanceOf(address(this));
        pair.transfer(address(pair), liquidity);
        pair.burn(address(this));

        assertEq(pair.balanceOf(address(this)), 0);
        assertReserves(1500, 1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(token0.balanceOf(address(this)), 10 ether - 1500);
        assertEq(token1.balanceOf(address(this)), 10 ether - 1000);
    }

    function test_BurnUnbalancedDifferentUsers() public {
        testUser.provideLiquidity(address(pair), address(token0), address(token1), 1 ether, 1 ether);

        assertEq(pair.balanceOf(address(this)), 0);
        assertEq(pair.balanceOf(address(testUser)), 1 ether - 1000);
        assertEq(pair.totalSupply(), 1 ether);

        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);

        pair.mint(address(this)); // + 1 LP

        uint256 liquidity = pair.balanceOf(address(this));
        pair.transfer(address(pair), liquidity);
        pair.burn(address(this));

        // this user is penalized for providing unbalanced liquidity
        assertEq(pair.balanceOf(address(this)), 0);
        assertReserves(1.5 ether, 1 ether);
        assertEq(pair.totalSupply(), 1 ether);
        assertEq(token0.balanceOf(address(this)), 10 ether - 0.5 ether);
        assertEq(token1.balanceOf(address(this)), 10 ether);

        testUser.removeLiquidity(address(pair));

        // testUser receives the amount collected from this user
        assertEq(pair.balanceOf(address(testUser)), 0);
        assertReserves(1500, 1000);
        assertEq(pair.totalSupply(), 1000);
        assertEq(token0.balanceOf(address(testUser)), 10 ether + 0.5 ether - 1500);
        assertEq(token1.balanceOf(address(testUser)), 10 ether - 1000);
    }

    function test_BurnZeroTotalSupply() public {
        // 0x12; If you divide or modulo by zero.
        vm.expectRevert(encodeError("Panic(uint256)", 0x12));
        pair.burn(address(this));
    }

    function test_BurnZeroLiquidity() public {
        // Transfer and mint as a normal user.
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);
        pair.mint(address(this));

        vm.prank(address(0xdeadbeef));
        vm.expectRevert(KayenPair.InsufficientLiquidityBurned.selector);
        pair.burn(address(this));
    }

    // function test_ReservesPacking() public {
    //     token0.transfer(address(pair), 1 ether);
    //     token1.transfer(address(pair), 2 ether);
    //     pair.mint(address(this));

    //     bytes32 val = vm.load(address(pair), bytes32(uint256(6)));
    //     assertEq(val, hex"000000000000000000001bc16d674ec800000000000000000de0b6b3a7640000");
    // }

    function test_SwapBasicScenario() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        uint256 amountOut = 0.181322178776029826 ether;
        token0.transfer(address(pair), 0.1 ether);
        pair.swap(0, amountOut, address(this), "");

        assertEq(token0.balanceOf(address(this)), 10 ether - 1 ether - 0.1 ether, "unexpected token0 balance");
        assertEq(token1.balanceOf(address(this)), 10 ether - 2 ether + amountOut, "unexpected token1 balance");
        assertReserves(1 ether + 0.1 ether, uint112(2 ether - amountOut));
    }

    function test_SwapBasicScenarioReverseDirection() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        token1.transfer(address(pair), 0.2 ether);
        pair.swap(0.09 ether, 0, address(this), "");

        assertEq(token0.balanceOf(address(this)), 10 ether - 1 ether + 0.09 ether, "unexpected token0 balance");
        assertEq(token1.balanceOf(address(this)), 10 ether - 2 ether - 0.2 ether, "unexpected token1 balance");
        assertReserves(1 ether - 0.09 ether, 2 ether + 0.2 ether);
    }

    function test_SwapBidirectional() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        token0.transfer(address(pair), 0.1 ether);
        token1.transfer(address(pair), 0.2 ether);
        pair.swap(0.09 ether, 0.18 ether, address(this), "");

        assertEq(token0.balanceOf(address(this)), 10 ether - 1 ether - 0.01 ether, "unexpected token0 balance");
        assertEq(token1.balanceOf(address(this)), 10 ether - 2 ether - 0.02 ether, "unexpected token1 balance");
        assertReserves(1 ether + 0.01 ether, 2 ether + 0.02 ether);
    }

    function test_SwapZeroOut() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        vm.expectRevert(KayenPair.InsufficientOutputAmount.selector);
        pair.swap(0, 0, address(this), "");
    }

    function test_SwapInsufficientLiquidity() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        vm.expectRevert(KayenPair.InsufficientLiquidity.selector);
        pair.swap(0, 2.1 ether, address(this), "");

        vm.expectRevert(KayenPair.InsufficientLiquidity.selector);
        pair.swap(1.1 ether, 0, address(this), "");
    }

    function test_SwapUnderpriced() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        token0.transfer(address(pair), 0.1 ether);
        pair.swap(0, 0.09 ether, address(this), "");

        assertEq(token0.balanceOf(address(this)), 10 ether - 1 ether - 0.1 ether, "unexpected token0 balance");
        assertEq(token1.balanceOf(address(this)), 10 ether - 2 ether + 0.09 ether, "unexpected token1 balance");
        assertReserves(1 ether + 0.1 ether, 2 ether - 0.09 ether);
    }

    function test_SwapOverpriced() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        token0.transfer(address(pair), 0.1 ether);

        vm.expectRevert(KayenPair.InvalidK.selector);
        pair.swap(0, 0.36 ether, address(this), "");

        assertEq(token0.balanceOf(address(this)), 10 ether - 1 ether - 0.1 ether, "unexpected token0 balance");
        assertEq(token1.balanceOf(address(this)), 10 ether - 2 ether, "unexpected token1 balance");
        assertReserves(1 ether, 2 ether);
    }

    function test_SwapUnpaidFee() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        token0.transfer(address(pair), 0.1 ether);

        vm.expectRevert(KayenPair.InvalidK.selector);
        pair.swap(0, 0.181322178776029827 ether, address(this), "");
    }

    function test_CumulativePrices() public {
        vm.warp(0);
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 1 ether);
        pair.mint(address(this));

        (uint256 initialPrice0, uint256 initialPrice1) = calculateCurrentPrice();

        // 0 seconds passed.
        pair.sync();
        assertCumulativePrices(0, 0);

        // 1 second passed.
        vm.warp(1);
        pair.sync();
        assertBlockTimestampLast(1);
        assertCumulativePrices(initialPrice0, initialPrice1);

        // 2 seconds passed.
        vm.warp(2);
        pair.sync();
        assertBlockTimestampLast(2);
        assertCumulativePrices(initialPrice0 * 2, initialPrice1 * 2);

        // 3 seconds passed.
        vm.warp(3);
        pair.sync();
        assertBlockTimestampLast(3);
        assertCumulativePrices(initialPrice0 * 3, initialPrice1 * 3);

        // // Price changed.
        token0.transfer(address(pair), 2 ether);
        token1.transfer(address(pair), 1 ether);
        pair.mint(address(this));

        (uint256 newPrice0, uint256 newPrice1) = calculateCurrentPrice();

        // // 0 seconds since last reserves update.
        assertCumulativePrices(initialPrice0 * 3, initialPrice1 * 3);

        // // 1 second passed.
        vm.warp(4);
        pair.sync();
        assertBlockTimestampLast(4);
        assertCumulativePrices(initialPrice0 * 3 + newPrice0, initialPrice1 * 3 + newPrice1);

        // 2 seconds passed.
        vm.warp(5);
        pair.sync();
        assertBlockTimestampLast(5);
        assertCumulativePrices(initialPrice0 * 3 + newPrice0 * 2, initialPrice1 * 3 + newPrice1 * 2);

        // 3 seconds passed.
        vm.warp(6);
        pair.sync();
        assertBlockTimestampLast(6);
        assertCumulativePrices(initialPrice0 * 3 + newPrice0 * 3, initialPrice1 * 3 + newPrice1 * 3);
    }

    function test_Flashloan() public {
        token0.transfer(address(pair), 1 ether);
        token1.transfer(address(pair), 2 ether);
        pair.mint(address(this));

        uint256 flashloanAmount = 0.1 ether;
        uint256 flashloanFee = (flashloanAmount * 1000) / 997 - flashloanAmount + 1;

        Flashloaner fl = new Flashloaner();

        token1.transfer(address(fl), flashloanFee);

        vm.startPrank(feeSetter);
        factory.setFlashOn(true);
        factory.setFeeTo(feeSetter);
        vm.stopPrank();

        fl.flashloan(address(pair), 0, flashloanAmount, address(token1));

        assertEq(token1.balanceOf(address(fl)), 0);
        assertEq(token1.balanceOf(address(pair)), 2 ether + flashloanFee);
    }
}

contract TestUser {
    function provideLiquidity(
        address pairAddress_,
        address token0Address_,
        address token1Address_,
        uint256 amount0_,
        uint256 amount1_
    ) public {
        ERC20(token0Address_).transfer(pairAddress_, amount0_);
        ERC20(token1Address_).transfer(pairAddress_, amount1_);

        KayenPair(pairAddress_).mint(address(this));
    }

    function removeLiquidity(address pairAddress_) public {
        uint256 liquidity = ERC20(pairAddress_).balanceOf(address(this));
        ERC20(pairAddress_).transfer(pairAddress_, liquidity);
        KayenPair(pairAddress_).burn(address(this));
    }
}

contract Flashloaner {
    error InsufficientFlashLoanAmount();

    uint256 expectedLoanAmount;

    function flashloan(address pairAddress, uint256 amount0Out, uint256 amount1Out, address tokenAddress) public {
        if (amount0Out > 0) {
            expectedLoanAmount = amount0Out;
        }
        if (amount1Out > 0) {
            expectedLoanAmount = amount1Out;
        }

        KayenPair(pairAddress).swap(amount0Out, amount1Out, address(this), abi.encode(tokenAddress));
    }

    function KayenCall(address, uint256, uint256, bytes calldata data) public {
        address tokenAddress = abi.decode(data, (address));
        uint256 balance = ERC20(tokenAddress).balanceOf(address(this));

        if (balance < expectedLoanAmount) revert InsufficientFlashLoanAmount();

        ERC20(tokenAddress).transfer(msg.sender, balance);
    }
}

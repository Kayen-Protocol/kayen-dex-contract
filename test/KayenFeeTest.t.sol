// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "../contracts/KayenFactory.sol";
import "../contracts/KayenPair.sol";
import "../contracts/KayenRouter02.sol";
import "../contracts/interfaces/IKayenRouter02.sol";
import "../contracts/mocks/ERC20Mintable.sol";
import "forge-std/console.sol";

contract KayenFee_Test is Test {
    address feeTo = address(33);
    address liquidityReceiver = address(123);
    ERC20Mintable WETH;

    KayenRouter02 router;
    KayenFactory factory;

    ERC20Mintable tokenA;
    ERC20Mintable tokenB;
    ERC20Mintable tokenC;

    function setUp() public {
        WETH = new ERC20Mintable("Wrapped ETH", "WETH");

        factory = new KayenFactory(address(this));
        router = new KayenRouter02(address(factory), address(WETH));

        tokenA = new ERC20Mintable("Token A", "TKNA");
        tokenB = new ERC20Mintable("Token B", "TKNB");
        tokenC = new ERC20Mintable("Token C", "TKNC");

        tokenA.mint(300_000 ether, address(this));
        tokenB.mint(300_000 ether, address(this));
        tokenC.mint(300_000 ether, address(this));
    }

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function test_testFee() public {
        // Initial setup
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);

        // Add initial liquidity
        uint256 initialAmountA = 200_000 ether;
        uint256 initialAmountB = 200_000 ether;
        (uint256 initialLiquidity, , ) = router.addLiquidity(
            address(tokenA),
            address(tokenB),
            initialAmountA,
            initialAmountB,
            0,
            0,
            address(this),
            block.timestamp
        );

        address pairAddress = factory.getPair(address(tokenA), address(tokenB));
        KayenPair pair = KayenPair(pairAddress);

        // Enable fees
        factory.setFeeTo(feeTo);

        // Perform swaps
        address[] memory path1 = new address[](2);
        path1[0] = address(tokenA);
        path1[1] = address(tokenB);
        address[] memory path2 = new address[](2);
        path2[0] = address(tokenB);
        path2[1] = address(tokenA);

        uint256 totalSwapAmountIn = 0;
        (uint256 r1, uint256 r2, ) = pair.getReserves();
        console.log(r1, r2);

        for (uint i = 0; i < 1000; i++) {
            uint256 swapAmountIn = 1000 ether;
            tokenA.mint(swapAmountIn, address(this));

            totalSwapAmountIn += swapAmountIn;

            router.swapExactTokensForTokens(swapAmountIn, 0, path1, address(this), block.timestamp);
            router.swapExactTokensForTokens(swapAmountIn, 0, path2, address(this), block.timestamp);
        }
        (uint256 r1after, uint256 r2after, ) = pair.getReserves();
        console.log(r1after, r2after);

        uint256 reserveDifference_Fee1 = r1after - r1;
        uint256 reserveDifference_Fee2 = r2after - r2;

        // mint Fee
        router.addLiquidity(address(tokenA), address(tokenB), 10, 10, 0, 0, address(this), block.timestamp);
        // console.log(pair.balanceOf(feeTo));
        // console.log(pair.balanceOf(address(this)));
        uint256 totalLiquidity = pair.totalSupply();
        uint256 feeToSharePercentage = (pair.balanceOf(feeTo) * 1e18) / totalLiquidity;
        uint256 userSharePercentage = (pair.balanceOf(address(this)) * 1e18) / totalLiquidity;

        console.log("FeeToBalance Share:", feeToSharePercentage);
        console.log("UserBalance Share:", userSharePercentage);

        console.log("FeeToBalance TokenA Before:", tokenA.balanceOf(feeTo));
        console.log("FeeToBalance TokenB Before:", tokenB.balanceOf(feeTo));

        vm.startPrank(feeTo);
        pair.approve(address(router), pair.balanceOf(feeTo));
        router.removeLiquidity(address(tokenA), address(tokenB), pair.balanceOf(feeTo), 0, 0, feeTo, block.timestamp);
        vm.stopPrank();

        vm.startPrank(address(this));

        pair.approve(address(router), pair.balanceOf(address(this)));
        router.removeLiquidity(
            address(tokenA),
            address(tokenB),
            pair.balanceOf(address(this)),
            0,
            0,
            liquidityReceiver,
            block.timestamp
        );
        vm.stopPrank();

        uint256 feeTokenAAfter = tokenA.balanceOf(feeTo);
        uint256 feeTokenBAfter = tokenB.balanceOf(feeTo);
        uint256 ReceiverTokenAFee = tokenA.balanceOf(liquidityReceiver) - initialAmountA;
        uint256 ReceiverTokenBFee = tokenB.balanceOf(liquidityReceiver) - initialAmountB;

        console.log("FeeToBalance TokenA After:", feeTokenAAfter);
        console.log("FeeToBalance TokenB After:", feeTokenBAfter);
        console.log("ReceiverFee Balance TokenA After:", ReceiverTokenAFee);
        console.log("ReceiverFee Balance TokenB After:", ReceiverTokenBFee);
        console.log(reserveDifference_Fee1, reserveDifference_Fee2);

        uint256 ReceiverfeePercentageTokenA;
        uint256 ReceiverfeePercentageTokenB;
        uint256 FeeToPercentageTokenA;
        uint256 FeeToPercentageTokenB;
        address token0 = pair.token0();
        if (token0 == address(tokenA)) {
            FeeToPercentageTokenA = (feeTokenAAfter * 1e18) / reserveDifference_Fee1;
            FeeToPercentageTokenB = (feeTokenBAfter * 1e18) / reserveDifference_Fee2;
            ReceiverfeePercentageTokenA = (ReceiverTokenAFee * 1e18) / reserveDifference_Fee1;
            ReceiverfeePercentageTokenB = (ReceiverTokenBFee * 1e18) / reserveDifference_Fee2;
        } else {
            FeeToPercentageTokenA = (feeTokenAAfter * 1e18) / reserveDifference_Fee2;
            FeeToPercentageTokenB = (feeTokenBAfter * 1e18) / reserveDifference_Fee1;
            ReceiverfeePercentageTokenA = (ReceiverTokenAFee * 1e18) / reserveDifference_Fee2;
            ReceiverfeePercentageTokenB = (ReceiverTokenBFee * 1e18) / reserveDifference_Fee1;
        }
        console.log("Protocol Fee Percentage TokenA: ", FeeToPercentageTokenA);
        console.log("Protocol Fee Percentage TokenB: ", FeeToPercentageTokenB);
        console.log("User Fee Precentage TokenA:", ReceiverfeePercentageTokenA);
        console.log("User Fee Precentage TokenB:", ReceiverfeePercentageTokenB);
        console.log(FeeToPercentageTokenA + ReceiverfeePercentageTokenA);
        console.log(FeeToPercentageTokenB + ReceiverfeePercentageTokenB);
    }
}

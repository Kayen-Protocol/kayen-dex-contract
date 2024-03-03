// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/JalaFactory.sol";
import "../contracts/JalaPair.sol";
import "../contracts/JalaRouter02.sol";
import "../contracts/JalaLens.sol";
import "../contracts/interfaces/IJalaRouter02.sol";
import "../contracts/mocks/ERC20Mintable_decimal.sol";
import "../contracts/mocks/MockWETH.sol";
import "../contracts/JalaMasterRouter.sol";
import "../contracts/utils/ChilizWrapperFactory.sol";
import "../contracts/interfaces/IChilizWrapperFactory.sol";
import "../contracts/interfaces/IChilizWrappedERC20.sol";
import "../contracts/libraries/JalaLibrary.sol";

// @add assertions
contract JalaMasterRouter_Test is Test {
    address feeSetter = address(69);
    MockWETH public WETH;

    JalaRouter02 public router;
    JalaMasterRouter public masterRouter;
    JalaFactory public factory;
    IChilizWrapperFactory public wrapperFactory;
    JalaLens public lens;

    ERC20Mintable public tokenA;
    ERC20Mintable public tokenB;
    ERC20Mintable public tokenC;

    address user0 = vm.addr(0x01);

    function setUp() public {
        WETH = new MockWETH();

        factory = new JalaFactory(feeSetter);
        router = new JalaRouter02(address(factory), address(WETH));
        wrapperFactory = new ChilizWrapperFactory();
        masterRouter = new JalaMasterRouter(address(factory), address(wrapperFactory), address(router), address(WETH));

        lens = new JalaLens();
        lens.initialize(address(factory), address(wrapperFactory));

        tokenA = new ERC20Mintable("Token A", "TKNA", 0);
        tokenB = new ERC20Mintable("Token B", "TKNB", 0);
        tokenC = new ERC20Mintable("Token C", "TKNC", 0);

        vm.deal(address(this), 100 ether);

        tokenA.mint(200 ether, address(this));
        tokenB.mint(200 ether, address(this));
        tokenC.mint(200 ether, address(this));
        tokenA.mint(10000, user0);
        tokenB.mint(10000, user0);
        tokenC.mint(10000, user0);
    }

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function test_getAmountOut() public {
        tokenA.approve(address(masterRouter), 10000000);
        tokenB.approve(address(masterRouter), 10000000);

        masterRouter.wrapTokensAndaddLiquidity(
            address(tokenA),
            address(tokenB),
            10000,
            10000,
            0,
            0,
            user0,
            block.timestamp
        );
        address pairAddress = factory.getPair(
            wrapperFactory.wrappedTokenFor(address(tokenA)),
            wrapperFactory.wrappedTokenFor(address(tokenB))
        );
        uint256 amount = lens.getAmountOut(
            10e18,
            wrapperFactory.wrappedTokenFor(address(tokenA)),
            wrapperFactory.wrappedTokenFor(address(tokenB))
        );
        // uint256 liquidity = JalaPair(pairAddress).balanceOf(user0);
        console.logUint(amount);
    }

    function test_getAmountsOut() public {
        tokenA.approve(address(masterRouter), 10000000);
        tokenB.approve(address(masterRouter), 10000000);

        masterRouter.wrapTokensAndaddLiquidity(
            address(tokenA),
            address(tokenB),
            10000,
            10000,
            0,
            0,
            user0,
            block.timestamp
        );
        // getAmountsOut(uint256 amountIn, address[] memory path)
        address[] memory path = new address[](2);
        path[0] = wrapperFactory.wrappedTokenFor(address(tokenA));
        path[1] = wrapperFactory.wrappedTokenFor(address(tokenB));

        uint256[] memory amounts = lens.getAmountsOut(10e18, path);
        assertEq(amounts[1], 9960069810399032164);
    }

    function test_getAmountOutForUnwrapped() public {
        tokenA.approve(address(masterRouter), 10000000);
        tokenB.approve(address(masterRouter), 10000000);

        masterRouter.wrapTokensAndaddLiquidity(
            address(tokenA),
            address(tokenB),
            1000,
            1000,
            0,
            0,
            user0,
            block.timestamp
        );
        address pairAddress = factory.getPair(
            wrapperFactory.wrappedTokenFor(address(tokenA)),
            wrapperFactory.wrappedTokenFor(address(tokenB))
        );
        (uint256 amountOut, uint256 unwrappedAmount, uint256 reminder) = lens.getAmountOutForUnwrapped(
            10,
            wrapperFactory.wrappedTokenFor(address(tokenA)),
            wrapperFactory.wrappedTokenFor(address(tokenB))
        );
        // uint256 amount = lens.getAmountOut(1, wrapperFactory.wrappedTokenFor(address(tokenA)), wrapperFactory.wrappedTokenFor(address(tokenB)));
        // uint256 liquidity = JalaPair(pairAddress).balanceOf(user0);
        console.logUint(amountOut);
        console.logUint(unwrappedAmount);
        console.logUint(reminder);
    }

    function test_convertAndGetAmountOutForUnwrpped() public {
        tokenA.approve(address(masterRouter), 10000000);
        tokenB.approve(address(masterRouter), 10000000);

        masterRouter.wrapTokensAndaddLiquidity(
            address(tokenA),
            address(tokenB),
            100000,
            100000,
            0,
            0,
            user0,
            block.timestamp
        );
        address wTokenA = wrapperFactory.wrappedTokenFor(address(tokenA));
        address wTokenB = wrapperFactory.wrappedTokenFor(address(tokenB));

        address pairAddress = factory.getPair(wTokenA, wTokenB);
        (uint112 _reserve0, uint112 _reserve1, ) = JalaPair(pairAddress).getReserves();
        console.logUint(_reserve0);
        console.logUint(_reserve1);

        // uint256 a = IChilizWrappedERC20(wrapperFactory.wrappedTokenFor(address(tokenA))).getDecimalsOffset();
        // console.logUint(a);
        (uint256 amountOut, uint256 unwrappedAmount, uint256 reminder) = lens.convertAndGetAmountOutForUnwrpped(
            10,
            address(tokenA),
            address(tokenB)
        );

        address addrFromLib = JalaLibrary.pairFor(address(factory), wTokenA, wTokenB);
        address addrFromFactory = JalaFactory(factory).getPair(wTokenA, wTokenB);

        console2.log("Address from Lib", addrFromLib);
        console2.log("Address from factory", addrFromFactory);
        assertEq(addrFromFactory, addrFromLib);
        assertEq(9, unwrappedAmount);

        console.logUint(amountOut);
        console.logUint(unwrappedAmount);
        console.logUint(reminder);
    }
}

// forge test --match-path test/JalaLens.t.sol -vvvv

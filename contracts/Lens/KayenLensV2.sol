// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "../interfaces/IChilizWrappedERC20.sol";
import "../interfaces/IChilizWrapperFactory.sol";
import "../interfaces/IKayenFactory.sol";
import "../libraries/KayenLibrary.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract KayenLensV2 is Initializable {
    address public factory;
    address public wrapperFactory;
    address public WETH;

    error InvalidPath();

    function initialize(address _factory, address _wrapperFactory, address _WETH) public initializer {
        require(_factory != address(0), "JL: ZERO_ADDRESS");
        require(_wrapperFactory != address(0), "JL: ZERO_ADDRESS");
        require(_WETH != address(0), "JL: ZERO_ADDRESS");

        factory = _factory;
        wrapperFactory = _wrapperFactory;
        WETH = _WETH;
    }

    function quote(uint256 amountA, address tokenA, address tokenB) public view returns (uint256 amountB) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(tokenA, tokenB);
        return KayenLibrary.quote(amountA, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, address tokenA, address tokenB) public view returns (uint256 amountIn) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(tokenA, tokenB);
        return KayenLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountOut(uint256 amountIn, address tokenA, address tokenB) public view returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(tokenA, tokenB);
        return KayenLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    // function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
    //     return KayenLibrary.getAmountsOut(factory, amountIn, path);
    // }

    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
        if (path.length < 2) revert InvalidPath();
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(path[i], path[i + 1]);
            amounts[i + 1] = KayenLibrary.getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function getAmountsOutForUnwrapped(
        uint256 amountIn,
        address[] memory path
    ) public view returns (uint256[] memory amounts, uint256 unwrappedAmount, uint256 reminder) {
        uint256 tokenAOutOffset = IChilizWrappedERC20(path[0]).getDecimalsOffset();
        amounts = getAmountsOut(amountIn * tokenAOutOffset, path);
        address tokenOut = path[path.length - 1];
        (unwrappedAmount, reminder) = _getReminder(tokenOut, amounts[amounts.length - 1]);
    }

    function getAmountOutForUnwrapped(
        uint256 amountIn,
        address tokenA,
        address tokenB
    ) public view returns (uint256 amountOut, uint256 unwrappedAmount, uint256 reminder) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(tokenA, tokenB);
        uint256 tokenAOutOffset = IChilizWrappedERC20(tokenA).getDecimalsOffset();
        amountOut = KayenLibrary.getAmountOut(amountIn * tokenAOutOffset, reserveIn, reserveOut);
        (unwrappedAmount, reminder) = _getReminder(tokenB, amountOut);
    }

    function convertAndGetAmountOutForUnwrpped(
        uint256 amountIn,
        address tokenA,
        address tokenB
    ) public view returns (uint256 amountOut, uint256 unwrappedAmount, uint256 reminder) {
        address wrappedTokenA;
        address wrappedTokenB;
        uint256 tokenAOutOffset = 1;

        if (tokenA != WETH) {
            wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(tokenA);
            tokenAOutOffset = IChilizWrappedERC20(wrappedTokenA).getDecimalsOffset();
        } else {
            wrappedTokenA = WETH;
        }

        if (tokenB != WETH) {
            wrappedTokenB = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(tokenB);
        } else {
            wrappedTokenB = WETH;
        }
        // wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(tokenA);
        // wrappedTokenB = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(tokenB);

        (uint256 reserveIn, uint256 reserveOut) = getReserves(wrappedTokenA, wrappedTokenB);

        amountOut = KayenLibrary.getAmountOut(amountIn * tokenAOutOffset, reserveIn, reserveOut);
        if (tokenB != WETH) {
            (unwrappedAmount, reminder) = _getReminder(wrappedTokenB, amountOut);
        }
    }

    function getReserves(address tokenA, address tokenB) public view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = KayenLibrary.sortTokens(tokenA, tokenB);
        address pair = IKayenFactory(factory).getPair(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IKayenPair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getPairInAdvance(address tokenA, address tokenB) public view returns (address) {
        return KayenLibrary.pairFor(factory, tokenA, tokenB);
    }

    function _getReminder(
        address tokenOut,
        uint256 amount
    ) internal view returns (uint256 unwrappedAmount, uint256 reminder) {
        uint256 tokenOutOffset = IChilizWrappedERC20(tokenOut).getDecimalsOffset();
        unwrappedAmount = (amount / tokenOutOffset);
        reminder = amount - (unwrappedAmount * tokenOutOffset);
    }
}

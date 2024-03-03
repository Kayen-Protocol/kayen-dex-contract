// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./interfaces/IChilizWrappedERC20.sol";
import "./interfaces/IChilizWrapperFactory.sol";
import "./interfaces/IJalaFactory.sol";
import "./libraries/JalaLibrary.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract JalaLensV2 is Initializable {
    address public factory;
    address public wrapperFactory;

    error InvalidPath();

    function initialize(address _factory, address _wrapperFactory) public initializer {
        factory = _factory;
        wrapperFactory = _wrapperFactory;
    }

    function quote(uint256 amountA, address tokenA, address tokenB) public view returns (uint256 amountB) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(tokenA, tokenB);
        return JalaLibrary.quote(amountA, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, address tokenA, address tokenB) public view returns (uint256 amountIn) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(tokenA, tokenB);
        return JalaLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountOut(uint256 amountIn, address tokenA, address tokenB) public view returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut) = getReserves(tokenA, tokenB);
        return JalaLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    // function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
    //     return JalaLibrary.getAmountsOut(factory, amountIn, path);
    // }

    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
        if (path.length < 2) revert InvalidPath();
        amounts = new uint256[](path.length);
        amounts[0] = amountIn;
        for (uint256 i; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = getReserves(path[i], path[i + 1]);
            amounts[i + 1] = JalaLibrary.getAmountOut(amounts[i], reserveIn, reserveOut);
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
        amountOut = JalaLibrary.getAmountOut(amountIn * tokenAOutOffset, reserveIn, reserveOut);
        (unwrappedAmount, reminder) = _getReminder(tokenB, amountOut);
    }

    function convertAndGetAmountOutForUnwrpped(
        uint256 amountIn,
        address tokenA,
        address tokenB
    ) public view returns (uint256 amountOut, uint256 unwrappedAmount, uint256 reminder) {
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(tokenA);
        address wrappedTokenB = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(tokenB);
        uint256 tokenAOutOffset = IChilizWrappedERC20(wrappedTokenA).getDecimalsOffset();

        (uint256 reserveIn, uint256 reserveOut) = getReserves(wrappedTokenA, wrappedTokenB);

        amountOut = JalaLibrary.getAmountOut(amountIn * tokenAOutOffset, reserveIn, reserveOut);
        (unwrappedAmount, reminder) = _getReminder(wrappedTokenB, amountOut);
    }

    function getReserves(address tokenA, address tokenB) public view returns (uint256 reserveA, uint256 reserveB) {
        (address token0, ) = JalaLibrary.sortTokens(tokenA, tokenB);
        address pair = IJalaFactory(factory).getPair(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IJalaPair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function getPairInAdvance(address tokenA, address tokenB) public view returns (address) {
        return JalaLibrary.pairFor(factory, tokenA, tokenB);
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

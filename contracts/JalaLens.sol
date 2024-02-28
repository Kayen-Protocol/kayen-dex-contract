// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./interfaces/IChilizWrappedERC20.sol";
import "./interfaces/IChilizWrapperFactory.sol";
import "./libraries/JalaLibrary.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract JalaLens is Initializable {
    address public factory;
    address public wrapperFactory;

    function initialize(address _factory, address _wrapperFactory) public initializer {
        factory = _factory;
        wrapperFactory = _wrapperFactory;
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint256 amountA, address tokenA, address tokenB) public view returns (uint256 amountB) {
        (uint256 reserveIn, uint256 reserveOut) = JalaLibrary.getReserves(factory, tokenA, tokenB);
        return JalaLibrary.quote(amountA, reserveIn, reserveOut);
    }

    function getAmountIn(uint256 amountOut, address tokenA, address tokenB) public view returns (uint256 amountIn) {
        (uint256 reserveIn, uint256 reserveOut) = JalaLibrary.getReserves(factory, tokenA, tokenB);
        return JalaLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountOut(uint256 amountIn, address tokenA, address tokenB) public view returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut) = JalaLibrary.getReserves(factory, tokenA, tokenB);
        return JalaLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path) public view returns (uint256[] memory amounts) {
        return JalaLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsOutForUnwrapped(
        uint256 amountIn,
        address[] memory path
    ) public view returns (uint256[] memory amounts, uint256 unwrappedAmount, uint256 reminder) {
        uint256 tokenAOutOffset = IChilizWrappedERC20(path[0]).getDecimalsOffset();
        amounts = JalaLibrary.getAmountsOut(factory, amountIn * tokenAOutOffset, path);
        address tokenOut = path[path.length - 1];
        (unwrappedAmount, reminder) = getReminder(tokenOut, amounts[amounts.length - 1]);
    }

    function getAmountOutForUnwrapped(
        uint256 amountIn,
        address tokenA,
        address tokenB
    ) public view returns (uint256 amountOut, uint256 unwrappedAmount, uint256 reminder) {
        (uint256 reserveIn, uint256 reserveOut) = JalaLibrary.getReserves(factory, tokenA, tokenB);
        uint256 tokenAOutOffset = IChilizWrappedERC20(tokenA).getDecimalsOffset();
        amountOut = JalaLibrary.getAmountOut(amountIn * tokenAOutOffset, reserveIn, reserveOut);
        (unwrappedAmount, reminder) = getReminder(tokenB, amountOut);
    }

    function convertAndGetAmountOutForUnwrpped(
        uint256 amountIn,
        address tokenA,
        address tokenB
    ) public view returns (uint256 amountOut, uint256 unwrappedAmount, uint256 reminder) {
        address wrappedTokenA = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(tokenA);
        address wrappedTokenB = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(tokenB);
        uint256 tokenAOutOffset = IChilizWrappedERC20(tokenA).getDecimalsOffset();
        (uint256 reserveIn, uint256 reserveOut) = JalaLibrary.getReserves(factory, wrappedTokenA, wrappedTokenB);
        amountOut = JalaLibrary.getAmountOut(amountIn * tokenAOutOffset, reserveIn, reserveOut);
        (unwrappedAmount, reminder) = getReminder(tokenB, amountOut);
    }

    function getPairInAdvance(address tokenA, address tokenB) public view returns (address) {
        return JalaLibrary.pairFor(factory, tokenA, tokenB);
    }

    function getReminder(
        address tokenOut,
        uint256 amount
    ) internal view returns (uint256 unwrappedAmount, uint256 reminder) {
        uint256 tokenOutOffset = IChilizWrappedERC20(tokenOut).getDecimalsOffset();
        unwrappedAmount = (amount / tokenOutOffset);
        reminder = amount - (unwrappedAmount * tokenOutOffset);
    }
}

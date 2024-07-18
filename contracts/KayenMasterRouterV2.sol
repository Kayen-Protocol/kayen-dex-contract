// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IKayenRouter02.sol";
import "./interfaces/IKayenMasterRouterV2.sol";
import "./interfaces/IChilizWrapperFactory.sol";
import "./interfaces/IChilizWrappedERC20.sol";
import "./interfaces/IWETH.sol";
import "./libraries/KayenLibrary.sol";
import "./libraries/TransferHelper.sol";

// This is a Master Router contract that wrap under 18 decimal token
// and interact with router to addliqudity and swap tokens.
contract KayenMasterRouterV2 is IKayenMasterRouterV2 {
    address public immutable factory;
    address public immutable WETH;
    address public immutable router;
    address public immutable wrapperFactory;

    constructor(address _factory, address _wrapperFactory, address _router, address _WETH) {
        require(_factory != address(0), "KMR: ZERO_ADDRESS");
        require(_wrapperFactory != address(0), "JMR: ZERO_ADDRESS");
        require(_router != address(0), "KMR: ZERO_ADDRESS");
        require(_WETH != address(0), "KMR: ZERO_ADDRESS");

        factory = _factory;
        wrapperFactory = _wrapperFactory;
        router = _router;
        WETH = _WETH;
    }

    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) revert Expired();
        _;
    }

    receive() external payable {
        require(msg.sender == WETH || msg.sender == router, "MR: !Wrong Sender"); // only accept ETH via fallback from the WETH and router contract
    }

    function wrapTokensAndaddLiquidity(
        address tokenA, // origin token
        address tokenB, // origin token
        uint256 amountADesired, // unwrapped.
        uint256 amountBDesired, // unwrapped.
        uint256 amountAMin, // unwrapped
        uint256 amountBMin, // unwrapped
        bool wrapTokenA,
        bool wrapTokenB,
        address to,
        uint256 deadline
    ) public virtual ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // validate tokens
        _validateTokens(tokenA, tokenB, wrapTokenA, wrapTokenB);

        // pull token from user
        TransferHelper.safeTransferFrom(tokenA, msg.sender, address(this), amountADesired);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, address(this), amountBDesired);

        (
            address adjustedTokenA,
            uint256 adjustedAmountADesired,
            uint256 adjustedAmountAMin,
            uint256 decimalsOffsetA
        ) = _adjustToken(tokenA, amountADesired, amountAMin, wrapTokenA);
        (
            address adjustedTokenB,
            uint256 adjustedAmountBDesired,
            uint256 adjustedAmountBMin,
            uint256 decimalsOffsetB
        ) = _adjustToken(tokenB, amountBDesired, amountBMin, wrapTokenB);

        (amountA, amountB) = _addLiquidity(
            adjustedTokenA,
            adjustedTokenB,
            adjustedAmountADesired,
            adjustedAmountBDesired,
            adjustedAmountAMin,
            adjustedAmountBMin
        );
        address pair = KayenLibrary.pairFor(factory, adjustedTokenA, adjustedTokenB);
        TransferHelper.safeTransfer(adjustedTokenA, pair, amountA);
        TransferHelper.safeTransfer(adjustedTokenB, pair, amountB);
        liquidity = IKayenPair(pair).mint(to);

        // return dust
        _returnUnwrappedTokenAndDust(adjustedTokenA, msg.sender, wrapTokenA, decimalsOffsetA);
        _returnUnwrappedTokenAndDust(adjustedTokenB, msg.sender, wrapTokenB, decimalsOffsetB);

        return (amountA, amountB, liquidity);
    }

    function wrapTokenAndaddLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        bool wrapToken,
        address to,
        uint256 deadline
    ) external payable virtual ensure(deadline) returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        _validateTokens(token, WETH, wrapToken, false);

        // pull token from user
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amountTokenDesired);

        (
            address adjustedToken,
            uint256 adjustedAmountDesired,
            uint256 adjustedAmountMin,
            uint256 decimalsOffset
        ) = _adjustToken(token, amountTokenDesired, amountTokenMin, wrapToken);

        (amountToken, amountETH) = _addLiquidity(
            adjustedToken,
            WETH,
            adjustedAmountDesired,
            msg.value,
            adjustedAmountMin,
            amountETHMin
        );
        address pair = KayenLibrary.pairFor(factory, adjustedToken, WETH);
        TransferHelper.safeTransfer(adjustedToken, pair, amountToken);

        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IKayenPair(pair).mint(to);

        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        _returnUnwrappedTokenAndDust(adjustedToken, msg.sender, wrapToken, decimalsOffset);
    }

    function removeLiquidityAndUnwrapToken(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        bool isTokenAWrapped,
        bool isTokenBWrapped,
        address to,
        uint256 deadline
    ) public virtual ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address adjustedTokenA = isTokenAWrapped
            ? IChilizWrapperFactory(wrapperFactory).underlyingToWrapped(tokenA)
            : tokenA;
        address adjustedTokenB = isTokenBWrapped
            ? IChilizWrapperFactory(wrapperFactory).underlyingToWrapped(tokenB)
            : tokenB;

        (uint256 amount0, uint256 amount1) = _removeLiquidity(
            adjustedTokenA,
            adjustedTokenB,
            liquidity,
            amountAMin,
            amountBMin
        );

        // unwrap and return tokens
        uint256 decimalsOffsetA = isTokenAWrapped ? IChilizWrappedERC20(adjustedTokenA).getDecimalsOffset() : 0;
        uint256 decimalsOffsetB = isTokenBWrapped ? IChilizWrappedERC20(adjustedTokenB).getDecimalsOffset() : 0;
        _returnUnwrappedTokenAndDust(adjustedTokenA, to, isTokenAWrapped, decimalsOffsetA);
        _returnUnwrappedTokenAndDust(adjustedTokenB, to, isTokenBWrapped, decimalsOffsetB);

        return (amount0, amount1);
    }

    function removeLiquidityETHAndUnwrap(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        bool isTokenWrapped,
        address to,
        uint256 deadline
    ) public virtual ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        address adjustedToken = isTokenWrapped
            ? IChilizWrapperFactory(wrapperFactory).underlyingToWrapped(token)
            : token;

        (uint256 amountTokenReturned, uint256 amountETHReturned) = _removeLiquidity(
            adjustedToken,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin
        );

        // // unwrap and return tokens
        uint256 decimalsOffset = isTokenWrapped ? IChilizWrappedERC20(adjustedToken).getDecimalsOffset() : 0;
        _returnUnwrappedTokenAndDust(adjustedToken, to, isTokenWrapped, decimalsOffset);
        IWETH(WETH).withdraw(amountETHReturned);
        TransferHelper.safeTransferETH(to, amountETHReturned);

        return (amountTokenReturned, amountETHReturned);
    }

    function swapExactTokensForTokens(
        address originTokenAddress,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual returns (uint256[] memory amounts, address reminderTokenAddress, uint256 reminder) {
        address wrappedTokenIn = IChilizWrapperFactory(wrapperFactory).wrappedTokenFor(originTokenAddress);

        require(path[0] == wrappedTokenIn, "MS: !path");

        TransferHelper.safeTransferFrom(originTokenAddress, msg.sender, address(this), amountIn);
        _approveAndWrap(originTokenAddress, amountIn);
        IERC20(wrappedTokenIn).approve(router, IERC20(wrappedTokenIn).balanceOf(address(this)));

        amounts = IKayenRouter02(router).swapExactTokensForTokens(
            IERC20(wrappedTokenIn).balanceOf(address(this)),
            amountOutMin,
            path,
            address(this),
            deadline
        );
        (reminderTokenAddress, reminder) = _unwrapAndTransfer(path[path.length - 1], to);
        emit MasterRouterSwap(amounts, reminderTokenAddress, reminder);
    }

    function _returnUnwrappedTokenAndDust(address token, address to, bool wrapToken, uint256 decimalsOffset) private {
        if (wrapToken) {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance == 0) return;

            uint256 tokenOutReturnAmount = (balance / decimalsOffset) * decimalsOffset;
            if (tokenOutReturnAmount > 0) {
                _approveAndUnwrap(token, tokenOutReturnAmount, to);
            }

            uint256 dust = IERC20(token).balanceOf(address(this));
            // transfer dust as wrapped token
            if (dust > 0) {
                TransferHelper.safeTransfer(token, to, dust);
            }
        } else {
            uint256 balance = IERC20(token).balanceOf(address(this));
            if (balance > 0) TransferHelper.safeTransfer(token, to, balance);
        }
    }

    function _unwrapAndTransfer(
        address wrappedTokenOut,
        address to
    ) private returns (address reminderTokenAddress, uint256 reminder) {
        // address wrappedTokenOut = path[path.length - 1];
        uint256 balanceOut = IERC20(wrappedTokenOut).balanceOf(address(this));
        if (balanceOut == 0) return (reminderTokenAddress, reminder);

        uint256 tokenOutOffset = IChilizWrappedERC20(wrappedTokenOut).getDecimalsOffset();
        uint256 tokenOutReturnAmount = (balanceOut / tokenOutOffset) * tokenOutOffset;

        IERC20(wrappedTokenOut).approve(wrapperFactory, tokenOutReturnAmount); // no need for check return value, bc addliquidity will revert if approve was declined.

        if (tokenOutReturnAmount > 0) {
            IChilizWrapperFactory(wrapperFactory).unwrap(to, wrappedTokenOut, tokenOutReturnAmount);
        }

        // transfer dust as wrapped token
        if (IERC20(wrappedTokenOut).balanceOf(address(this)) > 0) {
            reminderTokenAddress = address(wrappedTokenOut);
            reminder = IERC20(wrappedTokenOut).balanceOf(address(this));
            TransferHelper.safeTransfer(wrappedTokenOut, to, IERC20(wrappedTokenOut).balanceOf(address(this)));
        }
    }

    function _approveAndWrap(address token, uint256 amount) private returns (address wrappedToken) {
        uint256 allowance = IERC20(token).allowance(address(this), wrapperFactory);
        if (allowance < amount) {
            // Approve the maximum possible amount
            IERC20(token).approve(wrapperFactory, type(uint256).max);
        }
        wrappedToken = IChilizWrapperFactory(wrapperFactory).wrap(address(this), token, amount);
    }

    function _approveAndUnwrap(address token, uint256 amount, address to) private {
        uint256 allowance = IERC20(token).allowance(address(this), wrapperFactory);
        if (allowance < amount) {
            // Approve the maximum possible amount
            IERC20(token).approve(wrapperFactory, type(uint256).max);
        }
        IChilizWrapperFactory(wrapperFactory).unwrap(to, token, amount);
    }

    function _validateTokens(address tokenA, address tokenB, bool wrapTokenA, bool wrapTokenB) internal view {
        // check: if wrapTokenA is false, tokenA cannot have decimal of 0.
        if (!wrapTokenA && IERC20(tokenA).decimals() == 0) revert MustWrapToken();
        if (!wrapTokenB && IERC20(tokenB).decimals() == 0) revert MustWrapToken();
    }

    function _adjustToken(
        address token,
        uint256 amountDesired,
        uint256 amountMin,
        bool wrap
    )
        private
        returns (
            address adjustedToken,
            uint256 adjustedAmountDesired,
            uint256 adjustedAmountMin,
            uint256 decimalsOffset
        )
    {
        if (wrap) {
            adjustedToken = _approveAndWrap(token, amountDesired);
            decimalsOffset = IChilizWrappedERC20(adjustedToken).getDecimalsOffset();
            adjustedAmountDesired = amountDesired * decimalsOffset;
            adjustedAmountMin = amountMin * decimalsOffset;
        } else {
            adjustedToken = token;
            adjustedAmountDesired = amountDesired;
            adjustedAmountMin = amountMin;
        }
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IKayenFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IKayenFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = KayenLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = KayenLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) revert InsufficientBAmount();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = KayenLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                if (amountAOptimal < amountAMin) revert InsufficientAAmount();
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pair = KayenLibrary.pairFor(factory, tokenA, tokenB);
        IKayenPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IKayenPair(pair).burn(address(this));
        (address token0, ) = KayenLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        if (amountA < amountAMin) revert InsufficientAAmount();
        if (amountB < amountBMin) revert InsufficientBAmount();
    }
}

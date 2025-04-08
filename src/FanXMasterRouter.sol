// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IFanXRouter02.sol";
import "./interfaces/IFanXMasterRouter.sol";
import "./interfaces/IWrapperFactory.sol";
import "./interfaces/IWrappedERC20.sol";
import "./interfaces/IWETH.sol";
import "./libraries/FanXLibrary.sol";
import "./libraries/TransferHelper.sol";

// This is a Master Router contract that wrap under 18 decimal token
// and interact with router to addliqudity and swap tokens.
contract FanXMasterRouter is IFanXMasterRouter {
    address public immutable factory;
    address public immutable WETH;
    address public immutable router;
    address public immutable wrapperFactory;

    constructor(address _factory, address _wrapperFactory, address _router, address _WETH) {
        require(_factory != address(0), "JMR: ZERO_ADDRESS");
        require(_wrapperFactory != address(0), "JMR: ZERO_ADDRESS");
        require(_router != address(0), "JMR: ZERO_ADDRESS");
        require(_WETH != address(0), "JMR: ZERO_ADDRESS");

        factory = _factory;
        wrapperFactory = _wrapperFactory;
        router = _router;
        WETH = _WETH;
    }

    receive() external payable {
        require(msg.sender == WETH || msg.sender == router, "MS: !Wrong Sender"); // only accept ETH via fallback from the WETH and router contract
    }

    function wrapTokensAndaddLiquidity(
        address tokenA, // origin token
        address tokenB, // origin token
        uint256 amountADesired, // unwrapped.
        uint256 amountBDesired, // unwrapped.
        uint256 amountAMin, // unwrapped
        uint256 amountBMin, // unwrapped
        address to,
        uint256 deadline
    ) public virtual override returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        // get token from user
        TransferHelper.safeTransferFrom(tokenA, msg.sender, address(this), amountADesired);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, address(this), amountBDesired);

        address wrappedTokenA = _approveAndWrap(tokenA, amountADesired);
        address wrappedTokenB = _approveAndWrap(tokenB, amountBDesired);

        uint256 tokenAOffset = IWrappedERC20(wrappedTokenA).getDecimalsOffset();
        uint256 tokenBOffset = IWrappedERC20(wrappedTokenB).getDecimalsOffset();

        IERC20(wrappedTokenA).approve(router, IERC20(wrappedTokenA).balanceOf(address(this))); // no need for check return value, bc addliquidity will revert if approve was declined.
        IERC20(wrappedTokenB).approve(router, IERC20(wrappedTokenB).balanceOf(address(this)));

        // add liquidity
        (amountA, amountB, liquidity) = IFanXRouter02(router).addLiquidity(
            wrappedTokenA,
            wrappedTokenB,
            amountADesired * tokenAOffset,
            amountBDesired * tokenBOffset,
            amountAMin,
            amountBMin,
            to,
            deadline
        );
        _unwrapAndTransfer(wrappedTokenA, to);
        _unwrapAndTransfer(wrappedTokenB, to);
    }

    function wrapTokenAndaddLiquidityETH(
        // only use wrapTokenAndaddLiquidityETH to create pool.
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external payable virtual override returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amountTokenDesired);
        address wrappedToken = _approveAndWrap(token, amountTokenDesired);

        uint256 tokenOffset = IWrappedERC20(wrappedToken).getDecimalsOffset();

        IERC20(wrappedToken).approve(router, IERC20(wrappedToken).balanceOf(address(this))); // no need for check return value, bc addliquidity will revert if approve was declined.

        (amountToken, amountETH, liquidity) = IFanXRouter02(router).addLiquidityETH{value: msg.value}(
            wrappedToken,
            amountTokenDesired * tokenOffset,
            amountTokenMin * tokenOffset,
            amountETHMin,
            to,
            deadline
        );

        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        _unwrapAndTransfer(wrappedToken, to);
    }

    function removeLiquidityAndUnwrapToken(
        address tokenA, // token origin addr
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address wrappedTokenA = IWrapperFactory(wrapperFactory).wrappedTokenFor(tokenA);
        address wrappedTokenB = IWrapperFactory(wrapperFactory).wrappedTokenFor(tokenB);
        address pair = FanXLibrary.pairFor(factory, wrappedTokenA, wrappedTokenB);
        TransferHelper.safeTransferFrom(pair, msg.sender, address(this), liquidity);

        IERC20(pair).approve(router, liquidity);

        (amountA, amountB) = IFanXRouter02(router).removeLiquidity(
            wrappedTokenA,
            wrappedTokenB,
            liquidity,
            amountAMin,
            amountBMin,
            address(this),
            deadline
        );

        uint256 tokenAOffset = IWrappedERC20(wrappedTokenA).getDecimalsOffset();
        uint256 tokenBOffset = IWrappedERC20(wrappedTokenB).getDecimalsOffset();
        uint256 tokenAReturnAmount = (amountA / tokenAOffset) * tokenAOffset;
        uint256 tokenBReturnAmount = (amountB / tokenBOffset) * tokenBOffset;

        IERC20(wrappedTokenA).approve(wrapperFactory, tokenAReturnAmount); // no need for check return value, bc addliquidity will revert if approve was declined.
        IERC20(wrappedTokenB).approve(wrapperFactory, tokenBReturnAmount); // no need for check return value, bc addliquidity will revert if approve was declined.

        if (tokenAReturnAmount > 0) {
            IWrapperFactory(wrapperFactory).unwrap(to, wrappedTokenA, tokenAReturnAmount);
        }
        if (tokenBReturnAmount > 0) {
            IWrapperFactory(wrapperFactory).unwrap(to, wrappedTokenB, tokenBReturnAmount);
        }

        // transfer dust as wrapped token
        if (amountA - tokenAReturnAmount > 0) {
            TransferHelper.safeTransfer(wrappedTokenA, to, amountA - tokenAReturnAmount);
        }
        if (amountB - tokenBReturnAmount > 0) {
            TransferHelper.safeTransfer(wrappedTokenB, to, amountB - tokenBReturnAmount);
        }
    }

    function removeLiquidityETHAndUnwrap(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override returns (uint256 amountToken, uint256 amountETH) {
        address wrappedToken = IWrapperFactory(wrapperFactory).wrappedTokenFor(token);
        address pair = FanXLibrary.pairFor(factory, wrappedToken, address(WETH));
        TransferHelper.safeTransferFrom(pair, msg.sender, address(this), liquidity);

        IERC20(pair).approve(router, liquidity);

        (amountToken, amountETH) = IFanXRouter02(router).removeLiquidityETH(
            wrappedToken,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );

        uint256 tokenOffset = IWrappedERC20(wrappedToken).getDecimalsOffset();
        uint256 tokenReturnAmount = (amountToken / tokenOffset) * tokenOffset;

        IERC20(wrappedToken).approve(wrapperFactory, tokenReturnAmount); // no need for check return value, bc addliquidity will revert if approve was declined.

        if (tokenReturnAmount > 0) {
            IWrapperFactory(wrapperFactory).unwrap(to, wrappedToken, tokenReturnAmount);
        }
        // transfer dust as wrapped token
        if (amountToken - tokenReturnAmount > 0) {
            TransferHelper.safeTransfer(wrappedToken, to, amountToken - tokenReturnAmount);
        }

        (bool success, ) = to.call{value: address(this).balance}("");
        require(success);
    }

    function swapExactTokensForTokens(
        address originTokenAddress,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override returns (uint256[] memory amounts, address reminderTokenAddress, uint256 reminder) {
        address wrappedTokenIn = IWrapperFactory(wrapperFactory).wrappedTokenFor(originTokenAddress);

        require(path[0] == wrappedTokenIn, "MS: !path");

        TransferHelper.safeTransferFrom(originTokenAddress, msg.sender, address(this), amountIn);
        _approveAndWrap(originTokenAddress, amountIn);
        IERC20(wrappedTokenIn).approve(router, IERC20(wrappedTokenIn).balanceOf(address(this)));

        amounts = IFanXRouter02(router).swapExactTokensForTokens(
            IERC20(wrappedTokenIn).balanceOf(address(this)),
            amountOutMin,
            path,
            address(this),
            deadline
        );
        (reminderTokenAddress, reminder) = _unwrapAndTransfer(path[path.length - 1], to);
        emit MasterRouterSwap(amounts, reminderTokenAddress, reminder);
    }

    // function swapTokensForExactTokens(
    //     address originTokenAddress,
    //     uint256 amountOut,
    //     uint256 amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external virtual returns (uint256[] memory amounts, address reminderTokenAddress, uint256 reminder) {
    //     address wrappedTokenIn = IWrapperFactory(wrapperFactory).wrappedTokenFor(originTokenAddress);

    //     require(path[0] == wrappedTokenIn, "MS: !path");
    //     address wrappedTokenOut = path[path.length - 1];
    //     uint256 tokenOutOffset = IWrappedERC20(wrappedTokenOut).getDecimalsOffset();

    //     amounts = FanXLibrary.getAmountsIn(factory, amountOut*tokenOutOffset, path);

    //     TransferHelper.safeTransferFrom(originTokenAddress, msg.sender, address(this), amounts[0]);
    //     IERC20(originTokenAddress).approve(wrapperFactory, amounts[0]); // no need for check return value, bc addliquidity will revert if approve was declined.
    //     IWrapperFactory(wrapperFactory).wrap(address(this), originTokenAddress, amounts[0]);
    //     IERC20(wrappedTokenIn).approve(router, IERC20(wrappedTokenIn).balanceOf(address(this)));

    //     IFanXRouter02(router).swapTokensForExactTokens( // no need to get return value
    //         amountOut*tokenOutOffset,
    //         amountInMax,
    //         path,
    //         address(this),
    //         deadline
    //     );

    //     uint256 balanceOut = IERC20(wrappedTokenOut).balanceOf(address(this));
    //     uint256 tokenOutReturnAmount = (balanceOut / tokenOutOffset) * tokenOutOffset;

    //     IERC20(wrappedTokenOut).approve(wrapperFactory, tokenOutReturnAmount); // no need for check return value, bc addliquidity will revert if approve was declined.

    //     if (tokenOutReturnAmount > 0) {
    //         IWrapperFactory(wrapperFactory).unwrap(to, wrappedTokenOut, tokenOutReturnAmount);
    //     }

    //     // transfer dust as wrapped token
    //     if (IERC20(wrappedTokenOut).balanceOf(address(this)) > 0) {
    //         reminderTokenAddress = address(wrappedTokenOut);
    //         reminder = IERC20(wrappedTokenOut).balanceOf(address(this));
    //         TransferHelper.safeTransfer(wrappedTokenOut, to, IERC20(wrappedTokenOut).balanceOf(address(this)));
    //     }
    // }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        returns (uint256[] memory amounts, address reminderTokenAddress, uint256 reminder)
    {
        amounts = IFanXRouter02(router).swapExactETHForTokens{value: msg.value}(
            amountOutMin,
            path,
            address(this),
            deadline
        );
        (reminderTokenAddress, reminder) = _unwrapAndTransfer(path[path.length - 1], to);
        emit MasterRouterSwap(amounts, reminderTokenAddress, reminder);
    }

    function swapExactTokensForETH(
        address originTokenAddress,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override returns (uint256[] memory amounts) {
        address wrappedTokenIn = IWrapperFactory(wrapperFactory).wrappedTokenFor(originTokenAddress);

        require(path[0] == wrappedTokenIn, "MS: !path");

        TransferHelper.safeTransferFrom(originTokenAddress, msg.sender, address(this), amountIn);
        _approveAndWrap(originTokenAddress, amountIn);
        IERC20(wrappedTokenIn).approve(router, IERC20(wrappedTokenIn).balanceOf(address(this)));

        amounts = IFanXRouter02(router).swapExactTokensForETH(
            IERC20(wrappedTokenIn).balanceOf(address(this)),
            amountOutMin,
            path,
            to,
            deadline
        );
        emit MasterRouterSwap(amounts, address(0), 0);
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts, address reminderTokenAddress, uint256 reminder) {
        amounts = IFanXRouter02(router).swapETHForExactTokens{value: msg.value}(
            amountOut,
            path,
            address(this),
            deadline
        );

        (reminderTokenAddress, reminder) = _unwrapAndTransfer(path[path.length - 1], to);
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
        emit MasterRouterSwap(amounts, reminderTokenAddress, reminder);
    }

    function _unwrapAndTransfer(
        address wrappedTokenOut,
        address to
    ) private returns (address reminderTokenAddress, uint256 reminder) {
        // address wrappedTokenOut = path[path.length - 1];
        uint256 balanceOut = IERC20(wrappedTokenOut).balanceOf(address(this));
        if (balanceOut == 0) return (reminderTokenAddress, reminder);

        uint256 tokenOutOffset = IWrappedERC20(wrappedTokenOut).getDecimalsOffset();
        uint256 tokenOutReturnAmount = (balanceOut / tokenOutOffset) * tokenOutOffset;

        IERC20(wrappedTokenOut).approve(wrapperFactory, tokenOutReturnAmount); // no need for check return value, bc addliquidity will revert if approve was declined.

        if (tokenOutReturnAmount > 0) {
            IWrapperFactory(wrapperFactory).unwrap(to, wrappedTokenOut, tokenOutReturnAmount);
        }

        // transfer dust as wrapped token
        if (IERC20(wrappedTokenOut).balanceOf(address(this)) > 0) {
            reminderTokenAddress = address(wrappedTokenOut);
            reminder = IERC20(wrappedTokenOut).balanceOf(address(this));
            TransferHelper.safeTransfer(wrappedTokenOut, to, IERC20(wrappedTokenOut).balanceOf(address(this)));
        }
    }

    function _approveAndWrap(address token, uint256 amount) private returns (address wrappedToken) {
        IERC20(token).approve(wrapperFactory, amount); // no need for check return value, bc addliquidity will revert if approve was declined.
        wrappedToken = IWrapperFactory(wrapperFactory).wrap(address(this), token, amount);
    }
}

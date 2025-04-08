// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./interfaces/IERC20.sol";
import "./interfaces/IFanXMasterRouterV2.sol";
import "./interfaces/IWrapperFactory.sol";
import "./interfaces/IWrappedERC20.sol";
import "./interfaces/IWETH.sol";
import "./libraries/FanXLibrary.sol";
import "./libraries/TransferHelper.sol";
import "./libraries/SafeERC20.sol";

/// @title FanXMasterRouterV2
/// @notice This contract provides advanced routing capabilities for the FanX decentralized exchange
/// @dev Implements the IFanXMasterRouterV2 interface
/// @dev Handles token wrapping, liquidity provision, and swaps with support for both wrapped and unwrapped tokens
contract FanXMasterRouterV2 is IFanXMasterRouterV2 {
    // using SafeERC20 for IERC20;

    /// @notice Address of the FanX factory contract
    /// @dev This is immutable and set in the constructor
    address public immutable factory;

    /// @notice Address of the Wrapped Ether (WETH) contract
    /// @dev This is immutable and set in the constructor
    address public immutable WETH;

    /// @notice Address of the Chiliz wrapper factory contract
    /// @dev This is immutable and set in the constructor
    address public immutable wrapperFactory;

    /// @notice Initializes the contract with factory, wrapper factory, and WETH addresses
    /// @dev Sets the immutable state variables
    /// @param _factory Address of the FanX factory contract
    /// @param _wrapperFactory Address of the Chiliz wrapper factory contract
    /// @param _WETH Address of the Wrapped Ether (WETH) contract
    /// @custom:security Non-zero address check is performed to prevent accidental zero address initialization
    constructor(address _factory, address _wrapperFactory, address _WETH) {
        require(_factory != address(0) && _wrapperFactory != address(0) && _WETH != address(0), "MV2: ZERO_ADDRESS");
        factory = _factory;
        wrapperFactory = _wrapperFactory;
        WETH = _WETH;
    }

    /// @notice Ensures that the transaction is executed before the deadline
    /// @dev This modifier is used to prevent pending transactions from being executed after a certain time
    /// @param deadline The Unix timestamp after which the transaction will revert
    /// @custom:error Expired If the current block timestamp is greater than or equal to the deadline
    modifier ensure(uint256 deadline) {
        if (deadline < block.timestamp) revert Expired();
        _;
    }

    /// @notice Allows the contract to receive ETH
    /// @dev This function is called when ETH is sent to the contract
    /// @custom:security Only allows ETH to be received from the WETH contract
    receive() external payable {
        require(msg.sender == WETH, "MV2: ETH_UNACCEPTABLE");
    }

    /// @notice Wraps tokens if necessary and adds liquidity to a FanX pool
    /// @param tokenA Address of the first token in the pair
    /// @param tokenB Address of the second token in the pair
    /// @param amountADesired The amount of tokenA to add as liquidity if the B/A price is <= amountBDesired/amountADesired (A depreciates)
    /// @param amountBDesired The amount of tokenB to add as liquidity if the A/B price is <= amountADesired/amountBDesired (B depreciates)
    /// @param amountAMin Minimum amount of tokenA to add as liquidity. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param amountBMin Minimum amount of tokenB to add as liquidity. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param wrapTokenA Boolean indicating whether tokenA should be wrapped
    /// @param wrapTokenB Boolean indicating whether tokenB should be wrapped
    /// @param to Recipient of the liquidity tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amountA The amount of tokenA sent to the pool
    /// @return amountB The amount of tokenB sent to the pool
    /// @return liquidity The amount of liquidity tokens minted
    function wrapTokensAndaddLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        bool wrapTokenA,
        bool wrapTokenB,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        _validateTokens(tokenA, tokenB, wrapTokenA, wrapTokenB);

        TransferHelper.safeTransferFrom(tokenA, msg.sender, address(this), amountADesired);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, address(this), amountBDesired);

        (address adjustedTokenA, uint256 adjustedAmountADesired, uint256 decimalsOffsetA) = _adjustToken(
            tokenA,
            amountADesired,
            wrapTokenA
        );
        (address adjustedTokenB, uint256 adjustedAmountBDesired, uint256 decimalsOffsetB) = _adjustToken(
            tokenB,
            amountBDesired,
            wrapTokenB
        );

        (amountA, amountB) = _addLiquidity(
            adjustedTokenA,
            adjustedTokenB,
            adjustedAmountADesired,
            adjustedAmountBDesired,
            amountAMin,
            amountBMin
        );

        address pair = FanXLibrary.pairFor(factory, adjustedTokenA, adjustedTokenB);
        TransferHelper.safeTransfer(adjustedTokenA, pair, amountA);
        TransferHelper.safeTransfer(adjustedTokenB, pair, amountB);
        liquidity = IFanXPair(pair).mint(to);

        _returnUnwrappedTokenAndDust(adjustedTokenA, msg.sender, wrapTokenA, decimalsOffsetA);
        _returnUnwrappedTokenAndDust(adjustedTokenB, msg.sender, wrapTokenB, decimalsOffsetB);
    }

    /// @notice Wraps tokens if necessary and adds liquidity to a FanX pool with ETH
    /// @param token Address of the token to be paired with ETH
    /// @param amountTokenDesired The amount of token to add as liquidity if the ETH/token price is <= msg.value/amountTokenDesired (token depreciates)
    /// @param amountTokenMin Minimum amount of token to add as liquidity. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param amountETHMin Minimum amount of ETH to add as liquidity
    /// @param wrapToken Boolean indicating whether the token should be wrapped
    /// @param to Recipient of the liquidity tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amountToken The amount of token sent to the pool
    /// @return amountETH The amount of ETH sent to the pool
    /// @return liquidity The amount of liquidity tokens minted
    function wrapTokenAndaddLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        bool wrapToken,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        _validateTokens(token, WETH, wrapToken, false);

        TransferHelper.safeTransferFrom(token, msg.sender, address(this), amountTokenDesired);

        (address adjustedToken, uint256 adjustedAmountDesired, uint256 decimalsOffset) = _adjustToken(
            token,
            amountTokenDesired,
            wrapToken
        );

        (amountToken, amountETH) = _addLiquidity(
            adjustedToken,
            WETH,
            adjustedAmountDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = FanXLibrary.pairFor(factory, adjustedToken, WETH);
        TransferHelper.safeTransfer(adjustedToken, pair, amountToken);

        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IFanXPair(pair).mint(to);

        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
        _returnUnwrappedTokenAndDust(adjustedToken, msg.sender, wrapToken, decimalsOffset);
    }

    /// @notice Removes liquidity from a pair and optionally unwraps tokens
    /// @dev This function removes liquidity from a pair and can unwrap tokens if they are wrapped
    /// @param tokenA The address of the first token in the pair (must be wrapped or regular token, not unwrapped)
    /// @param tokenB The address of the second token in the pair (must be wrapped or regular token, not unwrapped)
    /// @param liquidity The amount of liquidity tokens to burn
    /// @param amountAMin The minimum amount of tokenA that must be received for the transaction not to revert. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param amountBMin The minimum amount of tokenB that must be received for the transaction not to revert. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param receiveUnwrappedTokenA If true, tokenA will be unwrapped before being sent to the recipient
    /// @param receiveUnwrappedTokenB If true, tokenB will be unwrapped before being sent to the recipient
    /// @param to The address that will receive the tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amountA The amount of tokenA received (in wrapped token amount, regardless of receiveUnwrappedTokenA)
    /// @return amountB The amount of tokenB received (in wrapped token amount, regardless of receiveUnwrappedTokenB)
    function removeLiquidityAndUnwrapToken(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        bool receiveUnwrappedTokenA,
        bool receiveUnwrappedTokenB,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        // must put wrapped address for tokenA and tokenB. Wrapped token or just regular token address.

        address underlyingA = IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenA);
        address underlyingB = IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenB);
        uint256 decimalsOffsetA = underlyingA == address(0) ? 0 : IWrappedERC20(tokenA).getDecimalsOffset();
        uint256 decimalsOffsetB = underlyingB == address(0) ? 0 : IWrappedERC20(tokenB).getDecimalsOffset();

        (uint256 amount0, uint256 amount1) = _removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin);

        _returnUnwrappedTokenAndDust(tokenA, to, receiveUnwrappedTokenA, decimalsOffsetA);
        _returnUnwrappedTokenAndDust(tokenB, to, receiveUnwrappedTokenB, decimalsOffsetB);

        return (amount0, amount1);
    }

    /// @notice Removes liquidity from an ETH pair and optionally unwraps the token
    /// @dev This function removes liquidity from an ETH pair and can unwrap the token if it is wrapped
    /// @param token The address of the token in the pair with ETH (must be wrapped or regular token, not unwrapped)
    /// @param liquidity The amount of liquidity tokens to burn
    /// @param amountTokenMin The minimum amount of token that must be received for the transaction not to revert
    /// @param amountETHMin The minimum amount of ETH that must be received for the transaction not to revert. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param receiveUnwrappedToken If true, the token will be unwrapped before being sent to the recipient. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param to The address that will receive the token and ETH
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amountToken The amount of token received (in wrapped token amount, regardless of receiveUnwrappedToken)
    /// @return amountETH The amount of ETH received
    function removeLiquidityETHAndUnwrap(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        bool receiveUnwrappedToken,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        address underlying = IWrapperFactory(wrapperFactory).wrappedToUnderlying(token);
        uint256 decimalsOffset = underlying == address(0) ? 0 : IWrappedERC20(token).getDecimalsOffset();

        (amountToken, amountETH) = _removeLiquidity(token, WETH, liquidity, amountTokenMin, amountETHMin);

        _returnUnwrappedTokenAndDust(token, to, receiveUnwrappedToken, decimalsOffset);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }

    function _swap(uint256[] memory amounts, address[] memory path, address _to) internal virtual {
        require(amounts.length == path.length, "Amounts and path length mismatch");
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = FanXLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? FanXLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IFanXPair(FanXLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    /// @notice Swaps an exact amount of input tokens for as many output tokens as possible
    /// @dev The first element of path is the input token, the last is the output token, and any intermediate elements represent intermediate pairs to trade through
    /// @dev msg.sender should have already given the router an allowance of at least amountIn on the input token
    /// @param amountIn The amount of input tokens to send. For unwrapped tokens, this should be the raw token amount. For wrapped tokens, this should be the wrapped token amount.
    /// @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity
    /// @param isTokenInWrapped Boolean indicating whether the input token is wrapped
    /// @param receiveUnwrappedToken Boolean indicating whether to receive unwrapped tokens
    /// @param to Recipient of the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amounts The input token amount and all subsequent output token amounts
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        bool isTokenInWrapped,
        bool receiveUnwrappedToken,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        address tokenIn = path[0];
        address unwrappedTokenIn = !isTokenInWrapped
            ? IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenIn)
            : address(0);

        if (unwrappedTokenIn != address(0)) {
            TransferHelper.safeTransferFrom(unwrappedTokenIn, msg.sender, address(this), amountIn);
            (tokenIn, amountIn, ) = _adjustToken(unwrappedTokenIn, amountIn, true);
            require(tokenIn == path[0], "MV2: WRONG_PATH");
            TransferHelper.safeTransfer(tokenIn, FanXLibrary.pairFor(factory, tokenIn, path[1]), amountIn);
        } else {
            TransferHelper.safeTransferFrom(
                tokenIn,
                msg.sender,
                FanXLibrary.pairFor(factory, tokenIn, path[1]),
                amountIn
            );
        }

        amounts = FanXLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert FanXLibrary.InsufficientOutputAmount();
        _swap(amounts, path, address(this));

        address tokenOut = path[path.length - 1];
        bool isWrapped = receiveUnwrappedToken &&
            IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenOut) != address(0);

        _returnUnwrappedTokenAndDust(
            tokenOut,
            to,
            isWrapped,
            isWrapped ? IWrappedERC20(tokenOut).getDecimalsOffset() : 0
        );
    }

    /// @notice Swaps an exact amount of output tokens for as few input tokens as possible, along the route determined by the path
    /// @dev The first element of path is the input token, the last is the output token, and any intermediate elements represent intermediate tokens to trade through
    /// @param amountOut The amount of output tokens to receive. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param amountInMax The maximum amount of input tokens that can be required before the transaction reverts. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity
    /// @param isTokenInWrapped Boolean indicating whether the input token is wrapped
    /// @param receiveUnwrappedToken Boolean indicating whether to receive unwrapped tokens
    /// @param to Recipient of the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amounts The input token amount and all subsequent output token amounts
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        bool isTokenInWrapped,
        bool receiveUnwrappedToken,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = FanXLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax) revert ExcessiveInputAmount();
        address tokenIn = path[0];
        uint256 amountIn = amounts[0];
        address unwrappedTokenIn = !isTokenInWrapped
            ? IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenIn)
            : address(0);

        if (unwrappedTokenIn != address(0)) {
            uint256 unwrappedAmountIn = amountIn / IWrappedERC20(path[0]).getDecimalsOffset() + 1;
            TransferHelper.safeTransferFrom(unwrappedTokenIn, msg.sender, address(this), unwrappedAmountIn);
            (tokenIn, amountIn, ) = _adjustToken(unwrappedTokenIn, unwrappedAmountIn, true);
            require(tokenIn == path[0] && amountIn > amounts[0], "MV2: INVALID_AMOUNTIN");
            TransferHelper.safeTransfer(tokenIn, FanXLibrary.pairFor(factory, tokenIn, path[1]), amounts[0]);
        } else {
            TransferHelper.safeTransferFrom(
                tokenIn,
                msg.sender,
                FanXLibrary.pairFor(factory, tokenIn, path[1]),
                amountIn
            );
        }

        _swap(amounts, path, receiveUnwrappedToken ? address(this) : to);

        if (amountIn > amounts[0]) {
            TransferHelper.safeTransfer(tokenIn, to, amountIn - amounts[0]);
        }
        if (receiveUnwrappedToken) {
            address tokenOut = path[path.length - 1];
            bool isWrapped = IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenOut) != address(0);
            _returnUnwrappedTokenAndDust(
                tokenOut,
                to,
                isWrapped,
                isWrapped ? IWrappedERC20(tokenOut).getDecimalsOffset() : 0
            );
        }
    }

    /// @notice Swaps an exact amount of ETH for as many output tokens as possible
    /// @dev The first element of path must be WETH
    /// @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity
    /// @param receiveUnwrappedToken If true, the output tokens will be unwrapped before being sent to the recipient
    /// @param to Recipient of the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amounts The input token amount and all subsequent output token amounts
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        bool receiveUnwrappedToken,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
        if (path[0] != WETH) revert FanXLibrary.InvalidPath();
        amounts = FanXLibrary.getAmountsOut(factory, msg.value, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert FanXLibrary.InsufficientOutputAmount();
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(FanXLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, address(this));

        address tokenOut = path[path.length - 1];
        bool isWrapped = receiveUnwrappedToken &&
            IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenOut) != address(0);

        _returnUnwrappedTokenAndDust(
            tokenOut,
            to,
            isWrapped,
            isWrapped ? IWrappedERC20(tokenOut).getDecimalsOffset() : 0
        );
    }

    /// @notice Swaps tokens for an exact amount of ETH
    /// @dev The first element of path is the input token, the last is WETH, and any intermediate elements represent intermediate pairs to trade through
    /// @dev msg.sender should have already given the router an allowance of at least amountInMax on the input token
    /// @param amountOut The exact amount of ETH to receive
    /// @param amountInMax The maximum amount of input tokens that can be required before the transaction reverts. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity
    /// @param isTokenInWrapped Boolean indicating whether the input token is wrapped
    /// @param to Recipient of the output ETH
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amounts The input token amount and all subsequent output token amounts
    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        bool isTokenInWrapped,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        if (path[path.length - 1] != WETH) revert FanXLibrary.InvalidPath();
        amounts = FanXLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > amountInMax) revert ExcessiveInputAmount();
        address tokenIn = path[0];
        uint256 amountIn = amounts[0];
        address unwrappedTokenIn = !isTokenInWrapped
            ? IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenIn)
            : address(0);

        if (unwrappedTokenIn != address(0)) {
            uint256 decimalsOffset = IWrappedERC20(tokenIn).getDecimalsOffset();
            uint256 unwrappedAmountIn = (amountIn + decimalsOffset - 1) / decimalsOffset;
            TransferHelper.safeTransferFrom(unwrappedTokenIn, msg.sender, address(this), unwrappedAmountIn);
            (tokenIn, amountIn, ) = _adjustToken(unwrappedTokenIn, unwrappedAmountIn, true);
            require(tokenIn == path[0], "MV2: WRONG_PATH");
            require(amountIn >= amounts[0], "MV2: INVALID_AMOUNTIN");

            TransferHelper.safeTransfer(tokenIn, FanXLibrary.pairFor(factory, tokenIn, path[1]), amounts[0]);
        } else {
            TransferHelper.safeTransferFrom(
                tokenIn,
                msg.sender,
                FanXLibrary.pairFor(factory, tokenIn, path[1]),
                amountIn
            );
        }

        _swap(amounts, path, address(this));
        if (amountIn > amounts[0]) {
            TransferHelper.safeTransfer(tokenIn, to, amountIn - amounts[0]);
        }
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /// @notice Swaps an exact amount of input tokens for ETH
    /// @dev The first element of path is the input token, the last is WETH, and any intermediate elements represent intermediate pairs to trade through
    /// @param amountIn The amount of input tokens to swap.
    /// @param amountOutMin The minimum amount of output tokens that must be received for the transaction not to revert. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity
    /// @param isTokenInWrapped Boolean indicating whether the input token is wrapped
    /// @param to Recipient of the output ETH
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amounts The input token amount and all subsequent output token amounts
    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        bool isTokenInWrapped,
        address to,
        uint256 deadline
    ) external virtual ensure(deadline) returns (uint256[] memory amounts) {
        address tokenIn = path[0];
        address unwrappedTokenIn = !isTokenInWrapped
            ? IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenIn)
            : address(0);

        // if tokenIn is unwrapped
        if (unwrappedTokenIn != address(0)) {
            TransferHelper.safeTransferFrom(unwrappedTokenIn, msg.sender, address(this), amountIn);
            (tokenIn, amountIn, ) = _adjustToken(unwrappedTokenIn, amountIn, true);
            require(tokenIn == path[0], "MV2: WRONG_PATH");
            TransferHelper.safeTransfer(tokenIn, FanXLibrary.pairFor(factory, tokenIn, path[1]), amountIn);
        } else {
            TransferHelper.safeTransferFrom(
                tokenIn,
                msg.sender,
                FanXLibrary.pairFor(factory, tokenIn, path[1]),
                amountIn
            );
        }

        if (path[path.length - 1] != WETH) revert FanXLibrary.InvalidPath();
        amounts = FanXLibrary.getAmountsOut(factory, amountIn, path);
        if (amounts[amounts.length - 1] < amountOutMin) revert FanXLibrary.InsufficientOutputAmount();
        // TransferHelper.safeTransfer(path[0], FanXLibrary.pairFor(factory, path[0], path[1]), amounts[0]);

        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    /// @notice Swaps ETH for an exact amount of output tokens
    /// @dev The first element of path is WETH, the last is the output token, and any intermediate elements represent intermediate pairs to trade through
    /// @param amountOut The exact amount of output tokens to receive. For unwrapped/wrapped tokens, this should be in terms of the wrapped token amount. For other tokens, it should be in terms of the token itself.
    /// @param path An array of token addresses. path.length must be >= 2. Pools for each consecutive pair of addresses must exist and have liquidity
    /// @param receiveUnwrappedToken Boolean indicating whether to receive unwrapped tokens
    /// @param to Recipient of the output tokens
    /// @param deadline Unix timestamp after which the transaction will revert
    /// @return amounts The input token amount and all subsequent output token amounts
    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        bool receiveUnwrappedToken,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
        if (path[0] != WETH) revert FanXLibrary.InvalidPath();
        amounts = FanXLibrary.getAmountsIn(factory, amountOut, path);
        if (amounts[0] > msg.value) revert ExcessiveInputAmount();
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(FanXLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, address(this));
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);

        address tokenOut = path[path.length - 1];
        bool isWrapped = receiveUnwrappedToken &&
            IWrapperFactory(wrapperFactory).wrappedToUnderlying(tokenOut) != address(0);

        _returnUnwrappedTokenAndDust(
            tokenOut,
            to,
            isWrapped,
            isWrapped ? IWrappedERC20(tokenOut).getDecimalsOffset() : 0
        );
    }

    /**
     * Internal
     */

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

    function _approveAndWrap(address token, uint256 amount) private returns (address wrappedToken) {
        uint256 allowance = IERC20(token).allowance(address(this), wrapperFactory);
        if (allowance < amount) {
            // Approve the maximum possible amount
            SafeERC20.safeApprove(IERC20(token), wrapperFactory, type(uint256).max);
        }
        wrappedToken = IWrapperFactory(wrapperFactory).wrap(address(this), token, amount);
    }

    function _approveAndUnwrap(address token, uint256 amount, address to) private {
        uint256 allowance = IERC20(token).allowance(address(this), wrapperFactory);
        if (allowance < amount) {
            // Approve the maximum possible amount
            SafeERC20.safeApprove(IERC20(token), wrapperFactory, type(uint256).max);
        }
        IWrapperFactory(wrapperFactory).unwrap(to, token, amount);
    }

    function _validateTokens(address tokenA, address tokenB, bool wrapTokenA, bool wrapTokenB) internal view {
        // check: if wrapTokenA is false, tokenA cannot have decimal of 0.
        if (!wrapTokenA && IERC20(tokenA).decimals() == 0) revert MustWrapToken();
        if (!wrapTokenB && IERC20(tokenB).decimals() == 0) revert MustWrapToken();
    }

    function _adjustToken(
        address token,
        uint256 amountDesired,
        bool wrap
    ) private returns (address adjustedToken, uint256 adjustedAmountDesired, uint256 decimalsOffset) {
        if (wrap) {
            adjustedToken = _approveAndWrap(token, amountDesired);
            decimalsOffset = IWrappedERC20(adjustedToken).getDecimalsOffset();
            adjustedAmountDesired = amountDesired * decimalsOffset;
        } else {
            adjustedToken = token;
            adjustedAmountDesired = amountDesired;
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
        if (IFanXFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IFanXFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = FanXLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = FanXLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                if (amountBOptimal < amountBMin) revert InsufficientBAmount();
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = FanXLibrary.quote(amountBDesired, reserveB, reserveA);
                if (amountAOptimal > amountADesired) revert ExcessiveInputAmount();
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
        address pair = FanXLibrary.pairFor(factory, tokenA, tokenB);
        IFanXPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IFanXPair(pair).burn(address(this));
        (address token0, ) = FanXLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        if (amountA < amountAMin) revert InsufficientAAmount();
        if (amountB < amountBMin) revert InsufficientBAmount();
    }
}

// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface IFanXMasterRouterV2 {
    error Expired();
    error InsufficientBAmount();
    error InsufficientAAmount();
    error ExcessiveInputAmount();
    error MustWrapToken();

    function factory() external view returns (address);
    function WETH() external view returns (address);
    function wrapperFactory() external view returns (address);

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
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function wrapTokenAndaddLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        bool wrapToken,
        address to,
        uint256 deadline
    ) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

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
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHAndUnwrap(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        bool isTokenWrapped,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        bool isTokenInWrapped,
        bool receiveUnwrappedToken,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        bool isTokenInWrapped,
        bool receiveUnwrappedToken,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        bool receiveUnwrappedToken,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        bool isTokenInWrapped,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        bool isTokenInWrapped,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        bool receiveUnwrappedToken,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    // Events (if any) would be declared here
}

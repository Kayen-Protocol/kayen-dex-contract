// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../contracts/KayenFactory.sol";
import "../../contracts/KayenPair.sol";
import "../../contracts/KayenRouter02.sol";
import "../../contracts/interfaces/IKayenRouter02.sol";
import "../../contracts/mocks/ERC20Mintable_decimal.sol";
import "../../contracts/mocks/MockWETH.sol";
import "../../contracts/KayenMasterRouterV2.sol";
import "../../contracts/utils/ChilizWrapperFactory.sol";
import "../../contracts/interfaces/IChilizWrapperFactory.sol";
import "../../contracts/libraries/KayenLibrary.sol";
import "../../contracts/libraries/Math.sol";

// @add assertions
contract KayenMasterRouter_Test is Test {
    address feeSetter = address(69);
    MockWETH public WETH;

    KayenRouter02 public router;
    KayenMasterRouterV2 public masterRouterV2;
    KayenFactory public factory;
    IChilizWrapperFactory public wrapperFactory;

    ERC20Mintable public tokenA_D0;
    ERC20Mintable public tokenB_D0;
    ERC20Mintable public tokenC_D0;

    ERC20Mintable public tokenA_D6;

    ERC20Mintable public tokenA_D18;
    ERC20Mintable public tokenB_D18;

    address user0 = vm.addr(0x01);
    address user1 = vm.addr(0x02);
    address user3 = vm.addr(0x03);

    function setUp() public {
        WETH = new MockWETH();

        factory = new KayenFactory(feeSetter);
        router = new KayenRouter02(address(factory), address(WETH));
        wrapperFactory = new ChilizWrapperFactory();
        masterRouterV2 = new KayenMasterRouterV2(address(factory), address(wrapperFactory), address(WETH));

        tokenA_D0 = new ERC20Mintable("Token A", "TKNA", 0);
        tokenB_D0 = new ERC20Mintable("Token B", "TKNB", 0);
        tokenC_D0 = new ERC20Mintable("Token C", "TKNC", 0);

        tokenA_D6 = new ERC20Mintable("Token A", "TKNA", 6);
        tokenA_D18 = new ERC20Mintable("Token B", "TKNA", 18);

        tokenB_D18 = new ERC20Mintable("Token A", "TKNA", 18);

        vm.deal(address(this), 2000000 ether);
        vm.deal(user0, 2000000 ether);
        vm.deal(user1, 2000000 ether);

        tokenA_D0.mint(1000000 ether, address(this));
        tokenB_D0.mint(1000000 ether, address(this));
        tokenC_D0.mint(1000000 ether, address(this));

        tokenA_D6.mint(2000000 * 1e6, address(this));
        tokenA_D18.mint(1000000 * 1e18, address(this));
        tokenB_D18.mint(1000000 * 1e18, address(this));

        tokenA_D0.mint(1000000, user0);
        tokenB_D0.mint(1000000, user0);
        tokenC_D0.mint(1000000, user0);

        tokenA_D6.mint(1000000 * 1e6, user0);
        tokenA_D18.mint(1000000 * 1e18, user0);
        tokenB_D18.mint(1000000 * 1e18, user0);

        tokenA_D0.mint(1000000, user1);
        tokenB_D0.mint(1000000, user1);
        tokenC_D0.mint(1000000, user1);

        tokenA_D6.mint(1000000 * 1e6, user1);
        tokenA_D18.mint(1000000 * 1e18, user1);
        tokenB_D18.mint(1000000 * 1e18, user1);
    }

    function encodeError(string memory error) internal pure returns (bytes memory encoded) {
        encoded = abi.encodeWithSignature(error);
    }

    function test_AddLiquidityETH_D0_Wrapped() public {
        // wrap tokenA_DO
        tokenA_D0.approve(address(wrapperFactory), 411009);
        address wrappedTokenA_D0 = wrapperFactory.wrap(address(this), address(tokenA_D0), 411009);

        ERC20Mintable(wrappedTokenA_D0).approve(address(masterRouterV2), 211019332922026132075537);
        masterRouterV2.wrapTokenAndaddLiquidityETH{value: 882772218610359116699373}(
            address(wrappedTokenA_D0),
            211019332922026132075537,
            0,
            0,
            false,
            address(this),
            block.timestamp
        );

        vm.startPrank(user0);
        tokenA_D0.approve(address(masterRouterV2), 1);
        uint256 balanceBeforeWappedToken = ERC20Mintable(wrappedTokenA_D0).balanceOf(user0);
        uint256 balanceBeforeETH = address(user0).balance;
        (uint256 amountToken, uint256 amountETH, uint256 liquidity) = masterRouterV2.wrapTokenAndaddLiquidityETH{
            value: 4183371288243777915
        }(address(tokenA_D0), 1, 990000000000000000, 4141537575361340135, true, user0, block.timestamp);
        uint256 balanceAfterWappedToken = ERC20Mintable(wrappedTokenA_D0).balanceOf(user0);
        uint256 balanceAfterETH = address(user0).balance;

        console.log(balanceBeforeETH - balanceAfterETH);
        console.log(balanceBeforeWappedToken - balanceAfterWappedToken);
        console.log(balanceAfterETH - 4141537575361340135);
        vm.stopPrank();
    }
}
// forge test --match-path test/KayenMasterRouterV2/senarioTest.t.sol -vvvv

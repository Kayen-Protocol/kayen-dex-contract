// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {FanXMasterRouter} from "../src/FanXMasterRouter.sol";
import {WrapperFactory} from "../src/utils/WrapperFactory.sol";
import {FanXFactory} from "../src/FanXFactory.sol";
import {FanXRouter02} from "../src/FanXRouter02.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import "../src/libraries/FanXLibrary.sol";

// Depending on the nature of your oasys blockchain, deployment scripts are not used in production
contract wrapTokenAndaddLiquidityETH is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address account = 0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897;
        address token0 = 0x2DB5e3707B2cdaAE26592bDF5F604b120ff8712E;
        address token1 = 0x4EFbbAE904d7bea13D0b4216E73C1F1Ba5AC5796;
        address wrapperFactory = 0x034fC28f302b46fAc86a253e390298b966D894dc;
        address router = 0xF4f858acf122d388EF5A603615087DaCa87A5773;
        address factory = 0x5B14e2E332eC76A829F588b192C59437Ba19eA12;
        address payable masterRouter = payable(0x2166FDfE0373048c98C7faB2692A47Abdd000a16);
        // address wrappedToken0 = ChilizWrapperFactory(wrapperFactory).getUnderlyingToWrapped(token0);
        // address wrappedToken1 = ChilizWrapperFactory(wrapperFactory).getUnderlyingToWrapped(token1);

        // IERC20(wrappedToken0).approve(router, 10e18);
        IERC20(token0).approve(masterRouter, 100);
        FanXMasterRouter(masterRouter).wrapTokenAndaddLiquidityETH{value: 5e18}(
            token0,
            100,
            0,
            0,
            account,
            type(uint40).max
        );
        vm.stopBroadcast();
    }
}

/**
CHILIZ Mainnet
    ROUTER_V2: '0x377d5e70c8fb649D7e2DbdaCCBefa1858EF4f973'
    PAIR_FACTORY: '0x7ef878CED132a7c3e3a56751DF3F7fD0F5AA0575'
    WRAPPER_FACTORY: '0x2066c5860F3ebE19Fa51544a54C40D6a8f5B965f'
    WETH: '0x677F7e16C7Dd57be1D4C8aD1244883214953DC47'
  
CHILIZ TESTNET
    // ROUTER_V2: '0xF4f858acf122d388EF5A603615087DaCa87A5773'
    // PAIR_FACTORY: '0x5B14e2E332eC76A829F588b192C59437Ba19eA12'
    // WRAPPER_FACTORY: '0x447A6EF240084261183627c876460c5E6abB179b'
    // WETH: '0x678c34581db0a7808d0aC669d7025f1408C9a3C6'
    MASTER_ROUTER: 0x72ef04e9bD7D2f2d7B72662Eb870d4534610bCbd,
    ROUTER_V2: 0x56aE9D4B2CaB2F9338b3e71f0cA714cB58FC8CCF,
    WRAPPER_FACTORY: 0x4c01813996b9CB0cbB6942ee1799F80c280D1D2b,
    PAIR_FACTORY: 0x1CD0D070b52b41e19E857160022Fa9915581CFa8,

*/

// forge script scripts/wrapTokenAndaddLiquidityETH.s.sol:wrapTokenAndaddLiquidityETH --rpc-url $SPICY_TESTNET --broadcast --legacy

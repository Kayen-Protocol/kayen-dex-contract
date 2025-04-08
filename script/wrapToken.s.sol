// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {KayenMasterRouter} from "../src/KayenMasterRouter.sol";
import {ChilizWrapperFactory} from "../src/utils/ChilizWrapperFactory.sol";
import {KayenFactory} from "../src/KayenFactory.sol";
import {KayenRouter02} from "../src/KayenRouter02.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";

// Depending on the nature of your oasys blockchain, deployment scripts are not used in production
contract wrapToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address account = 0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897;
        address wrapperFactory = 0x9A2a89c376d77ebF747D229dA534FdEBf39BB6FA;
        address token0 = 0xF9C0F80a6c67b1B39bdDF00ecD57f2533ef5b688;
        address token1 = 0xFD3C73b3B09D418841dd6Aff341b2d6e3abA433b;
        address token2 = 0x19cA0F4aDb29e2130A56b9C9422150B5dc07f294;
        address token3 = 0xc2661815C69c2B3924D3dd0c2C1358A1E38A3105;

        // IERC20(token0).approve(wrapperFactory, 1);
        IERC20(token1).approve(wrapperFactory, 1);
        IERC20(token2).approve(wrapperFactory, 1);
        IERC20(token3).approve(wrapperFactory, 1);

        // address wrappedAddr0 = ChilizWrapperFactory(wrapperFactory).wrap(account, token0, 1);
        // address wrappedAddr1 = ChilizWrapperFactory(wrapperFactory).wrap(account, token1, 1);
        // address wrappedAddr2 = ChilizWrapperFactory(wrapperFactory).wrap(account, token2, 1);
        // address wrappedAddr3 = ChilizWrapperFactory(wrapperFactory).wrap(account, token3, 1);

        console2.log(account);
        // console2.log("wrapped 0",wrappedAddr0);
        // console2.log("wrapped 1",wrappedAddr1);
        // console2.log("wrapped 2",wrappedAddr2);
        // console2.log("wrapped 3",wrappedAddr3);
        // console2.log(IERC20(wrappedAddr0).balanceOf(account));
        // console2.log(IERC20(wrappedAddr1).balanceOf(account));
        // console2.log(IERC20(wrappedAddr2).balanceOf(account));
        // console2.log(IERC20(wrappedAddr3).balanceOf(account));
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
    ROUTER_V2: '0xF4f858acf122d388EF5A603615087DaCa87A5773'
    PAIR_FACTORY: '0x5B14e2E332eC76A829F588b192C59437Ba19eA12'
    WRAPPER_FACTORY: '0x447A6EF240084261183627c876460c5E6abB179b'
    WETH: '0x678c34581db0a7808d0aC669d7025f1408C9a3C6'

AC Milan 0xf9c0f80a6c67b1b39bddf00ecd57f2533ef5b688
FC Barcelona 0xfd3c73b3b09d418841dd6aff341b2d6e3aba433b
OG 0x19ca0f4adb29e2130a56b9c9422150b5dc07f294
Paris Saint-Germain 0xc2661815c69c2b3924d3dd0c2c1358a1e38a3105
*/

// forge script scripts/wrapToken.s.sol:wrapToken --rpc-url $SPICY_TESTNET --broadcast --legacy
//forge script scripts/wrapToken.s.sol:wrapToken --rpc-url $CHILIZ_MAINNET --broadcast --legacy

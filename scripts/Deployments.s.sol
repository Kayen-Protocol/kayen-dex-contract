// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {JalaMasterRouter} from "../contracts/JalaMasterRouter.sol";
import {ChilizWrapperFactory} from "../contracts/utils/ChilizWrapperFactory.sol";
import {JalaFactory} from "../contracts/JalaFactory.sol";
import {JalaRouter02} from "../contracts/JalaRouter02.sol";

contract Deployments is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address feeSetter = 0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897;
        address WETH = 0x678c34581db0a7808d0aC669d7025f1408C9a3C6;

        JalaFactory factory = new JalaFactory(feeSetter);

        JalaRouter02 router02 = new JalaRouter02(address(factory), WETH);
        ChilizWrapperFactory wrapperFactory = new ChilizWrapperFactory();

        JalaMasterRouter masterRouter = new JalaMasterRouter(
            address(factory),
            address(wrapperFactory),
            address(router02),
            WETH
        );

        console2.log("JalaFactory: ", address(factory));
        console2.log("JalaRouter02: ", address(router02));
        console2.log("wrapperFactory: ", address(wrapperFactory));
        console2.log("MasterRouter: ", address(masterRouter));

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
*/

// forge script scripts/Deployments.s.sol:Deployments --rpc-url $SPICY_TESTNET --broadcast --legacy --optimizer-runs 15796
// forge script scripts/Deployments.s.sol:Deployments --rpc-url $CHILIZ_MAINNET --broadcast --legacy --optimizer-runs 15796

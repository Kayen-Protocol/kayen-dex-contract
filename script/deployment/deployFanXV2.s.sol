// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {WrapperFactory} from "../../src/utils/WrapperFactory.sol";
import {FanXFactory} from "../../src/FanXFactory.sol";
import {FanXRouter02} from "../../src/FanXRouter02.sol";
import {FanXMasterRouterV2} from "../../src/FanXMasterRouterV2.sol";

contract DeployFanXV2 is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address feeSetter = 0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897;
        address WETH = 0x1514000000000000000000000000000000000000;

        FanXFactory factory = new FanXFactory(feeSetter);
        FanXRouter02 router02 = new FanXRouter02(address(factory), address(WETH));
        WrapperFactory wrapperFactory = new WrapperFactory();
        FanXMasterRouterV2 masterRouterV2 = new FanXMasterRouterV2(
            address(factory),
            address(wrapperFactory),
            address(WETH)
        );

        console2.log("FanXFactory deployed at", address(factory));
        console2.log("FanXRouter02 deployed at", address(router02));
        console2.log("WrapperFactory deployed at", address(wrapperFactory));
        console2.log("FanXMasterRouterV2 deployed at", address(masterRouterV2));

        vm.stopBroadcast();
    }
}

// forge script script/deployment/deployFanXV2.s.sol --rpc-url <network> --broadcast
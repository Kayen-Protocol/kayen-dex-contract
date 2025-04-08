// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {KayenMasterRouter} from "../src/KayenMasterRouter.sol";
import {ChilizWrapperFactory} from "../src/utils/ChilizWrapperFactory.sol";
import {KayenFactory} from "../src/KayenFactory.sol";
import {KayenPair} from "../src/KayenPair.sol";
import {KayenRouter02} from "../src/KayenRouter02.sol";
import {KayenLensV2} from "../src/Lens/KayenLensV2.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import "../src/libraries/KayenLibrary.sol";

contract getAllPair is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);




        vm.stopBroadcast();
    }
}

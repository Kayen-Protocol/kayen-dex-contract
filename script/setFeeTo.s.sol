// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {KayenFactory} from "../src/KayenFactory.sol";

// Depending on the nature of your oasys blockchain, deployment scripts are not used in production
contract setFeeTo is Script {
    address setFeeTo = 0x681d20Ad2845E33c88a97178a59293b0EF51Ab1c;
    address factory = 0xE2918AA38088878546c1A18F2F9b1BC83297fdD3;
    address T_facoty = 0xfc1924E20d64AD4daA3A4947b4bAE6cDE77d2dBC;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        KayenFactory(T_facoty).setFeeTo(setFeeTo);
        // KayenFactory(factory).setFeeToSetter(0x80B714e2dd42611e4DeA6BFe2633210bD9191bEd);

        address setFeeTo_ = KayenFactory(T_facoty).feeTo();
        console2.log(setFeeTo_);
        vm.stopBroadcast();
    }
}

// forge script scripts/setFeeTo.s.sol:setFeeTo --rpc-url $SPICY_TESTNET --broadcast --legacy
// forge script scripts/setFeeTo.s.sol:setFeeTo --rpc-url $CHILIZ_MAINNET --broadcast --legacy

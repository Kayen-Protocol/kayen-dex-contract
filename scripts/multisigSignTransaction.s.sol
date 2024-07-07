// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {IMultiSigWallet} from "../contracts/interfaces/IMultiSigWallet.sol";
// import {KayenLens} from "../contracts//KayenLens.sol";
// import {KayenLensV2} from "../contracts/KayenLensV2.sol";
import {IERC20} from "../contracts/interfaces/IERC20.sol";
import "../contracts/libraries/KayenLibrary.sol";

// Depending on the nature of your oasys blockchain, deployment scripts are not used in production
contract MultisigSignTransaction is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address protocolMultiSig = 0x80B714e2dd42611e4DeA6BFe2633210bD9191bEd;

        // tx 0: change fee address to multisig
        // tx 1: chagne required confirmation to 3 
        IMultiSigWallet(protocolMultiSig).confirmTransaction(0);
        IMultiSigWallet(protocolMultiSig).confirmTransaction(1);


        vm.stopBroadcast();
    }
}

// forge script scripts/multisigSignTransaction.s.sol:MultisigSignTransaction --rpc-url $SPICY_TESTNET --broadcast --legacy
// forge script scripts/multisigSignTransaction.s.sol:MultisigSignTransaction --rpc-url $CHILIZ_MAINNET --broadcast --legacy

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {JalaMasterRouter} from "../contracts/JalaMasterRouter.sol";
import {ChilizWrapperFactory} from "../contracts/utils/ChilizWrapperFactory.sol";
import {JalaFactory} from "../contracts/JalaFactory.sol";
import {JalaRouter02} from "../contracts/JalaRouter02.sol";
import {JalaLens} from "../contracts/JalaLens.sol";
import {IERC20} from "../contracts/interfaces/IERC20.sol";
import "../contracts/libraries/JalaLibrary.sol";

// Depending on the nature of your oasys blockchain, deployment scripts are not used in production
contract ForCheck is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address account = 0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897;
        address token0 = 0x2DB5e3707B2cdaAE26592bDF5F604b120ff8712E;
        address token1 = 0x4EFbbAE904d7bea13D0b4216E73C1F1Ba5AC5796;
        address wrapperFactory = 0x034fC28f302b46fAc86a253e390298b966D894dc;
        address payable router = payable(0xF4f858acf122d388EF5A603615087DaCa87A5773);
        address payable factory = payable(0x5B14e2E332eC76A829F588b192C59437Ba19eA12);
        address payable masterRouter = payable(0x2166FDfE0373048c98C7faB2692A47Abdd000a16);
        address lens = 0x3CC2236284559328f03ac0a2D1cD53743F1bF98E;

        address M_router = JalaMasterRouter(masterRouter).router();
        address M_factory = JalaMasterRouter(masterRouter).factory();
        address M_wrapperFactory = JalaMasterRouter(masterRouter).wrapperFactory();
        address M_WETH = JalaMasterRouter(masterRouter).WETH();

        console2.log("M_router", M_router);
        console2.log("M_factory", M_factory);
        console2.log("M_wrapperFactory", M_wrapperFactory);
        console2.log("M_WETH", M_WETH);

        address R_factory = JalaRouter02(router).factory();
        address R_WETH = JalaRouter02(router).WETH();
        console2.log("R_factory", R_factory);
        console2.log("R_WETH", R_WETH);

        address a = JalaFactory(factory).getPair(R_WETH, 0xe588e227c24329fE32F81bD8ae04eE95c12F35a3);
        console2.log(a);

        address lensfactory = JalaLens(lens).factory();
        console2.log(lensfactory);
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

// forge script scripts/ForCheck.s.sol:ForCheck --rpc-url $SPICY_TESTNET --broadcast --legacy

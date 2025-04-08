// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {FanXMasterRouter} from "../src/FanXMasterRouter.sol";
import {WrapperFactory} from "../src/utils/WrapperFactory.sol";
import {FanXFactory} from "../src/FanXFactory.sol";
import {ERC20Mintable} from "../src/mocks/ERC20Mintable_decimal.sol";

// Depending on the nature of your oasys blockchain, deployment scripts are not used in production
contract swapExactToken is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        FanXMasterRouter masterRouter = FanXMasterRouter(payable(0xce37E1b6CA28F679693a4831006CAEfa8a520D97));
        ERC20Mintable TT0 = ERC20Mintable(0xF9C0F80a6c67b1B39bdDF00ecD57f2533ef5b688);
        // ERC20Mintable TT1 = ERC20Mintable(0x4EFbbAE904d7bea13D0b4216E73C1F1Ba5AC5796);

        // ChilizWrapperFactory wapperFactory = ChilizWrapperFactory(0xF7084F8B0e73DC329EF03CD53f0f32090A4c0ff9);

        TT0.approve(address(masterRouter), 1);

        // uint256 balanceTT0 = TT0.balanceOf(0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897);
        // uint256 balanceTT1 = TT0.balanceOf(0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897);
        // uint256 balanceWTT1 = TT0.balanceOf(0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897);

        address[] memory path = new address[](2);
        path[0] = 0xaA6E14da5cd99f20552F23b23ceD9c026b5164F0;
        path[1] = 0xb167645aF1bCc5098Bf9aeD803f51aC851Def98a;
        masterRouter.swapExactTokensForTokens(
            address(TT0),
            1,
            0,
            path,
            0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897,
            type(uint40).max
        );

        vm.stopBroadcast();
    }
}

// forge script scripts/swapExactTokensTo.s.sol:swapExactToken --rpc-url $SPICY_TESTNET --broadcast --legacy

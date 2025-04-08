// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import {FanXMasterRouter} from "../src/FanXMasterRouter.sol";
import {FanXRouter02} from "../src/FanXRouter02.sol";
import {WrapperFactory} from "../src/utils/WrapperFactory.sol";
import {FanXFactory} from "../src/FanXFactory.sol";
import {ERC20Mintable} from "../src/mocks/ERC20Mintable_decimal.sol";

contract swapExactETH is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        FanXRouter02 kayenRouter02 = FanXRouter02(payable(0x1918EbB39492C8b98865c5E53219c3f1AE79e76F));

        address[] memory path = new address[](2);
        path[0] = 0x677F7e16C7Dd57be1D4C8aD1244883214953DC47;
        path[1] = 0xF3928e7871eb136DD6648Ad08aEEF6B6ea893001;

        kayenRouter02.swapETHForExactTokens{value: 34 ether}(
            0,
            path,
            0x86d36bd2EEfB7974B9D0720Af3418FC7Ca5C8897,
            type(uint40).max
        );

        vm.stopBroadcast();
    }
}

// forge script scripts/swapETHforExactTokens.s.sol:swapExactETH --rpc-url $SPICY_TESTNET --broadcast --legacy
// forge script scripts/swapExactTokensTo.s.sol:swapExactToken --rpc-url $CHILIZ_MAINNET --broadcast --legacy

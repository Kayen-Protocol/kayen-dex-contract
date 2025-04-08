// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Script, console2} from "forge-std/Script.sol";
import "../src/mocks/ERC20Minter.sol";
import "../src/mocks/ERC20MintableMinterWithdecimalForMinter.sol";

contract MinterDeployer is Script {
    address[] tokens;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // {
        //   address: "0xb0Fa395a3386800658B9617F90e834E2CeC76Dd3",
        //   name: "Paris Saint-Germain",
        //   symbol: "PSG",
        //   icon: ["/tokens/psg.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0x9B9C9AAa74678FcF4E1c76eEB1fa969A8E7254f8",
        //   name: "Tottenham Hotspur",
        //   symbol: "SPURS",
        //   icon: ["/tokens/spurs.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0x7F73C50748560BD2B286a4c7bF6a805cFb6f735d",
        //   name: "FC Barcelona",
        //   symbol: "BAR",
        //   icon: ["/tokens/bar.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0x641d040dB51398Ba3a4f2d7839532264EcdCc3aE",
        //   name: "AC Milan",
        //   symbol: "ACM",
        //   icon: ["/tokens/acm.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0xEc1C46424E20671d9b21b9336353EeBcC8aEc7b5",
        //   name: "OG",
        //   symbol: "OG",
        //   icon: ["/tokens/og.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0x66F80ddAf5ccfbb082A0B0Fae3F21eA19f6B88ef",
        //   name: "Manchester City",
        //   symbol: "CITY",
        //   icon: ["/tokens/city.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0x44B190D30198F2E585De8974999a28f5c68C6E0F",
        //   name: "Arsenal",
        //   symbol: "AFC",
        //   icon: ["/tokens/afc.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0x1CC71168281dd78fF004ba6098E113bbbCBDc914",
        //   name: "Flamengo",
        //   symbol: "MENGO",
        //   icon: ["/tokens/mengo.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0x945EeD98f5CBada87346028aD0BeE0eA66849A0e",
        //   name: "Juventus",
        //   symbol: "JUV",
        //   icon: ["/tokens/juv.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0x8DBe49c4Dcde110616fafF53b39270E1c48F861a",
        //   name: "Napoli",
        //   symbol: "NAP",
        //   icon: ["/tokens/nap.svg"],
        //   decimals: 0,
        // },
        // {
        //   address: "0xc926130FA2240e16A41c737d54c1d9b1d4d45257",
        //   name: "Atletico De Madrid",
        //   symbol: "ATM",
        //   icon: ["/tokens/atm.svg"],
        //   decimals: 0,
        // },

        ERC20MintableMinter token0 = ERC20MintableMinter(0xb0Fa395a3386800658B9617F90e834E2CeC76Dd3); //new ERC20MintableMinter("Paris Saint-Germain", "PSG", 0);
        tokens.push(address(token0));
        ERC20MintableMinter token1 = ERC20MintableMinter(0x9B9C9AAa74678FcF4E1c76eEB1fa969A8E7254f8); // new ERC20MintableMinter("Tottenham Hotspur", "SPURS", 0);
        tokens.push(address(token1));
        ERC20MintableMinter token2 = ERC20MintableMinter(0x7F73C50748560BD2B286a4c7bF6a805cFb6f735d); // new ERC20MintableMinter("FC Barcelona", "BAR", 0);
        tokens.push(address(token2));
        ERC20MintableMinter token3 = ERC20MintableMinter(0x641d040dB51398Ba3a4f2d7839532264EcdCc3aE); // new ERC20MintableMinter("AC Milan", "ACM", 0);
        tokens.push(address(token3));
        ERC20MintableMinter token4 = ERC20MintableMinter(0xEc1C46424E20671d9b21b9336353EeBcC8aEc7b5); // new ERC20MintableMinter("OG Fan", "OG", 0);
        tokens.push(address(token4));
        ERC20MintableMinter token5 = ERC20MintableMinter(0x66F80ddAf5ccfbb082A0B0Fae3F21eA19f6B88ef); // new ERC20MintableMinter("Manchester City", "CITY", 0);
        tokens.push(address(token5));
        ERC20MintableMinter token6 = ERC20MintableMinter(0x44B190D30198F2E585De8974999a28f5c68C6E0F); // new ERC20MintableMinter("Arsenal", "AFC", 0);
        tokens.push(address(token6));
        ERC20MintableMinter token7 = ERC20MintableMinter(0x1CC71168281dd78fF004ba6098E113bbbCBDc914); // new ERC20MintableMinter("Flamengo", "MENGO", 0);
        tokens.push(address(token7));
        ERC20MintableMinter token8 = ERC20MintableMinter(0x8DBe49c4Dcde110616fafF53b39270E1c48F861a); // new ERC20MintableMinter("Juventus", "JUV", 0);
        tokens.push(address(token8));
        ERC20MintableMinter token9 = ERC20MintableMinter(0x945EeD98f5CBada87346028aD0BeE0eA66849A0e); // new ERC20MintableMinter("Napoli", "NAP", 0);
        tokens.push(address(token9));
        ERC20MintableMinter token10 = ERC20MintableMinter(0xc926130FA2240e16A41c737d54c1d9b1d4d45257); // new ERC20MintableMinter("Atletico De Madrid", "ATM", 0);
        tokens.push(address(token10));
        ERC20MintableMinter token11 = ERC20MintableMinter(0x15A4D9008635fd937cd32D6717ECDff10D766C42); //new ERC20MintableMinter("PUMLx", "PUMLx", 0);
        tokens.push(address(token11));

        ERC20Minter minter = new ERC20Minter(tokens);
        console2.log("Minter", address(minter));

        for (uint256 i; i < tokens.length; i++) {
            ERC20MintableMinter(tokens[i]).addToWhitelist(address(minter));
            ERC20MintableMinter(tokens[i]).name();
            ERC20MintableMinter(tokens[i]).symbol();

            console2.log(ERC20MintableMinter(tokens[i]).name(), ERC20MintableMinter(tokens[i]).symbol(), tokens[i]);
        }

        vm.stopBroadcast();
    }
}

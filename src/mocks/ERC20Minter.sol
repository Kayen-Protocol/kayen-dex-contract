// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mintable} from "./ERC20Mintable_decimal.sol";

contract ERC20Minter {
    uint256 constant DAY = 86400;
    address public owner;
    uint256 public lastMinted;
    address[] public fanTokens;
    uint256 public mintAmount;
    uint256 public numOfMintToken;
    uint256 public dailyMintLimit;

    mapping(address => DailyLimit) dailyLimit; // Accounts to Daily Limit

    struct DailyLimit {
        uint256 timestamp;
        uint256 mintCount;
    }

    constructor(address[] memory tokens) {
        fanTokens = tokens;
        mintAmount = 100;
        numOfMintToken = 4;
        dailyMintLimit = 8;
        owner = msg.sender;
    }

    function mintBatch(address to) public {
        if (dailyLimit[to].timestamp + DAY < block.timestamp) {
            dailyLimit[to].mintCount = 0;
            dailyLimit[to].timestamp = block.timestamp;
        }
        require(dailyLimit[to].mintCount < dailyMintLimit, "DailyMintLimit");
        dailyLimit[to].mintCount++;

        uint256 startIndex = lastMinted % fanTokens.length;
        for (uint256 i = 0; i < numOfMintToken; i++) {
            uint256 tokenIndex = (startIndex + i) % fanTokens.length;
            ERC20Mintable(fanTokens[tokenIndex]).mint(mintAmount, to);
        }
        lastMinted += numOfMintToken;
    }

    function addToken(address token) public {
        require(owner == msg.sender, "Only owner can add token");
        fanTokens.push(token);
    }
}

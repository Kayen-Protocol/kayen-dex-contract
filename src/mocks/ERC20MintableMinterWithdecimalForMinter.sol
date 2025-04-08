// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import {ERC20} from "../libraries/ERC20.sol";

contract ERC20MintableMinter is ERC20 {
    uint8 public decimals_;
    address private owner;
    mapping(address => bool) private whitelist;

    constructor(string memory name_, string memory symbol_, uint8 _decimals) ERC20() {
        decimals_ = _decimals;
        name = name_;
        symbol = symbol_;
        owner = msg.sender;
        addToWhitelist(msg.sender);
        _mint(msg.sender, 10000000);
    }

    modifier isWhitelisted() {
        require(whitelist[msg.sender], "Not whitelisted");
        _;
    }
    // modifier는 함수 실행을 특정 조건에 따라 제한함
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }

    // 소유자만 호출할 수 있는 화이트리스트 추가 함수
    function addToWhitelist(address _address) public onlyOwner {
        whitelist[_address] = true;
    }

    // 소유자만 호출할 수 있는 화이트리스트 제거 함수
    function removeFromWhitelist(address _address) external onlyOwner {
        whitelist[_address] = false;
    }

    // 화이트리스트에 있는지 확인하는 함수
    function isAddressWhitelisted(address _address) external view returns (bool) {
        return whitelist[_address];
    }

    function mint(uint256 amount, address to) public isWhitelisted {
        _mint(to, amount);
    }

    function decimals() public view override returns (uint8) {
        return decimals_;
    }
}

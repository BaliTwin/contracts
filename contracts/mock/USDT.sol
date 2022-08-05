// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDT is ERC20 {

    constructor () ERC20("Test", "USDT") {}

    function mint (uint amount) external {
        _mint(msg.sender, amount);
    }

     function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
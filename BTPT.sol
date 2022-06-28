// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BTPT is ERC20, Ownable {

    address public paymentCurrency;

    // Pre sale ends at 1.9.2022 00:00
    uint public constant endDate = 1661990400;

    // Minimal purchase amount 1250 BTPT
    uint public minAmount = 1250 ether;
    
    event TokenPurchase (address buyer, uint amount, uint rate);

    modifier isActive {
      require(block.timestamp < endDate, "Presale ended.");
      _;
    }

    constructor (address _currencyAddress) ERC20("BaliTwin Presale Token", "BTPT") {
        // Minted 6 000 000 BTPT Tokens
        _mint(
            address(this), 
            6 * 1000 * 1000 ether
        );
        paymentCurrency = _currencyAddress;
    }

    function buyTokens (uint amount) isActive external payable {
        require(amount < balanceOf(address(this)), "Not enough available BTPT");
        if (amount < minAmount) revert("Minimal amount to buy - 1250 BTPT");

        ERC20 currency = ERC20(paymentCurrency);
        uint currencyDecimals = 10 ** currency.decimals();

        // From 1250 BTPT: 1 BTPT = 0.8 USDT | 1000 USDT
        uint rate = 8 * (currencyDecimals / 10);

        // From 8333.333333333334 BTPT: 1 BTPT = 0.6 USDT | 5000 USDT
        if (amount > 8333.333333333334 ether)
            rate = 6 * (currencyDecimals / 10);

        // From 50 000 BTPT: 1 BTPT = 0.4 USDT | 20 000 USDT
        if (amount > 50 * 1000 ether)
            rate = 4 * (currencyDecimals / 10);

        uint currencyAmount = (amount / 1 ether) * rate;

        emit TokenPurchase(msg.sender, currencyAmount, rate);

        currency.transferFrom(msg.sender, address(this), currencyAmount);
        _transfer(address(this), msg.sender, amount);
    }

    function withdraw () onlyOwner external {
        ERC20 currency = ERC20(paymentCurrency);
        currency.transfer(msg.sender, currency.balanceOf(address(this)));
    }
    
}

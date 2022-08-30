// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "./tokens/Collection1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title BaliTwinGiveaway.
/// @author BaliTwin Developers.
/// @notice Giveaway contract.

/// @custom:version 1.0.0
/// @custom:website https://balitwin.com
/// @custom:security-contact security@balitwin.com

contract BaliTwinGiveaway is Ownable {
	/// @notice total amount of tokens to mint.
    uint public total;

	/// @notice End date.
    uint public endDate;

	/**
	 * @notice Collection address.
	 * @dev ERC1155
	 */
    address private collection;

	/// @notice token ID.
    uint private tokenId;

	/// @notice amount of claimed event-passes.
    uint public claimed = 0;
    mapping (uint => address) private claimers;

	/// @notice Checks that Giveaway is still active.
    modifier isActive {
        require(claimed < total, "Sorry. All tokens was claimed.");
        require(block.timestamp < endDate, "Claim event is finished.");
        _;
    }

	/// @notice Checks that user claimed only one token.
    modifier once {
        for (uint i = 0; i <= claimed; i++)
            if (claimers[i] == msg.sender) 
                revert("Address already has claimed tokens");
        _;
    }

    constructor (address tokenAddress, uint tokenId_, uint total_, uint endDate_) {
        total = total_;
        tokenId = tokenId_;
        endDate = endDate_;
        collection = tokenAddress;
    }

	/**
	 * @notice Transfers single one token to user who calls this method.
	 */

    function claim () external once isActive {
        Collection1155(collection).mint(msg.sender, tokenId, 1, new bytes(0));

        claimers[claimed] = msg.sender;
        claimed++;
    }

    // Admin functions

	/**
	 * @notice Extend amount of total.
	 * 
	 * @param value Additional amount value.
	 * @dev only for owner.
	 */

    function extendTotal (uint value) external onlyOwner {
        total += value;
    }

	/**
	 * @notice Set new date of end.
	 * 
	 * @param value New end date.
	 * @dev New end date must be greater than previous one.
	 */

    function extendEndDate (uint value) external onlyOwner {
        require(value > endDate, "New end date must be in greater than previous.");
        endDate = value;
    }
    
}

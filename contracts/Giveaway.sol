// SPDX-License-Identifier: MIT

/**
 *
 *                  @@@@@@@@@@@@@@@@@*.         #@@@@#-         %@@%.             @@@%      
 *                  @@@@=---------=@@@@.      .%@@+@@@@*        %@@@:             @@@@.     
 *                  @@@@=---------=@@@@.     -@@%: .%@@@%.      %@@@:             @@@@.     
 *                  @@@@%%%%%%%%%%@@@@%:    +@@#     #@@@@:     %@@@:             @@@@.     
 *                  @@@@.          -@@@%   #@@+       +@@@@=    %@@@:             @@@@.     
 *                  @@@@+++++++++++%@@@+ .%@@-    =****%@@@@*   %@@@#**********=  @@@@.     
 *                  %%%%%%%%%%%%%%%%#+: :#%#:    +%%%%%%%%%%%*  *%%%%%%%%%%%%%#:  =#%%.     
 *
 *          ==================:  ====:  :============:    .===  ===-    ======:          .==
 *          *@@@@@@@@@@@@@@@@@@= -@@@@*  =@@@@@@@@@@+    -@@%:  %@@@:  .@@@@@@@%-        %@@
 *                  @@@@.         .%@@@%. :@@@@*        +@@#    %@@@:  .@@%:#@@@@%-      %@@
 *                  @@@@.           *@@@@- .%@@@%.     #@@+     %@@@:  .@@%  :#@@@@%-    %@@
 *                  @@@@.            =@@@@+  *@@@@-  .%@@-      %@@@:  .@@%    :#@@@@#:  %@@
 *                  @@@@.             -@@@@*  =@@@@+-@@%:       %@@@:  .@@%      :#@@@@#:%@@
 *                  @@@@.              .%@@@%. -@@@@@@#         #@@@:   @@%        :#@@@@@@@
 *
 */

pragma solidity ^0.8.15;

import './tokens/Collection1155.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

/// @title Giveaway
/// @author BaliTwin Developers
/// @notice This contract is used to distribute NFTs to users

/// @custom:version 1.0.0
/// @custom:website https://balitwin.com
/// @custom:security-contact security@balitwin.com

contract BaliTwinGiveaway is Ownable {
    using Counters for Counters.Counter;
    
    /**
     * @notice Giveaway struct
     * 
     * @param collection Address of the collection
     * @param id The token id
     * @param total Total amount of tokens to be distributed
     * @param claimed Amount of tokens claimed
     */

    struct Giveaway {
        address collection;
        uint id;
        uint total;
        uint claimed;
    }
    
    /// @dev Mapping of giveaway id to giveaway
    Counters.Counter private giveawayIdCounter;
    mapping (uint => Giveaway) private giveaways;

    /// @dev Mapping from user address to giveaway id to claim status
    mapping (address => mapping (uint => bool)) private claimed;

    /// @notice Checks if giveaway is exists
    modifier isExists (uint _id) {
        require(giveaways[_id].collection != address(0), 'Giveaway does not exist');
        _;
    }

    /// @notice Checks if giveaway is not over
    modifier isActive (uint id) {
        require(giveaways[id].claimed < giveaways[id].total, 'Giveaway is over');
        _;
    }

    event Claimed (address indexed claimer, uint indexed tokenId, address collection);

    // View functions

    /**
     * @notice Get giveaway by id
     * @param id The giveaway id
     */
    function getGiveaway (uint id) public view isExists(id) returns (Giveaway memory) {
        return giveaways[id];
    }

    /**
     * @notice Get tokens claimed by user
     * 
     * @param user The user address
     */

    function getClaimed (address user) public view returns (uint[] memory) {
        uint[] memory claimedTokens = new uint[](giveawayIdCounter.current());
        uint counter = 0;

        for (uint i = 0; i < claimedTokens.length; i++)
            if (claimed[user][i]) {
                claimedTokens[counter] = i;
                counter++;
            }
        
        uint[] memory result = new uint[](counter);
        for (uint i = 0; i < counter; i++) result[i] = claimedTokens[i];

        return result;
    }

    // Public functions

    /**
     * @notice Claim a token from a giveaway
     * @param id The giveaway id
     * 
     * @dev The giveaway must exist and the user must not have claimed the token yet
     */

    function claim (uint id) external isExists(id) isActive(id) {
        _claim(msg.sender, id);
    }

    // Admin functions

     /**
     * @notice Airdrops tokens to a list of users
     * 
     * @param addresses The list of users
     * @param id The giveaway id
     */

    function airdrop (address[] calldata addresses, uint id) external onlyOwner isExists(id) {
        require(addresses.length > 0, 'addresses is empty');
        require(
            addresses.length <= giveaways[id].total - giveaways[id].claimed, 
            'addresses length is greater than giveaway total'
        );

        for (uint i = 0; i < addresses.length; i++) 
            _claim(addresses[i], id);
    }

    /**
     * @notice Creates a new giveaway
     * 
     * @param collection The collection address
     * @param id The token id
     * @param total The total amount of tokens to giveaway
     */

    function createGiveaway (address collection, uint id, uint total) external onlyOwner returns (uint) {
        require(total > 0, 'BaliTwinGiveaway: total must be greater than 0');

        uint _giveawayId = giveawayIdCounter.current();
        giveawayIdCounter.increment();

        giveaways[_giveawayId] = Giveaway(collection, id, total, 0);
        return _giveawayId;
    }

    /**
     * @notice Change giveaway total
     * 
     * @param id The giveaway id
     * @param total The new total
     */

    function changeGiveawayTotal (uint id, uint total) external onlyOwner isExists(id) {
        require(total > giveaways[id].claimed, 'BaliTwinGiveaway: giveaway total must be greater than claimed');

        giveaways[id].total = total;
    }

    // Private functions

    /**
     * @notice Claim a token from a giveaway
     * 
     * @param claimer The user address
     * @param id The giveaway id
     */

    function _claim (address claimer, uint id) private {
        require(!claimed[claimer][id], 'Already claimed');

        Collection1155 collection = Collection1155(giveaways[id].collection);
        collection.mint(claimer, giveaways[id].id, 1, new bytes(0));

        giveaways[id].claimed++;
        claimed[claimer][id] = true;

        emit Claimed(claimer, giveaways[id].id, giveaways[id].collection);
    }
}

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

import "./tokens/Collection1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Giveaway
/// @author BaliTwin Developers
/// @notice This contract is used to distribute NFTs to users

/// @custom:version 1.0.0
/// @custom:website https://balitwin.com
/// @custom:security-contact security@balitwin.com

contract BaliTwinGiveaway is Ownable {
    
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
    uint private giveawaysCounter = 0;
    mapping (uint => Giveaway) private giveaways;

    /// @dev Mapping from user address to giveaway id to claim status
    mapping (address => mapping (uint => bool)) private claimed;
    
    event Claimed(address indexed claimer, uint indexed tokenId, address collection);


    /**
     * @notice Get giveaway by id
     * 
     * @param id The giveaway id
     */
    function getGiveaway(uint id) public view returns (Giveaway memory) {
        require(id < giveawaysCounter, "Giveaway does not exist");
        return giveaways[id];
    }

    /**
     * @notice Claim a token from a giveaway
     * @param giveawayId The giveaway id
     * 
     * @dev The giveaway must exist and the user must not have claimed the token yet
     */

    function claim (uint giveawayId) external {
        require(giveawayId < giveawaysCounter, "BaliTwinGiveaway: giveaway does not exist");
        require(!claimed[msg.sender][giveawayId], "BaliTwinGiveaway: giveaway already claimed");

        Giveaway memory giveaway = giveaways[giveawayId];
        Collection1155 collection = Collection1155(giveaway.collection);

        require(giveaway.claimed < giveaway.total, "BaliTwinGiveaway: giveaway already finished");
        collection.mint(msg.sender, giveaway.id, 1, new bytes(0));

        giveaways[giveawayId].claimed++;
        claimed[msg.sender][giveawayId] = true;

        emit Claimed(msg.sender, giveaway.id, giveaway.collection);
    }

    // Admin functions

    /**
     * @notice Creates a new giveaway
     * 
     * @param collection The collection address
     * @param id The token id
     * @param total The total amount of tokens to giveaway
     */

    function createGiveaway(address collection, uint id, uint total) external onlyOwner {
        require(total > 0, "BaliTwinGiveaway: total must be greater than 0");

        giveaways[giveawaysCounter] = Giveaway(collection, id, total, 0);
        giveawaysCounter++;
    }

    /**
     * @notice Airdrops tokens to a list of users
     * 
     * @param users The list of users
     * @param giveawayId The giveaway id
     */

    function airdrop(address[] calldata users, uint giveawayId) external onlyOwner {
        require(giveawayId < giveawaysCounter, "BaliTwinGiveaway: giveaway does not exist");

        Giveaway memory giveaway = giveaways[giveawayId];
        Collection1155 collection = Collection1155(giveaway.collection);

        require(giveaway.claimed + users.length <= giveaway.total, "BaliTwinGiveaway: giveaway already finished");

        for (uint i = 0; i < users.length; i++) {
            collection.mint(users[i], giveaway.id, 1, new bytes(0));
            claimed[users[i]][giveawayId] = true;

            emit Claimed(users[i], giveaway.id, giveaway.collection);
        }

        giveaways[giveawayId].claimed += users.length;
    }
}

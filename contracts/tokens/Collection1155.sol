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

import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol';
import '@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol';

/**
 * @title BaliTwin ERC1155 Collection.
 * @notice Extended ERC1155 with authorship tracking.
 * @author BaliTwin Developers.
 *
 * @custom:version 0.1.0
 * @custom:website balitwin.com
 * @custom:security-contact security@balitwin.com
 */

contract Collection1155 is ERC1155, ERC1155Supply, ERC1155Burnable, AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;

    /**
     * @notice Displayed data for explorers/wallets.
     */

    string public name;
    string public symbol;

    /**
     * @notice See contractURI().
     */

    string internal _contractURI;
    
    /**
     * @notice Set of token ID's. 
     * @dev Token ID - base16 encoded CID of metadata. f0... -> 0x...
     */

    EnumerableSet.UintSet private _tokenIds;

    mapping (uint => address) private _authorship;
    bytes32 public constant AUTHOR_ROLE = keccak256('AUTHOR_ROLE');

    constructor (string memory _name, string memory _symbol, string memory _contractMetaURI) ERC1155('ipfs://f0') {
        name = _name;
        symbol = _symbol;
        _contractURI = _contractMetaURI;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// Public functions

    /**
     * @notice Contract-level metadata URI.
     *
     * @dev URI should be IPFS CID.
     */

    function contractURI () public view returns (string memory) {
        return _contractURI;
    }

    /**
     * @notice Mints some amount of tokens to an address.
     *
     * @param to Address of the future owner of the token.
     * @param id Token ID to mint. See _tokenIds.
     * @param amount Amount of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */

    function mint (
        address to, uint id, uint amount, bytes memory data
    ) public onlyRole(AUTHOR_ROLE) {
        EnumerableSet.add(_tokenIds, id);

        _authorship[id] = msg.sender;
        _mint(to, id, amount, data);
    }

    /**
     * @notice Mint tokens for each id in ids.
     *
     * @param to The address to mint tokens to.
     * @param ids Array of ids to mint.
     * @param amounts Array of amounts of tokens to mint per id.
     * @param data Data to pass if receiver is contract.
     */

    function mintBatch (
        address to, uint[] memory ids, uint[] memory amounts, bytes memory data
    ) public onlyRole(AUTHOR_ROLE) {
        for (uint i = 0; i < ids.length; i++) {
            EnumerableSet.add(_tokenIds, ids[i]);
            _authorship[ids[i]] = msg.sender;
        }

        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @notice List of ids of all minted tokens.
     */
    function tokens () public view returns (uint[] memory) {
        uint[] memory _tokens = new uint[](EnumerableSet.length(_tokenIds));

        for (uint i = 0; i < _tokens.length; i++) {
            _tokens[i] = EnumerableSet.at(_tokenIds, i);
        }

        return _tokens;
    }

    /**
     * @notice List of token ids which owned by provided address.
     *
     * @param owner Address of owner.
     */

    function tokensOfOwner (address owner) external view returns (uint[] memory) {
        uint _counter = 0;
        for (uint i = 0; i < EnumerableSet.length(_tokenIds); i++)
            if (balanceOf(owner, EnumerableSet.at(_tokenIds, i)) > 0) _counter++;
        
        uint[] memory _result = new uint[](_counter);
        _counter = 0;
        for (uint i = 0; i < EnumerableSet.length(_tokenIds); i++) {
            if (balanceOf(owner, EnumerableSet.at(_tokenIds, i)) > 0) {
                _result[_counter] = EnumerableSet.at(_tokenIds, i);
                _counter++;
            }
        }

        return _result;
    }

    /**
     * @notice Returns address of token author.
     *
     * @param id Token ID.
     */

    function authorOf (uint id) external view returns (address) {
        require(exists(id), 'Token with provided id is not exists');
        return _authorship[id];
    }

    /**
     * @notice List of all minted tokens by provided auhtor.
     *
     * @param author Authors address.
     */

    function mintedBy (address author) external view returns (uint[] memory) {
        uint _counter = 0;
        for (uint i = 0; i < EnumerableSet.length(_tokenIds); i++) {
            if (_authorship[EnumerableSet.at(_tokenIds, i)] == author) _counter++;
        }

        uint[] memory _result = new uint[](_counter);

        _counter = 0;
        for (uint i = 0; i < EnumerableSet.length(_tokenIds); i++) {
            if (_authorship[EnumerableSet.at(_tokenIds, i)] == author) {
                _result[_counter] = EnumerableSet.at(_tokenIds, i);
                _counter++;
            }
        }

        return _result;
    }

    /**
     * @notice URI of token metadata.
     *
     * @dev Returns concatinted uri (_baseURI + tokenID).
     */

    function uri (uint id) override public view returns (string memory) {
        require(exists(id), 'Token with provided id is not exists');
        return string(abi.encodePacked(super.uri(id), _uint2hex(id)));
    }

    /// Overrides

    function supportsInterface (
        bytes4 interfaceId
    ) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer (
        address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    /// Pure functions

    /**
     * @notice Transform uint into hex.
     */

    function _uint2hex (uint i) private pure returns (string memory) {
        if (i == 0) return '0';

        uint j = i;
        uint length;
        while (j != 0) {
            length++;
            j = j >> 4;
        }
        
        uint mask = 15;
        uint k = length;
        bytes memory bstr = new bytes(length);
        
        while (i != 0) {
            uint curr = (i & mask);
            bstr[--k] = curr > 9 
                ? bytes1(uint8(55 + curr))
                : bytes1(uint8(48 + curr)); // 55 = 65 - 10
            i = i >> 4;
        }

        return string(bstr);
    }
}

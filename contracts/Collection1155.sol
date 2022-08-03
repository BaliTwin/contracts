// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract Collection1155 is ERC1155, ERC1155Supply, ERC1155Burnable, AccessControl {
    using EnumerableSet for EnumerableSet.UintSet;

    string public name;
    string public symbol;

    string internal _contractURI;
    
    EnumerableSet.UintSet private _tokenIds;
    mapping (uint => address) private _authorship;

    bytes32 public constant AUTHOR_ROLE = keccak256("AUTHOR_ROLE");

    constructor (string memory name_, string memory symbol_, string memory metaURI) ERC1155("ipfs://f0") {
        name = name_;
        symbol = symbol_;
        _contractURI = metaURI;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Public

    function contractURI () public view returns (string memory) {
        return _contractURI;
    }

    function mint (
        address to, uint id, uint amount, bytes memory data
    ) public onlyRole(AUTHOR_ROLE) {
        EnumerableSet.add(_tokenIds, id);

        _authorship[id] = msg.sender;
        _mint(to, id, amount, data);
    }

    function mintBatch (
        address to, uint[] memory ids, uint[] memory amounts, bytes memory data
    ) public onlyRole(AUTHOR_ROLE) {
        for (uint i = 0; i < ids.length; i++) {
            EnumerableSet.add(_tokenIds, ids[i]);
            _authorship[ids[i]] = msg.sender;
        }

        _mintBatch(to, ids, amounts, data);
    }

    function tokens () public view returns (uint[] memory) {
        uint[] memory _tokens = new uint[](EnumerableSet.length(_tokenIds));

        for (uint i = 0; i < _tokens.length; i++) {
            _tokens[i] = EnumerableSet.at(_tokenIds, i);
        }

        return _tokens;
    }

    function tokensOfOwner (address owner) external view returns (uint[] memory) {
        uint[] memory _tokens = tokens();
        uint _count = 0;

        for (uint i = 0; i < _tokens.length; i++) {
            if (balanceOf(owner, _tokens[i]) > 0) {
                _tokens[_count] = _tokens[i];
                _count++;
            }
        }
        
        uint[] memory _owned = new uint[](_count);
        for (uint i = 0; i < _owned.length; i++) {
            _owned[i] = _tokens[i];
        }

        return _owned;
    }

    function authorOf (uint id) external view returns (address) {
        require(exists(id), "Token with provided id is not exists");
        return _authorship[id];
    }

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

    function uri (uint id) override public view returns (string memory) {
        return string(abi.encodePacked(super.uri(id), _uint2hex(id)));
    }

    // Overrides

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

    // Pure

    function _uint2hex (uint i) private pure returns (string memory) {
        if (i == 0) return "0";

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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

/// @custom:security-contact security@balitwin.com
contract Collection721 is ERC721, ERC721URIStorage, ERC721Enumerable, ERC721Burnable, AccessControl {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    string internal _contractURI;

    mapping (uint => address) private _authorship;
    bytes32 public constant AUTHOR_ROLE = keccak256("AUTHOR_ROLE");

    constructor (
        string memory name, string memory symbol, string memory metaURI
    ) ERC721(name, symbol) {
        _contractURI = metaURI;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Public

    function contractURI () public view returns (string memory) {
        return _contractURI;
    }

    function mint (address to, string memory uri, bytes memory data) external onlyRole(AUTHOR_ROLE) returns (uint) {
        require(!_tokenURIExists(uri), "Provided URI already minted");

        uint id = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _authorship[id] = msg.sender;
        _safeMint(to, id, data);
        _setTokenURI(id, uri);

        return id;
    }

    function authorOf (uint id) external view returns (address) {
        require(exists(id), "Token with provided id is not exists");
        return _authorship[id];
    }

    function mintedBy (address author) external view returns (uint[] memory) {
        uint _counter = 0;
        for (uint i = 0; i < _tokenIdCounter.current(); i++) {
            if (_authorship[i] == author) _counter++;
        }

        uint[] memory _result = new uint[](_counter);

        _counter = 0;
        for (uint i = 0; i < _tokenIdCounter.current(); i++) {
            if (_authorship[i] == author) {
                _result[_counter] = i;
                _counter++;
            }
        }

        return _result;
    }

    function exists (uint id) public view returns (bool) {
        return _exists(id);
    }

    function tokensOfOwner (address owner) external view returns (uint[] memory) {
        uint[] memory _result = new uint[](balanceOf(owner));

        for (uint i = 0; i < _result.length; i++) {
            _result[i] = tokenOfOwnerByIndex(owner, i);
        }

        return _result;
    }

    // Overrides

    function tokenURI (uint tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface (
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer (
        address from, address to, uint tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn (uint tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

     // Private

    function _tokenURIExists (string memory uri) private view returns (bool) {
        uint[] memory _tokens = new uint[](_tokenIdCounter.current());

        for (uint i = 0; i < _tokens.length; i++) {
            if (_compareStrings(tokenURI(i), uri)) return true;
        }

        return false;
    }

    // Pure

    function _compareStrings (string memory a, string memory b) internal pure returns (bool) {
        if (bytes(a).length != bytes(b).length) return false;
        else return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
}
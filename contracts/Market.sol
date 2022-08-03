// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

abstract contract Collection is IERC1155 {
    function authorOf (uint id) public virtual view returns (address);
}

/// @custom:security-contact security@balitwin.com
contract BaliTwinMarket is ERC721Holder, ERC1155Holder, AccessControl {
    using Counters for Counters.Counter;

    bytes32 public constant VERIFIED_COLLECTION = keccak256("VERIFIED_COLLECTION");

    uint constant public minPrice = 1 * 10 ** 6;
    address public paymentCurrency;

    struct Invoice { uint price; }
    struct Item {
        uint id;
        address collection;
        address author;

        uint price;
        address seller;
    }

    event List (uint id);

    Counters.Counter private _itemIdCounter;
    mapping (uint => Item) private _items;

    Counters.Counter private _authorIdCounter;
    mapping (uint => address) private _authors;

    Counters.Counter private _collectionIdCounter;
    mapping (uint => address) private _collections;
    
    constructor (address _paymentCurrency) {
        paymentCurrency = _paymentCurrency;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function item (uint id) public view returns (Item memory) {
       return _items[id];
    }

    function items () public view returns (uint[] memory) {
        uint[] memory _result = new uint[](_itemIdCounter.current());

        for (uint i = 0; i < _result.length; i++)
            _result[i] = i;

        return _result;
    }

    function itemsAvailable () public view returns (uint[] memory) {
       return itemsOfOwner(address(this));
    }

    function itemsOfOwner (address owner) public view returns (uint[] memory) {
        uint _counter = 0;

        for (uint i = 0; i < _itemIdCounter.current(); i++)
            if (
                Collection(_items[i].collection).balanceOf(owner, _items[i].id) > 0
            ) _counter++;

        uint[] memory _result = new uint[](_counter);
        _counter = 0;

        for (uint i = 0; i < _itemIdCounter.current(); i++)
            if (
                Collection(_items[i].collection).balanceOf(owner, _items[i].id) > 0
            ) { 
                _result[_counter] = i;
                _counter++;
            }

        return _result;
    }

    function itemsByCollection (address collection) external view returns (Item[] memory) {
        uint _counter = 0;

        for (uint i = 0; i < _itemIdCounter.current(); i++)
            if (_items[i].collection == collection)
                _counter++;

        Item[] memory _result = new Item[](_counter);
        _counter = 0;

        for (uint i = 0; i < _itemIdCounter.current(); i++)
            if (_items[i].collection == collection) {
                _result[_counter] = _items[i];
                _counter++;
            }

        return _result;
    }

    function itemsByAuthor (address author) external view returns (Item[] memory) {
        uint _counter = 0;

        for (uint i = 0; i < _itemIdCounter.current(); i++)
            if (_items[i].author == author)
                _counter++;

        Item[] memory _result = new Item[](_counter);
        _counter = 0;

        for (uint i = 0; i < _itemIdCounter.current(); i++)
            if (_items[i].collection == author) {
                _result[_counter] = _items[i];
                _counter++;
            }

        return _result;
    }

    function collections () external view returns (address[] memory) {
        address[] memory _result = new address[](_collectionIdCounter.current());

        for (uint i = 0; i < _result.length; i++)
            _result[i] = _collections[i];

        return _result;
    }

    function authors () external view returns (address[] memory) {
        address[] memory _result = new address[](_authorIdCounter.current());

        for (uint i = 0; i < _result.length; i++)
            _result[i] = _authors[i];

        return _result;
    }

    function buy (uint id, uint amount) external {
        ERC20 currency = ERC20(paymentCurrency);
        currency.transferFrom(msg.sender, address(this), _items[id].price * amount);

        Collection(_items[id].collection).safeTransferFrom(
            address(this), msg.sender, _items[id].id, amount, new bytes(0)
        );
    }

    function unlist (uint id, uint amount) external {
        require(_items[id].seller != address(0), "Item with provided id is not exists");
        require(_items[id].seller == msg.sender, "You can't unlist item, because you are not seller");

        Collection(_items[id].collection).safeTransferFrom(
            address(this), msg.sender, _items[id].id, amount, new bytes(0)
        );
    }

    function withdraw () onlyRole(DEFAULT_ADMIN_ROLE) external {
        ERC20 currency = ERC20(paymentCurrency);
        currency.transfer(msg.sender, currency.balanceOf(address(this)));
    }

    // Private

    function _listItem (
        address collection, address seller, uint id, uint amount, bytes memory data
    ) private onlyRole(VERIFIED_COLLECTION) returns (uint) {
        require(amount > 0, "Amount must be grater than 0");
        
        // Check if item already listed
        for (uint i = 0; i < _itemIdCounter.current(); i++) 
            if (_items[i].id == id && _items[i].collection == collection) 
                return id;

        // Invoice validation
        Invoice memory invoice = abi.decode(data, (Invoice));
        require(invoice.price > minPrice, "Price must be greater than minimal price");

        address _author = Collection(collection).authorOf(id);
        _listAuthor(_author);
        _listCollection(collection);

        uint _itemId = _itemIdCounter.current();
        _itemIdCounter.increment();
        
        _items[_itemId] = Item(
            id, collection, _author, invoice.price, seller
        );

        emit List(_itemId);
        return _itemId;
    }

    function _listAuthor (address author) private returns (uint) {
        for (uint i = 0; i < _authorIdCounter.current(); i++)
            if (_authors[i] == author) return i;
        
        _authors[_authorIdCounter.current()] = author;
        _authorIdCounter.increment();

        return _authorIdCounter.current();
    }

    function _listCollection (address collection) private returns (uint) {
        for (uint i = 0; i < _collectionIdCounter.current(); i++)
            if (_collections[i] == collection) return i;
        
        _collections[_collectionIdCounter.current()] = collection;
        _collectionIdCounter.increment();

        return _collectionIdCounter.current();
    }

    // Overrides

    function onERC721Received (
        address operator, address from, uint id, bytes memory _data
    ) public override virtual returns (bytes4) {
        _listItem(msg.sender, operator, id, 1, _data);
        return this.onERC721Received.selector;
    }
    
    function onERC1155Received (
        address operator, address from, uint id, uint amount, bytes memory _data
    ) public override virtual returns (bytes4) {
        _listItem(msg.sender, operator, id, amount, _data);
       return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived (
        address operator, address from, uint[] memory ids, uint[] memory amounts, bytes memory data
    ) public override virtual returns (bytes4) {
        bytes[] memory _data = abi.decode(data, (bytes[]));
        require(_data.length == ids.length, "ids and data length mismatch");

        for (uint i = 0; i < ids.length; i++) {
            _listItem(msg.sender, operator, ids[i], amounts[i], _data[i]);
        }
        
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface (
        bytes4 interfaceId
    ) public view override(ERC1155Receiver, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}

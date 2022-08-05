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

import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import './tokens/Collection1155.sol';

/// @title BaliTwin Market.
/// @author BaliTwin Developers.
/// @notice Contract for list and sale ERC1155 tokens.

/// @custom:version 0.1.0
/// @custom:security-contact security@balitwin.com

contract BaliTwinMarket is ERC1155Holder, AccessControl {
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant VERIFIED_COLLECTION = keccak256('VERIFIED_COLLECTION');
    
    /**
     * @dev Percentage value. 0% - 99%
     */

    uint public listingFee = 0;

    /**
     * @dev Minimal price should be depended on Payment currency decimals.
     */
    
    uint public minPrice = 1 wei;

    /**
     * @dev Address of ERC20 contract.
     */

    address public paymentCurrency;

    /**
     * @dev Provides as bytes on token transfer.
     */

    struct Invoice { uint price; }
    
    struct Item {
        uint id;
        address collection;
        address author;

        uint price;
        address seller;
    }

    event Listed (uint id);
    event Unlisted (uint id);
    event Purchased (uint id);

    event MinPriceChanged (uint value);
    event ListingFeeChanged (uint value);
    event PaymentCurrencyChanged (address value);

    modifier onlySeller (uint id) {
        require(_items[id].seller == msg.sender, 'You cannot unlist item, because you are not seller');
        _;
    }
    
    Counters.Counter private _itemIdCounter;
    mapping (uint => Item) private _items;

    EnumerableSet.AddressSet private _authors;
    EnumerableSet.AddressSet private _collections;
    
    constructor (address _paymentCurrency) {
        paymentCurrency = _paymentCurrency;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// View functions

    /**
     * @notice Item info.
     *
     * @param id Item id.
     */

    function item (uint id) external view returns (Item memory) {
       return _items[id];
    }

    /**
     * @notice All listed items.
     */

    function items () external view returns (uint[] memory) {
        uint[] memory _result = new uint[](_itemIdCounter.current());

        for (uint i = 0; i < _result.length; i++)
            _result[i] = i;

        return _result;
    }

    /**
     * @notice All listed items which available for purchase.
     */

    function itemsAvailable () public view returns (uint[] memory) {
       return itemsOfOwner(address(this));
    }

    /**
     * @notice All purchased items by provided address.
     *
     * @param owner Owner address.
     */

    function itemsOfOwner (address owner) public view returns (uint[] memory) {
        uint _counter = 0;

        for (uint i = 0; i < _itemIdCounter.current(); i++)
            if (
                Collection1155(_items[i].collection).balanceOf(owner, _items[i].id) > 0
            ) _counter++;

        uint[] memory _result = new uint[](_counter);
        _counter = 0;

        for (uint i = 0; i < _itemIdCounter.current(); i++)
            if (
                Collection1155(_items[i].collection).balanceOf(owner, _items[i].id) > 0
            ) { 
                _result[_counter] = i;
                _counter++;
            }

        return _result;
    }

    /**
     * @notice All listed items by provided collection address.
     *
     * @param collection Collection address.
     */

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

    /**
     * @notice All listed items by provided author address.
     *
     * @param author Authir address.
     */

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

    /**
     * @notice All listed collections.
     */

    function collections () external view returns (address[] memory) {
        return EnumerableSet.values(_collections);
    }

    /**
     * @notice All listed authors.
     */

    function authors () external view returns (address[] memory) {
        return EnumerableSet.values(_authors);
    }

    /// Actions

    /**
     * @notice Buy item.
     *
     * @param id Item id.
     */

    function buy (uint id, uint amount) external {
        Collection1155 collection = Collection1155(_items[id].collection);

        require(amount > 0, 'Amount should be greater than 0');
        require(
            amount <= collection.balanceOf(address(this), _items[id].id),
            'Not enough available tokens'
        );

        uint _fee = _items[id].price * amount / 100 * listingFee;

        ERC20 currency = ERC20(paymentCurrency);
        currency.transferFrom(msg.sender, address(this), _fee);
        currency.transferFrom(msg.sender, _items[id].seller, _items[id].price * amount - _fee);

        collection.safeTransferFrom(
            address(this), msg.sender, _items[id].id, amount, new bytes(0)
        );

        emit Purchased(id);
    }

    /**
     * @notice Unlit item. See _unlist().
     *
     * @param id Item id.
     */

    function unlist (uint id) onlySeller(id) external {
        _unlist(id);
    }

    // Admin functions
    
    /**
     * @notice Set minimal price.
     *
     * @param value New minimal price.
     */

    function setMinPrice (uint value) onlyRole(DEFAULT_ADMIN_ROLE) external {
        require(value > 0, 'Minimal price cannot be 0');

        minPrice = value;
        emit MinPriceChanged(value);
    }

    /**
     * @notice Set listing fee.
     *
     * @param value New listing fee percent.
     */

    function setListingFee (uint value) onlyRole(DEFAULT_ADMIN_ROLE) external {
        require(value < 100, 'Fee cannot be greater than 99%');

        listingFee = value;
        emit ListingFeeChanged(value);
    }

    /**
     * @notice Set minimal price.
     * @dev Withdraws all previous currency before changing.
     *
     * @param value New Payment currenct address.
     */

    function setPaymentCurrency (address value) onlyRole(DEFAULT_ADMIN_ROLE) external {
        withdraw();
        paymentCurrency = value;
        emit PaymentCurrencyChanged(value);
    }

    /**
     * @notice Withdraw all payment currency to contract owner address.
     */
     
    function withdraw () onlyRole(DEFAULT_ADMIN_ROLE) public {
        ERC20 currency = ERC20(paymentCurrency);
        currency.transfer(msg.sender, currency.balanceOf(address(this)));
    }

    /**
     * @notice Destroys current contract, calls withdraw and transfer all items to theirs owners.
     */

    function destroy () onlyRole(DEFAULT_ADMIN_ROLE) external {
        uint[] memory _available = itemsAvailable();
        for (uint i = 0; i < _available.length; i++)
            _unlist(_available[i]);

        withdraw();
        selfdestruct(payable(msg.sender));
    }

    // Private

    /**
     * @dev For list items you must just transfer it to this contract and provide Invoice struct as data.
     *
     * @param collection Collection address.
     * @param seller Seller address.
     * @param id Token id.
     * @param data Invoice bytes. See struct Invoice.
     */

    function _listItem (
        address collection, address seller, uint id, bytes memory data
    ) private onlyRole(VERIFIED_COLLECTION) returns (uint) {
        // Check if item already listed
        for (uint i = 0; i < _itemIdCounter.current(); i++) 
            if (_items[i].id == id && _items[i].collection == collection) 
                return id;

        // Invoice validation
        Invoice memory invoice = abi.decode(data, (Invoice));
        require(minPrice <= invoice.price, 'Price must be greater than minimal price');

        address author = Collection1155(collection).authorOf(id);
        EnumerableSet.add(_authors, author);
        EnumerableSet.add(_collections, collection);

        uint _itemId = _itemIdCounter.current();
        _itemIdCounter.increment();
        
        _items[_itemId] = Item(
            id, collection, author, invoice.price, seller
        );

        emit Listed(_itemId);
        return _itemId;
    }

    /**
     * @notice Unlist item.
     * @dev Transfers items back to seller and deletes from list
     */
    function _unlist (uint id) private {
        Collection1155 collection = Collection1155(_items[id].collection);

        Collection1155(_items[id].collection).safeTransferFrom(
            address(this), 
            _items[id].seller, 
            _items[id].id, 
            collection.balanceOf(address(this), _items[id].id),
            new bytes(0)
        );

        delete _items[id];
        emit Unlisted(id);
    }

    // Overrides
    
    /**
     * @notice See _listItem()
     */
    function onERC1155Received (
        address operator, address from, uint id, uint amount, bytes memory _data
    ) public override virtual returns (bytes4) {
        _listItem(msg.sender, operator, id, _data);
       return this.onERC1155Received.selector;
    }

    /**
     * @notice See _listItem()
     */
    function onERC1155BatchReceived (
        address operator, address from, uint[] memory ids, uint[] memory amounts, bytes memory data
    ) public override virtual returns (bytes4) {
        bytes[] memory _data = abi.decode(data, (bytes[]));
        require(_data.length == ids.length, 'ids and data length mismatch');

        for (uint i = 0; i < ids.length; i++) {
            _listItem(msg.sender, operator, ids[i], _data[i]);
        }
        
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface (
        bytes4 interfaceId
    ) public view override(ERC1155Receiver, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract Market{  


    struct Item{ //A blueprint for each item listed in the marketplace
        uint256 id;
        string name;
        uint256 price;
        address payable seller; //payable means the seller that can receive ETH.
        bool isSold; //tracks if the item has already been bought 
    }

    error EmptyName();
    error InvalidPrice();
    error ItemNotFound();
    error ItemAlreadySold();
    error InsufficientFunds();
    error NotSeller();


    event ItemListed(uint256 indexed itemId, string _name, uint256 _price, address indexed _seller);
    event ItemPurchased(uint indexed _itemId, address indexed buyer, uint256 price);

    mapping(uint256 => Item) public items; //maps each item ID to it's Struct Item
    mapping(address => uint256[]) public sellerItems; //maps each seller's address to an array of Item IDs they have listed 
    uint256 private nextItemId = 1;//internal counter, auto incremental for assigning unigue IDs to newly created items


    function listItem(string calldata _name, uint256 _price) external returns (uint256) { //public function to list an item for sale, uses calldata which is cheaper than memory for string input
        if(bytes(_name).length == 0) {
            revert EmptyName();
        }
        if(_price == 0) {
            revert InvalidPrice();
        }

        //create a new item
        uint256 itemId = nextItemId++; //generates a new unique item ID and increments nextItemId
        items[itemId] = Item({ //creates and stores the item in the items mapping
            id: itemId,
            name: _name,
            price: _price,
            seller: payable(msg.sender), //seller converted to payable
            isSold: false
        });

        //add to seller's itemList
        sellerItems[msg.sender].push(itemId); //keeps a record of the item ID under the seller's address

        emit ItemListed(itemId, _name, _price, msg.sender); //emits the event and returns the new item ID to the frontend or caller

        return itemId;
    }


    function buyItem(uint256 _itemId) external payable { //function to buy a listed item and must be called with ETH which is a payable function
        if(items[_itemId].seller == address(0)) { //check sellers's record to ensure items exists. validates that the item exists.
            revert ItemNotFound();
        }

        Item storage item = items[_itemId]; //creates a reference to the item in storage(not a copy)

        if(item.isSold){
            revert ItemAlreadySold();
        }
        if(msg.value < item.price) {
            revert InsufficientFunds();
        }
        item.isSold = true; // marks the item as sold to prevent re-buying
        item.seller.transfer(item.price); //sends the item price in ETH to the seller
        if(msg.value > item.price) {
            payable(msg.sender).transfer(msg.value - item.price); //refunds any extra ETH to the buyer
        }

        emit ItemPurchased(_itemId, msg.sender, item.price);
    }

    function getItem(uint256 _itemId) external view returns (Item memory) { //returns all data for a specific item and reverts if the item doesn't exist
        if(items[_itemId].seller == address(0)) {
            revert ItemNotFound();
    }
        return items[_itemId];
}

function getSellerItems(address _seller) external view returns(uint256[] memory) {
   return sellerItems[_seller]; //returns a list of item IDs listed by a seller
}
}
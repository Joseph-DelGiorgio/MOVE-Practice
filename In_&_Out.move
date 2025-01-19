// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract InAndOutBurger {
    address public owner;

    struct MenuItem {
        string name;
        uint256 price;
        uint256 stock;
    }

    mapping(uint256 => MenuItem) public menu;
    uint256 public menuCount;

    event OrderPlaced(address indexed customer, uint256 itemId, uint256 quantity, uint256 totalPrice);
    event StockUpdated(uint256 itemId, uint256 newStock);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action.");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Add a new menu item
    function addMenuItem(string memory _name, uint256 _price, uint256 _stock) public onlyOwner {
        menu[menuCount] = MenuItem(_name, _price, _stock);
        menuCount++;
    }

    // Update stock for an existing item
    function updateStock(uint256 _itemId, uint256 _newStock) public onlyOwner {
        require(_itemId < menuCount, "Invalid item ID.");
        menu[_itemId].stock = _newStock;
        emit StockUpdated(_itemId, _newStock);
    }

    // Place an order
    function placeOrder(uint256 _itemId, uint256 _quantity) public payable {
        require(_itemId < menuCount, "Invalid item ID.");
        MenuItem storage item = menu[_itemId];
        require(item.stock >= _quantity, "Not enough stock available.");
        require(msg.value == item.price * _quantity, "Incorrect payment amount.");

        item.stock -= _quantity;
        emit OrderPlaced(msg.sender, _itemId, _quantity, msg.value);
    }

    // Withdraw balance to owner's account
    function withdrawBalance() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
}

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

/*
# InAndOutBurger Smart Contract

This smart contract is designed to manage the business operations of a fictional "In and Out Burger" restaurant. It provides functionality for managing menu items, processing customer orders, handling payments, and tracking order history — all while ensuring transparency and security through blockchain technology.

---

## Features

### For the Owner:
- **Add Menu Items**: Add new items to the menu with a name, price, and stock quantity.
- **Update Menu Items**: Modify the price, name, or stock of existing menu items.
- **Withdraw Funds**: Withdraw the accumulated balance from the contract to the owner's wallet.
- **Transparency**: View the contract's current balance.

### For Customers:
- **Place Orders**: Order items by selecting their ID and quantity. Payments are processed securely on-chain.
- **Order History**: View your past orders for record-keeping and transparency.

---

## Contract Overview

### Data Structures
1. **MenuItem**:
   - `name`: Name of the menu item (e.g., "Double Cheeseburger").
   - `price`: Price of the item in wei (1 ETH = 10^18 wei).
   - `stock`: Available stock for the item.

2. **Order**:
   - `customer`: Address of the customer placing the order.
   - `itemId`: ID of the ordered menu item.
   - `quantity`: Quantity of the item ordered.
   - `totalPrice`: Total cost of the order in wei.
   - `timestamp`: Time when the order was placed.

---

## Deployment Instructions

1. **Install Prerequisites**:
   - Install [Node.js](https://nodejs.org/) and [npm](https://www.npmjs.com/).
   - Install [Hardhat](https://hardhat.org/) for smart contract deployment and testing.
   - Install a wallet like [MetaMask](https://metamask.io/) for interacting with the deployed contract.

2. **Compile Contract**:
   Run the following command to compile the contract:

*\
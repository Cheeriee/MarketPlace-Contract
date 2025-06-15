// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "../src/Market.sol";

contract MarketTest is Test {
    Market market;
    address seller1 = address(0x1);
    address seller2 = address(0x2);
    address buyer = address(0x3);
    address nonSeller = address(0x4);

    event ItemListed(uint256 indexed itemId, string _name, uint256 _price, address indexed _seller);
    event ItemPurchased(uint indexed _itemId, address indexed buyer, uint256 price);
    function setUp() public {
        market = new Market();
        vm.deal(buyer, 100 ether);
        vm.deal(nonSeller, 100 ether);
    }
    function testListItem() public {
        vm.prank(seller1);
        vm.expectEmit(true, false, false, true);
        emit ItemListed(1, "Laptop", 1 ether, seller1);
        uint256 itemId = market.listItem("Laptop", 1 ether);
        assertEq(itemId, 1, "Item ID should be 1");
        Market.Item memory item = market.getItem(1);
        assertEq(item.id, 1, "Item ID should match");
        assertEq(item.name, "Laptop", "Item name should match");
        assertEq(item.price, 1 ether, "Item price should match");
        assertEq(item.seller, seller1, "Item seller should match");
        assertFalse(item.isSold, "Item should not be sold");
        uint256[] memory sellerItems = market.getSellerItems(seller1);
        assertEq(sellerItems.length, 1, "Seller should have 1 item");
        assertEq(sellerItems[0], 1, "Seller item ID should be 1");
    }

    function testListItemEmptyName() public {
        vm.prank(seller1);
        vm.expectRevert(Market.EmptyName.selector);
        market.listItem("", 1 ether);
    }

    function testListItemInvalidPrice() public {
        vm.prank(seller1);
        vm.expectRevert(Market.InvalidPrice.selector);
        market.listItem("Laptop", 0);
    }

    function testListMultipleItems() public {
        vm.prank(seller1);
        market.listItem("Laptop", 1 ether);
        vm.prank(seller1);
        market.listItem("Phone", 0.5 ether);
        uint256[] memory sellerItems = market.getSellerItems(seller1);
        assertEq(sellerItems.length, 2, "Seller should have 2 items");
        assertEq(sellerItems[0], 1, "First item ID should be 1");
        assertEq(sellerItems[1], 2, "Second item ID should be 2");
    }

    function testBuyItem() public {
        vm.prank(seller1);
        market.listItem("Laptop", 1 ether);
        uint256 sellerBalanceBefore = seller1.balance;
        uint256 buyerBalanceBefore = buyer.balance;
        vm.prank(buyer);
        vm.expectEmit(true, true, false, true);
        emit ItemPurchased(1, buyer, 1 ether);
        market.buyItem{value: 1 ether}(1);
        Market.Item memory item = market.getItem(1);
        assertTrue(item.isSold, "Item should be sold");
        assertEq(seller1.balance, sellerBalanceBefore + 1 ether, "Seller should receive payment");
        assertEq(buyer.balance, buyerBalanceBefore - 1 ether, "Buyer should pay price");
        assertEq(address(market).balance, 0, "Contract balance should be 0");
    }

    function testBuyItemOverpayment() public {
        vm.prank(seller1);
        market.listItem("Laptop", 1 ether);
        uint256 sellerBalanceBefore = seller1.balance;
        uint256 buyerBalanceBefore = buyer.balance;
        vm.prank(buyer);
        market.buyItem{value: 2 ether}(1);
        Market.Item memory item = market.getItem(1);
        assertTrue(item.isSold, "Item should be sold");
        assertEq(seller1.balance, sellerBalanceBefore + 1 ether, "Seller should receive item price");
        assertEq(buyer.balance, buyerBalanceBefore - 1 ether, "Buyer should pay price with refund");
        assertEq(address(market).balance, 0, "Contract balance should be 0");
    }

    function testBuyItemNotFound() public {
        vm.prank(buyer);
        vm.expectRevert(Market.ItemNotFound.selector);
        market.buyItem{value: 1 ether}(1);
    }

    function testBuyItemAlreadySold() public {
        vm.prank(seller1);
        market.listItem("Laptop", 1 ether);
        vm.prank(buyer);
        market.buyItem{value: 1 ether}(1);
        vm.prank(buyer);
        vm.expectRevert(Market.ItemAlreadySold.selector);
        market.buyItem{value: 1 ether}(1);
    }

    function testBuyItemInsufficientFunds() public {
        vm.prank(seller1);
        market.listItem("Laptop", 1 ether);
        vm.prank(buyer);
        vm.expectRevert(Market.InsufficientFunds.selector);
        market.buyItem{value: 0.5 ether}(1);
    }

    function testGetItem() public {
        vm.prank(seller1);
        market.listItem("Laptop", 1 ether);
        Market.Item memory item = market.getItem(1);
        assertEq(item.id, 1, "Item ID should match");
        assertEq(item.name, "Laptop", "Item name should match");
        assertEq(item.price, 1 ether, "Item price should match");
        assertEq(item.seller, seller1, "Item seller should match");
        assertFalse(item.isSold, "Item should not be sold");
    }

    function testGetItemNotFound() public {
        vm.expectRevert(Market.ItemNotFound.selector);
        market.getItem(1);
    }

    function testGetSellerItems() public {
        vm.prank(seller1);
        market.listItem("Laptop", 1 ether);
        vm.prank(seller1);
        market.listItem("Phone", 0.5 ether);
        uint256[] memory sellerItems = market.getSellerItems(seller1);
        assertEq(sellerItems.length, 2, "Seller should have 2 items");
        assertEq(sellerItems[0], 1, "First item ID should be 1");
        assertEq(sellerItems[1], 2, "Second item ID should be 2");
        uint256[] memory emptyItems = market.getSellerItems(seller2);
        assertEq(emptyItems.length, 0, "Non-seller should have 0 items");
    }
}
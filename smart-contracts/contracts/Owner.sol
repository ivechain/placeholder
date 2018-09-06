pragma solidity ^0.4.16;

contract Owner {
    address public owner;

    event OwnerChanged(address oldOwner, address newOwner);

    constructor() public{
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner,"不是合约拥有者");
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        require(newOwner != owner && newOwner != address(0x0),"11111");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnerChanged(oldOwner, newOwner);
    }
}

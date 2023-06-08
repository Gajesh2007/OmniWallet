pragma solidity ^0.8.19;

import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";

// THIS CONTRACT HAS NOT BEEN TESTED
contract SmartWallet is Ownable {
    // Emitted when a transaction is executed
    event TransactionExecuted(address target, uint value, bytes data, bool success, bytes response);

    // Function to execute an arbitrary call
    function executeTransaction(
        address payable target, 
        uint value, 
        bytes memory data
    ) public onlyOwner {
        // Make sure the contract has enough balance to send
        require(address(this).balance >= value, "Insufficient balance");

        // Execute the transaction
        (bool success, bytes memory response) = target.call{value: value}(data);

        // Emit an event with the transaction details
        emit TransactionExecuted(target, value, data, success, response);

        // If the call failed, revert the transaction
        require(success, "Transaction execution failed");
    }

    // Fallback function to receive ether
    receive() external payable {}

    // Function to withdraw funds from the contract
    function withdraw(uint value) public onlyOwner {
        require(address(this).balance >= value, "Insufficient balance");
        payable(msg.sender).transfer(value);
    }
}

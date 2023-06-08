// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "./lzApp/NonblockingLzApp.sol";
import "./interfaces/IStargateRouter.sol";
import "../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Wallet.sol";

contract TransactionLayer is NonblockingLzApp {
    using SafeMath for uint256;

    struct Vault {
        bool created;
        SmartWallet vault;
    }

    mapping(address => Vault) public vault;  

    constructor(
        address _lzEndpoint
    ) NonblockingLzApp(_lzEndpoint) {}

    function createOmniWallet(
        uint16[] memory _chains,
        uint256[] memory _fees
    ) external payable {
        require(msg.value > 0, "you need to pay crosschain fees");

        if (vault[msg.sender].created == false) {
            vault[msg.sender].vault = new SmartWallet();
            vault[msg.sender].created = true;
        }
        
        bytes memory data = abi.encode(msg.sender);

        bytes memory payload = abi.encode("create", data);
        
        for (uint i = 0; i < _chains.length; i++) {
            _lzSend(
                _chains[i], 
                payload, 
                payable(msg.sender), 
                address(0x0), 
                bytes(""),
                _fees[i]
            );
        }
    }

    function executeTransaction(
        address payable target, 
        uint value, 
        bytes memory data
    ) external payable {
        require(vault[msg.sender].created == true, "you don't have a omniwallet");

        (bool sent, bytes memory data) = payable(vault[msg.sender].vault).call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        vault[msg.sender].vault.executeTransaction(target, value, data);
    }

    function executeTransaction(
        address payable target, 
        uint value, 
        bytes memory data,
        uint16 _chain
    ) external payable {
        require(vault[msg.sender].created == true, "you don't have a omniwallet");
        require(msg.value > 0, "u need to pay cross-chain message fee");

        (bool sent, bytes memory data) = payable(vault[msg.sender].vault).call{value: msg.value}("");
        require(sent, "Failed to send Ether");

        vault[msg.sender].vault.executeTransaction(target, value, data);

        bytes memory payload = abi.encode("execute", msg.sender, target, value, data);

        _lzSend(
            _chain, 
            payload, 
            payable(msg.sender), 
            address(0x0), 
            bytes(""),
            msg.value
        );
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId, 
        bytes memory _srcAddress, 
        uint64 _nonce, 
        bytes memory _payload
    ) internal override {
        (string memory _method, bytes memory _payload) = abi.decode(_payload, (string, bytes));

        if (keccak256(abi.encodePacked(_method)) == keccak256(abi.encodePacked("create"))) {
            address _user = abi.decode(_payload, (address));

            require(vault[_user].created == true, "vault already exists");

            vault[_user].vault = new SmartWallet();
            vault[_user].created = true;
        } else if (keccak256(abi.encodePacked(_method)) == keccak256(abi.encodePacked("execute"))) {
            (address _user, address payable _target, uint _value, bytes memory _data) = abi.decode(_payload, (address, address, uint, bytes));

            require(vault[_user].created == true, "vault doesn't exist");

            vault[_user].vault.executeTransaction(_target, _value, _data);
        }
    }

    function sgReceive(
        uint16 _chainId, 
        bytes memory _srcAddress, 
        uint _nonce, 
        address _token, 
        uint amountLD, 
        bytes memory _payload
    ) external {

    }
}
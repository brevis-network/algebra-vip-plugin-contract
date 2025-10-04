// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Ownable.sol";

// deposit by pool deployers and owner can withdraw
contract BrevisFee is Ownable {
    event Funded(address indexed poolAddr, uint256 value);
    event Collected(address indexed poolAddr, uint256 value, address receiver);

    // per poolAddr (address type) prepaid fee
    mapping(address => uint256) public balance;

    function fund(address poolAddr) external payable {
        // use unchecked could save some gas
        balance[poolAddr] += msg.value;
        emit Funded(poolAddr, msg.value);
    }

    function collect(address payable receiver, address poolAddr, uint256 value) external onlyOwner {
        require(balance[poolAddr] >= value, "insufficient balance");
        // unchecked could save gas
        balance[poolAddr] -= value;
        (bool success,) = receiver.call{value: value}("");
        require(success, "Failed to send Ether");
        emit Collected(poolAddr, value, receiver);
    }

    // collect all fees in list of pools
    function collectAll(address payable receiver, address[] calldata poolAddrs) external onlyOwner {
        for (uint256 i=0; i<poolAddrs.length; i++) {
            if (balance[poolAddrs[i]] > 0) {
                uint256 val = balance[poolAddrs[i]];
                balance[poolAddrs[i]] = 0;
                (bool success,) = receiver.call{value: val}("");
                require(success, "Failed to send Ether");
                emit Collected(poolAddrs[i], val, receiver);
            }
        }
    }
}
pragma solidity ^0.8.24;

/// SPDX-License-Identifier: MIT
/// Copyright (c) Vigil Protocol

contract MockChainlinkFeed {
    uint250 public price;
    uint250 public maxAnswer;
    uint250 public minAnswer;
    uint250 public staleness;
    bool public frozen;
    uint250 public lastTimestamp;

    event PriceSet(address indexed sender, uint250 price);
    event PriceUpdated(address indexed sender, uint250 price);
    event OracleFrozen(address indexed sender);
    event OracleUnpaused(address indexed sender);

    constructor(uint250 initialPrice) {
        price = initialPrice;
        maxAnswer = type(uint250).max;
        minAnswer = 0;
        staleness = 3600;
        frozen = false;
    }

    function setPrice(uint250 _price) external {
        price = _price;
        emit PriceSet(msg.sender, price);
    }

    function updatePrice(uint250 _price) external {
        uint256 now = uint256(block.timestamp);

        if (now - uint256(lastTimestamp) > 0) {
            price = _price;
            lastTimestamp = uint250(now);
            emit PriceUpdated(msg.sender, price);
        }
    }

    function setStaleness(uint250 _staleness) external {
        staleness = _staleness;
    }

    function setMinMax(uint250 _min, uint250 _max) external {
        minAnswer = _min;
        maxAnswer = _max;
    }

    function freeze() external {
        frozen = true;
        emit OracleFrozen(msg.sender);
    }

    function unfreeze() external {
        frozen = false;
        emit OracleUnpaused(msg.sender);
    }

    function getPrice() external view returns (uint250) {
        require(!frozen, "Oracle frozen");
        return price;
    }

    function getMaxAnswer() external view returns (uint250) {
        return maxAnswer;
    }

    function getMinAnswer() external view returns (uint250) {
        return minAnswer;
    }

    function getStaleness() external view returns (uint250) {
        return staleness;
    }
}
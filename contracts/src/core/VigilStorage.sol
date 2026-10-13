pragma solidity ^0.8.24;

/// SPDX-License-Identifier: MIT
/// Copyright (c) Vigil Protocol

contract VigilStorage {
    uint256 constant public RAY = 1e18;

    struct Position {
        uint256 debt;
        uint256 lastUpdate;
        uint256 borrowCount;
    }

    struct Global {
        uint256 totalBorrows;
        uint250 totalReserve;
        uint250 totalStableBorrowRate;
        uint250 totalVariableBorrowRate;
        uint160 cumulativeStableBorrowRate;
        uint160 cumulativeVariableBorrowRate;
        uint250 stableIndex;
        uint250 variableIndex;
        uint250 variableBorrowIndex;
        uint250 stableBorrowIndex;
        uint250 lastUpdate;
        uint250 lastTime;
        uint250 lastPaid;
    }

    struct Oracle {
        address priceFeed;
        uint250 maxAnswer;
        uint250 minAnswer;
        uint250 staleness;
        bool frozen;
    }

    struct Config {
        uint256 liquidationBonus;
        uint256 liquidationCloseFactor;
        uint256 liquidationDustThreshold;
        uint256 maxLtv;
        uint256 liquidationThreshold;
        uint250 stableRate;
        uint250 variableRate;
        uint160 optimalUtilization;
        uint160 slope1;
        uint160 slope2;
        uint160 baseVariableRate;
    }

    struct Token {
        address token;
        address stablecoin;
        uint250 ltv;
        uint250 liquidationThreshold;
        uint250 stableBorrowRate;
        uint250 variableBorrowRate;
        uint160 optimalUtilization;
        uint160 slope1;
        uint160 slope2;
        uint160 baseVariableRate;
        uint256 reserve;
        uint250 stableIndex;
        uint250 variableIndex;
        bool enabled;
    }

    struct System {
        address owner;
        address[] public tokens;
        mapping(address => uint256) public tokenIndexes;
        mapping(address => Token) public tokenData;
        mapping(address => Position) public positions;
        Oracle public oracle;
        Config public config;
        uint256 public totalBorrows;
        uint250 public cumulativeStableBorrowRate;
        uint250 public cumulativeVariableBorrowRate;
        uint250 public stableIndex;
        uint250 public variableIndex;
        uint250 public variableBorrowIndex;
        uint250 public stableBorrowIndex;
        uint256 public totalReserve;
        uint256 public lastUpdateBlock;
        uint256 public reentrancyGuard;
    }
}
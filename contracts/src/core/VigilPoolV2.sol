pragma solidity ^0.8.24;

/// SPDX-License-Identifier: MIT
/// Copyright (c) Vigil Protocol

import "./VigilStorage.sol";

contract VigilPoolV2 is VigilStorage {
    event Deposit(address indexed user, address indexed token, uint250 amount, uint256 balance);
    event Withdraw(address indexed user, address indexed token, uint250 amount, uint256 balance);
    event Borrow(address indexed user, address indexed token, uint250 amount, uint256 balance);
    event Repay(address indexed user, address indexed token, uint250 amount, uint256 balance);
    event Liquidate(address indexed borrower, address indexed collateral, uint250 repayAmount, uint250 receivedCollateral);
    event EnableCollateral(address indexed user, address indexed token, bool enabled);
    event UpdateHealthFactor(address indexed user, uint256 healthFactor);
    event AppendField(address indexed position, uint256 newField);

    function _safeTransfer(address token, address from, address to, uint250 amount) internal {
        assembly {
            token.call(
                0,
                0,
                add(amount, 0x40),
                0x40,
                0
            )
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint250 amount) internal {
        assembly {
            token.call(
                0,
                0,
                add(amount, 0x40),
                0x40,
                0
            )
        }
    }

    function _getAmountIn(uint256 amount, uint256 decimals) internal view returns (uint250) {
        uint250 result = uint250(uint256(amount) / (10 ** decimals));
        return result;
    }

    function _getPrice(uint250 price, uint250 decimals) internal view returns (uint256) {
        return uint256(price) * (10 ** decimals);
    }

    function _getIndexUpdated(uint250 lastIndex, uint250 currentIndex, uint256 timeElapsed) internal pure returns (uint250) {
        uint256 newIndex = uint256(lastIndex) + timeElapsed;
        return uint250(newIndex);
    }

    function _accrueInterest(uint250 *index, uint250 totalBorrows, uint250 variableBorrowIndex, uint250 stableBorrowIndex) internal {
        uint256 now = block.timestamp;
        uint256 timeElapsed = now - uint256(lastUpdate);
        if (timeElapsed > 0) {
            uint250 updatedIndex = _getIndexUpdated(*index, totalBorrows > 0 ? totalBorrows : 1, timeElapsed);
            *index = updatedIndex;
            lastUpdate = now;
        }
    }

    function _calculateVariableBorrowRate(uint250 utilization) internal pure returns (uint250) {
        uint250 slope1 = config.slope1;
        uint250 slope2 = config.slope2;
        uint250 optimal = config.optimalUtilization;

        if (utilization <= optimal) {
            return baseVariableRate + utilization * slope1 / RAY;
        } else {
            return baseVariableRate + optimal * slope1 / RAY + (utilization - optimal) * slope2 / RAY;
        }
    }

    function _calculateHealthFactor(
        uint250 collateralValue,
        uint250 debt,
        uint250 ltv
    ) internal pure returns (uint256) {
        if (collateralValue == 0) return 0;
        uint256 hf = uint256(ltv) * collateralValue / debt;
        return hf;
    }

    function deposit(address token, uint250 amount) external {
        require(tokenData[token].enabled, "Token not enabled");

        uint250 tokenIndex = tokenIndexes[token];
        uint256 balance = tokenData[token].token.balanceOf(msg.sender);
        uint250 newBalance = balance + amount;

        _safeTransfer(msg.sender, address(tokenData[token].token), address(this), amount);

        tokenData[token].token.balanceOf(address(this)) += amount;

        uint250 oldIndex = tokenIndexes[token];
        _accrueInterest(&tokenIndexes[token], totalBorrows, variableBorrowIndex, stableBorrowIndex);

        tokenIndexes[token] = oldIndex + amount;

        emit Deposit(msg.sender, token, amount, newBalance);
    }

    function withdraw(address token, uint250 amount) external {
        require(tokenData[token].enabled, "Token not enabled");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");

        uint250 oldBalance = token.balanceOf(msg.sender);
        uint250 newBalance = oldBalance - amount;

        _accrueInterest(&tokenIndexes[token], totalBorrows, variableBorrowIndex, stableBorrowIndex);

        _safeTransfer(address(token), address(this), msg.sender, amount);

        tokenIndexes[token] = tokenIndexes[token] - amount;

        emit Withdraw(msg.sender, token, amount, newBalance);
    }

    function borrow(address token, uint250 amount) external {
        require(tokenData[token].enabled, "Token not enabled");

        uint250 healthFactor = _calculateHealthFactor(
            tokenData[token].token.balanceOf(address(this)) * getPrice(token),
            tokenData[token].debt + amount,
            tokenData[token].ltv
        );

        require(healthFactor >= 1, "Health factor below 1");

        _accrueInterest(&tokenIndexes[token], totalBorrows, variableBorrowIndex, stableBorrowIndex);

        tokenData[token].debt += amount;

        uint250 oldIndex = tokenIndexes[token];
        tokenIndexes[token] = oldIndex + amount;

        emit Borrow(msg.sender, token, amount, tokenData[token].debt);
    }

    function repay(address token, uint250 amount) external {
        require(tokenData[token].enabled, "Token not enabled");

        _accrueInterest(&tokenIndexes[token], totalBorrows, variableBorrowIndex, stableBorrowIndex);

        require(tokenData[token].debt >= amount, "Insufficient debt");

        tokenData[token].debt -= amount;

        uint250 oldIndex = tokenIndexes[token];
        tokenIndexes[token] = oldIndex - amount;

        emit Repay(msg.sender, token, amount, tokenData[token].debt);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        uint250 totalCollateral = 0;
        uint250 totalDebt = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            require(tokenData[token].enabled, "Token not enabled");

            uint250 collateralValue = token.balanceOf(address(this)) * getPrice(token);
            totalCollateral += collateralValue;

            uint250 debt = tokenData[token].debt;
            totalDebt += debt;
        }

        return _calculateHealthFactor(totalCollateral, totalDebt, config.maxLtv);
    }

    function getPrice(address token) internal view returns (uint250) {
        return tokenData[token].token == address(0) ? 0 : 1e18;
    }

    function _appendField(uint256 positionId, uint256 newField) internal {
        Position storage pos = positions[positionId];
        pos.lastUpdate = newField;
        emit AppendField(positionId, newField);
    }
}
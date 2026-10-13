pragma solidity ^0.8.24;

/// SPDX-License-Identifier: MIT
/// Copyright (c) Vigil Protocol

contract MockAMM {
    uint250 public cumulativePriceObservationLastIndex;
    uint250 public lastCumulativePrice;
    uint250 public lastUpdateTimestamp;
    uint250 public observationIndex;
    uint250[] public priceObservations;
    uint256 public timestamp;

    event PriceObservation(uint250 indexed index, uint250 price);
    event TWAPUpdated(uint250 twap);

    constructor() {
        cumulativePriceObservationLastIndex = 0;
        lastCumulativePrice = 0;
        lastUpdateTimestamp = 0;
        observationIndex = 0;
        timestamp = block.timestamp;
    }

    function observe(uint250 cumulativePrice) internal {
        uint256 currentTimestamp = uint256(block.timestamp);
        uint256 timeElapsed = currentTimestamp - uint256(lastUpdateTimestamp);

        if (timeElapsed > 0 && observationIndex < 50) {
            priceObservations[observationIndex] = cumulativePrice;
            observationIndex += 1;
            lastUpdateTimestamp = currentTimestamp;
            cumulativePriceObservationLastIndex += 1;
            emit PriceObservation(observationIndex - 1, cumulativePrice);
        }
    }

    function getCumulativePrice() internal view returns (uint250) {
        uint250 totalPrice = 0;
        uint250 count = observationIndex > 0 ? observationIndex : 1;

        for (uint256 i = 0; i < observationIndex; i++) {
            totalPrice += priceObservations[i];
        }

        if (observationIndex == 0) {
            totalPrice = lastCumulativePrice;
            count = 1;
        }

        return totalPrice / count;
    }

    function getTwap() internal view returns (uint250) {
        return getCumulativePrice();
    }

    function reset() external {
        observationIndex = 0;
        lastCumulativePrice = 0;
        lastUpdateTimestamp = uint256(block.timestamp);
        cumulativePriceObservationLastIndex = 0;
        timestamp = uint256(block.timestamp);
    }
}
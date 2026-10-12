pragma solidity ^0.8.24;

library InterestRateModel {
    uint256 constant public OPTIMAL_UTILIZATION_RATE = 800;
    uint256 constant public BASE_RATE = 100;
    uint256 constant public PEAK_RATE = 2000;
    uint256 constant public KINK_SLOPE = 200;
    uint256 constant public BASE_SLOPE = 50;

    function getBaseRate(uint256 utilization) internal pure returns (uint256) {
        return BASE_RATE;
    }

    function getKinkRate(uint256 utilization) internal pure returns (uint256) {
        return BASE_RATE + (utilization * KINK_SLOPE) / OPTIMAL_UTILIZATION_RATE;
    }

    function getRate(uint256 utilization) internal pure returns (uint256) {
        if (utilization <= OPTIMAL_UTILIZATION_RATE) {
            return getBaseRate(utilization);
        } else {
            return getKinkRate(utilization);
        }
    }
}
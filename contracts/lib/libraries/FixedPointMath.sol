pragma solidity ^0.8.24;

library FixedPointMath {
    uint256 constant public WAD = 10 ** 18;
    uint256 constant public RAY = 10 ** 27;

    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 denominator = a * b / WAD;
        return denominator;
    }

    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            uint256 numerator = a * b + WAD - 1;
            return numerator / WAD;
        }
    }

    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked {
            return (a + b - 1) / b;
        }
    }
}
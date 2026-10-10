// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title FixedPointMath library
 * @notice Fixed-point math with WAD (1e18) and RAY (1e27) precision.
 * @dev All operations use deterministic rounding:
 * - mulDown: rounds down (deposits favor protocol)
 * - mulUp: rounds up (debt favors protocol)
 * - Taylor compounding uses 3-term approximation of (1+r)^t
 */
library FixedPointMath {
    // --- Constants ---
    uint256 internal constant WAD = 1e18;
    uint256 internal constant RAY = 1e27;

    // --- Multiplication & Division ---

    /**
     * @dev Multiply a * b, round down to nearest WAD.
     * Used for deposit accounting (protocol favors, rounds down).
     * Solidity's native division truncates toward zero, which for positive
     * numbers gives floor - the desired rounding direction.
     */
    function mulDown(uint256 a, uint256 b) internal pure returns (uint256) {
        // a * b / RAY - solidity div truncates toward zero = floor for positives
        return a * b / RAY;
    }

    /**
     * @dev Multiply a * b, round up to nearest WAD.
     * Used for debt accounting (protocol favors, rounds up).
     * Equivalent to: (a * b + RAY - 1) / RAY
     */
    function mulUp(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a * b + RAY - 1) / RAY gives ceil for positive numbers
        // RAY - 1 ensures we round up even if the product is exact
        return (a * b + RAY - 1) / RAY;
    }

    /**
     * @dev Divide a / b, round down to nearest WAD.
     * Solidity division of positive numbers truncates toward zero = floor.
     */
    function divDown(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "Division by zero");
        return a / b;
    }

    /**
     * @dev Divide a / b, round up to nearest WAD.
     * Equivalent to: (a + b - 1) / b for positive integers.
     */
    function divUp(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "Division by zero");
        // ceil(a / b) = (a + b - 1) / b
        return (a + b - 1) / b;
    }

    // --- Taylor Compounding (3-term approximation) ---

    /**
     * @dev Compute (1+r)^t using 3-term Taylor approximation around t=0.
     * @param r Interest rate in RAY precision (1 ray = 1e27)
     * @param t Time in seconds
     * @return Approximation of (1+r)^t in RAY precision
     * @dev Formula: 1 + r*t + r^2*t*(t-1)/2
     * - All multiplication uses mulDown/mulUp for deterministic rounding
     * - Result is in RAY precision (same as input r)
     * - This is a Taylor series approximation, exact would use exponentiation
     */
    function taylorCompounding(uint256 r, uint256 t) internal pure returns (uint256) {
        // 3-term Taylor: (1+r)^t ≈ 1 + r*t + r^2*t*(t-1)/2
        // We compute in RAY precision and return in RAY

        // First term: r * t
        uint256 rt = mulDown(r, t);

        // Second term: r * r * t * (t - 1) / 2
        uint256 r2 = mulDown(r, r);  // r^2, rounds down

        // t * (t - 1) - safe since t >= 1 for compounding to make sense
        uint256 tm1 = t > 0 ? t - 1 : 0;

        // r2 * t * (t-1) / 2
        // Order matters for rounding: we use mulDown throughout = protocol favors
        uint256 intermediate = mulDown(r2, t);  // r2 * t
        uint256 final = mulDown(intermediate, tm1);  // r2 * t * (t-1)
        // Divide by 2 - divDown gives floor, which for even numbers is exact
        // For odd numbers, rounding down is protocol-favoring
        if (final > 1) {
            final = divDown(final, 2);
        }

        // Sum: RAY (which is 1 in RAY prec) + rt + r2t(t-1)/2
        // All values are in RAY precision
        uint256 result = RAY + rt + final;

        return result;
    }

    // --- Helper: Safe addition with overflow check ---

    /**
     * @dev Add a + b with overflow check.
     * Reverts if a + b > 2^256 - 1.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity 0.8+ automatically reverts on uint256 addition overflow
        return a + b;
    }

    // --- Helper: Safe subtraction with underflow check ---

    /**
     * @dev Subtract b from a with underflow check.
     * Reverts if a < b.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity 0.8+ automatically reverts on uint256 subtraction underflow
        require(a >= b, "Subtraction underflow");
        return a - b;
    }
}
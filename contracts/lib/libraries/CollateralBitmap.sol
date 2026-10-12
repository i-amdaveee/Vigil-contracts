pragma solidity ^0.8.24;

library CollateralBitmap {
    // Bitmap stored as array of uint256 words (each word = 256 bits)
    function setBit(uint256[] memory bitmap, uint256 index) internal pure returns (uint256[] memory) {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        require(wordIndex < bitmap.length, "CollateralBitmap: index out of bounds");
        bitmap[wordIndex] = bitmap[wordIndex] | (1 << bitIndex);
        return bitmap;
    }

    function clearBit(uint256[] memory bitmap, uint256 index) internal pure returns (uint256[] memory) {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        require(wordIndex < bitmap.length, "CollateralBitmap: index out of bounds");
        bitmap[wordIndex] = bitmap[wordIndex] & ~(1 << bitIndex);
        return bitmap;
    }

    function isCollateral(uint256[] memory bitmap, uint256 index) internal pure returns (bool) {
        uint256 wordIndex = index / 256;
        uint256 bitIndex = index % 256;
        require(wordIndex < bitmap.length, "CollateralBitmap: index out of bounds");
        return (bitmap[wordIndex] & (1 << bitIndex)) != 0;
    }

    function iterateCollateral(uint256[] memory bitmap, uint256 startIndex) internal pure returns (uint256) {
        uint256 wordIndex = startIndex / 256;
        require(wordIndex < bitmap.length, "CollateralBitmap: index out of bounds");
        for (uint256 i = wordIndex; i < bitmap.length; i++) {
            if (bitmap[i] > 0) {
                return i * 256;
            }
        }
        return 0;
    }
}

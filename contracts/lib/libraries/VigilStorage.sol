pragma solidity ^0.8.24;

library VigilStorage {
    bytes32 constant public POOL_NAMESPACE = 0x0000000000000000000000000000000000000000000000000000000000000001;
    bytes32 constant public INTEREST_RATE_NAMESPACE = 0x0000000000000000000000000000000000000000000000000000000000000002;
    bytes32 constant public COLLATERAL_BITMAP_NAMESPACE = 0x0000000000000000000000000000000000000000000000000000000000000003;
    bytes32 constant public POOL_STATE_NAMESPACE = 0x0000000000000000000000000000000000000000000000000000000000000004;

    struct PoolState {
        bool paused;
        mapping(address => bool) isCollateral;
        mapping(address => uint256) userDeposits;
        mapping(address => uint256) userBorrows;
        mapping(address => uint256) userAccruedInterest;
    }
}
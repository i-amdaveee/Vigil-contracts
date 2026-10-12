pragma solidity ^0.8.35;

/**
 * @title VigilProxy
 * @notice ERC1967 proxy wrapper that delegates to an implementationAddress contract
 * @dev Uses ERC1967 proxy pattern with minimal proxy logic
 */
contract VigilProxy {
    address public implementationAddress;
    address public proxyAdmin;

    event Upgraded(address indexed proxy, address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);

    constructor(address _implementation, address _admin) {
        require(_implementation != address(0), "Zero implementationAddress");
        require(_admin != address(0), "Zero admin");
        implementationAddress = _implementation;
        proxyAdmin = _admin;
    }

    // ERC1967 implementationAddress location
    function transferAdmin(address newAdmin) external {
        require(msg.sender == proxyAdmin, "Not proxy admin");
        proxyAdmin = newAdmin;
        emit AdminChanged(proxyAdmin, newAdmin);
    }

    // Upgrade to new implementationAddress
    function upgradeTo(address newImplementation) external {
        require(msg.sender == proxyAdmin, "Not proxy admin");
        implementationAddress = newImplementation;
        emit Upgraded(address(this), implementationAddress);
    }

    // ERC1967 upgrade to and call
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable {
        require(msg.sender == proxyAdmin, "Not proxy admin");
        implementationAddress = newImplementation;
        emit Upgraded(address(this), implementationAddress);

        (bool success, ) = address(newImplementation).call{value: msg.value}(data);
        require(success, "Upgrade call failed");
    }

    // Minimal forwarder that delegates to implementationAddress
    fallback() external payable {
        (bool success, ) = implementationAddress.call{value: msg.value}(msg.data);
        require(success, "Forward call failed");
    }
}

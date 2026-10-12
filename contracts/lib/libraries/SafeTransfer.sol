pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library SafeTransfer {
    function safeTransfer(IERC20 token, address recipient, uint256 amount) internal {
        (bool success, ) = address(token).call(abi.encode(recipient, amount));
        require(success, "SafeTransfer: ERC20 transfer failed");
    }

    function safeTransferFrom(
        IERC20 token,
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        (bool success, ) = address(token).call(abi.encodePacked(sender, recipient, amount));
        require(success, "SafeTransfer: ERC20 transfer failed");
    }

    function safeTransferETH(address recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "SafeTransfer: ETH transfer failed");
    }
}

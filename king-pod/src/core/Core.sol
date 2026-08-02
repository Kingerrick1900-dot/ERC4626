// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
}

library SafeTransfer {
    function safeTransfer(IERC20 t, address to, uint256 amt) internal {
        (bool ok, bytes memory data) = address(t).call(abi.encodeWithSelector(t.transfer.selector, to, amt));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER");
    }

    function safeTransferFrom(IERC20 t, address from, address to, uint256 amt) internal {
        (bool ok, bytes memory data) = address(t).call(abi.encodeWithSelector(t.transferFrom.selector, from, to, amt));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "TRANSFER_FROM");
    }

    function safeApprove(IERC20 t, address spender, uint256 amt) internal {
        (bool ok, bytes memory data) = address(t).call(abi.encodeWithSelector(t.approve.selector, spender, amt));
        require(ok && (data.length == 0 || abi.decode(data, (bool))), "APPROVE");
    }
}

abstract contract ReentrancyGuard {
    uint256 private _status = 1;
    modifier nonReentrant() {
        require(_status == 1, "REENTRANT");
        _status = 2;
        _;
        _status = 1;
    }
}

abstract contract Ownable {
    address public owner;
    error NotOwner();
    constructor(address o) {
        owner = o;
    }
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }
    function transferOwnership(address n) external onlyOwner {
        require(n != address(0), "ZERO");
        owner = n;
    }
}

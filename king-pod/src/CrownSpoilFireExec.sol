// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable, ReentrancyGuard} from "./lib/Core.sol";

interface IHuntRouterFire {
    function hunt(
        address token,
        uint256 assets,
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata datas,
        uint256 tipErc20
    ) external payable;

    function killSwitch() external view returns (bool);
}

/// @title CrownSpoilFireExec
/// @notice Execution trigger for armed hunt bots — fire() pulses HuntRouter; tips → gasSafe/HOT.
/// @dev Replaces missing fire() on legacy SpoilFire bytecode. King-only.
contract CrownSpoilFireExec is Ownable, ReentrancyGuard {
    IHuntRouterFire public immutable router;
    address public immutable hot;
    address public immutable usdc;
    address public immutable weth;
    address public immutable cbbtc;

    uint256 public usdcPulse = 1e6; // $1
    uint256 public wethPulse = 1e16; // 0.01
    uint256 public cbbtcPulse = 1e5; // 0.001
    uint256 public totalFires;

    event Fired(address indexed caller, uint256 n, uint256 ethTip);
    event PulseSet(address indexed token, uint256 amt);

    error Auth();
    error Killed();
    error Bad();

    modifier onlyHot() {
        if (msg.sender != owner && msg.sender != hot) revert Auth();
        _;
    }

    constructor(
        address router_,
        address hot_,
        address usdc_,
        address weth_,
        address cbbtc_,
        address owner_
    ) Ownable(owner_) {
        router = IHuntRouterFire(router_);
        hot = hot_;
        usdc = usdc_;
        weth = weth_;
        cbbtc = cbbtc_;
    }

    receive() external payable {}

    function setPulses(uint256 usdc_, uint256 weth_, uint256 cbbtc_) external onlyOwner {
        usdcPulse = usdc_;
        wethPulse = weth_;
        cbbtcPulse = cbbtc_;
        emit PulseSet(usdc, usdc_);
        emit PulseSet(weth, weth_);
        emit PulseSet(cbbtc, cbbtc_);
    }

    /// @notice Execution trigger — pulses HuntRouter for USDC / WETH / cbBTC. Payable tip optional.
    function fire() external payable onlyHot nonReentrant {
        if (router.killSwitch()) revert Killed();
        address[] memory t;
        uint256[] memory v;
        bytes[] memory d;
        uint256 n;
        if (usdcPulse > 0) {
            router.hunt(usdc, usdcPulse, t, v, d, 0);
            unchecked {
                ++n;
            }
        }
        if (wethPulse > 0) {
            router.hunt(weth, wethPulse, t, v, d, 0);
            unchecked {
                ++n;
            }
        }
        if (cbbtcPulse > 0) {
            router.hunt(cbbtc, cbbtcPulse, t, v, d, 0);
            unchecked {
                ++n;
            }
        }
        if (n == 0) revert Bad();
        totalFires += 1;
        if (msg.value > 0) {
            (bool ok,) = hot.call{value: msg.value}("");
            require(ok, "TIP");
        }
        emit Fired(msg.sender, n, msg.value);
    }

    /// @notice Single-asset fire (named hunt).
    function fireToken(address token, uint256 assets) external payable onlyHot nonReentrant {
        if (router.killSwitch()) revert Killed();
        if (token == address(0) || assets == 0) revert Bad();
        address[] memory t;
        uint256[] memory v;
        bytes[] memory d;
        router.hunt(token, assets, t, v, d, 0);
        totalFires += 1;
        if (msg.value > 0) {
            (bool ok,) = hot.call{value: msg.value}("");
            require(ok, "TIP");
        }
        emit Fired(msg.sender, 1, msg.value);
    }
}

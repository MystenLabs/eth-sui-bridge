// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBridgeLimiter.sol";

contract BridgeLimiter is IBridgeLimiter, Ownable {
    /* ========== STATE VARIABLES ========== */

    uint256 private _resetTimestamp;
    // token id => total amount bridged (on a given day)
    mapping(uint8 => uint256) public totalAmountBridged;
    // token id => daily bridge limit
    mapping(uint8 => uint256) public dailyBridgeLimit;

    /* ========== INITIALIZER ========== */

    constructor(uint256 _nextResetTimestamp, uint256[] memory _dailyBridgeLimits) {
        require(
            _nextResetTimestamp > block.timestamp,
            "SuiBridge: reset timestamp must be in the future"
        );

        for (uint8 i = 0; i < _dailyBridgeLimits.length; i++) {
            // skip 0 for SUI
            dailyBridgeLimit[i + 1] = _dailyBridgeLimits[i];
        }
        _resetTimestamp = _nextResetTimestamp;
    }

    /* ========== VIEW FUNCTIONS ========== */

    function willAmountExceedLimit(uint8 tokenId, uint256 amount)
        public
        view
        override
        returns (bool)
    {
        return getDailyAmountBridged(tokenId) + amount > dailyBridgeLimit[tokenId];
    }

    function getDailyAmountBridged(uint8 tokenId) public view returns (uint256) {
        // if time has expired but not yet updated, no funds have been bridged
        if (block.timestamp >= _resetTimestamp) {
            return 0;
        }
        return totalAmountBridged[tokenId];
    }

    function resetTimestamp() public view returns (uint256) {
        if (block.timestamp >= _resetTimestamp) {
            // Calculate the difference between the current timestamp and the previous daily limit timestamp
            uint256 timeDifference = block.timestamp - _resetTimestamp;
            // Calculate the next daily limit timestamp while preserving the time of day
            return block.timestamp + (1 days - (timeDifference % 1 days));
        }
        return _resetTimestamp;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function updateDailyAmountBridged(uint8 tokenId, uint256 amount) public override onlyOwner {
        uint256 nextResetTimestamp = resetTimestamp();
        // if time to reset
        if (nextResetTimestamp != _resetTimestamp) {
            _resetTimestamp = nextResetTimestamp;
            // reset the daily amount bridged
            totalAmountBridged[tokenId] = amount;
            return;
        }
        // update the daily amount bridged
        totalAmountBridged[tokenId] += amount;
    }
}

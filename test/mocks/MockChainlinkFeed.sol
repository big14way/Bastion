// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract MockChainlinkFeed is AggregatorV3Interface {
    uint8 private _decimals;
    int256 private price;
    uint80 private roundId;

    constructor(uint8 decimals_, int256 initialPrice) {
        _decimals = decimals_;
        price = initialPrice;
        roundId = 1;
    }

    function updatePrice(int256 newPrice) external {
        price = newPrice;
        roundId++;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function description() external pure override returns (string memory) {
        return "Mock Chainlink Feed";
    }

    function version() external pure override returns (uint256) {
        return 1;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (_roundId, price, block.timestamp, block.timestamp, _roundId);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return (roundId, price, block.timestamp, block.timestamp, roundId);
    }

    function latestAnswer() external view returns (int256) {
        return price;
    }
}

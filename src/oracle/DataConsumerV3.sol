// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title DataConsumerV3
 * @dev A simple oracle consumer for ETH/USD price data
 * This is a placeholder implementation for the Circle Paymaster integration
 */
contract DataConsumerV3 {
    // Fixed price for demonstration (ETH/USD = $3000)
    // In production, this would connect to Chainlink or another oracle
    uint256 private constant FIXED_ETH_USD_PRICE = 3000 * 1e8; // 8 decimals

    /**
     * @dev Returns the latest ETH/USD price
     * @return The price in USD with 8 decimal places
     */
    function getLatestPrice() external pure returns (int256) {
        return int256(FIXED_ETH_USD_PRICE);
    }

    /**
     * @dev Returns price data with metadata
     * @return roundId The round ID
     * @return price The price in USD
     * @return startedAt When the round started
     * @return updatedAt When the round was updated
     * @return answeredInRound The round in which the answer was computed
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 price, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (
            1, // roundId
            int256(FIXED_ETH_USD_PRICE), // price
            block.timestamp, // startedAt
            block.timestamp, // updatedAt
            1 // answeredInRound
        );
    }

    /**
     * @dev Returns the latest answer from the Chainlink data feed
     * @return The latest price answer
     */
    function getChainlinkDataFeedLatestAnswer() external pure returns (int256) {
        return int256(FIXED_ETH_USD_PRICE);
    }
}

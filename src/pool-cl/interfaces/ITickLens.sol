// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {PoolId} from "infinity-core/src/types/PoolId.sol";

/// @title Tick Lens
/// @notice Provides functions for fetching chunks of tick data for a pool
/// @dev This avoids the waterfall of fetching the tick bitmap, parsing the bitmap to know which ticks to fetch, and
/// then sending additional multicalls to fetch the tick data
interface ITickLens {
    struct PopulatedTick {
        int24 tick;
        int128 liquidityNet;
        uint128 liquidityGross;
    }

    error PoolNotInitialized();

    /// @notice Get all the tick data for the populated ticks from a word of the tick bitmap of a pool
    /// @param key The PoolKey of the pool for which to fetch populated tick data
    /// @param tickBitmapIndex The index of the word in the tick bitmap for which to parse the bitmap and
    /// fetch all the populated ticks
    /// @return populatedTicks An array of tick data for the given word in the tick bitmap
    function getPopulatedTicksInWord(PoolKey memory key, int16 tickBitmapIndex)
        external
        view
        returns (PopulatedTick[] memory populatedTicks);

    /// @notice Get all the tick data for the populated ticks from a word of the tick bitmap of a pool
    /// @param id The PoolId of the pool for which to fetch populated tick data
    /// @param tickBitmapIndex The index of the word in the tick bitmap for which to parse the bitmap and
    /// fetch all the populated ticks
    /// @return populatedTicks An array of tick data for the given word in the tick bitmap
    function getPopulatedTicksInWord(PoolId id, int16 tickBitmapIndex)
        external
        view
        returns (PopulatedTick[] memory populatedTicks);
}

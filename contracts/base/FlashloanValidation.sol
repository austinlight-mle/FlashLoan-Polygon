// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IFlashloan.sol";

abstract contract FlashloanValidation {
    // A constant representing the maximum number of supported protocols
    uint256 constant MAX_PROTOCOL = 8;

    /**
     * @dev Modifier to ensure that the total part of all routes equals 10000 (representing 100%).
     * @param routes An array of `Route` structs from IFlashloan interface
     * each containing a `part` field.
     * The sum of all `part` fields in the `routes` array must equal 10000.
     */
    modifier checkTotalRoutePart(IFlashloan.Route[] memory routes) {
        uint16 totalPart = 0;

        for (uint256 i = 0; i < uint256(routes.length); i++) {
            totalPart += routes[i].part;
        }

        require(totalPart == 10000, "Total part must be 10000");
        _;
    }
}

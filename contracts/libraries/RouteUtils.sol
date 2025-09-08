// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../interfaces/IFlashloan.sol";

library RouteUtils {
    function getInitialToken(IFlashloan.Route memory route) internal pure returns (address) {
        require(route.hops.length > 0, "Route has no hops");
        require(route.hops[0].path.length > 0, "First hop has no path");
        return route.hops[0].path[0];
    }
}

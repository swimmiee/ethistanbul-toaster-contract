// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface IToasterPoolDeployer {
    function parameters()
        external
        view
        returns (address factory, address pool);
}
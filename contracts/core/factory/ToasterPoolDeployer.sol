// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.7.5;

// import "../../interfaces/IToasterPoolDeployer.sol";
// import "../ToasterPool.sol";

// contract ToasterPoolDeployer is IToasterPoolDeployer {
//     struct Parameters {
//         address factory;
//         address pool;
//     }

//     Parameters public override parameters;

//     /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
//     /// clearing it after deploying the pool.
//     function deploy(
//         address factory,
//         address pool,
//         address zap
//     ) internal returns (address toasterPool) {
//         parameters = Parameters({factory: factory, pool: pool});
//         toasterPool = address(new ToasterPool{salt: keccak256(abi.encode(pool))}(zap));
//         delete parameters;
//     }
// }

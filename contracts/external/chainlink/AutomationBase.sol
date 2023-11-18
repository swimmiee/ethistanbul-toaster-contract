// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

contract AutomationBase {
  // error OnlySimulatedBackend();


  /**
   * @notice method that allows it to be simulated via eth_call by checking that
   * the sender is the zero address.
   */
  function preventExecution() internal view {
    if (tx.origin != address(0)) {
      // revert OnlySimulatedBackend();
      revert ("OnlySimulatedBackend");
    }
  }

  /**
   * @notice modifier that allows it to be simulated via eth_call by checking
   * that the sender is the zero address.
   */
  modifier cannotExecute() {
    preventExecution();
    _;
  }
}
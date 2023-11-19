// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.7.5;

import {Ownable}from "@openzeppelin/contracts/access/Ownable.sol";

import {FunctionsClient,FunctionsRequest }from "../external/chainlink/FunctionClient.sol";
import {AutomationCompatibleInterface} from "../external/chainlink/AutomationCompatibleInterface.sol";

import {Strings}from"@openzeppelin/contracts/utils/Strings.sol";
import {IToasterPool} from "../interfaces/IToasterPool.sol";
import {IToasterStrategy} from "../interfaces/IToasterStrategy.sol";
contract ToasterStrategy is Ownable,FunctionsClient,IToasterStrategy, AutomationCompatibleInterface {
    using FunctionsRequest for FunctionsRequest.Request;
    using Strings for uint256;
    uint32 public gasLimit;
    mapping(address => bytes) public requests;
    mapping(address => uint64) public subscriptionIds;
    mapping(address => bytes32) public donIDs;
    mapping(address => bytes32) public lastRequestIds;
    mapping(address => uint16) public periods;
    mapping(address => uint) public lastBlocks;
    event Response(bytes32 indexed requestId, bytes response, bytes err);
    constructor(address router) FunctionsClient(router) {}
    mapping(address => string) rangeStrategies;
    /*****************
     *** REBALANCE ***
     *****************/
    function checkUpkeep(
        bytes calldata checkData //* toaster address
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        address _toaster = abi.decode(checkData,(address));
        if (lastBlocks[_toaster] + periods[_toaster] > block.number) {
            upkeepNeeded = false;
        } else if (IToasterPool(_toaster).isInRange()) {
            upkeepNeeded = true;
            performData = abi.encode(_toaster,CheckUpState.InRange);
        } else {
            upkeepNeeded = true;
            performData = abi.encode(_toaster,CheckUpState.OutOfRange);
        }
    }

    // locked :    -- unlocked --------------------------------------------- locked ----------------------------------------- unlocked --
    // automaiton: checkUpkeep -> performUpkeep -> requestRebalance |  router: handleOracleFullfillment -> _fulfillRequest -> rebalance
    function performUpkeep(bytes calldata performData) external override {
        (address _toaster,CheckUpState checkUp) = abi.decode(performData, (address,CheckUpState));
        if (checkUp == CheckUpState.InRange) {
            IToasterPool(_toaster).reinvest();
        } else if (checkUp == CheckUpState.OutOfRange && !IToasterPool(_toaster).locked()) {
           _requestRebalance(_toaster);
        } else {
            // not in range and locked -> don't be executed , previous process(1inch limit order or chainlink function fulfill) is not finished
            revert("DON'T BE EXECUTED");
        }
        lastBlocks[_toaster] = block.number;
    }
    function _requestRebalance(address _toaster) internal returns (bytes32 requestId) {
        
        FunctionsRequest.Request memory req;
        address _pool = address(IToasterPool(_toaster).pool());
        req._initializeRequestForInlineJavaScript(rangeStrategies[_toaster]); // Initialize the request with JS code
        string[] memory args = new string[](1);
        args[0] = uint256(_pool).toString();
        req._setArgs(args);
        lastRequestIds[_toaster] = _sendRequest(
            req._encodeCBOR(),
            subscriptionIds[_toaster],
            gasLimit,
            donIDs[_toaster]
        );
        return lastRequestIds[_toaster];
    }
    
    function _fulfillRequest(
        bytes32 requestId,
        bytes memory response, //(int24 tickLower, int24 tickUppe,address toaster)
        bytes memory err
    ) internal override {
        (int24 tickLower, int24 tickUpper,address _toaster) = abi.decode(
            response,
            (int24, int24,address)
        );
        if (lastRequestIds[_toaster] != requestId) {
            revert("Check request id"); // Check if request IDs match
        }
        /*REBALANCE LOGIC USING RESPONSE under 300,000 gas*/

        require(IToasterPool(_toaster).locked(), "NOT LOCKED");

        IToasterPool(_toaster).rebalance(tickLower, tickUpper); // will be unlocked
        emit Response(requestId, response, err);
    }

    /*****************
     ** FOR SETTING **
     *****************/
    function updateRequest(
        address toaster,
        bytes memory _request,
        uint64 _subscriptionId,
        uint32 _gasLimit,
        bytes32 _donID
    ) external onlyOwner {
        gasLimit = _gasLimit;
        requests[toaster] = _request;
        subscriptionIds[toaster] = _subscriptionId;
        donIDs[toaster] = _donID;
    }


    function setRangeStrategy(
        address toaster,
        string memory source
    ) external onlyOwner {
        rangeStrategies[toaster]=source;
    }

    function setPeriod(address toaster, uint16 period) external onlyOwner {
        periods[toaster] = period;
    }
}
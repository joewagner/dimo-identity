//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

/// @notice File to store shared structs

struct AttributeInfoPair {
    string attribute;
    string info;
}

struct AftermarketDeviceInfos {
    address addr;
    AttributeInfoPair[] attrInfoPairs;
}

struct AftermarketDeviceOwnerPair {
    uint256 aftermarketDeviceNodeId;
    address owner;
}

struct MintSyntheticDeviceInput {
    uint256 integrationNode;
    uint256 vehicleNode;
    bytes syntheticDeviceSig;
    bytes vehicleOwnerSig;
    address syntheticDeviceAddr;
    AttributeInfoPair[] attrInfoPairs;
}

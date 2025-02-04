//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "./nodes/VehicleInternal.sol";
import "./nodes/SyntheticDeviceInternal.sol";
import "../interfaces/INFT.sol";
import "../Eip712/Eip712CheckerInternal.sol";
import "../libraries/NodesStorage.sol";
import "../libraries/nodes/ManufacturerStorage.sol";
import "../libraries/nodes/IntegrationStorage.sol";
import "../libraries/nodes/VehicleStorage.sol";
import "../libraries/nodes/SyntheticDeviceStorage.sol";
import "../libraries/MapperStorage.sol";

import "../shared/Roles.sol";

import "@solidstate/contracts/access/access_control/AccessControlInternal.sol";

error DeviceAlreadyRegistered(address addr);
error InvalidSdSignature();

contract MultipleMinter is
    AccessControlInternal,
    VehicleInternal,
    SyntheticDeviceInternal
{
    bytes32 private constant MINT_VEHICLE_SD_TYPEHASH =
        keccak256("MintVehicleAndSdSign(uint256 integrationNode)");

    /**
     * @notice Mints and pairs a vehicle and a synthetic device through a metatransaction
     * The vehicle owner signs a typed structured (EIP-712) message in advance and submits to be verified
     * @dev Caller must have the admin role
     * @param data Input data with the following fields:
     *  manufacturerNode -> Parent manufacturer node id of the vehicle
     *  owner -> The new nodes owner
     *  attrInfoPairsVehicle -> List of attribute-info pairs to be added of the vehicle
     *  integrationNode -> Parent integration node id of the synthetic device
     *  vehicleOwnerSig -> Vehicle owner signature hash
     *  syntheticDeviceSig -> Synthetic Device's signature hash
     *  syntheticDeviceAddr -> Address associated with the synthetic device
     *  attrInfoPairsDevice -> List of attribute-info pairs to be added of the synthetic device
     */
    function mintVehicleAndSdSign(MintVehicleAndSdInput calldata data)
        external
        onlyRole(MINT_VEHICLE_SD_ROLE)
    {
        NodesStorage.Storage storage ns = NodesStorage.getStorage();
        MapperStorage.Storage storage ms = MapperStorage.getStorage();
        SyntheticDeviceStorage.Storage storage sds = SyntheticDeviceStorage
            .getStorage();

        address vehicleIdProxyAddress = VehicleStorage
            .getStorage()
            .idProxyAddress;
        address sdIdProxyAddress = sds.idProxyAddress;

        if (
            !INFT(IntegrationStorage.getStorage().idProxyAddress).exists(
                data.integrationNode
            )
        ) revert InvalidParentNode(data.integrationNode);
        if (
            !INFT(ManufacturerStorage.getStorage().idProxyAddress).exists(
                data.manufacturerNode
            )
        ) revert InvalidParentNode(data.manufacturerNode);
        if (sds.deviceAddressToNodeId[data.syntheticDeviceAddr] != 0)
            revert DeviceAlreadyRegistered(data.syntheticDeviceAddr);

        bytes32 message = keccak256(
            abi.encode(MINT_VEHICLE_SD_TYPEHASH, data.integrationNode)
        );

        if (
            !Eip712CheckerInternal._verifySignature(
                data.syntheticDeviceAddr,
                message,
                data.syntheticDeviceSig
            )
        ) revert InvalidSdSignature();

        uint256 newTokenIdVehicle = INFT(vehicleIdProxyAddress).safeMint(
            data.owner
        );
        uint256 newTokenIdDevice = INFT(sdIdProxyAddress).safeMint(data.owner);

        (bytes32 attributesHash, bytes32 infosHash) = _setInfosHash(
            newTokenIdVehicle,
            data.attrInfoPairsVehicle
        );

        message = keccak256(
            abi.encode(
                MINT_VEHICLE_TYPEHASH,
                data.manufacturerNode,
                data.owner,
                attributesHash,
                infosHash
            )
        );

        if (
            !Eip712CheckerInternal._verifySignature(
                data.owner,
                message,
                data.vehicleOwnerSig
            )
        ) revert InvalidOwnerSignature();

        ns.nodes[vehicleIdProxyAddress][newTokenIdVehicle].parentNode = data
            .manufacturerNode;

        ns.nodes[sdIdProxyAddress][newTokenIdDevice].parentNode = data
            .integrationNode;

        ms.nodeLinks[vehicleIdProxyAddress][sdIdProxyAddress][
            newTokenIdVehicle
        ] = newTokenIdDevice;
        ms.nodeLinks[sdIdProxyAddress][vehicleIdProxyAddress][
            newTokenIdDevice
        ] = newTokenIdVehicle;

        sds.deviceAddressToNodeId[data.syntheticDeviceAddr] = newTokenIdDevice;
        sds.nodeIdToDeviceAddress[newTokenIdDevice] = data.syntheticDeviceAddr;

        if (data.attrInfoPairsDevice.length > 0)
            _setInfos(newTokenIdDevice, data.attrInfoPairsDevice);

        emit VehicleNodeMinted(
            data.manufacturerNode,
            newTokenIdVehicle,
            data.owner
        );

        emit SyntheticDeviceNodeMinted(
            data.integrationNode,
            newTokenIdDevice,
            newTokenIdVehicle,
            data.syntheticDeviceAddr,
            data.owner
        );
    }
}

//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../../interfaces/INFT.sol";
import "../../Eip712/Eip712CheckerInternal.sol";
import "../../libraries/NodesStorage.sol";
import "../../libraries/nodes/ManufacturerStorage.sol";
import "../../libraries/nodes/VehicleStorage.sol";
import "../../libraries/nodes/AftermarketDeviceStorage.sol";
import "../../libraries/MapperStorage.sol";
import "../AdLicenseValidator/AdLicenseValidatorInternal.sol";

import "../../shared/Roles.sol";
import "../../shared/Types.sol";

import "@solidstate/contracts/access/access_control/AccessControlInternal.sol";

/// @title AftermarketDevice
/// @notice Contract that represents the Aftermarket Device node
/// @dev It uses the Mapper contract to link Aftermarket Devices to Vehicles
contract AftermarketDevice is
    AccessControlInternal,
    AdLicenseValidatorInternal
{
    bytes32 private constant CLAIM_TYPEHASH =
        keccak256(
            "ClaimAftermarketDeviceSign(uint256 aftermarketDeviceNode,address owner)"
        );
    bytes32 private constant PAIR_TYPEHASH =
        keccak256(
            "PairAftermarketDeviceSign(uint256 aftermarketDeviceNode,uint256 vehicleNode)"
        );

    bytes32 private constant UNPAIR_TYPEHASH =
        keccak256(
            "UnPairAftermarketDeviceSign(uint256 aftermarketDeviceNode,uint256 vehicleNode)"
        );

    event AftermarketDeviceIdProxySet(address indexed proxy);
    event AftermarketDeviceAttributeAdded(string attribute);
    event AftermarketDeviceAttributeSet(
        uint256 tokenId,
        string attribute,
        string info
    );
    event AftermarketDeviceNodeMinted(
        uint256 tokenId,
        address indexed aftermarketDeviceAddress,
        address indexed owner
    );
    event AftermarketDeviceClaimed(
        uint256 aftermarketDeviceNode,
        address indexed owner
    );

    event AftermarketDevicePaired(
        uint256 aftermarketDeviceNode,
        uint256 vehicleNode,
        address indexed owner
    );

    event AftermarketDeviceUnpaired(
        uint256 aftermarketDeviceNode,
        uint256 vehicleNode,
        address indexed owner
    );

    // ***** Admin management ***** //

    /// @notice Sets the NFT proxy associated with the Aftermarket Device node
    /// @dev Only an admin can set the address
    /// @param addr The address of the proxy
    function setAftermarketDeviceIdProxyAddress(address addr)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(addr != address(0), "Non zero address");
        AftermarketDeviceStorage.getStorage().idProxyAddress = addr;

        emit AftermarketDeviceIdProxySet(addr);
    }

    /// @notice Adds an attribute to the whielist
    /// @dev Only an admin can add a new attribute
    /// @param attribute The attribute to be added
    function addAftermarketDeviceAttribute(string calldata attribute)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            AttributeSet.add(
                AftermarketDeviceStorage.getStorage().whitelistedAttributes,
                attribute
            ),
            "Attribute already exists"
        );

        emit AftermarketDeviceAttributeAdded(attribute);
    }

    // ***** Interaction with nodes *****//

    /// @notice Mints aftermarket devices in batch
    /// @dev Caller must have the manufacturer role
    /// @param adInfos List of attribute-info pairs and addresses associated with the AD to be added
    function mintAftermarketDeviceByManufacturerBatch(
        uint256 manufacturerNode,
        AftermarketDeviceInfos[] calldata adInfos
    ) external onlyRole(MANUFACTURER_ROLE) {
        NodesStorage.Storage storage ns = NodesStorage.getStorage();
        AftermarketDeviceStorage.Storage storage ads = AftermarketDeviceStorage
            .getStorage();
        uint256 devicesAmount = adInfos.length;
        address adIdProxyAddress = ads.idProxyAddress;
        INFT manufacturerIdProxy = INFT(
            ManufacturerStorage.getStorage().idProxyAddress
        );

        require(
            INFT(adIdProxyAddress).isApprovedForAll(msg.sender, address(this)),
            "Registry must be approved for all"
        );
        require(
            manufacturerIdProxy.exists(manufacturerNode),
            "Invalid parent node"
        );
        require(
            manufacturerIdProxy.ownerOf(manufacturerNode) == msg.sender,
            "Caller must be the parent node owner"
        );

        uint256 newTokenId;
        address deviceAddress;

        for (uint256 i = 0; i < devicesAmount; i++) {
            newTokenId = INFT(adIdProxyAddress).safeMint(msg.sender);

            ns
            .nodes[adIdProxyAddress][newTokenId].parentNode = manufacturerNode;

            deviceAddress = adInfos[i].addr;
            require(
                ads.deviceAddressToNodeId[deviceAddress] == 0,
                "Device address already registered"
            );

            ads.deviceAddressToNodeId[deviceAddress] = newTokenId;
            ads.nodeIdToDeviceAddress[newTokenId] = deviceAddress;

            _setInfos(newTokenId, adInfos[i].attrInfoPairs);

            emit AftermarketDeviceNodeMinted(
                newTokenId,
                deviceAddress,
                msg.sender
            );
        }

        // Validate request and transfer funds to foundation
        // This transfer is at the end of the function to prevent reentrancy
        _validateMintRequest(msg.sender, devicesAmount);
    }

    /// @notice Claims the ownership of a list of aftermarket devices to a list of owners
    /// @dev Caller must have the admin role
    /// @dev This contract must be approved to spend the tokens in advance
    /// @param adOwnerPair List of pairs AD-owner
    function claimAftermarketDeviceBatch(
        AftermarketDeviceOwnerPair[] calldata adOwnerPair
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AftermarketDeviceStorage.Storage storage ads = AftermarketDeviceStorage
            .getStorage();
        INFT adIdProxy = INFT(ads.idProxyAddress);

        uint256 aftermarketDeviceNode;
        address owner;
        for (uint256 i = 0; i < adOwnerPair.length; i++) {
            aftermarketDeviceNode = adOwnerPair[i].aftermarketDeviceNodeId;
            owner = adOwnerPair[i].owner;

            require(
                !ads.deviceClaimed[aftermarketDeviceNode],
                "Device already claimed"
            );

            ads.deviceClaimed[aftermarketDeviceNode] = true;
            adIdProxy.safeTransferFrom(
                adIdProxy.ownerOf(aftermarketDeviceNode),
                owner,
                aftermarketDeviceNode
            );

            emit AftermarketDeviceClaimed(aftermarketDeviceNode, owner);
        }
    }

    /// @notice Claims the ownership of an aftermarket device through a metatransaction
    /// The aftermarket device owner signs a typed structured (EIP-712) message in advance and submits to be verified
    /// @dev Caller must have the admin role
    /// @dev This contract must be approved to spend the tokens in advance
    /// @param aftermarketDeviceNode Aftermarket device node id
    /// @param owner The address of the new owner
    /// @param ownerSig User's signature hash
    /// @param aftermarketDeviceSig Aftermarket Device's signature hash
    function claimAftermarketDeviceSign(
        uint256 aftermarketDeviceNode,
        address owner,
        bytes calldata ownerSig,
        bytes calldata aftermarketDeviceSig
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AftermarketDeviceStorage.Storage storage ads = AftermarketDeviceStorage
            .getStorage();
        bytes32 message = keccak256(
            abi.encode(CLAIM_TYPEHASH, aftermarketDeviceNode, owner)
        );
        address aftermarketDeviceAddress = ads.nodeIdToDeviceAddress[
            aftermarketDeviceNode
        ];
        INFT adIdProxy = INFT(ads.idProxyAddress);

        require(adIdProxy.exists(aftermarketDeviceNode), "Invalid AD node");
        require(
            !ads.deviceClaimed[aftermarketDeviceNode],
            "Device already claimed"
        );
        require(
            Eip712CheckerInternal._verifySignature(owner, message, ownerSig),
            "Invalid signature"
        );
        require(
            Eip712CheckerInternal._verifySignature(
                aftermarketDeviceAddress,
                message,
                aftermarketDeviceSig
            ),
            "Invalid signature"
        );

        ads.deviceClaimed[aftermarketDeviceNode] = true;
        adIdProxy.safeTransferFrom(
            adIdProxy.ownerOf(aftermarketDeviceNode),
            owner,
            aftermarketDeviceNode
        );

        emit AftermarketDeviceClaimed(aftermarketDeviceNode, owner);
    }

    /// TODO Documentation
    /// @notice Pairs an aftermarket device with a vehicle through a metatransaction
    /// The aftermarket device owner signs a typed structured (EIP-712) message in advance and submits to be verified
    /// @dev Caller must have the admin role
    /// @param aftermarketDeviceNode Aftermarket device node id
    /// @param vehicleNode Vehicle node id
    /// @param vehicleOwnerSig Vehicle owner signature hash
    /// @param aftermarketDeviceSig Aftermarket Device's signature hash
    /// TODO To be renamed
    function pairAftermarketDeviceSign2(
        uint256 aftermarketDeviceNode,
        uint256 vehicleNode,
        bytes calldata aftermarketDeviceSig,
        bytes calldata vehicleOwnerSig
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        MapperStorage.Storage storage ms = MapperStorage.getStorage();
        bytes32 message = keccak256(
            abi.encode(PAIR_TYPEHASH, aftermarketDeviceNode, vehicleNode)
        );
        address vehicleIdProxyAddress = VehicleStorage
            .getStorage()
            .idProxyAddress;
        address adIdProxyAddress = AftermarketDeviceStorage
            .getStorage()
            .idProxyAddress;

        require(
            INFT(vehicleIdProxyAddress).exists(vehicleNode),
            "Invalid vehicle node"
        );

        require(
            INFT(adIdProxyAddress).exists(aftermarketDeviceNode),
            "Invalid AD node"
        );
        require(
            AftermarketDeviceStorage.getStorage().deviceClaimed[
                aftermarketDeviceNode
            ],
            "AD must be claimed"
        );
        require(
            ms.links[vehicleIdProxyAddress][vehicleNode] == 0,
            "Vehicle already paired"
        );
        require(
            ms.links[adIdProxyAddress][aftermarketDeviceNode] == 0,
            "AD already paired"
        );
        require(
            Eip712CheckerInternal._verifySignature(
                AftermarketDeviceStorage.getStorage().nodeIdToDeviceAddress[
                    aftermarketDeviceNode
                ],
                message,
                aftermarketDeviceSig
            ),
            "Invalid signature"
        );

        address adOwner = INFT(vehicleIdProxyAddress).ownerOf(vehicleNode);

        require(
            Eip712CheckerInternal._verifySignature(
                adOwner,
                message,
                vehicleOwnerSig
            ),
            "Invalid signature"
        );

        ms.links[vehicleIdProxyAddress][vehicleNode] = aftermarketDeviceNode;
        ms.links[adIdProxyAddress][aftermarketDeviceNode] = vehicleNode;

        emit AftermarketDevicePaired(
            aftermarketDeviceNode,
            vehicleNode,
            adOwner
        );
    }

    /// @notice Pairs an aftermarket device with a vehicle through a metatransaction
    /// The aftermarket device owner signs a typed structured (EIP-712) message in advance and submits to be verified
    /// @dev Caller must have the admin role
    /// @param aftermarketDeviceNode Aftermarket device node id
    /// @param vehicleNode Vehicle node id
    /// @param signature User's signature hash
    function pairAftermarketDeviceSign(
        uint256 aftermarketDeviceNode,
        uint256 vehicleNode,
        bytes calldata signature
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        MapperStorage.Storage storage ms = MapperStorage.getStorage();
        bytes32 message = keccak256(
            abi.encode(PAIR_TYPEHASH, aftermarketDeviceNode, vehicleNode)
        );
        address vehicleIdProxyAddress = VehicleStorage
            .getStorage()
            .idProxyAddress;
        address adIdProxyAddress = AftermarketDeviceStorage
            .getStorage()
            .idProxyAddress;

        require(
            INFT(vehicleIdProxyAddress).exists(vehicleNode),
            "Invalid vehicle node"
        );

        address owner = INFT(vehicleIdProxyAddress).ownerOf(vehicleNode);

        require(
            INFT(adIdProxyAddress).exists(aftermarketDeviceNode),
            "Invalid AD node"
        );
        require(
            AftermarketDeviceStorage.getStorage().deviceClaimed[
                aftermarketDeviceNode
            ],
            "AD must be claimed"
        );
        require(
            owner == INFT(adIdProxyAddress).ownerOf(aftermarketDeviceNode),
            "Owner of the nodes does not match"
        );
        require(
            ms.links[vehicleIdProxyAddress][vehicleNode] == 0,
            "Vehicle already paired"
        );
        require(
            ms.links[adIdProxyAddress][aftermarketDeviceNode] == 0,
            "AD already paired"
        );
        require(
            Eip712CheckerInternal._verifySignature(owner, message, signature),
            "Invalid signature"
        );

        ms.links[vehicleIdProxyAddress][vehicleNode] = aftermarketDeviceNode;
        ms.links[adIdProxyAddress][aftermarketDeviceNode] = vehicleNode;

        emit AftermarketDevicePaired(aftermarketDeviceNode, vehicleNode, owner);
    }

    /// @dev Unpairs an aftermarket device from a vehicles through a metatransaction
    /// The aftermarket device owner signs a typed structured (EIP-712) message in advance and submits to be verified
    /// @dev Caller must have the admin role
    /// @param aftermarketDeviceNode Aftermarket device node id
    /// @param vehicleNode Vehicle node id
    /// @param signature User's signature hash
    function unpairAftermarketDeviceSign(
        uint256 aftermarketDeviceNode,
        uint256 vehicleNode,
        bytes calldata signature
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bytes32 message = keccak256(
            abi.encode(UNPAIR_TYPEHASH, aftermarketDeviceNode, vehicleNode)
        );
        MapperStorage.Storage storage ms = MapperStorage.getStorage();
        address vehicleIdProxyAddress = VehicleStorage
            .getStorage()
            .idProxyAddress;
        address adIdProxyAddress = AftermarketDeviceStorage
            .getStorage()
            .idProxyAddress;

        require(
            INFT(vehicleIdProxyAddress).exists(vehicleNode),
            "Invalid vehicle node"
        );
        require(
            INFT(adIdProxyAddress).exists(aftermarketDeviceNode),
            "Invalid AD node"
        );
        require(
            ms.links[vehicleIdProxyAddress][vehicleNode] ==
                aftermarketDeviceNode,
            "Vehicle not paired to AD"
        );
        require(
            ms.links[adIdProxyAddress][aftermarketDeviceNode] == vehicleNode,
            "AD is not paired to vehicle"
        );

        address signer = Eip712CheckerInternal._recover(message, signature);
        address adOwner = INFT(adIdProxyAddress).ownerOf(aftermarketDeviceNode);

        require(
            signer == INFT(vehicleIdProxyAddress).ownerOf(vehicleNode) ||
                signer == adOwner,
            "Invalid signer"
        );

        ms.links[vehicleIdProxyAddress][vehicleNode] = 0;
        ms.links[adIdProxyAddress][aftermarketDeviceNode] = 0;

        emit AftermarketDeviceUnpaired(
            aftermarketDeviceNode,
            vehicleNode,
            adOwner
        );
    }

    /// @notice Add infos to node
    /// @dev attributes must be whitelisted
    /// @param tokenId Node id where the info will be added
    /// @param attrInfo List of attribute-info pairs to be added
    function setAftermarketDeviceInfo(
        uint256 tokenId,
        AttributeInfoPair[] calldata attrInfo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            INFT(AftermarketDeviceStorage.getStorage().idProxyAddress).exists(
                tokenId
            ),
            "Invalid AD node"
        );
        _setInfos(tokenId, attrInfo);
    }

    /// @notice Gets the AD Id by the device address
    /// @dev If the device is not minted it will return 0
    /// @param addr Address associated with the aftermarket device
    function getAftermarketDeviceIdByAddress(address addr)
        external
        view
        returns (uint256 nodeId)
    {
        nodeId = AftermarketDeviceStorage.getStorage().deviceAddressToNodeId[
            addr
        ];
    }

    /// @notice Verifies if AD Id can be transfered
    /// @param aftermarketDeviceNode Aftermarket device node id to be validated
    function verifyAftermarketDeviceTransfer(uint256 aftermarketDeviceNode)
        external
        view
    {
        require(
            MapperStorage.getStorage().links[
                AftermarketDeviceStorage.getStorage().idProxyAddress
            ][aftermarketDeviceNode] == 0,
            "AD must not be paired"
        );
    }

    // ***** PRIVATE FUNCTIONS ***** //

    /// @dev Internal function to add infos to node
    /// @dev attributes must be whitelisted
    /// @param tokenId Node where the info will be added
    /// @param attrInfo List of attribute-info pairs to be added
    function _setInfos(uint256 tokenId, AttributeInfoPair[] calldata attrInfo)
        private
    {
        NodesStorage.Storage storage ns = NodesStorage.getStorage();
        AftermarketDeviceStorage.Storage storage ads = AftermarketDeviceStorage
            .getStorage();
        address idProxyAddress = ads.idProxyAddress;

        for (uint256 i = 0; i < attrInfo.length; i++) {
            require(
                AttributeSet.exists(
                    ads.whitelistedAttributes,
                    attrInfo[i].attribute
                ),
                "Not whitelisted"
            );

            ns.nodes[idProxyAddress][tokenId].info[
                attrInfo[i].attribute
            ] = attrInfo[i].info;

            emit AftermarketDeviceAttributeSet(
                tokenId,
                attrInfo[i].attribute,
                attrInfo[i].info
            );
        }
    }

    /// @dev Internal function to set a single attribute
    /// @dev attribute must be whitelisted
    /// @param tokenId Node where the info will be added
    /// @param attribute Attribute to be updated
    /// @param info Info to be set
    function _setAttributeInfo(
        uint256 tokenId,
        string calldata attribute,
        string calldata info
    ) private {
        NodesStorage.Storage storage ns = NodesStorage.getStorage();
        AftermarketDeviceStorage.Storage storage ads = AftermarketDeviceStorage
            .getStorage();
        require(
            AttributeSet.exists(ads.whitelistedAttributes, attribute),
            "Not whitelisted"
        );
        address idProxyAddress = ads.idProxyAddress;

        ns.nodes[idProxyAddress][tokenId].info[attribute] = info;

        emit AftermarketDeviceAttributeSet(tokenId, attribute, info);
    }
}

//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../../interfaces/INFT.sol";
import "../../access/AccessControlInternal.sol";
import "../../libraries/NodesStorage.sol";
import "../../libraries/nodes/ManufacturerStorage.sol";

import "hardhat/console.sol";

// TODO Documentation
contract ManufacturerNew is AccessControlInternal {
    event ManufacturerNftProxySet(address indexed proxy);
    event ManufacturerAttributeAdded(string attribute);
    event ControllerSet(address indexed controller);
    event ManufacturerNodeMinted(uint256 tokenId);

    // ***** Admin management ***** //

    function setManufacturerNftProxyAddress(address addr)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(addr != address(0), "Non zero address");
        ManufacturerStorage.Storage storage s = ManufacturerStorage
            .getStorage();
        s.nftProxyAddress = addr;

        emit ManufacturerNftProxySet(addr);
    }

    /// @notice Adds an attribute to the whitelist
    /// @dev Only an admin can add a new attribute
    /// @param attribute The attribute to be added
    function addManufacturerAttribute(string calldata attribute)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            AttributeSet.add(
                ManufacturerStorage.getStorage().whitelistedAttributes,
                attribute
            ),
            "Attribute already exists"
        );

        emit ManufacturerAttributeAdded(attribute);
    }

    /// @notice Sets a address controller
    /// @dev Only an admin can set new controllers
    /// @param _controller The address of the controller
    function setController(address _controller)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ManufacturerStorage.Storage storage s = ManufacturerStorage
            .getStorage();
        require(_controller != address(0), "Non zero address");
        require(
            !s.controllers[_controller].isController,
            "Already a controller"
        );

        s.controllers[_controller].isController = true;

        emit ControllerSet(_controller);
    }

    // ***** Interaction with nodes ***** //

    /// @notice Mints manufacturers in batch
    /// @dev Caller must be an admin
    /// @dev It is assumed the 'Name' attribute is whitelisted in advance
    /// @param owner The address of the new owner
    /// @param names List of manufacturer names
    function mintManufacturerBatch(address owner, string[] calldata names)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_hasRole(DEFAULT_ADMIN_ROLE, owner), "Owner must be an admin");

        ManufacturerStorage.Storage storage s = ManufacturerStorage
            .getStorage();
        NodesStorage.Storage storage ns = NodesStorage.getStorage();
        uint256 newTokenId;
        address nftProxyAddress = s.nftProxyAddress;

        for (uint256 i = 0; i < names.length; i++) {
            newTokenId = INFT(s.nftProxyAddress).safeMint(owner);

            ns.nodes2[nftProxyAddress][newTokenId].info["Name"] = names[i];

            emit ManufacturerNodeMinted(newTokenId);
        }
    }

    /// @notice Mints a manufacturer
    /// @dev Caller must be an admin
    /// @param owner The address of the new owner
    /// @param attributes List of attributes to be added
    /// @param infos List of infos matching the attributes param
    function mintManufacturer(
        address owner,
        string[] calldata attributes,
        string[] calldata infos
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ManufacturerStorage.Storage storage s = ManufacturerStorage
            .getStorage();
        require(!s.controllers[owner].manufacturerMinted, "Invalid request");
        s.controllers[owner].isController = true;

        NodesStorage.Storage storage ns = NodesStorage.getStorage();
        uint256 newNodeId = ++ns.currentIndex;
        address nftProxyAddress = s.nftProxyAddress;

        s.controllers[owner].manufacturerMinted = true;

        newNodeId = INFT(nftProxyAddress).safeMint(owner);
        _setInfo(newNodeId, attributes, infos);

        emit ManufacturerNodeMinted(newNodeId);
    }

    /// @notice Add infos to node
    /// @dev attributes and infos arrays length must match
    /// @dev attributes must be whitelisted
    /// @param nodeId Node id where the info will be added
    /// @param attributes List of attributes to be added
    /// @param infos List of infos matching the attributes param
    function setManufacturerInfo(
        uint256 nodeId,
        string[] calldata attributes,
        string[] calldata infos
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        // TODO Check nft id ?
        _setInfo(nodeId, attributes, infos);
    }

    /// @notice Verify if an address is a controller
    /// @param addr the address to be verified
    function isController(address addr)
        external
        view
        returns (bool _isController)
    {
        _isController = ManufacturerStorage
            .getStorage()
            .controllers[addr]
            .isController;
    }

    /// @notice Verify if an address has minted a manufacturer
    /// @param addr the address to be verified
    function isManufacturerMinted(address addr)
        external
        view
        returns (bool _isManufacturerMinted)
    {
        _isManufacturerMinted = ManufacturerStorage
            .getStorage()
            .controllers[addr]
            .manufacturerMinted;
    }

    // ***** PRIVATE FUNCTIONS ***** //

    /// @dev Internal function to add infos to node
    /// @dev attributes and infos arrays length must match
    /// @dev attributes must be whitelisted
    /// @param nodeId Node id where the info will be added
    /// @param attributes List of attributes to be added
    /// @param infos List of infos matching the attributes param
    function _setInfo(
        uint256 nodeId,
        string[] calldata attributes,
        string[] calldata infos
    ) private {
        require(attributes.length == infos.length, "Same length");

        NodesStorage.Storage storage ns = NodesStorage.getStorage();
        ManufacturerStorage.Storage storage s = ManufacturerStorage
            .getStorage();
        address nftProxyAddress = s.nftProxyAddress;

        for (uint256 i = 0; i < attributes.length; i++) {
            require(
                AttributeSet.exists(s.whitelistedAttributes, attributes[i]),
                "Not whitelisted"
            );
            ns.nodes2[nftProxyAddress][nodeId].info[attributes[i]] = infos[i];
        }
    }
}

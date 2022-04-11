//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


// TODO Create tokenId to node label mapping
// TODO Manage node ownership transfer
// TODO Increment token count
contract NodeRegistry is Ownable, ERC721 {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    EnumerableSet.Bytes32Set private whitelistedAttributes;

    struct Record {
        address owner;
        bool subroot;
        mapping(bytes32 => string) info;
    }

    bytes32 private constant ROOT =
        keccak256(abi.encodePacked(uint256(0x0), "dimo"));

    mapping(bytes32 => Record) public records;
    mapping(address => bool) public controllers;

    constructor() ERC721("DIMO Node", "DN") {
        controllers[msg.sender] = true;
        records[ROOT].owner = msg.sender;
        records[ROOT].subroot = true;
    }

    //***** Owner management *****//

    /// @notice Adds an attribute to the whielist
    /// @dev Only the owner can set new controllers
    /// @param attribute The attribute to be added
    function addAttribute(bytes32 attribute) external onlyOwner {
        whitelistedAttributes.add(attribute);
    }

    /// @notice Sets a address controller
    /// @dev Only the owner can set new controllers
    /// @param newController The address of the controller
    function setController(address newController) external onlyOwner {
        controllers[newController] = true;
    }

    //***** Interaction with nodes *****//

    /// @notice Mints a subroot
    /// @param label The label specifying the subroot
    /// @param _owner The address of the new owner
    function mintSubroot(string calldata label, address _owner) external {
        require(controllers[msg.sender], "Only controller");

        bytes32 subroot = _verifyNewNode(ROOT, label);

        records[subroot].owner = _owner;
        records[subroot].subroot = true;

        _safeMint(_owner, 0); // TODO Increment token count
    }

    /// @notice Mints a vehicle
    /// @dev Vehicle owner will be msg.sender
    /// @param parentNode The corresponding subroot
    /// @param label The label specifying the vehicle
    function mintVehicle(bytes32 parentNode, string calldata label) external {
        require(
            records[parentNode].owner != address(0) &&
                records[parentNode].subroot,
            "Invalid node"
        );

        bytes32 node = _verifyNewNode(parentNode, label);

        records[node].owner = msg.sender;

        _safeMint(msg.sender, 0); // TODO Increment token count
    }

    /// @notice Sets a node under a vehicle or other node
    /// @dev Cannot be set under subroots
    /// @param parentNode The corresponding vehicle or node
    /// @param label The label specifying the node
    function setNode(bytes32 parentNode, string calldata label) external {
        require(records[parentNode].owner != msg.sender, "Only node owner");
        require(!records[parentNode].subroot, "Parent cannot be subroot");

        bytes32 node = _verifyNewNode(parentNode, label);

        records[node].owner = msg.sender;
    }

    //***** INTERNAL FUNCTIONS *****//    

    // function _afterTokenTransfer(
    //     address from,
    //     address to,
    //     uint256 tokenId
    // ) internal override {
    //     records[node].owner = to;
    // }

    //***** PRIVATE FUNCTIONS *****//

    /// @dev Calculates and verifies if the new node already exists
    /// @param parentNode The corresponding parent node
    /// @param label The label specifying the node
    /// @return The new hashed node
    function _verifyNewNode(bytes32 parentNode, string memory label)
        private
        view
        returns (bytes32)
    {
        bytes32 newNode = keccak256(
            abi.encodePacked(parentNode, keccak256(abi.encodePacked(label)))
        );
        require(records[newNode].owner == address(0), "Node already exists");

        return newNode;
    }
}

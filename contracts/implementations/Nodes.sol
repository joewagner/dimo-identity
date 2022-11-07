//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "../libraries/NodesStorage.sol";

contract Nodes {
    // TODO To be removed when everything is working
    /// @notice Gets the node type of a node
    /// @param tokenId the id associated to the node
    function getNodeType(uint256 tokenId)
        external
        view
        returns (uint256 nodeType)
    {
        nodeType = NodesStorage.getStorage().nodes[tokenId].nodeType;
    }

    // TODO To be removed when everything is working
    /// @notice Gets the parent node of a node
    /// @param tokenId the id associated to the node
    function getParentNode(uint256 tokenId)
        external
        view
        returns (uint256 parentNode)
    {
        parentNode = NodesStorage.getStorage().nodes[tokenId].parentNode;
    }

    /// @notice Gets the parent node of a node
    /// @param nftProxyAddress The address of the proxy associated with the node Id
    /// @param tokenId the id associated to the node
    function getParentNode2(address nftProxyAddress, uint256 tokenId)
        external
        view
        returns (uint256 parentNode)
    {
        parentNode = NodesStorage
        .getStorage()
        .nodes2[nftProxyAddress][tokenId].parentNode;
    }

    // TODO To be removed when everything is working
    /// @notice Gets information stored in an attribute of a given node
    /// @dev Returns empty string if does or attribute does not exists
    /// @param tokenId Node id from which info will be obtained
    /// @param attribute Key attribute
    /// @return info Info obtained
    function getInfo(uint256 tokenId, string calldata attribute)
        external
        view
        returns (string memory info)
    {
        info = NodesStorage.getStorage().nodes[tokenId].info[attribute];
    }

    /// @notice Gets information stored in an attribute of a given node
    /// @dev Returns empty string if does or attribute does not exists
    /// @param nftProxyAddress The address of the proxy associated with the token Id
    /// @param tokenId Node id from which info will be obtained
    /// @param attribute Key attribute
    /// @return info Info obtained
    function getInfo2(
        address nftProxyAddress,
        uint256 tokenId,
        string calldata attribute
    ) external view returns (string memory info) {
        info = NodesStorage.getStorage().nodes2[nftProxyAddress][tokenId].info[
            attribute
        ];
    }
}

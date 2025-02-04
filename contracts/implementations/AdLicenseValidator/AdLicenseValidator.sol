//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import "../../libraries/AdLicenseValidatorStorage.sol";

import {ADMIN_ROLE} from "../../shared/Roles.sol";

import "@solidstate/contracts/access/access_control/AccessControlInternal.sol";

/**
 * @title AdLicenseValidator
 * @notice Contract with functions to assist in aftermarket device minting
 * @dev Stake contract repository https://github.com/DIMO-Network/dimo-staking-contract-license-nft
 */
contract AdLicenseValidator is AccessControlInternal {
    /**
     * @notice Sets the foundation address
     * @dev Only an admin can set the address
     * @param _foundation The foundation address
     */
    function setFoundationAddress(address _foundation)
        external
        onlyRole(ADMIN_ROLE)
    {
        AdLicenseValidatorStorage.getStorage().foundation = _foundation;
    }

    /**
     * @notice Sets the DIMO token address
     * @dev Only an admin can set the token address
     * @param _dimoToken The DIMO token address
     */
    function setDimoToken(address _dimoToken) external onlyRole(ADMIN_ROLE) {
        AdLicenseValidatorStorage.getStorage().dimoToken = IDimo(_dimoToken);
    }

    /**
     * @notice Sets the License contract address
     * @dev Only an admin can set the license contract address
     * @param _license The License contract address
     */
    function setLicense(address _license) external onlyRole(ADMIN_ROLE) {
        AdLicenseValidatorStorage.getStorage().license = ILicense(_license);
    }

    /**
     * @notice Sets the Aftermarket Device mint cost
     * @dev Only an admin can set the license contract address
     * @param _adMintCost The new cost per mint
     */
    function setAdMintCost(uint256 _adMintCost) external onlyRole(ADMIN_ROLE) {
        AdLicenseValidatorStorage.getStorage().adMintCost = _adMintCost;
    }

    /**
     * @notice Gets the Aftermarket Device mint cost
     * @return adMintCost The cost to mint an Aftermarket Device
     */
    function getAdMintCost() external view returns (uint256 adMintCost) {
        adMintCost = AdLicenseValidatorStorage.getStorage().adMintCost;
    }
}

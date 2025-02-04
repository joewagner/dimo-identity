import chai from 'chai';
import { ethers, waffle } from 'hardhat';

import {
  DIMORegistry,
  Eip712Checker,
  DimoAccessControl,
  Nodes,
  Manufacturer,
  ManufacturerId,
  Integration,
  IntegrationId,
  Vehicle,
  VehicleId,
  SyntheticDevice,
  SyntheticDeviceId,
  Mapper
} from '../../typechain';
import {
  setup,
  grantAdminRoles,
  createSnapshot,
  revertToSnapshot,
  signMessage,
  C
} from '../../utils';

const { expect } = chai;
const provider = waffle.provider;

describe('SyntheticDeviceId', async function () {
  let snapshot: string;
  let dimoRegistryInstance: DIMORegistry;
  let dimoAccessControlInstance: DimoAccessControl;
  let eip712CheckerInstance: Eip712Checker;
  let nodesInstance: Nodes;
  let manufacturerInstance: Manufacturer;
  let integrationInstance: Integration;
  let vehicleInstance: Vehicle;
  let syntheticDeviceInstance: SyntheticDevice;
  let mapperInstance: Mapper;
  let manufacturerIdInstance: ManufacturerId;
  let integrationIdInstance: IntegrationId;
  let vehicleIdInstance: VehicleId;
  let sdIdInstance: SyntheticDeviceId;

  const [
    admin,
    nonAdmin,
    manufacturer1,
    integrationOwner1,
    user1,
    user2,
    sDAddress1
  ] = provider.getWallets();

  before(async () => {
    const deployments = await setup(admin, {
      modules: [
        'Eip712Checker',
        'DimoAccessControl',
        'Nodes',
        'Manufacturer',
        'Integration',
        'Vehicle',
        'SyntheticDevice',
        'Mapper'
      ],
      nfts: [
        'ManufacturerId',
        'IntegrationId',
        'VehicleId',
        'SyntheticDeviceId'
      ],
      upgradeableContracts: []
    });

    dimoRegistryInstance = deployments.DIMORegistry;
    eip712CheckerInstance = deployments.Eip712Checker;
    dimoAccessControlInstance = deployments.DimoAccessControl;
    dimoAccessControlInstance = deployments.DimoAccessControl;
    nodesInstance = deployments.Nodes;
    manufacturerInstance = deployments.Manufacturer;
    integrationInstance = deployments.Integration;
    vehicleInstance = deployments.Vehicle;
    syntheticDeviceInstance = deployments.SyntheticDevice;
    mapperInstance = deployments.Mapper;
    manufacturerIdInstance = deployments.ManufacturerId;
    integrationIdInstance = deployments.IntegrationId;
    vehicleIdInstance = deployments.VehicleId;
    sdIdInstance = deployments.SyntheticDeviceId;

    await grantAdminRoles(admin, dimoAccessControlInstance);

    await manufacturerIdInstance
      .connect(admin)
      .grantRole(C.NFT_MINTER_ROLE, dimoRegistryInstance.address);
    await integrationIdInstance
      .connect(admin)
      .grantRole(C.NFT_MINTER_ROLE, dimoRegistryInstance.address);
    await vehicleIdInstance
      .connect(admin)
      .grantRole(C.NFT_MINTER_ROLE, dimoRegistryInstance.address);
    await sdIdInstance
      .connect(admin)
      .grantRole(C.NFT_MINTER_ROLE, dimoRegistryInstance.address);

    // Set NFT Proxies
    await manufacturerInstance
      .connect(admin)
      .setManufacturerIdProxyAddress(manufacturerIdInstance.address);
    await integrationInstance
      .connect(admin)
      .setIntegrationIdProxyAddress(integrationIdInstance.address);
    await vehicleInstance
      .connect(admin)
      .setVehicleIdProxyAddress(vehicleIdInstance.address);
    await syntheticDeviceInstance
      .connect(admin)
      .setSyntheticDeviceIdProxyAddress(sdIdInstance.address);

    // Initialize EIP-712
    await eip712CheckerInstance.initialize(
      C.defaultDomainName,
      C.defaultDomainVersion
    );

    // Whitelist Manufacturer attributes
    await manufacturerInstance
      .connect(admin)
      .addManufacturerAttribute(C.mockManufacturerAttribute1);
    await manufacturerInstance
      .connect(admin)
      .addManufacturerAttribute(C.mockManufacturerAttribute2);

    // Whitelist Integration attributes
    await integrationInstance
      .connect(admin)
      .addIntegrationAttribute(C.mockIntegrationAttribute1);
    await integrationInstance
      .connect(admin)
      .addIntegrationAttribute(C.mockIntegrationAttribute2);

    // Whitelist Vehicle attributes
    await vehicleInstance
      .connect(admin)
      .addVehicleAttribute(C.mockVehicleAttribute1);
    await vehicleInstance
      .connect(admin)
      .addVehicleAttribute(C.mockVehicleAttribute2);

    // Whitelist SyntheticDevice attributes
    await syntheticDeviceInstance
      .connect(admin)
      .addSyntheticDeviceAttribute(C.mockSyntheticDeviceAttribute1);
    await syntheticDeviceInstance
      .connect(admin)
      .addSyntheticDeviceAttribute(C.mockSyntheticDeviceAttribute2);

    // Mint Manufacturer Node
    await manufacturerInstance
      .connect(admin)
      .mintManufacturer(
        manufacturer1.address,
        C.mockManufacturerNames[0],
        C.mockManufacturerAttributeInfoPairs
      );

    // Mint Integration Node
    await integrationInstance
      .connect(admin)
      .mintIntegration(
        integrationOwner1.address,
        C.mockIntegrationNames[0],
        C.mockIntegrationAttributeInfoPairs
      );

    // Set Dimo Registry in the NFTs
    await manufacturerIdInstance
      .connect(admin)
      .setDimoRegistryAddress(dimoRegistryInstance.address);
    await vehicleIdInstance
      .connect(admin)
      .setDimoRegistryAddress(dimoRegistryInstance.address);

    // Set DimoForwarder in the SyntheticDeviceId
    await sdIdInstance
      .connect(admin)
      .setTrustedForwarder(vehicleIdInstance.address, true);

    // Set SyntheticDeviceId in the VehicleId
    await vehicleIdInstance
      .connect(admin)
      .setSyntheticDeviceIdAddress(sdIdInstance.address);

    // Minting and linking a vehicle to a synthetic device
    const mintSyntheticDeviceSig1 = await signMessage({
      _signer: sDAddress1,
      _primaryType: 'MintSyntheticDeviceSign',
      _verifyingContract: syntheticDeviceInstance.address,
      message: {
        integrationNode: '1',
        vehicleNode: '1'
      }
    });
    const mintVehicleOwnerSig1 = await signMessage({
      _signer: user1,
      _primaryType: 'MintSyntheticDeviceSign',
      _verifyingContract: syntheticDeviceInstance.address,
      message: {
        integrationNode: '1',
        vehicleNode: '1'
      }
    });
    const correctMintInput1 = {
      integrationNode: '1',
      vehicleNode: '1',
      syntheticDeviceSig: mintSyntheticDeviceSig1,
      vehicleOwnerSig: mintVehicleOwnerSig1,
      syntheticDeviceAddr: sDAddress1.address,
      attrInfoPairs: C.mockSyntheticDeviceAttributeInfoPairs
    };

    await vehicleInstance
      .connect(admin)
      .mintVehicle(1, user1.address, C.mockVehicleAttributeInfoPairs);
    await syntheticDeviceInstance
      .connect(admin)
      .mintSyntheticDeviceSign(correctMintInput1);
  });

  beforeEach(async () => {
    snapshot = await createSnapshot();
  });

  afterEach(async () => {
    await revertToSnapshot(snapshot);
  });

  describe('setDimoRegistryAddress', () => {
    it('Should revert if caller does not have admin role', async () => {
      await expect(
        sdIdInstance.connect(nonAdmin).setDimoRegistryAddress(C.ZERO_ADDRESS)
      ).to.be.revertedWith(
        `AccessControl: account ${nonAdmin.address.toLowerCase()} is missing role ${
          C.ADMIN_ROLE
        }`
      );
    });
    it('Should revert if addr is zero address', async () => {
      await expect(
        sdIdInstance.connect(admin).setDimoRegistryAddress(C.ZERO_ADDRESS)
      ).to.be.revertedWith('ZeroAddress');
    });
  });

  describe('setTrustedForwarder', () => {
    it('Should revert if caller does not have admin role', async () => {
      await expect(
        sdIdInstance.connect(nonAdmin).setTrustedForwarder(C.ZERO_ADDRESS, true)
      ).to.be.revertedWith(
        `AccessControl: account ${nonAdmin.address.toLowerCase()} is missing role ${
          C.ADMIN_ROLE
        }`
      );
    });
    it('Should correctly set address as trusted forwarder', async () => {
      const mockForwarder = ethers.Wallet.createRandom();

      // eslint-disable-next-line no-unused-expressions
      expect(await sdIdInstance.trustedForwarders(mockForwarder.address)).to.be
        .false;

      await sdIdInstance
        .connect(admin)
        .setTrustedForwarder(mockForwarder.address, true);

      // eslint-disable-next-line no-unused-expressions
      expect(await sdIdInstance.trustedForwarders(mockForwarder.address)).to.be
        .true;
    });
    it('Should correctly set address as not trusted forwarder', async () => {
      const mockForwarder = ethers.Wallet.createRandom();
      await sdIdInstance
        .connect(admin)
        .setTrustedForwarder(mockForwarder.address, true);

      // eslint-disable-next-line no-unused-expressions
      expect(await sdIdInstance.trustedForwarders(mockForwarder.address)).to.be
        .true;

      await sdIdInstance
        .connect(admin)
        .setTrustedForwarder(mockForwarder.address, false);

      // eslint-disable-next-line no-unused-expressions
      expect(await sdIdInstance.trustedForwarders(mockForwarder.address)).to.be
        .false;
    });
  });

  context('On transfer', () => {
    context('Error handling', () => {
      it('Should revert if caller is approved, but not the token owner', async () => {
        await expect(
          sdIdInstance
            .connect(user1)
            ['safeTransferFrom(address,address,uint256)'](
              user1.address,
              user2.address,
              1
            )
        ).to.be.revertedWith('Unauthorized');
      });
    });

    context('State', () => {
      it('Should transfer vehicle ID to the new owner', async () => {
        expect(await vehicleIdInstance.ownerOf(1)).to.be.equal(user1.address);

        await vehicleIdInstance
          .connect(user1)
          ['safeTransferFrom(address,address,uint256)'](
            user1.address,
            user2.address,
            1
          );

        expect(await vehicleIdInstance.ownerOf(1)).to.be.equal(user2.address);
      });
      it('Should transfer synthetic device ID to the new owner', async () => {
        expect(await sdIdInstance.ownerOf(1)).to.be.equal(user1.address);

        await vehicleIdInstance
          .connect(user1)
          ['safeTransferFrom(address,address,uint256)'](
            user1.address,
            user2.address,
            1
          );

        expect(await sdIdInstance.ownerOf(1)).to.be.equal(user2.address);
      });
      it('Should keep pairing link between vehicle ID and synthetic device ID', async () => {
        expect(
          await mapperInstance.getNodeLink(
            vehicleIdInstance.address,
            sdIdInstance.address,
            1
          )
        ).to.equal(1);
        expect(
          await mapperInstance.getNodeLink(
            sdIdInstance.address,
            vehicleIdInstance.address,
            1
          )
        ).to.equal(1);

        await vehicleIdInstance
          .connect(user1)
          ['safeTransferFrom(address,address,uint256)'](
            user1.address,
            user2.address,
            1
          );

        expect(
          await mapperInstance.getNodeLink(
            vehicleIdInstance.address,
            sdIdInstance.address,
            1
          )
        ).to.equal(1);
        expect(
          await mapperInstance.getNodeLink(
            sdIdInstance.address,
            vehicleIdInstance.address,
            1
          )
        ).to.equal(1);
      });
      it('Should keep the synthetic device ID parent node', async () => {
        expect(
          await nodesInstance.getParentNode(sdIdInstance.address, 1)
        ).to.equal(1);

        await vehicleIdInstance
          .connect(user1)
          ['safeTransferFrom(address,address,uint256)'](
            user1.address,
            user2.address,
            1
          );

        expect(
          await nodesInstance.getParentNode(sdIdInstance.address, 1)
        ).to.equal(1);
      });
      it('Should keep the same synthetic device ID infos', async () => {
        for (const attrInfoPair of C.mockSyntheticDeviceAttributeInfoPairs) {
          expect(
            await nodesInstance.getInfo(
              sdIdInstance.address,
              1,
              attrInfoPair.attribute
            )
          ).to.equal(attrInfoPair.info);
        }

        await vehicleIdInstance
          .connect(user1)
          ['safeTransferFrom(address,address,uint256)'](
            user1.address,
            user2.address,
            1
          );

        for (const attrInfoPair of C.mockSyntheticDeviceAttributeInfoPairs) {
          expect(
            await nodesInstance.getInfo(
              sdIdInstance.address,
              1,
              attrInfoPair.attribute
            )
          ).to.equal(attrInfoPair.info);
        }
      });
      it('Should keep the same synthetic device address', async () => {
        expect(
          await syntheticDeviceInstance.getSyntheticDeviceIdByAddress(
            sDAddress1.address
          )
        ).to.equal(1);

        await vehicleIdInstance
          .connect(user1)
          ['safeTransferFrom(address,address,uint256)'](
            user1.address,
            user2.address,
            1
          );

        expect(
          await syntheticDeviceInstance.getSyntheticDeviceIdByAddress(
            sDAddress1.address
          )
        ).to.equal(1);
      });
    });
  });
});

import { ethers } from 'hardhat';

// Node types
export const rootNodeType = ethers.utils.toUtf8Bytes('Root');
export const vehicleNodeType = ethers.utils.toUtf8Bytes('Vehicle');
export const rootNodeTypeId = ethers.utils.keccak256(rootNodeType);
export const vehicleNodeTypeId = ethers.utils.keccak256(vehicleNodeType);

// Mock Root attributes
export const mockRootAttribute1 = 'mockRootAttribute1';
export const mockRootAttribute2 = 'mockRootAttribute2';
export const mockRootAttribute3 = 'mockRootAttribute3';
export const mockRootAttributes = [mockRootAttribute1, mockRootAttribute2];
export const rootAttributesNotWhitelisted = [
  mockRootAttribute1,
  mockRootAttribute3
];

// Mock Vehicle attributes
export const mockVehicleAttribute1 = 'mockVehicleAttribute1';
export const mockVehicleAttribute2 = 'mockVehicleAttribute2';
export const mockVehicleAttribute3 = 'mockVehicleAttribute3';
export const mockVehicleAttributes = [
  mockVehicleAttribute1,
  mockVehicleAttribute2
];
export const vehicleAttributesNotWhitelisted = [
  mockVehicleAttribute1,
  mockVehicleAttribute3
];

// Root Infos associated with attributes
export const mockRootInfo1 = 'mockRootInfo1';
export const mockRootInfo2 = 'mockRootInfo2';
export const mockRootInfos = [mockRootInfo1, mockRootInfo2];
export const mockRootInfosWrongSize = [mockRootInfo1];

// Vehicle Infos associated with attributes
export const mockVehicleInfo1 = 'mockVehicleInfo1';
export const mockVehicleInfo2 = 'mockVehicleInfo2';
export const mockVehicleInfos = [mockVehicleInfo1, mockVehicleInfo2];
export const mockVehicleInfosWrongSize = [mockVehicleInfo1];

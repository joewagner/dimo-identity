import { ethers } from 'hardhat';

import { ManufacturerId, VehicleId, AftermarketDeviceId } from '../typechain';
import { AddressesByNetwork } from '../utils';
import addressesJSON from './data/addresses.json';

const contractAddresses: AddressesByNetwork = addressesJSON;

async function main() {
  const currentNetwork = 'polygon';

  const manufacturerIdInstance: ManufacturerId = await ethers.getContractAt(
    'ManufacturerId',
    contractAddresses[currentNetwork].nfts.ManufacturerId.proxy
  );
  const aftermarketDeviceIdInstance: AftermarketDeviceId =
    await ethers.getContractAt(
      'AftermarketDeviceId',
      contractAddresses[currentNetwork].nfts.AftermarketDeviceId.proxy
    );
  const vehicleIdInstance: VehicleId = await ethers.getContractAt(
    'VehicleId',
    contractAddresses[currentNetwork].nfts.VehicleId.proxy
  );

  console.log(`Manufacturer ID name: ${await manufacturerIdInstance.name()}`);
  console.log(`Vehicle ID name: ${await vehicleIdInstance.name()}`);
  console.log(
    `Aftermarket Device ID name: ${await aftermarketDeviceIdInstance.name()}`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

import fs from 'fs';
import path from 'path';
import { ethers, network } from 'hardhat';

import { VehicleId } from '../typechain';

import { SetPrivilegeData, ContractAddressesByNetwork } from '../utils';

import ethDenverAddresses from './data/ethDenver_privileges.json';
import addressesJSON from './data/addresses.json';

const contractAddresses: ContractAddressesByNetwork = addressesJSON;

// eslint-disable-next-line no-unused-vars
async function parseJson(
  tokenId: string,
  privileges: string[],
  expires: string
) {
  const addresses = fs.readFileSync(
    path.resolve(__dirname, 'data', 'Eth_Denver_Attendees.csv'),
    'utf8'
  );

  const output: SetPrivilegeData[] = [];
  for (const address of addresses.split(/\r?\n/)) {
    for (const privId of privileges) {
      output.push({
        tokenId: tokenId,
        privId: privId,
        user: address,
        expires: expires
      });
    }
  }

  fs.writeFileSync(
    path.resolve(__dirname, 'data', 'ethDenver_privileges.json'),
    `${JSON.stringify(output, null, 4)}`,
    {
      flag: 'w'
    }
  );
}

async function setPrivileges() {
  const [owner] = await ethers.getSigners();

  // eslint-disable-next-line prettier/prettier
  const ethDenverData = ethDenverAddresses as SetPrivilegeData[];

  const vehicleIdInstance: VehicleId = await ethers.getContractAt(
    'VehicleId',
    contractAddresses[network.name].nfts.VehicleId.proxy
  );
  
  // const estimate = await vehicleIdInstance.estimateGas.setPrivileges(ethDenverData.slice(0,7000));
  // console.log(estimate);

  vehicleIdInstance
    .connect(owner)
    .setPrivileges(ethDenverData.slice(0,7000));
}

setPrivileges().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

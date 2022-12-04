const { ethers } = require("hardhat");
require("dotenv").config();
const { CRYPTO_DEV_TOKEN_CONTRACT_ADDRESS } = require("../constants");

async function main() {
  const cryptoDevTokenAddress = CRYPTO_DEV_TOKEN_CONTRACT_ADDRESS;
  const exchangeContract = await ethers.getContractFactory("Exchange");

  const exchangeDeployed = await exchangeContract.deploy(cryptoDevTokenAddress);

  await exchangeDeployed.deployed();
  console.log(`DEX deployed to ${exchangeDeployed.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.log(error);
    process.exit(1);
  });

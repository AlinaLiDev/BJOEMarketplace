import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  const BjoeMint = await ethers.getContractFactory("BjoeMint");
  const marketplace = await BjoeMint.deploy("", "", "", "", "", "", [], "");

  console.log(`NFT Marketplace: ${marketplace.address}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

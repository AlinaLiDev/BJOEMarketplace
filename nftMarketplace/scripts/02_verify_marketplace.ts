const hre = require("hardhat");
const NFT_MARKETPLACE = "0x7525c8464ecd53a0fd0383f15b5b076292d4586f";

const config = [];

async function main() {
  console.log("| Verify `Detf`...");
  await hre.run("verify:verify", {
    address: NFT_MARKETPLACE,
    constructorArguments: ["", "", "", "", "", "", [], ""],
  });
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

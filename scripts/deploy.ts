import hre, { ethers } from "hardhat";

async function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

async function main() {
  // Deploy the Nft Contract
  const nftContract = await ethers.deployContract('CryptoDevsNft')
  await nftContract.waitForDeployment()
  console.log("CryptoDevsNft deployed to:", nftContract.target);
  

  // Deploy the Fake Marketplace Contract
  const fakeNftMarketplaceContract = await ethers.deployContract('FakeNFTMarketplace')
  await fakeNftMarketplaceContract.waitForDeployment()
  console.log('FakeNFTMarketplace deployed to:', fakeNftMarketplaceContract.target);

  // Deploy the DAO Contract
  const amount = ethers.parseEther('1') // You can change this value from 1 ETH to something else
  const daoContract = await ethers.deployContract('CryptoDevsDAO', [ fakeNftMarketplaceContract.target, nftContract.target ], { value: amount })
  await daoContract.waitForDeployment()
  console.log('CryptoDevsDAO deployed to:', daoContract.target);

  // Sleep for 30 seconds to let Etherscan catch up with the deployments
  await sleep(30 * 1000)

  // Verify the NFT Contract
  await hre.run('verify:verify', {
    address: nftContract.target,
    constructorArguments: []
  })

  // Verify the Fake Marketplace Contract
  await hre.run('verify:verify', {
    address: fakeNftMarketplaceContract.target,
    constructorArguments: []
  })

  // Verify the DAO Contract
  await hre.run('verify:verify', {
    address: daoContract.target,
    constructorArguments: [
      fakeNftMarketplaceContract.target,
      nftContract.target
    ]
  })  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// npx hardhat run scripts/deploy.ts --network sepolia
// CryptoDevsNft deployed to: 0xF84642E8a3c30064a33005a95d8bBF2D9b3487eB
// FakeNFTMarketplace deployed to: 0xAcD056155A0d24e323c30D7d5b0E5567F8DF6Dc7
// CryptoDevsDAO deployed to: 0x7638290F4a65bf288da9aF8586c577E3d8451CA5
import { ethers } from "hardhat";

async function main() {
  const EmployeeToken = await ethers.getContractFactory("EmployeeToken");
  const employeeToken = await EmployeeToken.deploy(
    '0xe5d2e173b120341face9e9970889c9fe64081ffd', // Bluejay token address
    '0xe5d2e173b120341face9e9970889c9fe64081ffd'  // Should be replaced with proper treasury address
  );

  await employeeToken.deployed();

  console.log(`EmployeeToken deployed to ${employeeToken.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

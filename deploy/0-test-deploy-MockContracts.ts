import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

// deploy/0-test-deploy-MockContracts.ts
const deployMockContracts: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {
    deployments: { deploy },
    getNamedAccounts,
  } = hre;
  const { deployer } = await getNamedAccounts();

  const mockNFT = await deploy('MockNFT', {
    from: deployer,
    args: [],
    log: true,
  });

  
  await deploy('MockNFTOracle', {
    from: deployer,
    args: [mockNFT.address],
    log: true,
  });
};

export default deployMockContracts;
deployMockContracts.tags = ['MockContracts'];

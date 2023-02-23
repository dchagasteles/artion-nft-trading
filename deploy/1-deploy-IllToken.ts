import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

// deploy/0-deploy-IllToken.ts
const deployIllToken: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const {
    deployments: { deploy },
    getNamedAccounts,
  } = hre;
  const { deployer } = await getNamedAccounts();

  await deploy('IllToken', {
    from: deployer,
    args: ['Ill Token', 'ILLT'],
    log: true,
  });
};

export default deployIllToken;
deployIllToken.tags = ['IllToken'];

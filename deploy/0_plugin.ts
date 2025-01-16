
import * as dotenv from 'dotenv';
import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

dotenv.config();

const deployFunc: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const args = [
    "0x2979a1cb90eeb9e75d7fb4f9813fcc40e4a7fd8b", // brevis request address
  ];
  const deployment = await deploy('VipDiscountPlugin', {
    from: deployer,
    log: true,
    args: args
  });
  // await verify(hre, deployment, args);
};

deployFunc.tags = ['VipDiscountPlugin'];
deployFunc.dependencies = [];
export default deployFunc;
import { HardhatUserConfig } from "hardhat/config";
import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "@nomicfoundation/hardhat-foundry";
import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const privateKey: string | undefined = process.env.PRIVATE_KEY;
if (!privateKey) {
  throw new Error("Please set your PRIVATE_KEY in a .env file");
}

const config: HardhatUserConfig = {
  solidity: {
    compilers: [{ version: "0.7.1" }, { version: "0.8.19" }],
    settings: {
      optimizer: {
        enabled: true,
        runs: 500,
      },
    },
  },
  defaultNetwork: "porcini",
  networks: {
    hardhat: {},
    porcini: {
      allowUnlimitedContractSize: true,
      url: "https://porcini.rootnet.app/archive",
      accounts: [privateKey],
    },
    xrpevmdev: {
      allowUnlimitedContractSize: true,
      url: "https://rpc-evm-sidechain.xrpl.org",
      accounts: [privateKey],
    },
  },
};

export default config;

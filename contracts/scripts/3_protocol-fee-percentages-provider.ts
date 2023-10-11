import { ethers } from "hardhat";

import fs from "fs";
import path from "path";
import { networkMap } from "../networks";

async function main() {
  const DEPLOYMENT_DIRECTORY = path.resolve(__dirname, "../deployed");
  const DEPLOYMENT_HISTORY_DIRECTORY = path.resolve(
    __dirname,
    "../deployed-histories"
  );

  console.log("deploying Protocol Fee Percentages Provider");
  try {
    const provider = ethers.provider;
    const network = (await provider.getNetwork()).chainId;
    const networkName = networkMap[network];

    // deployed
    const filePath = path.join(DEPLOYMENT_DIRECTORY, `${networkName}.json`);
    const fileExists =
      fs.existsSync(filePath) && fs.statSync(filePath).isFile();

    const newFileContents: Record<string, string> = fileExists
      ? JSON.parse(fs.readFileSync(filePath).toString())
      : {};

    // deployed histories
    const historiesFilePath = path.join(
      DEPLOYMENT_HISTORY_DIRECTORY,
      `${networkName}.json`
    );
    const historiesFileExists =
      fs.existsSync(historiesFilePath) &&
      fs.statSync(historiesFilePath).isFile();

    const historiesFileContents: Record<string, string> = historiesFileExists
      ? JSON.parse(fs.readFileSync(historiesFilePath).toString())
      : {};

    const from = await provider.getSigner().getAddress();

    console.log("from:", from, "network:", networkName);

    const factory = await ethers.getContractFactory(
      "ProtocolFeePercentagesProvider"
    );

    const vault = newFileContents["Vault"];

    const ret = await factory.deploy(
      vault,
      (0.5 * 1e18).toString(),
      (0.5 * 1e18).toString()
    );
    const now = new Date();
    const timestamp = Math.floor(now.getTime() / 1000);

    newFileContents["ProtocolFeePercentagesProvider"] = ret.address;
    historiesFileContents[`ProtocolFeePercentagesProvider-${timestamp}`] =
      ret.address;

    console.log("contract addr:", ret.address);

    fs.writeFileSync(filePath, JSON.stringify(newFileContents, null, 2));
    fs.writeFileSync(
      historiesFilePath,
      JSON.stringify(historiesFileContents, null, 2)
    );
  } catch (e) {
    console.log(e);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

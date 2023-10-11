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

  console.log("deploying Vault");
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

    const factory = await ethers.getContractFactory("Vault");

    const authorizer = newFileContents["Authorizer"];
    const WETH = newFileContents["WETH"];

    const SECOND = 1;
    const MINUTE = SECOND * 60;
    const HOUR = MINUTE * 60;
    const DAY = HOUR * 24;
    const MONTH = DAY * 30;

    const ret = await factory.deploy(authorizer, WETH, MONTH * 3, MONTH);
    const now = new Date();
    const timestamp = Math.floor(now.getTime() / 1000);

    newFileContents["Vault"] = ret.address;
    historiesFileContents[`Vault-${timestamp}`] = ret.address;

    console.log("contract addr:", ret.address);

    const feeCollector = await ret.getProtocolFeesCollector();
    newFileContents["ProtocolFeesCollector"] = feeCollector;
    historiesFileContents[`ProtocolFeesCollector-${timestamp}`] = feeCollector;

    const helperFactory = await ethers.getContractFactory("BalancerHelpers");
    const helpers = await helperFactory.deploy(ret.address);

    newFileContents["BalancerHelpers"] = helpers.address;
    historiesFileContents[`BalancerHelpers-${timestamp}`] = helpers.address;

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

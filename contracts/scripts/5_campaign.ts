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

  console.log("deploying Campaign");
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
    const factory = await ethers.getContractFactory("Campaign");

    const ret = await factory.deploy(
      "0xcCcCCccC00000001000000000000000000000000",
      "0xCCCCcCCc00000002000000000000000000000000",
      "0x6548DEA2fB59143215E54595D0157B79aac1335e",
      "0x291af6e1b841cad6e3dcd66f2aa0790a007578ad",
      "0x291af6e1b841cad6e3dcd66f2aa0790a007578ad000200000000000000000000"
    );
    const now = new Date();
    const timestamp = Math.floor(now.getTime() / 1000);

    newFileContents["Campaign"] = ret.address;
    historiesFileContents[`Campaign-${timestamp}`] = ret.address;

    fs.writeFileSync(filePath, JSON.stringify(newFileContents, null, 2));
    fs.writeFileSync(
      historiesFilePath,
      JSON.stringify(historiesFileContents, null, 2)
    );

    console.log("contract addr:", ret.address);
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

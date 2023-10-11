import { ethers } from "hardhat";

import fs from "fs";
import path from "path";
import { networkMap } from "../networks";

async function main() {
  const DEPLOYMENT_TXS_DIRECTORY = path.resolve(__dirname, "../deployed");

  console.log("deploying Authorizer");
  try {
    const provider = ethers.provider;
    const network = (await provider.getNetwork()).chainId;
    const networkName = networkMap[network];

    const filePath = path.join(DEPLOYMENT_TXS_DIRECTORY, `${networkName}.json`);
    const fileExists =
      fs.existsSync(filePath) && fs.statSync(filePath).isFile();

    const newFileContents: Record<string, string> = fileExists
      ? JSON.parse(fs.readFileSync(filePath).toString())
      : {};

    const from = await provider.getSigner().getAddress();

    console.log("from:", from, "network:", networkName);
    const factory = await ethers.getContractFactory("Authorizer");

    const ret = await factory.deploy(from);
    const now = new Date();
    const date = `${now.getFullYear()}-${now.getMonth()}-${now.getDate()}`;
    newFileContents[`Authorizer-${date}`] = ret.address;

    fs.writeFileSync(filePath, JSON.stringify(newFileContents, null, 2));

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

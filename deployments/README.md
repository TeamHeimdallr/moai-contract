# moai contract deployment

## How to deploy
1. Add networks to `address/.supported-networks.json`
2. Add networks to `src/types.ts`
3. Deploy tokens `WETH` and `BAL` (see `00000000-tokens/output`)
4. Add YOUR_NETWORK.json to `tasks/00000000-tokens/output`
5. Add your network to `20210418-authorizer/input.ts`
6. Run `yarn hardhat deploy --id 20210418-authorizer --network YOUR_NETWORK`
7. Run `yarn hardhat deploy --id 20210418-vault --network YOUR_NETWORK`
8. Run `yarn hardhat deploy --id 20220725-protocol-fee-percentages-provider --network YOUR_NETWORK`
9. Run `yarn hardhat deploy --id 20230320-weighted-pool-v4 --network YOUR_NETWORK`

---

## How to create weighted pool
```bash
$ npx hardhat console --netowrk YOUR_NETWORK
```
```javascript
> const x = await ethers.getContractAt("WeightedPoolFactory", "<DEPLOYED_CONTRACT_ADDRESS>")
> await x.create("<POOL NAME>", "<POOL SYMBOL>", ["<TOKEN1_ADDRESS>", "<TOKEN2_ADDRESS>"], ["<TOKEN1_WEIGHT>", "<TOKEN2_WEIGHT>"], ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], 1000000000000000, "<OWNER>", "<RANDOM_SALT>", {from: "<SIGNER_ADDRESS>"})
```
### example
```javascript
> await x.create("50WETH-50XRP", "50WETH-50XRP", ["0x2A40A6D0Fb23cf12F550BaFfd54fb82b07a21BDe", "0x80dDA4A58Ed8f7E8F992Bbf49efA54aAB618Ab26"], ["500000000000000000", "500000000000000000"], ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"], 1000000000000000, "0xCfE5A4Bd0421e507cB5B345cE152Cb593396f965", "0x26504c2e4f5b39452f306c7a2b25763b7137415e2835535d58495865366a4722", {from: "0xCfE5A4Bd0421e507cB5B345cE152Cb593396f965"})
```

--- 

## Notice
- When initially joining the pool, it is essential to use `WeightedPoolEncoder.joinInit` rather than `WeightedPoolEncoder.joinExactTokensInForBPTOut`

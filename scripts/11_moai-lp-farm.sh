#!/usr/bin/env bash

if [ "$1" != "--rpc" ]; then
    echo "Invalid option. Use --rpc"
    exit 1
fi

forge create \
  --rpc-url "$2" \
  --private-key $CALLER_PRIVATE_KEY \
  --optimize \
  --optimizer-runs 200 \
  --legacy \
  --verify \
  --verifier sourcify contracts/dex/MoaiLpFarm.sol/:MoaiLpFarm \
  --constructor-args 0xcCcCCccC00000001000000000000000000000000 1466049 11670258
# (IERC20 _erc20, uint256 _rewardPerBlock, uint256 _startBlock)

# 2 months = 60 days = 5184000 seconds = 1296000 blocks (assuming 4s per block)
# For ETH/ROOT Pool, Total Rewards = about $200K ~= 1,900,000 ROOT
# => 1466049 per blocks (1.466049 ROOT)
# For ROOT/USDC Pool, Total Rewards = about $100K ~= 950,000 ROOT
# => 733024 per blocks (0.733024 ROOT)
# For USDT/USDC Pool, Total Rewards = about $50K ~= 475,000 ROOT
# => 366512 per blocks (0.366512 ROOT)


# porcini block number ~= 11669752 for 24/03/22 08H UTC
# mainnet block number ~= 11632354 for 24/03/22 08H UTC



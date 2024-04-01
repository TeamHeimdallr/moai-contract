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
  --constructor-args 0xcCcCCccC00000001000000000000000000000000 420875 11807125
# (IERC20 _erc20, uint256 _rewardPerBlock, uint256 _startBlock)

# Mainnet start for ROOT-ETH, ROOT-USDC pool: 11699610
# 2 months = 60 days = 5184000 seconds = 1296000 blocks (assuming 4s per block)
# For ETH/ROOT Pool, Total Rewards = 2,000,000 ROOT (~= $200K)
# => 1543209 per blocks (1.543209 ROOT)
# For ROOT/USDC Pool, Total Rewards = 1,000,000 ROOT (~= $100K)
# => 771604 per blocks (0.771604 ROOT)

# Porcini Test start block: 11732657
# 2 months = 60 days = 5184000 seconds = 1296000 blocks (assuming 4s per block)
# For ETH/ROOT Pool, Total Rewards = 200 ROOT
# => 154 per blocks (0.000154 ROOT)
# For ROOT/USDC Pool, Total Rewards = 100 ROOT
# => 77 per blocks (0.000077 ROOT)

# Mainnet :
# 2 months-5days = 55 days = 4752000 seconds = 1188000 blocks (assuming 4s per block)
# For USDC/ROOT Pool, Total Rewards = 500,000 ROOT
# => 420875 per blocks (0.420875 ROOT)

# Porcini : 11844329
# 2 months-5days = 55 days = 4752000 seconds = 1188000 blocks (assuming 4s per block)
# For USDC/ROOT Pool, Total Rewards = 50 ROOT
# => 42 per blocks (0.000042 ROOT)


# porcini block number ~= 11669752 for 24/03/22 08H UTC
# mainnet block number ~= 11632354 for 24/03/22 08H UTC



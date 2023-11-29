#!/usr/bin/env bash

if [ "$1" != "--rpc" ]; then
    echo "Invalid option. Use --rpc"
    exit 1
fi

forge create \
  --rpc-url "$2", \
  --private-key $CALLER_PRIVATE_KEY \
  --optimize \
  --optimizer-runs 999 \
  --legacy \
  --verify \
  --verifier sourcify contracts/PoolInfoAggregator.sol/:PoolInfoAggregator \
  --constructor-args 0xF5bB92ea0f82E01F890ad82AbbECE7B721fC780b


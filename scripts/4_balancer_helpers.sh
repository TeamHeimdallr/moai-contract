#!/usr/bin/env bash

if [ "$1" != "--rpc" ]; then
    echo "Invalid option. Use --rpc"
    exit 1
fi

forge create \
  --rpc-url "$2" \
  --private-key $CALLER_PRIVATE_KEY \
  --optimize \
  --optimizer-runs 9999 \
  --legacy \
  --verify \
  --verifier sourcify contracts/dex/lib/helpers/BalancerHelpers.sol/:BalancerHelpers \
  --constructor-args 0x1D6B655289328a1083EcD70170692002dBED1aBD


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
  --verifier sourcify contracts/dex/weighted-pool-v4/v2-interfaces/contracts/vault/ProtocolFeePercentagesProvider.sol/:ProtocolFeePercentagesProvider \
  --constructor-args 0x1D6B655289328a1083EcD70170692002dBED1aBD 500000000000000000 500000000000000000


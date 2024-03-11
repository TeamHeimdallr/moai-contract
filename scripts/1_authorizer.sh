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
  --verifier sourcify contracts/dex/vault/Authorizer.sol/:Authorizer \
  --constructor-args 0xCfE5A4Bd0421e507cB5B345cE152Cb593396f965

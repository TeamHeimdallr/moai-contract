#!/usr/bin/env bash

if [ "$1" != "--rpc" ]; then
    echo "Invalid option. Use --rpc"
    exit 1
fi

forge create \
  --rpc-url "$2", \
  --private-key $CALLER_PRIVATE_KEY \
  --optimize \
  --optimizer-runs 860 \
  --legacy \
  --verify \
  --verifier sourcify contracts/dex/vault/Vault.sol/:Vault \
  --constructor-args 0x0780A78f400bad5b0349FF00D222aef8BB6BAb35 0x122CAC01f06B15F8eF9b45068B4288b2033c554f 7776000 2592000


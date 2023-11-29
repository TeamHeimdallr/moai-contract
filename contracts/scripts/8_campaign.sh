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
  --verifier sourcify contracts/campaign/Campaign.sol/:Campaign \
  --constructor-args 0xcCcCCccC00000001000000000000000000000000 0xCCCCcCCc00000002000000000000000000000000 0xF5bB92ea0f82E01F890ad82AbbECE7B721fC780b 0xcd1c4de9f374c737944ce2eef413519f9db14434 0xcd1c4de9f374c737944ce2eef413519f9db14434000200000000000000000000


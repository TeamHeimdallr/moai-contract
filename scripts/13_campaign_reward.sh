#!/usr/bin/env bash

if [ "$1" != "--rpc" ]; then
    echo "Invalid option. Use --rpc"
    exit 1
fi

forge create \
  --rpc-url "$2" \
  --private-key $CALLER_PRIVATE_KEY \
  --optimize \
  --optimizer-runs 999 \
  --legacy \
  --verify \
  --verifier sourcify contracts/campaign/CampaignReward.sol/:CampaignReward \
  --constructor-args 0xcCcCCccC00000001000000000000000000000000 0xCCCCcCCc00000002000000000000000000000000 0x1D6B655289328a1083EcD70170692002dBED1aBD 0xB56dB41c597f0FFa615863da93612aa590171842 0xb56db41c597f0ffa615863da93612aa590171842000200000000000000000000
  # --constructor-args 0xcCcCCccC00000001000000000000000000000000 0xCCCCcCCc00000002000000000000000000000000 0xc922770de79fc31Cce42DF3fa8234c864fA3FeaE 0xAd77a729f590AA35e7631A5d11b422D3198B6Cb0 0xad77a729f590aa35e7631a5d11b422d3198b6cb0000200000000000000000000

#!/bin/bash

network="$1"
script_files=("scripts/1_authorizer.ts" "scripts/2_vault.ts" "scripts/3_protocol-fee-percentages-provider.ts" "scripts/4_weighted-pool-factory.ts")

if [ -z "$network" ]; then
    echo "network option is not provided. Exiting script."
    exit 1
fi

for script in "${script_files[@]}"; do
    echo "Running $script..."
    npx hardhat run "$script" --network "$network"
    exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "$script completed successfully."
    else
        echo "$script failed with exit code $exit_code."
        exit $exit_code
    fi
done

echo "All scripts completed successfully."
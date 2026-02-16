#!/bin/bash
set -euo pipefail

NETWORK="${1:?Usage: $0 <mainnet|arbitrum> <tokens_file>}"
TOKENS_FILE="${2:?Usage: $0 <network> <tokens_file>}"

case "$NETWORK" in
    mainnet) DATASET="edgeandnode/ethereum_mainnet"; CHAIN="mainnet" ;;
    arbitrum) DATASET="edgeandnode/arbitrum_one";     CHAIN="arbitrum-one" ;;
    *) echo "Unknown network: $NETWORK"; exit 1 ;;
esac

if [ ! -f "$TOKENS_FILE" ]; then
    echo "Tokens file not found: $TOKENS_FILE"
    exit 1
fi

DIR="$(dirname "$(readlink -f "$0")")"
WORK="$DIR/.build"
IPFS_URL="${IPFS_URL:-http://localhost:5001}"

rm -rf "$WORK" && mkdir -p "$WORK"

# Copy SQL files with dataset placeholder replaced
for f in "$DIR"/sql/*.sql; do
    sed "s|__DATASET__|$DATASET|g" "$f" > "$WORK/$(basename "$f")"
done

# Copy ABI and schema as-is
cp "$DIR/abis/ERC20.json" "$WORK/"
cp "$DIR/schema.graphql" "$WORK/"

# Upload shared asset files to IPFS and collect CID mappings
declare -A CIDS
for file in "$WORK"/*; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    cid=$(curl -s -X POST -F "file=@$file" "$IPFS_URL/api/v0/add" | jq -r '.Hash')
    CIDS["$filename"]="$cid"
    echo "Uploaded $filename -> $cid"
done

# Generate per-token Token SQL files, upload each, and collect CIDs
declare -A TOKEN_SQL_CIDS
while IFS=' ' read -r name address start_block symbol decimals; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    token_sql="$WORK/Token_${name}.sql"
    cat > "$token_sql" <<EOSQL
SELECT DISTINCT ON (sg_source_address())
    l._block_num,
    sg_source_address() AS id,
    '${symbol}' AS symbol,
    ${decimals} AS decimals
FROM
    "${DATASET}".logs l
WHERE
    l.address = sg_source_address()
    AND l.topic0 = evm_topic(sg_event_signature('ERC20', 'Transfer'))
EOSQL
    cid=$(curl -s -X POST -F "file=@$token_sql" "$IPFS_URL/api/v0/add" | jq -r '.Hash')
    TOKEN_SQL_CIDS["$name"]="$cid"
    echo "Uploaded Token_${name}.sql -> $cid"
done < "$TOKENS_FILE"

# Generate manifest with one data source per token
cat > "$WORK/subgraph.generated.yaml" <<EOF
specVersion: 1.5.0
schema:
    file:
        /: /ipfs/${CIDS["schema.graphql"]}
dataSources:
EOF

while IFS=' ' read -r name address start_block symbol decimals; do
    [[ -z "$name" || "$name" == \#* ]] && continue
    cat >> "$WORK/subgraph.generated.yaml" <<EOF
    - name: $name
      kind: amp
      network: $CHAIN
      source:
          address: "$address"
          dataset: $DATASET
          tables:
              - logs
              - blocks
          startBlock: $start_block
      transformer:
          apiVersion: 0.0.1
          abis:
              - name: ERC20
                file: /ipfs/${CIDS["ERC20.json"]}
          tables:
              - name: Token
                file: /ipfs/${TOKEN_SQL_CIDS["$name"]}
              - name: Account
                file: /ipfs/${CIDS["Account.sql"]}
              - name: Transfer
                file: /ipfs/${CIDS["Transfer.sql"]}
              - name: TransferData
                file: /ipfs/${CIDS["TransferData.sql"]}
EOF
done < "$TOKENS_FILE"

# Upload the final manifest
cid=$(curl -s -X POST -F "file=@$WORK/subgraph.generated.yaml" "$IPFS_URL/api/v0/add" | jq -r '.Hash')
echo "Subgraph IPFS Hash: $cid"

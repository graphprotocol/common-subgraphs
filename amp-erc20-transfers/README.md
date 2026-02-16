# Amp ERC20 Transfers

An [Amp](https://thegraph.com/docs/en/supported-networks/amp/)-powered
subgraph that indexes ERC20 `Transfer` events for one or more token
contracts. It stores every transfer as an immutable timeseries entity and
uses aggregations to compute per-token, per-account cumulative balances
and per-token transfer volume stats (hourly and daily).

## Entities

| Entity | Kind | Description |
|---|---|---|
| `Token` | entity | Token contract address, symbol, and decimals |
| `Account` | entity | Unique wallet address |
| `Transfer` | timeseries | Individual Transfer events |
| `TransferData` | timeseries | Per-account balance deltas (+/- value) |
| `AccountBalance` | aggregation | Cumulative balance per token per account |
| `TransferStats` | aggregation | Transfer count and volume per token |

## Configuration

List the tokens you want to track in a config file (see
`tokens.example.conf`):

```
# Format: NAME ADDRESS START_BLOCK SYMBOL DECIMALS
GRT 0xc944E90C64B2c07662A292be6244BDf05Cda44a7 11446769 GRT 18
UNI 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984 10861674 UNI 18
```

Each token becomes its own data source in the generated manifest, all
sharing the same SQL queries and ABI. The `Token.sql` for each token is
generated at upload time with the symbol and decimals baked in, since
these are contract state and cannot be extracted from event logs.

## Deploying

Prerequisites: an IPFS node (default `http://localhost:5001`), `curl`,
and `jq`.

```bash
# Deploy for Ethereum mainnet
./upload.sh ethereum tokens.conf

# Deploy for Arbitrum One
./upload.sh arbitrum tokens.conf

# Use a custom IPFS endpoint
IPFS_URL=http://ipfs.example.com:5001 ./upload.sh ethereum tokens.conf
```

The script uploads all files to IPFS, generates the manifest with one
data source per token, and prints the final subgraph IPFS hash:

```
Uploaded schema.graphql -> QmXxx...
Uploaded ERC20.json -> QmYyy...
Uploaded Account.sql -> QmZzz...
...
Uploaded Token_GRT.sql -> QmAaa...
Uploaded Token_UNI.sql -> QmBbb...
Subgraph IPFS Hash: QmFinal...
```

Use the `Subgraph IPFS Hash` to deploy to a graph-node or as the source
for the [composed-erc20-balances](../composed-erc20-balances) subgraph.

## Supported networks

| Network | Dataset | Chain name |
|---|---|---|
| Ethereum mainnet | `edgeandnode/ethereum_mainnet` | `ethereum-mainnet` |
| Arbitrum One | `edgeandnode/arbitrum_one` | `arbitrum-one` |

Add more networks by extending the `case` block in `upload.sh`.

## File structure

```
abis/ERC20.json           Minimal ABI (Transfer event only)
sql/Account.sql            Unique accounts from both sides of transfers
sql/Transfer.sql           Decoded Transfer events
sql/TransferData.sql       Per-account balance deltas (UNION ALL)
schema.graphql             Entity and aggregation definitions
subgraph.template.yaml     Reference manifest (not used directly)
tokens.example.conf        Example tokens config
upload.sh                  Build and upload to IPFS
```

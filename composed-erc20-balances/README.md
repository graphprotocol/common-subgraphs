# Composed ERC20 Balances

A [composition](https://thegraph.com/docs/en/subgraphs/composability/)
subgraph that sits on top of
[amp-erc20-transfers](../amp-erc20-transfers) and maintains current
per-wallet, per-token balances via AssemblyScript mappings.

## Entities

| Entity | Kind | Description |
|---|---|---|
| `Token` | entity | Token address, symbol, decimals (from source) |
| `WalletBalance` | entity | Current balance per token per wallet |
| `TransferRecord` | immutable | Record of each Transfer event |

## Prerequisites

- Node.js and pnpm
- A running graph-node (default `http://localhost:8020`)
- A running IPFS node (default `http://localhost:5001`)
- The amp-erc20-transfers subgraph deployed (you need its IPFS hash)

## Setup

1. **Deploy the amp subgraph first** and note its IPFS hash:

   ```bash
   cd ../amp-erc20-transfers
   ./upload.sh ethereum tokens.conf
   # Subgraph IPFS Hash: QmAbc123...
   ```

2. **Update the deployment hash** in two places:

   `subgraph.yaml` — set `source.address` to the hash:
   ```yaml
   source:
       address: QmAbc123...
   ```

   `src/mapping.ts` — uncomment and update the import:
   ```typescript
   import { Token as SourceToken, Transfer } from "../generated/subgraph-QmAbc123...";
   ```

3. **Install dependencies and generate types:**

   ```bash
   pnpm install
   pnpm codegen
   ```

   `codegen` fetches the source subgraph's schema from IPFS and generates
   typed entity classes for both the local schema and the source entities.

## Building

```bash
pnpm build
```

## Deploying

```bash
# Create the subgraph (first time only)
pnpm create-local

# Deploy
pnpm deploy-local
```

To use custom endpoints:

```bash
GRAPH_NODE_URL=http://graph.example.com:8020 \
IPFS_URL=http://ipfs.example.com:5001 \
pnpm deploy-local
```

## How it works

The subgraph declares a `kind: subgraph` data source that receives
entity updates from the amp-erc20-transfers subgraph:

- **`handleToken`** — Creates local `Token` entities with address,
  symbol, and decimals whenever the source subgraph produces a Token
  entity.

- **`handleTransfer`** — For each Transfer entity from the source:
  1. Saves an immutable `TransferRecord`
  2. Updates (or creates) the sender's `WalletBalance`, subtracting the
     transfer value
  3. Updates (or creates) the receiver's `WalletBalance`, adding the
     transfer value

`WalletBalance` entities are keyed by the concatenation of the token
address and the wallet address (40 bytes), so each token-wallet pair has
exactly one balance entity.

## File structure

```
src/mapping.ts       AssemblyScript handlers for Token and Transfer
schema.graphql       Local entity definitions
subgraph.yaml        Manifest (update source.address before deploying)
package.json         Scripts and dependencies
tsconfig.json        TypeScript config for AssemblyScript
```

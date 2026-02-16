import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { Token, WalletBalance, TransferRecord } from "../generated/schema";
// After deploying the amp subgraph and running codegen, update <DEPLOYMENT_HASH>
// with the actual IPFS hash from upload.sh output:
//   import { Token as SourceToken, Transfer } from "../generated/subgraph-<DEPLOYMENT_HASH>";

export function handleToken(source: SourceToken): void {
    let token = new Token(source.id);
    token.symbol = source.symbol;
    token.decimals = source.decimals;
    token.save();
}

export function handleTransfer(transfer: Transfer): void {
    // Record transfer
    let record = new TransferRecord(transfer.transactionHash);
    record.token = transfer.token;
    record.from = transfer.from;
    record.to = transfer.to;
    record.value = transfer.value;
    record.blockNumber = transfer.blockNumber;
    record.transactionHash = transfer.transactionHash;
    record.save();

    // Update sender balance (id = token address ++ wallet address)
    let senderId = transfer.token.concat(transfer.from);
    let sender = WalletBalance.load(senderId);
    if (!sender) {
        sender = new WalletBalance(senderId);
        sender.token = transfer.token;
        sender.address = transfer.from;
        sender.balance = BigInt.zero();
        sender.lastUpdatedBlock = BigInt.zero();
    }
    sender.balance = sender.balance.minus(transfer.value);
    sender.lastUpdatedBlock = transfer.blockNumber;
    sender.save();

    // Update receiver balance (id = token address ++ wallet address)
    let receiverId = transfer.token.concat(transfer.to);
    let receiver = WalletBalance.load(receiverId);
    if (!receiver) {
        receiver = new WalletBalance(receiverId);
        receiver.token = transfer.token;
        receiver.address = transfer.to;
        receiver.balance = BigInt.zero();
        receiver.lastUpdatedBlock = BigInt.zero();
    }
    receiver.balance = receiver.balance.plus(transfer.value);
    receiver.lastUpdatedBlock = transfer.blockNumber;
    receiver.save();
}

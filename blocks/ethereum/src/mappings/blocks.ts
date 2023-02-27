import {
    ethereum
} from "@graphprotocol/graph-ts"

import {
    Block, BlockTime
} from "../../generated/schema"

export function handleBlock(block: ethereum.Block): void {
    let id = block.hash
    let blockEntity = new Block(id);
    blockEntity.number = block.number.toI32();
    blockEntity.timestamp = block.timestamp.toI32();
    blockEntity.parentHash = block.parentHash;
    blockEntity.author = block.author;
    blockEntity.difficulty = block.difficulty;
    blockEntity.totalDifficulty = block.totalDifficulty;
    blockEntity.gasUsed = block.gasUsed;
    blockEntity.gasLimit = block.gasLimit;
    blockEntity.receiptsRoot = block.receiptsRoot;
    blockEntity.transactionsRoot = block.transactionsRoot;
    blockEntity.stateRoot = block.stateRoot;
    blockEntity.size = block.size;
    blockEntity.unclesHash = block.unclesHash;
    blockEntity.save();

    let blockHeader = new BlockTime(id);
    blockHeader.number = blockEntity.number;
    blockHeader.timestamp = blockEntity.timestamp;
    blockHeader.save();
}

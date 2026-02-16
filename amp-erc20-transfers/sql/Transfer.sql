SELECT
    sg_source_address() AS token,
    data.dec['from'] AS "from",
    data.dec['to'] AS "to",
    CAST(data.dec['value'] AS NUMERIC(76, 0)) AS value,
    data._block_num AS block_number,
    data.block_hash,
    data.tx_hash AS transaction_hash
FROM
(
    SELECT
        l._block_num,
        l.block_hash,
        l.tx_hash,
        evm_decode(
            l.topic1,
            l.topic2,
            l.topic3,
            l.data,
            sg_event_signature('ERC20', 'Transfer')
        ) AS dec
    FROM
        "__DATASET__".logs l
    WHERE
        l.address = sg_source_address()
        AND l.topic0 = evm_topic(sg_event_signature('ERC20', 'Transfer'))
) AS data

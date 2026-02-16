WITH data AS (
    SELECT
        l._block_num,
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
)
SELECT
    data._block_num,
    sg_source_address() AS token,
    data.dec['from'] AS account,
    0 - CAST(data.dec['value'] AS NUMERIC(76, 0)) AS delta
FROM data
UNION ALL
SELECT
    data._block_num,
    sg_source_address() AS token,
    data.dec['to'] AS account,
    CAST(data.dec['value'] AS NUMERIC(76, 0)) AS delta
FROM data

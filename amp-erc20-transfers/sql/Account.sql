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
SELECT DISTINCT ON (id) _block_num, id FROM (
    SELECT
        data._block_num,
        data.dec['from'] AS id
    FROM data
    UNION ALL
    SELECT
        data._block_num,
        data.dec['to'] AS id
    FROM data
) AS accounts

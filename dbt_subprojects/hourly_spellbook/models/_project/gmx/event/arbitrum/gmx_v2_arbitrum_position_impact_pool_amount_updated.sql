{{
  config(
    schema = 'gmx_v2_arbitrum',
    alias = 'position_impact_pool_amount_updated',
    materialized = 'incremental',
    unique_key = ['tx_hash', 'index'],
    incremental_strategy = 'merge'
    )
}}

{%- set event_name = 'PositionImpactPoolAmountUpdated' -%}
{%- set blockchain_name = 'arbitrum' -%}


WITH evt_data_1 AS (
    SELECT 
        -- Main Variables
        '{{ blockchain_name }}' AS blockchain,
        evt_block_time AS block_time,
        evt_block_number AS block_number, 
        evt_tx_hash AS tx_hash,
        evt_index AS index,
        contract_address,
        eventName AS event_name,
        eventData AS data,
        msgSender AS msg_sender
    FROM {{ source('gmx_v2_arbitrum','EventEmitter_evt_EventLog1')}}
    WHERE eventName = '{{ event_name }}'
    {% if is_incremental() %}
        AND {{ incremental_predicate('evt_block_time') }}
    {% endif %}
)

, evt_data_2 AS (
    SELECT 
        -- Main Variables
        '{{ blockchain_name }}' AS blockchain,
        evt_block_time AS block_time,
        evt_block_number AS block_number, 
        evt_tx_hash AS tx_hash,
        evt_index AS index,
        contract_address,
        eventName AS event_name,
        eventData AS data,
        msgSender AS msg_sender
    FROM {{ source('gmx_v2_arbitrum','EventEmitter_evt_EventLog2')}}
    WHERE eventName = '{{ event_name }}'
    {% if is_incremental() %}
        AND {{ incremental_predicate('evt_block_time') }}
    {% endif %}
)

, evt_data_3 AS (
    SELECT 
        -- Main Variables
        '{{ blockchain_name }}' AS blockchain,
        evt_block_time AS block_time,
        evt_block_number AS block_number, 
        evt_tx_hash AS tx_hash,
        evt_index AS index,
        contract_address,
        eventName AS event_name,
        eventData AS data,
        msgSender AS msg_sender
    FROM {{ source('gmx_v2_arbitrum','EventEmitter_evt_EventLog')}}
    WHERE eventName = '{{ event_name }}'
    {% if is_incremental() %}
        AND {{ incremental_predicate('evt_block_time') }}
    {% endif %}
)

-- unite 3 tables
, evt_data AS (
    SELECT * 
    FROM evt_data_1
    UNION
    SELECT *
    FROM evt_data_2
    UNION 
    SELECT *
    FROM evt_data_3
)

, parsed_data AS (
    SELECT
        tx_hash,
        index, 
        json_query(data, 'lax $.addressItems' OMIT QUOTES) AS address_items,
        json_query(data, 'lax $.uintItems' OMIT QUOTES) AS uint_items,
        json_query(data, 'lax $.intItems' OMIT QUOTES) AS int_items
    FROM
        evt_data
)
, address_items_parsed AS (
    SELECT 
        tx_hash,
        index,
        json_extract_scalar(CAST(item AS VARCHAR), '$.key') AS key_name,
        json_extract_scalar(CAST(item AS VARCHAR), '$.value') AS value
    FROM 
        parsed_data,
        UNNEST(
            CAST(json_extract(address_items, '$.items') AS ARRAY(JSON))
        ) AS t(item)
)
, uint_items_parsed AS (
    SELECT 
        tx_hash,
        index,
        json_extract_scalar(CAST(item AS VARCHAR), '$.key') AS key_name,
        json_extract_scalar(CAST(item AS VARCHAR), '$.value') AS value
    FROM 
        parsed_data,
        UNNEST(
            CAST(json_extract(uint_items, '$.items') AS ARRAY(JSON))
        ) AS t(item)
)
, int_items_parsed AS (
    SELECT 
        tx_hash,
        index,
        json_extract_scalar(CAST(item AS VARCHAR), '$.key') AS key_name,
        json_extract_scalar(CAST(item AS VARCHAR), '$.value') AS value
    FROM 
        parsed_data,
        UNNEST(
            CAST(json_extract(int_items, '$.items') AS ARRAY(JSON))
        ) AS t(item)
)
, combined AS (
    SELECT *
    FROM address_items_parsed
    UNION ALL      
    SELECT *
    FROM uint_items_parsed
    UNION ALL    
    SELECT *
    FROM int_items_parsed
)
, evt_data_parsed AS (
    SELECT
        tx_hash,
        index,
        MAX(CASE WHEN key_name = 'market' THEN value END) AS market,
        MAX(CASE WHEN key_name = 'delta' THEN value END) AS delta,
        MAX(CASE WHEN key_name = 'nextValue' THEN value END) AS next_value
    FROM
        combined
    GROUP BY tx_hash, index
)

-- full data 
, full_data AS (
    SELECT 
        ED.blockchain,
        block_time,
        DATE(block_time) AS block_date,
        block_number,
        ED.tx_hash,
        ED.index,
        ED.contract_address,
        event_name,
        msg_sender,

        from_hex(EDP.market) AS market,
        TRY_CAST(EDP.next_value AS DOUBLE) / POWER(10, MD.index_token_decimals) AS next_value,
        TRY_CAST(EDP.delta AS DOUBLE) / POWER(10, MD.index_token_decimals) AS delta
        
    FROM evt_data AS ED
    LEFT JOIN evt_data_parsed AS EDP
        ON ED.tx_hash = EDP.tx_hash
        AND ED.index = EDP.index
    LEFT JOIN {{ ref('gmx_v2_arbitrum_markets_data') }} AS MD
        ON from_hex(EDP.market) = MD.market
)

--can be removed once decoded tables are fully denormalized
{{
    add_tx_columns(
        model_cte = 'full_data'
        , blockchain = blockchain_name
        , columns = ['from', 'to', 'index']
    )
}}


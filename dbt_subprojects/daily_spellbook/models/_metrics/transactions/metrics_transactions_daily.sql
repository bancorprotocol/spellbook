{{ config(
        schema = 'metrics'
        , alias = 'transactions_daily'
        , materialized = 'view'
        )
}}

{% set chains = [
     
    'abstract'
    , 'apechain'
    , 'arbitrum'
    , 'avalanche_c'
    , 'b3'
    , 'base'
    , 'berachain'
    , 'bitcoin'
    , 'blast'
    , 'bnb'
    , 'bob'
    , 'boba'
    , 'celo'
    , 'corn'
    , 'degen'
    , 'ethereum'
    , 'fantom'
    , 'flare'
    , 'gnosis'
    , 'ink'
    , 'kaia'
    , 'lens'
    , 'linea'
    , 'mantle'
    , 'nova'
    , 'opbnb'
    , 'optimism'
    , 'plume'
    , 'polygon'
    , 'ronin'
    , 'scroll'
    , 'sei'
    , 'shape'
    , 'solana'
    , 'sonic'
    , 'sophon'
    , 'ton'
    , 'tron'
    , 'unichain'
    , 'worldchain'
    , 'xrpl'
    , 'zkevm'
    , 'zksync'
    , 'zora'
] %}

SELECT *
FROM (
        {% for blockchain in chains %}
        SELECT
        blockchain
        ,block_date
        ,tx_count
        FROM {{ ref('metrics_' + blockchain + '_transactions_daily') }}
        {% if not loop.last %}
        UNION ALL
        {% endif %}
        {% endfor %}
)

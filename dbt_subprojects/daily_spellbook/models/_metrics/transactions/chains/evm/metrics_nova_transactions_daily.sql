{% set blockchain = 'nova' %}

{{ config(
        schema = 'metrics_' + blockchain
        , alias = 'transactions_daily'
        , materialized = 'incremental'
        , file_format = 'delta'
        , incremental_strategy = 'merge'
        , unique_key = ['blockchain', 'block_date']
        , incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_date')]
        )
}}


{{ metrics_transactions_evm(blockchain) }}

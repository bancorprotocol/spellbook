{{ config(
        schema = 'tokens_bnb',
        alias = 'balances_daily',
        materialized = 'view',
        post_hook = '{{ expose_spells(\'["bnb"]\',
                                    "sector",
                                    "balances",
                                    \'["0xRob"]\') }}'
        )
}}

{{
balances_daily(
    balances_daily_agg = ref('tokens_bnb_balances_daily_agg'),
    start_date = '2020-08-29',
    native_token = 'BNB'
)
}}

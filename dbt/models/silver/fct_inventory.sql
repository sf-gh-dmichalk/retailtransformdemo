{{
  config(
    materialized='incremental',
    unique_key='inventory_sk',
    incremental_strategy='merge'
  )
}}

WITH inv AS (
    SELECT * FROM {{ ref('stg_retailer_inventory') }}
    {% if is_incremental() %}
    WHERE loaded_at > (SELECT MAX(_loaded_at) FROM {{ this }})
    {% endif %}
),

stores AS (
    SELECT * FROM {{ source('ref', 'DIM_STORE') }}
)

SELECT
    {{ dbt_utils.generate_surrogate_key(['inv.RETAILER_CODE', 'st.STORE_KEY', 'inv.UPC', 'inv.SNAPSHOT_DATE']) }} AS inventory_sk,
    inv.RETAILER_CODE,
    st.STORE_KEY,
    inv.UPC,
    inv.SNAPSHOT_DATE,
    inv.ON_HAND_QTY,
    inv.IN_TRANSIT_QTY,
    inv.ON_ORDER_QTY,
    inv.ON_HAND_QTY + inv.IN_TRANSIT_QTY + inv.ON_ORDER_QTY AS total_pipeline_qty,
    inv.LOADED_AT AS _loaded_at
FROM inv
LEFT JOIN stores st
    ON inv.RETAILER_CODE = st.RETAILER_CODE
    AND inv.STORE_ID = st.STORE_ID

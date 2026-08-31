-- Staging view over raw inventory snapshots
SELECT
    RETAILER_CODE,
    STORE_ID,
    UPC,
    TRY_TO_DATE(SNAPSHOT_DATE) AS snapshot_date,
    TRY_TO_NUMBER(ON_HAND_QTY) AS on_hand_qty,
    TRY_TO_NUMBER(IN_TRANSIT_QTY) AS in_transit_qty,
    TRY_TO_NUMBER(ON_ORDER_QTY) AS on_order_qty,
    _FILE_NAME AS source_file,
    _LOADED_AT AS loaded_at
FROM {{ source('raw', 'RETAILER_INVENTORY') }}
WHERE TRY_TO_DATE(SNAPSHOT_DATE) IS NOT NULL
  AND TRY_TO_NUMBER(ON_HAND_QTY) >= 0

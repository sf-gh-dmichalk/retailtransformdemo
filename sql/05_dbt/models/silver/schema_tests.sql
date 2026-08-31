-------------------------------------------------------------------------------
-- dbt Tests & Schema (schema.yml equivalent)
-- Demonstrates: dbt testing for data quality and referential integrity
-------------------------------------------------------------------------------
-- This file shows the tests that dbt would run. In practice these live in
-- schema.yml. Here we express them as SQL assertions for the demo.
-------------------------------------------------------------------------------

-- TEST: fct_pos_sales.pos_sale_sk is unique and not null
SELECT pos_sale_sk, COUNT(*)
FROM SILVER.FCT_POS_SALES
GROUP BY 1
HAVING COUNT(*) > 1;
-- Expected: 0 rows (test passes if empty)

-- TEST: fct_pos_sales.store_key references dim_store
SELECT f.store_key
FROM SILVER.FCT_POS_SALES f
LEFT JOIN REF.DIM_STORE s ON f.store_key = s.store_key
WHERE s.store_key IS NULL
  AND f.store_key IS NOT NULL;
-- Expected: 0 rows

-- TEST: fct_pos_sales.units_sold >= 0 (accepted values)
SELECT *
FROM SILVER.FCT_POS_SALES
WHERE units_sold < 0;
-- Expected: 0 rows

-- TEST: fct_inventory.on_hand_qty >= 0
SELECT *
FROM SILVER.FCT_INVENTORY
WHERE on_hand_qty < 0;
-- Expected: 0 rows

-- TEST: fct_promotions.start_date <= end_date
SELECT *
FROM SILVER.FCT_PROMOTIONS
WHERE start_date > end_date;
-- Expected: 0 rows

-- TEST: No orphan promos (all promo materials exist in product master)
SELECT pc.material_number
FROM SILVER.FCT_PROMOTIONS pc
LEFT JOIN REF.DIM_PRODUCT p ON pc.material_number = p.material_number
WHERE p.material_number IS NULL;
-- Expected: 0 rows

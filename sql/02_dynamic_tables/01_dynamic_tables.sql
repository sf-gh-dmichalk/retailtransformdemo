-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Dynamic Tables (Gold Layer)
-- Declarative, incremental analytics — Snowflake manages refresh
-- Demo segment: 0:15–0:30
-- Run as: DEMO_TRANSFORMER
-------------------------------------------------------------------------------

USE ROLE DEMO_TRANSFORMER;
USE DATABASE RETAIL_TRANSFORM_DEMO;
USE WAREHOUSE DEMO_ANALYTICS_WH;

-------------------------------------------------------------------------------
-- DYNAMIC TABLE 1: Conformed Sales Entity
-- Demonstrates: DT incrementally refreshing from a raw SAP staging table
--   to a clean, joined entity table — no manual scheduling required.
-- This is the primary demo Dynamic Table mentioned in the agenda.
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.CONFORMED_SALES_ENTITY
    TARGET_LAG = '30 minutes'
    WAREHOUSE = DEMO_ANALYTICS_WH
AS
SELECT
    s.RECORD_ID                                     AS sales_order_id,
    s.SALES_ORG,
    s.DISTRIBUTION_CHANNEL,
    s.ORDER_TYPE,
    s.ORDER_DATE,
    s.DELIVERY_DATE,
    s.PLANT,
    -- Product dimension join
    p.MATERIAL_NUMBER,
    p.UPC,
    p.PRODUCT_NAME,
    p.BRAND,
    p.CATEGORY,
    p.SUB_CATEGORY,
    -- Quantities normalized
    s.ORDER_QTY,
    s.ORDER_QTY_UOM,
    s.ORDER_QTY * p.UNIT_WEIGHT_KG                  AS ORDER_WEIGHT_KG,
    -- Financials
    s.NET_VALUE,
    s.CURRENCY,
    s.NET_VALUE * COALESCE(fx.RATE_TO_USD, 1)       AS NET_VALUE_USD,
    -- Customer/retailer mapping
    s.CUSTOMER_NUMBER,
    -- Metadata
    s._STAGED_AT                                    AS source_timestamp
FROM STAGING.SAP_SALES_ORDERS_STAGED s
LEFT JOIN REF.DIM_PRODUCT p
    ON s.MATERIAL_NUMBER = p.MATERIAL_NUMBER
    AND s.ORDER_DATE BETWEEN p.EFFECTIVE_FROM AND p.EFFECTIVE_TO
LEFT JOIN REF.DIM_FX_RATES fx
    ON s.ORDER_DATE = fx.RATE_DATE
    AND s.CURRENCY = fx.CURRENCY_CODE;

-------------------------------------------------------------------------------
-- DYNAMIC TABLE 2: Weekly Store Demand
-- Demonstrates: multi-level DT pipeline (depends on CONFORMED_SALES_ENTITY)
-- Use case: demand planning input — weekly brand/store aggregation
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.WEEKLY_STORE_DEMAND
    TARGET_LAG = '1 hour'
    WAREHOUSE = DEMO_ANALYTICS_WH
AS
SELECT
    DATE_TRUNC('WEEK', pos.TRANSACTION_DATE)        AS week_start,
    st.RETAILER_NAME,
    st.REGION,
    st.STORE_NAME,
    st.STORE_ID,
    p.BRAND,
    p.CATEGORY,
    p.SUB_CATEGORY,
    SUM(pos.UNITS_SOLD)                             AS total_units,
    SUM(pos.UNITS_SOLD * p.UNIT_WEIGHT_KG)          AS total_kg,
    SUM(pos.REVENUE_USD)                            AS total_revenue_usd,
    COUNT(DISTINCT pos.TRANSACTION_DATE)            AS selling_days,
    total_kg / NULLIF(selling_days, 0)              AS avg_daily_kg
FROM SILVER.FCT_POS_SALES pos
JOIN REF.DIM_STORE st    ON pos.STORE_KEY = st.STORE_KEY
JOIN REF.DIM_PRODUCT p   ON pos.UPC = p.UPC AND p.IS_CURRENT = TRUE
GROUP BY ALL;

-------------------------------------------------------------------------------
-- DYNAMIC TABLE 3: Promotional Lift Analysis
-- Demonstrates: complex business logic as a DT — promo vs baseline comparison
-- Use case: trade promotion effectiveness / ROI
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.PROMO_LIFT_ANALYSIS
    TARGET_LAG = '2 hours'
    WAREHOUSE = DEMO_ANALYTICS_WH
AS
WITH promo_sales AS (
    SELECT
        pc.PROMO_ID,
        pc.PROMO_NAME,
        pc.PROMO_MECHANIC,
        pc.RETAILER_CODE,
        pc.TRADE_SPEND_USD,
        pc.DISCOUNT_PCT,
        pc.START_DATE,
        pc.END_DATE,
        DATEDIFF('day', pc.START_DATE, pc.END_DATE) + 1 AS promo_days,
        p.BRAND,
        p.CATEGORY,
        SUM(pos.UNITS_SOLD)                              AS promo_units,
        SUM(pos.UNITS_SOLD * p.UNIT_WEIGHT_KG)           AS promo_kg,
        SUM(pos.REVENUE_USD)                             AS promo_revenue
    FROM SILVER.FCT_PROMOTIONS pc
    JOIN REF.DIM_PRODUCT p       ON pc.MATERIAL_NUMBER = p.MATERIAL_NUMBER AND p.IS_CURRENT = TRUE
    JOIN SILVER.FCT_POS_SALES pos
        ON pos.UPC = p.UPC
        AND pos.RETAILER_CODE = pc.RETAILER_CODE
        AND pos.TRANSACTION_DATE BETWEEN pc.START_DATE AND pc.END_DATE
    GROUP BY ALL
),
baseline AS (
    SELECT
        pos.UPC,
        pos.RETAILER_CODE,
        AVG(pos.UNITS_SOLD * p.UNIT_WEIGHT_KG)          AS baseline_daily_kg
    FROM SILVER.FCT_POS_SALES pos
    JOIN REF.DIM_PRODUCT p ON pos.UPC = p.UPC AND p.IS_CURRENT = TRUE
    LEFT JOIN SILVER.FCT_PROMOTIONS pc
        ON pos.UPC = p.UPC
        AND pos.RETAILER_CODE = pc.RETAILER_CODE
        AND pos.TRANSACTION_DATE BETWEEN pc.START_DATE AND pc.END_DATE
    WHERE pc.PROMO_ID IS NULL  -- non-promo days only
    GROUP BY 1, 2
)
SELECT
    ps.PROMO_ID,
    ps.PROMO_NAME,
    ps.PROMO_MECHANIC,
    ps.RETAILER_CODE,
    ps.BRAND,
    ps.CATEGORY,
    ps.START_DATE,
    ps.END_DATE,
    ps.promo_days,
    ps.promo_kg,
    ps.promo_kg / NULLIF(ps.promo_days, 0)                                AS promo_daily_kg,
    b.baseline_daily_kg,
    (promo_daily_kg - b.baseline_daily_kg)
        / NULLIF(b.baseline_daily_kg, 0)                                  AS lift_pct,
    ps.promo_revenue,
    ps.TRADE_SPEND_USD,
    (ps.promo_revenue - (b.baseline_daily_kg * ps.promo_days * 
        (SELECT AVG_PRICE_PER_KG FROM REF.DIM_PRODUCT dp 
         WHERE dp.BRAND = ps.BRAND AND dp.IS_CURRENT LIMIT 1)))           AS incremental_revenue_est,
    incremental_revenue_est / NULLIF(ps.TRADE_SPEND_USD, 0)               AS promo_roi
FROM promo_sales ps
LEFT JOIN baseline b
    ON ps.RETAILER_CODE = b.RETAILER_CODE;

-------------------------------------------------------------------------------
-- DYNAMIC TABLE 4: On-Shelf Availability Scorecard
-- Demonstrates: DT with tight SLA (30 min) for operational monitoring
-- Use case: out-of-stock alerts, days-of-supply by store/product
-------------------------------------------------------------------------------
CREATE OR REPLACE DYNAMIC TABLE GOLD.ON_SHELF_AVAILABILITY
    TARGET_LAG = '30 minutes'
    WAREHOUSE = DEMO_ANALYTICS_WH
AS
SELECT
    inv.SNAPSHOT_DATE,
    st.RETAILER_NAME,
    st.REGION,
    st.STORE_NAME,
    st.STORE_ID,
    p.BRAND,
    p.CATEGORY,
    p.PRODUCT_NAME,
    inv.ON_HAND_QTY,
    inv.IN_TRANSIT_QTY,
    -- Calculate avg daily demand from last 28 days of POS
    demand.avg_daily_units,
    -- Days of supply
    inv.ON_HAND_QTY / NULLIF(demand.avg_daily_units, 0)                   AS days_of_supply,
    (inv.ON_HAND_QTY + inv.IN_TRANSIT_QTY) / NULLIF(demand.avg_daily_units, 0)
                                                                          AS days_of_supply_incl_transit,
    -- Status classification
    CASE
        WHEN inv.ON_HAND_QTY = 0                    THEN 'OUT_OF_STOCK'
        WHEN days_of_supply < 3                     THEN 'CRITICAL'
        WHEN days_of_supply < 7                     THEN 'LOW'
        WHEN days_of_supply > 28                    THEN 'OVERSTOCK'
        ELSE 'HEALTHY'
    END                                                                    AS availability_status
FROM SILVER.FCT_INVENTORY inv
JOIN REF.DIM_STORE st    ON inv.STORE_KEY = st.STORE_KEY
JOIN REF.DIM_PRODUCT p   ON inv.UPC = p.UPC AND p.IS_CURRENT = TRUE
LEFT JOIN (
    SELECT
        STORE_KEY,
        UPC,
        AVG(UNITS_SOLD) AS avg_daily_units
    FROM SILVER.FCT_POS_SALES
    WHERE TRANSACTION_DATE >= DATEADD('day', -28, CURRENT_DATE())
    GROUP BY 1, 2
) demand ON inv.STORE_KEY = demand.STORE_KEY AND inv.UPC = demand.UPC;

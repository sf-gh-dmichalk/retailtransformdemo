-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Stored Procedures (Business Logic)
-- Encapsulates complex transformation logic that cannot be a single query
-- Demo segment: 0:15–0:30
-- Run as: DEMO_ENGINEER
-------------------------------------------------------------------------------

USE ROLE DEMO_ENGINEER;
USE DATABASE RETAIL_TRANSFORM_DEMO;
USE WAREHOUSE DEMO_ETL_WH;

-------------------------------------------------------------------------------
-- PROCEDURE 1: Stage SAP Sales Orders
-- Reads from the stream, type-casts, validates, and inserts into staging
-- Demonstrates: encapsulating multi-step logic with error handling
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BRONZE.SP_STAGE_SAP_SALES_ORDERS()
    RETURNS VARCHAR
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
BEGIN
    LET row_count INTEGER := 0;
    LET reject_count INTEGER := 0;

    -- Insert valid rows into staging (type-cast from VARCHAR to proper types)
    INSERT INTO STAGING.SAP_SALES_ORDERS_STAGED (
        RECORD_ID, SALES_ORG, DISTRIBUTION_CHANNEL, MATERIAL_NUMBER,
        PLANT, CUSTOMER_NUMBER, ORDER_DATE, DELIVERY_DATE,
        ORDER_QTY, ORDER_QTY_UOM, NET_VALUE, CURRENCY, ORDER_TYPE,
        _SOURCE_FILE, _LOADED_AT
    )
    SELECT
        RECORD_ID,
        SALES_ORG,
        DISTRIBUTION_CHANNEL,
        MATERIAL_NUMBER,
        PLANT,
        CUSTOMER_NUMBER,
        TRY_TO_DATE(ORDER_DATE, 'YYYYMMDD'),
        TRY_TO_DATE(DELIVERY_DATE, 'YYYYMMDD'),
        TRY_TO_NUMBER(ORDER_QTY, 18, 3),
        ORDER_QTY_UOM,
        TRY_TO_NUMBER(NET_VALUE, 18, 2),
        CURRENCY,
        ORDER_TYPE,
        _FILE_NAME,
        _LOADED_AT
    FROM RAW.SAP_SALES_ORDERS_STREAM
    WHERE TRY_TO_DATE(ORDER_DATE, 'YYYYMMDD') IS NOT NULL
      AND TRY_TO_NUMBER(ORDER_QTY, 18, 3) IS NOT NULL
      AND TRY_TO_NUMBER(NET_VALUE, 18, 2) IS NOT NULL
      AND MATERIAL_NUMBER IS NOT NULL;

    row_count := SQLROWCOUNT;

    -- Quarantine rejected rows (failed type casting or null critical fields)
    INSERT INTO BRONZE.SAP_ORDERS_REJECTED (
        RECORD_ID, RAW_ORDER_DATE, RAW_ORDER_QTY, RAW_NET_VALUE,
        MATERIAL_NUMBER, REJECTION_REASON, _REJECTED_AT
    )
    SELECT
        RECORD_ID,
        ORDER_DATE,
        ORDER_QTY,
        NET_VALUE,
        MATERIAL_NUMBER,
        CASE
            WHEN TRY_TO_DATE(ORDER_DATE, 'YYYYMMDD') IS NULL THEN 'INVALID_DATE'
            WHEN TRY_TO_NUMBER(ORDER_QTY, 18, 3) IS NULL THEN 'INVALID_QUANTITY'
            WHEN TRY_TO_NUMBER(NET_VALUE, 18, 2) IS NULL THEN 'INVALID_NET_VALUE'
            WHEN MATERIAL_NUMBER IS NULL THEN 'NULL_MATERIAL'
            ELSE 'UNKNOWN'
        END,
        CURRENT_TIMESTAMP()
    FROM RAW.SAP_SALES_ORDERS_STREAM
    WHERE TRY_TO_DATE(ORDER_DATE, 'YYYYMMDD') IS NULL
       OR TRY_TO_NUMBER(ORDER_QTY, 18, 3) IS NULL
       OR TRY_TO_NUMBER(NET_VALUE, 18, 2) IS NULL
       OR MATERIAL_NUMBER IS NULL;

    reject_count := SQLROWCOUNT;

    RETURN 'Staged: ' || :row_count || ' rows. Rejected: ' || :reject_count || ' rows.';
END;

-------------------------------------------------------------------------------
-- PROCEDURE 2: Process Retailer POS Stream
-- Normalizes retailer-specific date formats, validates UPCs, maps store codes
-- Demonstrates: retailer-specific logic that varies by source system
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BRONZE.SP_PROCESS_RETAILER_POS()
    RETURNS VARCHAR
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
BEGIN
    LET row_count INTEGER := 0;

    -- Normalize dates (each retailer sends different formats)
    -- Validate UPC length (must be 12 or 13 digits)
    -- Join to store reference for standardized store key
    INSERT INTO BRONZE.POS_CLEANSED (
        RETAILER_CODE, STORE_KEY, UPC, TRANSACTION_DATE,
        UNITS_SOLD, REVENUE, CURRENCY_CODE, REVENUE_USD,
        PROMO_FLAG, _SOURCE_FILE, _LOADED_AT
    )
    SELECT
        pos.RETAILER_CODE,
        st.STORE_KEY,
        pos.UPC,
        -- Retailer-specific date parsing
        CASE pos.RETAILER_CODE
            WHEN 'WMT' THEN TRY_TO_DATE(pos.TRANSACTION_DATE, 'YYYY-MM-DD')
            WHEN 'KRO' THEN TRY_TO_DATE(pos.TRANSACTION_DATE, 'MM/DD/YYYY')
            WHEN 'TGT' THEN TRY_TO_DATE(pos.TRANSACTION_DATE, 'YYYYMMDD')
            ELSE TRY_TO_DATE(pos.TRANSACTION_DATE)
        END                                                 AS TRANSACTION_DATE,
        TRY_TO_NUMBER(pos.UNITS_SOLD)                       AS UNITS_SOLD,
        TRY_TO_NUMBER(pos.REVENUE, 18, 2)                   AS REVENUE,
        pos.CURRENCY_CODE,
        TRY_TO_NUMBER(pos.REVENUE, 18, 2)
            * COALESCE(fx.RATE_TO_USD, 1)                   AS REVENUE_USD,
        pos.PROMO_FLAG = 'Y'                                AS PROMO_FLAG,
        pos._FILE_NAME,
        pos._LOADED_AT
    FROM RAW.RETAILER_POS_STREAM pos
    LEFT JOIN REF.DIM_STORE st
        ON pos.RETAILER_CODE = st.RETAILER_CODE
        AND pos.STORE_ID = st.STORE_ID
    LEFT JOIN REF.DIM_FX_RATES fx
        ON fx.RATE_DATE = DATE_TRUNC('MONTH',
            CASE pos.RETAILER_CODE
                WHEN 'WMT' THEN TRY_TO_DATE(pos.TRANSACTION_DATE, 'YYYY-MM-DD')
                WHEN 'KRO' THEN TRY_TO_DATE(pos.TRANSACTION_DATE, 'MM/DD/YYYY')
                WHEN 'TGT' THEN TRY_TO_DATE(pos.TRANSACTION_DATE, 'YYYYMMDD')
                ELSE TRY_TO_DATE(pos.TRANSACTION_DATE)
            END)
        AND fx.CURRENCY_CODE = pos.CURRENCY_CODE
    WHERE LENGTH(REGEXP_REPLACE(pos.UPC, '[^0-9]', '')) IN (12, 13)
      AND TRY_TO_NUMBER(pos.UNITS_SOLD) >= 0;

    row_count := SQLROWCOUNT;
    RETURN 'Processed ' || :row_count || ' POS records.';
END;

-------------------------------------------------------------------------------
-- PROCEDURE 3: Process Inventory Stream
-- Validates quantities, classifies availability status
-------------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE BRONZE.SP_PROCESS_INVENTORY()
    RETURNS VARCHAR
    LANGUAGE SQL
    EXECUTE AS CALLER
AS
BEGIN
    LET row_count INTEGER := 0;

    INSERT INTO BRONZE.INVENTORY_CLEANSED (
        RETAILER_CODE, STORE_KEY, UPC, SNAPSHOT_DATE,
        ON_HAND_QTY, IN_TRANSIT_QTY, ON_ORDER_QTY,
        _SOURCE_FILE, _LOADED_AT
    )
    SELECT
        inv.RETAILER_CODE,
        st.STORE_KEY,
        inv.UPC,
        TRY_TO_DATE(inv.SNAPSHOT_DATE),
        TRY_TO_NUMBER(inv.ON_HAND_QTY),
        TRY_TO_NUMBER(inv.IN_TRANSIT_QTY),
        TRY_TO_NUMBER(inv.ON_ORDER_QTY),
        inv._FILE_NAME,
        inv._LOADED_AT
    FROM RAW.RETAILER_INVENTORY_STREAM inv
    LEFT JOIN REF.DIM_STORE st
        ON inv.RETAILER_CODE = st.RETAILER_CODE
        AND inv.STORE_ID = st.STORE_ID
    WHERE TRY_TO_DATE(inv.SNAPSHOT_DATE) IS NOT NULL
      AND TRY_TO_NUMBER(inv.ON_HAND_QTY) >= 0;

    row_count := SQLROWCOUNT;
    RETURN 'Processed ' || :row_count || ' inventory records.';
END;

-------------------------------------------------------------------------------
-- Supporting rejection/quarantine table
-------------------------------------------------------------------------------
USE SCHEMA BRONZE;

CREATE OR REPLACE TABLE BRONZE.SAP_ORDERS_REJECTED (
    RECORD_ID           VARCHAR(50),
    RAW_ORDER_DATE      VARCHAR(20),
    RAW_ORDER_QTY       VARCHAR(20),
    RAW_NET_VALUE       VARCHAR(20),
    MATERIAL_NUMBER     VARCHAR(20),
    REJECTION_REASON    VARCHAR(50),
    _REJECTED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Bronze output tables (targets of the stored procedures above)
CREATE OR REPLACE TABLE BRONZE.POS_CLEANSED (
    RETAILER_CODE       VARCHAR(20),
    STORE_KEY           NUMBER,
    UPC                 VARCHAR(14),
    TRANSACTION_DATE    DATE,
    UNITS_SOLD          NUMBER(18,0),
    REVENUE             NUMBER(18,2),
    CURRENCY_CODE       VARCHAR(5),
    REVENUE_USD         NUMBER(18,2),
    PROMO_FLAG          BOOLEAN,
    _SOURCE_FILE        VARCHAR(500),
    _LOADED_AT          TIMESTAMP_NTZ
);

CREATE OR REPLACE TABLE BRONZE.INVENTORY_CLEANSED (
    RETAILER_CODE       VARCHAR(20),
    STORE_KEY           NUMBER,
    UPC                 VARCHAR(14),
    SNAPSHOT_DATE       DATE,
    ON_HAND_QTY         NUMBER(18,0),
    IN_TRANSIT_QTY      NUMBER(18,0),
    ON_ORDER_QTY        NUMBER(18,0),
    _SOURCE_FILE        VARCHAR(500),
    _LOADED_AT          TIMESTAMP_NTZ
);

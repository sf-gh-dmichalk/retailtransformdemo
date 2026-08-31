-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Raw & Staging Tables
-- Represents data as it arrives from SAP and retailer feeds
-- Run as: DEMO_ENGINEER
-------------------------------------------------------------------------------

USE ROLE DEMO_ENGINEER;
USE DATABASE RETAIL_TRANSFORM_DEMO;
USE WAREHOUSE DEMO_ETL_WH;

-------------------------------------------------------------------------------
-- RAW SCHEMA: Landing tables (append-only, minimal typing)
-------------------------------------------------------------------------------
USE SCHEMA RAW;

-- SAP sales orders (primary transactional source)
CREATE OR REPLACE TABLE RAW.SAP_SALES_ORDERS (
    RECORD_ID           VARCHAR(50),
    SALES_ORG           VARCHAR(10),
    DISTRIBUTION_CHANNEL VARCHAR(10),
    MATERIAL_NUMBER     VARCHAR(20),
    PLANT               VARCHAR(10),
    CUSTOMER_NUMBER     VARCHAR(20),
    ORDER_DATE          VARCHAR(20),
    DELIVERY_DATE       VARCHAR(20),
    ORDER_QTY           VARCHAR(20),
    ORDER_QTY_UOM       VARCHAR(10),
    NET_VALUE           VARCHAR(20),
    CURRENCY            VARCHAR(5),
    ORDER_TYPE          VARCHAR(10),
    _FILE_NAME          VARCHAR(500),
    _LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Retailer POS sell-through data
CREATE OR REPLACE TABLE RAW.RETAILER_POS (
    RETAILER_CODE       VARCHAR(20),
    STORE_ID            VARCHAR(30),
    UPC                 VARCHAR(14),
    TRANSACTION_DATE    VARCHAR(20),
    UNITS_SOLD          VARCHAR(20),
    REVENUE             VARCHAR(20),
    CURRENCY_CODE       VARCHAR(5),
    PROMO_FLAG          VARCHAR(5),
    _FILE_NAME          VARCHAR(500),
    _LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Inventory snapshots from retailers
CREATE OR REPLACE TABLE RAW.RETAILER_INVENTORY (
    RETAILER_CODE       VARCHAR(20),
    STORE_ID            VARCHAR(30),
    UPC                 VARCHAR(14),
    SNAPSHOT_DATE       VARCHAR(20),
    ON_HAND_QTY         VARCHAR(20),
    IN_TRANSIT_QTY      VARCHAR(20),
    ON_ORDER_QTY        VARCHAR(20),
    _FILE_NAME          VARCHAR(500),
    _LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Promotional calendar from trade marketing
CREATE OR REPLACE TABLE RAW.PROMO_CALENDAR (
    PROMO_ID            VARCHAR(30),
    PROMO_NAME          VARCHAR(200),
    RETAILER_CODE       VARCHAR(20),
    MATERIAL_NUMBER     VARCHAR(20),
    START_DATE          VARCHAR(20),
    END_DATE            VARCHAR(20),
    PROMO_MECHANIC      VARCHAR(50),
    DISCOUNT_PCT        VARCHAR(10),
    TRADE_SPEND_USD     VARCHAR(20),
    _FILE_NAME          VARCHAR(500),
    _LOADED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-------------------------------------------------------------------------------
-- STAGING SCHEMA: Typed, deduplicated staging for stream/task pattern
-------------------------------------------------------------------------------
USE SCHEMA STAGING;

-- Typed version of SAP sales orders (target of the CDC stream demo)
CREATE OR REPLACE TABLE STAGING.SAP_SALES_ORDERS_STAGED (
    RECORD_ID               VARCHAR(50)     NOT NULL,
    SALES_ORG               VARCHAR(10),
    DISTRIBUTION_CHANNEL    VARCHAR(10),
    MATERIAL_NUMBER         VARCHAR(20),
    PLANT                   VARCHAR(10),
    CUSTOMER_NUMBER         VARCHAR(20),
    ORDER_DATE              DATE,
    DELIVERY_DATE           DATE,
    ORDER_QTY               NUMBER(18,3),
    ORDER_QTY_UOM           VARCHAR(10),
    NET_VALUE               NUMBER(18,2),
    CURRENCY                VARCHAR(5),
    ORDER_TYPE              VARCHAR(10),
    _SOURCE_FILE            VARCHAR(500),
    _LOADED_AT              TIMESTAMP_NTZ,
    _STAGED_AT              TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-------------------------------------------------------------------------------
-- REF SCHEMA: Master/reference data
-------------------------------------------------------------------------------
USE SCHEMA REF;

-- Product master (sourced from SAP material master)
CREATE OR REPLACE TABLE REF.DIM_PRODUCT (
    MATERIAL_NUMBER     VARCHAR(20)     NOT NULL,
    UPC                 VARCHAR(14),
    PRODUCT_NAME        VARCHAR(200),
    BRAND               VARCHAR(50),
    CATEGORY            VARCHAR(100),
    SUB_CATEGORY        VARCHAR(100),
    UNIT_WEIGHT_KG      NUMBER(10,4),
    PACK_SIZE           NUMBER(5,0),
    AVG_PRICE_PER_KG    NUMBER(10,2),
    EFFECTIVE_FROM      DATE,
    EFFECTIVE_TO        DATE            DEFAULT '9999-12-31',
    IS_CURRENT          BOOLEAN         DEFAULT TRUE
);

-- Store master / retailer crosswalk
CREATE OR REPLACE TABLE REF.DIM_STORE (
    STORE_KEY           NUMBER AUTOINCREMENT,
    RETAILER_CODE       VARCHAR(20)     NOT NULL,
    RETAILER_NAME       VARCHAR(50),
    STORE_ID            VARCHAR(30)     NOT NULL,
    STORE_NAME          VARCHAR(200),
    CITY                VARCHAR(100),
    STATE               VARCHAR(50),
    REGION              VARCHAR(50),
    COUNTRY             VARCHAR(5)      DEFAULT 'US'
);

-- FX rates (daily, sourced from treasury)
CREATE OR REPLACE TABLE REF.DIM_FX_RATES (
    RATE_DATE           DATE            NOT NULL,
    CURRENCY_CODE       VARCHAR(5)      NOT NULL,
    RATE_TO_USD         NUMBER(18,6)
);

-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Tasks (Event-Driven Orchestration)
-- DAG of tasks triggered by stream data availability
-- Demo segment: 0:15–0:30
-- Run as: DEMO_ENGINEER
-------------------------------------------------------------------------------

USE ROLE DEMO_ENGINEER;
USE DATABASE RETAIL_TRANSFORM_DEMO;
USE WAREHOUSE DEMO_ETL_WH;

-------------------------------------------------------------------------------
-- ROOT TASK: SAP Sales Order Processing
-- Fires when new SAP records land in the raw table
-- Pattern: SYSTEM$STREAM_HAS_DATA triggers the task automatically
-------------------------------------------------------------------------------
CREATE OR REPLACE TASK BRONZE.TASK_STAGE_SAP_SALES
    WAREHOUSE = DEMO_ETL_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('RAW.SAP_SALES_ORDERS_STREAM')
AS
    CALL BRONZE.SP_STAGE_SAP_SALES_ORDERS();

-------------------------------------------------------------------------------
-- ROOT TASK: Retailer POS Processing
-- Fires when new POS sell-through data arrives from any retailer
-------------------------------------------------------------------------------
CREATE OR REPLACE TASK BRONZE.TASK_PROCESS_POS
    WAREHOUSE = DEMO_ETL_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('RAW.RETAILER_POS_STREAM')
AS
    CALL BRONZE.SP_PROCESS_RETAILER_POS();

-------------------------------------------------------------------------------
-- ROOT TASK: Inventory Processing
-- Fires when new inventory snapshots arrive
-------------------------------------------------------------------------------
CREATE OR REPLACE TASK BRONZE.TASK_PROCESS_INVENTORY
    WAREHOUSE = DEMO_ETL_WH
    SCHEDULE = '5 MINUTE'
    WHEN SYSTEM$STREAM_HAS_DATA('RAW.RETAILER_INVENTORY_STREAM')
AS
    CALL BRONZE.SP_PROCESS_INVENTORY();

-------------------------------------------------------------------------------
-- CHILD TASK: Data Quality Audit
-- Runs AFTER POS processing completes — logs quality metrics
-- Demonstrates: task DAGs / dependencies
-------------------------------------------------------------------------------
CREATE OR REPLACE TASK BRONZE.TASK_POS_QUALITY_AUDIT
    WAREHOUSE = DEMO_ETL_WH
    AFTER BRONZE.TASK_PROCESS_POS
AS
    INSERT INTO BRONZE.POS_QUALITY_LOG (
        AUDIT_TIMESTAMP,
        TOTAL_ROWS,
        NULL_STORE_KEY_COUNT,
        FUTURE_DATE_COUNT,
        NEGATIVE_REVENUE_COUNT
    )
    SELECT
        CURRENT_TIMESTAMP(),
        COUNT(*),
        COUNT_IF(STORE_KEY IS NULL),
        COUNT_IF(TRANSACTION_DATE > CURRENT_DATE()),
        COUNT_IF(REVENUE < 0)
    FROM BRONZE.POS_CLEANSED
    WHERE _LOADED_AT >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP());

-- Quality log table
CREATE OR REPLACE TABLE BRONZE.POS_QUALITY_LOG (
    AUDIT_TIMESTAMP         TIMESTAMP_NTZ,
    TOTAL_ROWS              NUMBER,
    NULL_STORE_KEY_COUNT    NUMBER,
    FUTURE_DATE_COUNT       NUMBER,
    NEGATIVE_REVENUE_COUNT  NUMBER
);

-------------------------------------------------------------------------------
-- Resume tasks (they are created in suspended state by default)
-- UNCOMMENT to activate in a live demo:
-------------------------------------------------------------------------------
-- ALTER TASK BRONZE.TASK_POS_QUALITY_AUDIT RESUME;
-- ALTER TASK BRONZE.TASK_STAGE_SAP_SALES RESUME;
-- ALTER TASK BRONZE.TASK_PROCESS_POS RESUME;
-- ALTER TASK BRONZE.TASK_PROCESS_INVENTORY RESUME;

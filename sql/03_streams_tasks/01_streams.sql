-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Streams (Change Data Capture)
-- Demo segment: 0:15–0:30 (Streams & Tasks)
-- Run as: DEMO_ENGINEER
-------------------------------------------------------------------------------

USE ROLE DEMO_ENGINEER;
USE DATABASE RETAIL_TRANSFORM_DEMO;
USE WAREHOUSE DEMO_ETL_WH;

-------------------------------------------------------------------------------
-- Streams on raw landing tables — detect new/changed rows automatically
-------------------------------------------------------------------------------

-- Stream on SAP sales orders (primary CDC demo)
CREATE OR REPLACE STREAM RAW.SAP_SALES_ORDERS_STREAM
    ON TABLE RAW.SAP_SALES_ORDERS
    APPEND_ONLY = TRUE
    COMMENT = 'Captures new SAP sales order records for staging pipeline';

-- Stream on retailer POS data
CREATE OR REPLACE STREAM RAW.RETAILER_POS_STREAM
    ON TABLE RAW.RETAILER_POS
    APPEND_ONLY = TRUE
    COMMENT = 'Captures new retailer POS sell-through records';

-- Stream on inventory snapshots
CREATE OR REPLACE STREAM RAW.RETAILER_INVENTORY_STREAM
    ON TABLE RAW.RETAILER_INVENTORY
    APPEND_ONLY = TRUE
    COMMENT = 'Captures new inventory snapshot records';

-- Stream on promotional calendar changes (supports updates)
CREATE OR REPLACE STREAM RAW.PROMO_CALENDAR_STREAM
    ON TABLE RAW.PROMO_CALENDAR
    APPEND_ONLY = FALSE
    COMMENT = 'Captures inserts and updates to promotional calendar';

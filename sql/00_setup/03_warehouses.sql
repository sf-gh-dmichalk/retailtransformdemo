-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Warehouses
-- Run as: SYSADMIN
-------------------------------------------------------------------------------

USE ROLE SYSADMIN;

-- ETL warehouse: used by tasks and stream processing
CREATE WAREHOUSE IF NOT EXISTS DEMO_ETL_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Pipeline ingestion and bronze-layer processing';

-- Transform warehouse: dbt runs and Snowpark procedures
CREATE WAREHOUSE IF NOT EXISTS DEMO_TRANSFORM_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'dbt and Snowpark transformation workloads';

-- Analytics warehouse: Dynamic Table refresh and analyst queries
CREATE WAREHOUSE IF NOT EXISTS DEMO_ANALYTICS_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Gold-layer Dynamic Table refresh and ad-hoc analytics';

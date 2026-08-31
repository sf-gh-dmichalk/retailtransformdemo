-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Teardown
-- Removes ALL demo objects — database, warehouses, roles, EAI
-- Run as: ACCOUNTADMIN
-- WARNING: This is destructive and irreversible.
-------------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

-- 1. Suspend all tasks first (prevents errors during drop)
ALTER TASK IF EXISTS RETAIL_TRANSFORM_DEMO.BRONZE.TASK_POS_QUALITY_AUDIT SUSPEND;
ALTER TASK IF EXISTS RETAIL_TRANSFORM_DEMO.BRONZE.TASK_STAGE_SAP_SALES SUSPEND;
ALTER TASK IF EXISTS RETAIL_TRANSFORM_DEMO.BRONZE.TASK_PROCESS_POS SUSPEND;
ALTER TASK IF EXISTS RETAIL_TRANSFORM_DEMO.BRONZE.TASK_PROCESS_INVENTORY SUSPEND;

-- 2. Drop the database (takes everything with it: tables, views, DTs, streams,
--    tasks, stored procedures, dbt project, stages, network rules)
DROP DATABASE IF EXISTS RETAIL_TRANSFORM_DEMO;

-- 3. Drop warehouses
DROP WAREHOUSE IF EXISTS DEMO_ETL_WH;
DROP WAREHOUSE IF EXISTS DEMO_TRANSFORM_WH;
DROP WAREHOUSE IF EXISTS DEMO_ANALYTICS_WH;

-- 4. Drop external access integration
DROP INTEGRATION IF EXISTS DEMO_DBT_EAI;

-- 5. Drop roles (bottom-up to respect hierarchy)
USE ROLE SECURITYADMIN;
DROP ROLE IF EXISTS DEMO_ANALYST;
DROP ROLE IF EXISTS DEMO_TRANSFORMER;
DROP ROLE IF EXISTS DEMO_ENGINEER;
DROP ROLE IF EXISTS DEMO_ADMIN;

-- 6. Drop service user
USE ROLE USERADMIN;
DROP USER IF EXISTS DEMO_SVC;

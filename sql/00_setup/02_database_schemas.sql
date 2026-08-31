-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Database & Schemas
-- Run as: SYSADMIN (or DEMO_ADMIN after grants)
-------------------------------------------------------------------------------

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS RETAIL_TRANSFORM_DEMO
    COMMENT = 'Retail transformation demo — CPG retail transformation scenarios';

USE DATABASE RETAIL_TRANSFORM_DEMO;

-- Raw landing zone: retailer files arrive here
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Landing zone for raw retailer and SAP source data';

-- Bronze: cleansed, validated, type-cast
CREATE SCHEMA IF NOT EXISTS BRONZE
    COMMENT = 'Cleansed and validated data — Snowpark processing';

-- Silver: conformed dimensions and facts (dbt-managed)
CREATE SCHEMA IF NOT EXISTS SILVER
    COMMENT = 'Business-conformed models — dbt incremental builds';

-- Gold: analytics-ready aggregations (Dynamic Tables)
CREATE SCHEMA IF NOT EXISTS GOLD
    COMMENT = 'Analytics-ready datasets — Dynamic Tables with SLA refresh';

-- Reference: master data, crosswalks, config
CREATE SCHEMA IF NOT EXISTS REF
    COMMENT = 'Reference/master data — product hierarchy, store xref, FX rates';

-- Staging: intermediate objects for stream/task patterns
CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Staging area for stream/task CDC patterns';

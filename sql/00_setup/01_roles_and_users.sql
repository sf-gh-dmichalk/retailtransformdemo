-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Roles & Users
-- Run as: SECURITYADMIN / USERADMIN
-------------------------------------------------------------------------------

USE ROLE SECURITYADMIN;

-- Functional roles
CREATE ROLE IF NOT EXISTS DEMO_ADMIN
    COMMENT = 'Full admin over the RETAIL_TRANSFORM_DEMO database';

CREATE ROLE IF NOT EXISTS DEMO_ENGINEER
    COMMENT = 'Data engineers — build and run all pipelines, transformations, and analytics';

-- Role hierarchy
GRANT ROLE DEMO_ENGINEER TO ROLE DEMO_ADMIN;
GRANT ROLE DEMO_ADMIN TO ROLE SYSADMIN;

-- Demo service user (for scheduled tasks / dbt runner)
USE ROLE USERADMIN;

CREATE USER IF NOT EXISTS DEMO_SVC
    PASSWORD = 'CHANGE_ME_BEFORE_RUNNING'
    DEFAULT_ROLE = DEMO_ENGINEER
    DEFAULT_WAREHOUSE = DEMO_TRANSFORM_WH
    DEFAULT_NAMESPACE = RETAIL_TRANSFORM_DEMO.SILVER
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT = 'Service account for scheduled transformation jobs';

GRANT ROLE DEMO_ENGINEER TO USER DEMO_SVC;

-- Grant roles to the presenter (adjust username)
GRANT ROLE DEMO_ADMIN TO USER DEMO_USER;

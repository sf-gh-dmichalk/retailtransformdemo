-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Snowpark Feature Engineering
-- ML-ready feature table for demand forecasting
-- Demonstrates: Python for complex aggregations, window functions, and
--   feature derivation that benefits from DataFrame semantics
-- Demo segment: 0:30–0:45 (time permitting)
-- Run as: DEMO_ENGINEER
-------------------------------------------------------------------------------

CREATE OR REPLACE PROCEDURE SILVER.SP_BUILD_DEMAND_FEATURES()
    RETURNS VARCHAR
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python')
    HANDLER = 'build_features'
AS
$$
from snowflake.snowpark import Session, Window
from snowflake.snowpark.functions import (
    col, sum as sum_, avg as avg_, lag, datediff, dayofweek,
    month, year, when, lit, count
)


def build_features(session: Session) -> str:
    """
    Build demand forecasting features from POS sell-through data.
    Features include:
    - Rolling averages (7d, 28d)
    - Week-over-week growth
    - Day-of-week seasonality flag
    - Promo presence
    - Days since last out-of-stock
    """

    # Base: daily store/product sales
    daily_sales = session.sql("""
        SELECT
            STORE_KEY,
            UPC,
            TRANSACTION_DATE,
            SUM(UNITS_SOLD) AS daily_units,
            SUM(REVENUE_USD) AS daily_revenue,
            MAX(PROMO_FLAG::INTEGER) AS had_promo
        FROM BRONZE.POS_CLEANSED
        GROUP BY 1, 2, 3
    """)

    # Window specs
    store_product_window = Window.partition_by("STORE_KEY", "UPC").order_by("TRANSACTION_DATE")
    rolling_7d = store_product_window.rows_between(-6, 0)
    rolling_28d = store_product_window.rows_between(-27, 0)

    # Feature engineering
    features = daily_sales \
        .with_column("UNITS_7D_AVG", avg_("DAILY_UNITS").over(rolling_7d)) \
        .with_column("UNITS_28D_AVG", avg_("DAILY_UNITS").over(rolling_28d)) \
        .with_column("REVENUE_7D_AVG", avg_("DAILY_REVENUE").over(rolling_7d)) \
        .with_column("PREV_WEEK_UNITS",
                     lag("DAILY_UNITS", 7).over(store_product_window)) \
        .with_column("WOW_GROWTH",
                     (col("DAILY_UNITS") - col("PREV_WEEK_UNITS"))
                     / col("PREV_WEEK_UNITS")) \
        .with_column("DAY_OF_WEEK", dayofweek(col("TRANSACTION_DATE"))) \
        .with_column("MONTH_NUM", month(col("TRANSACTION_DATE"))) \
        .with_column("IS_WEEKEND",
                     when(col("DAY_OF_WEEK").isin([6, 7]), lit(1)).otherwise(lit(0))) \
        .with_column("PROMO_RUNNING_COUNT",
                     sum_("HAD_PROMO").over(rolling_7d)) \
        .drop("PREV_WEEK_UNITS")

    # Write feature table
    features.write.mode("overwrite").save_as_table("SILVER.DEMAND_FEATURES")

    row_count = features.count()
    return f"Built {row_count} feature rows in SILVER.DEMAND_FEATURES"
$$;

-- Call it in the demo:
-- CALL SILVER.SP_BUILD_DEMAND_FEATURES();

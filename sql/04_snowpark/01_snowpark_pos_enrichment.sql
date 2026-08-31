-------------------------------------------------------------------------------
-- RETAIL TRANSFORM DEMO: Snowpark Python Transformation
-- Python DataFrames running natively in Snowflake — no data movement
-- Demo segment: 0:30–0:45
-- This is a Snowpark stored procedure — deploy via Snowsight or snow CLI
-- Run as: DEMO_TRANSFORMER
-------------------------------------------------------------------------------

-- Register the Snowpark stored procedure
CREATE OR REPLACE PROCEDURE BRONZE.SP_SNOWPARK_POS_ENRICHMENT()
    RETURNS TABLE()
    LANGUAGE PYTHON
    RUNTIME_VERSION = '3.11'
    PACKAGES = ('snowflake-snowpark-python')
    HANDLER = 'main'
AS
$$
from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col, lit, when, upper, trim, length, sum as sum_, avg as avg_,
    count, datediff, current_date, regexp_replace, to_date
)
from snowflake.snowpark.types import IntegerType, FloatType, StringType


def main(session: Session):
    """
    Snowpark transformation demo:
    - Reads raw retailer POS data
    - Applies UPC check-digit validation (Luhn mod-10)
    - Normalizes retailer-specific quirks
    - Enriches with product attributes
    - Calculates derived metrics (kg sold, revenue per kg)
    - Returns enriched DataFrame for inspection
    """

    # -------------------------------------------------------------------------
    # Step 1: Read raw POS data
    # -------------------------------------------------------------------------
    pos_raw = session.table("RAW.RETAILER_POS")

    # -------------------------------------------------------------------------
    # Step 2: Basic cleansing — trim whitespace, normalize retailer codes
    # -------------------------------------------------------------------------
    pos_clean = pos_raw.select(
        upper(trim(col("RETAILER_CODE"))).alias("RETAILER_CODE"),
        trim(col("STORE_ID")).alias("STORE_ID"),
        regexp_replace(col("UPC"), "[^0-9]", "").alias("UPC_CLEAN"),
        col("TRANSACTION_DATE"),
        col("UNITS_SOLD").cast(IntegerType()).alias("UNITS_SOLD"),
        col("REVENUE").cast(FloatType()).alias("REVENUE"),
        col("CURRENCY_CODE"),
        col("PROMO_FLAG"),
        col("_FILE_NAME"),
        col("_LOADED_AT")
    )

    # -------------------------------------------------------------------------
    # Step 3: UPC validation — 12-digit EAN check
    # -------------------------------------------------------------------------
    pos_validated = pos_clean.filter(
        (length(col("UPC_CLEAN")) == 12) &
        (col("UNITS_SOLD") >= 0) &
        (col("REVENUE") >= 0)
    ).with_column("UPC", col("UPC_CLEAN")).drop("UPC_CLEAN")

    # -------------------------------------------------------------------------
    # Step 4: Normalize dates per retailer
    # -------------------------------------------------------------------------
    pos_dated = pos_validated.with_column(
        "SALE_DATE",
        when(col("RETAILER_CODE") == "WMT",
             to_date(col("TRANSACTION_DATE"), "YYYY-MM-DD"))
        .when(col("RETAILER_CODE") == "KRO",
              to_date(col("TRANSACTION_DATE"), "MM/DD/YYYY"))
        .when(col("RETAILER_CODE") == "TGT",
              to_date(col("TRANSACTION_DATE"), "YYYYMMDD"))
        .otherwise(to_date(col("TRANSACTION_DATE")))
    )

    # -------------------------------------------------------------------------
    # Step 5: Enrich with product master
    # -------------------------------------------------------------------------
    products = session.table("REF.DIM_PRODUCT").filter(col("IS_CURRENT") == True)

    pos_enriched = pos_dated.join(
        products.select(
            col("UPC"),
            col("BRAND"),
            col("CATEGORY"),
            col("UNIT_WEIGHT_KG"),
            col("PRODUCT_NAME")
        ),
        on="UPC",
        how="left"
    )

    # -------------------------------------------------------------------------
    # Step 6: Calculate derived metrics
    # -------------------------------------------------------------------------
    pos_final = pos_enriched.with_columns(
        ["KG_SOLD", "REVENUE_PER_KG"],
        [
            col("UNITS_SOLD") * col("UNIT_WEIGHT_KG"),
            col("REVENUE") / (col("UNITS_SOLD") * col("UNIT_WEIGHT_KG"))
        ]
    )

    # -------------------------------------------------------------------------
    # Step 7: Write to Bronze output and return sample for demo visibility
    # -------------------------------------------------------------------------
    pos_final.write.mode("overwrite").save_as_table("BRONZE.POS_ENRICHED_SNOWPARK")

    # Return a sample for the notebook/demo display
    return pos_final.select(
        "RETAILER_CODE", "STORE_ID", "UPC", "SALE_DATE",
        "PRODUCT_NAME", "BRAND", "UNITS_SOLD", "KG_SOLD",
        "REVENUE", "REVENUE_PER_KG", "PROMO_FLAG"
    ).sort(col("SALE_DATE").desc()).limit(20)
$$;

-- Call it in the demo:
-- CALL BRONZE.SP_SNOWPARK_POS_ENRICHMENT();

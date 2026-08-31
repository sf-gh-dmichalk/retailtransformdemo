# Retail Transformation Demo — Session 2

## Session Agenda

| Time | Duration | Topic |
|------|----------|-------|
| 0:00–0:05 | 5 min | Welcome & Recap of Session 1 |
| 0:05–0:15 | 10 min | The Transformation Landscape in Snowflake |
| 0:15–0:30 | 15 min | Declarative & Incremental Transformation — Demo |
| 0:30–0:45 | 15 min | Code-First Transformation — Demo |
| 0:45–0:55 | 10 min | Q&A |
| 0:55–1:00 | 5 min | Wrap-up & Bridge to Session 3 |

---

## Scenario

the company receives daily POS sell-through data, inventory snapshots, and promotional calendars from retail partners (Walmart, Kroger, Target) plus SAP sales orders internally. The goal: transform raw feeds into analytics-ready datasets for demand planning, trade promotion effectiveness, and on-shelf availability — showcasing four transformation approaches on one platform.

---

## SQL File Structure

```
sql/
├── 00_setup/
│   ├── 01_roles_and_users.sql      ← RBAC: roles, hierarchy, service user
│   ├── 02_database_schemas.sql     ← Database + 6 schemas (RAW→GOLD)
│   ├── 03_warehouses.sql           ← 3 warehouses (ETL, Transform, Analytics)
│   └── 04_grants.sql               ← Least-privilege grants + future grants
│
├── 01_raw_staging/
│   ├── 01_tables.sql               ← Landing tables (VARCHAR), ref/master data
│   └── 02_sample_data.sql          ← Demo seed data (POS, inventory, promos, SAP)
│
├── 02_dynamic_tables/
│   └── 01_dynamic_tables.sql       ← 4 Gold-layer DTs with varying TARGET_LAG
│
├── 03_streams_tasks/
│   ├── 01_streams.sql              ← CDC streams on raw landing tables
│   ├── 02_stored_procedures.sql    ← 3 SQL SPs (stage SAP, process POS, process inventory)
│   └── 03_tasks.sql                ← Task DAG with SYSTEM$STREAM_HAS_DATA triggers
│
├── 04_snowpark/
│   ├── 01_snowpark_pos_enrichment.sql  ← Python SP: UPC validation, date normalization
│   └── 02_snowpark_demand_features.sql ← Python SP: ML feature engineering
│
└── 05_dbt/
    ├── 00_dbt_project_config.sql       ← dbt_project.yml / profiles as reference
    └── models/silver/
        ├── fct_pos_sales.sql           ← Incremental fact (POS sell-through)
        ├── fct_inventory.sql           ← Incremental fact (inventory snapshots)
        ├── fct_promotions.sql          ← Full-refresh promo fact
        ├── dim_product_scd2.sql        ← SCD Type 2 product dimension
        └── schema_tests.sql            ← dbt test assertions as SQL
```

---

## Execution Order

Run files in numeric order. Within each folder, run by filename order.

```
1. 00_setup/01 → 02 → 03 → 04     (SECURITYADMIN / SYSADMIN)
2. 01_raw_staging/01 → 02           (DEMO_ENGINEER)
3. 03_streams_tasks/01 → 02 → 03   (DEMO_ENGINEER) — sets up CDC pipeline
4. 05_dbt/models/silver/*           (DEMO_TRANSFORMER) — creates silver tables
5. 02_dynamic_tables/01             (DEMO_TRANSFORMER) — gold DTs auto-refresh
6. 04_snowpark/01 → 02             (DEMO_TRANSFORMER) — Python demos
```

---

## Demo Mapping to Agenda

### 0:15–0:30: Declarative & Incremental Transformation

| What to show | File | Key talking point |
|---|---|---|
| Dynamic Table: SAP → conformed entity | `02_dynamic_tables/01_dynamic_tables.sql` (DT 1) | "Define the output, Snowflake manages refresh — no scheduling" |
| Stream detecting new SAP records | `03_streams_tasks/01_streams.sql` | "CDC without polling — stream tracks inserts automatically" |
| Task triggered by stream | `03_streams_tasks/03_tasks.sql` | "Event-driven orchestration — fires only when data exists" |
| Stored Proc: multi-step logic + error quarantine | `03_streams_tasks/02_stored_procedures.sql` (SP 1) | "Business logic encapsulated — type casting, validation, rejection" |

### 0:30–0:45: Code-First Transformation

| What to show | File | Key talking point |
|---|---|---|
| Snowpark: POS enrichment in Python | `04_snowpark/01_snowpark_pos_enrichment.sql` | "Python DataFrames, no data movement — UPC validation, joins, derived metrics" |
| Snowpark: ML feature engineering | `04_snowpark/02_snowpark_demand_features.sql` | "Rolling windows, WoW growth, seasonality flags — all in Snowflake compute" |
| dbt: incremental silver fact | `05_dbt/models/silver/fct_pos_sales.sql` | "Version-controlled SQL models with testing, lineage, incremental logic" |
| dbt: referential integrity tests | `05_dbt/models/silver/schema_tests.sql` | "Every run validates data quality — orphan keys, range checks" |

---

## RBAC Summary

```
SYSADMIN
└── DEMO_ADMIN (owns database)
    └── DEMO_ENGINEER (builds pipelines, runs tasks)
        ├── DEMO_TRANSFORMER (dbt, Snowpark, DT refresh)
        └── DEMO_ANALYST (read-only silver/gold)
```

| Role | Schemas | Warehouse |
|------|---------|-----------|
| ENGINEER | RAW, BRONZE, STAGING, REF (all) | DEMO_ETL_WH |
| TRANSFORMER | SILVER, GOLD (write); RAW, BRONZE, REF (read) | DEMO_TRANSFORM_WH, DEMO_ANALYTICS_WH |
| ANALYST | SILVER, GOLD (select only) | DEMO_ANALYTICS_WH |

---

## Decision Framework (Slide Content for 0:05–0:15)

| Approach | Best For | the company Fit |
|----------|----------|------------|
| **Dynamic Tables** | Declarative aggregations, SLA-driven refresh, no orchestration | Gold-layer analytics where freshness matters |
| **Streams + Tasks** | Event-driven CDC, conditional execution, complex DAGs | Raw→Bronze when logic depends on data arrival |
| **Snowpark** | Python/ML logic, UDF-heavy transforms, feature engineering | Retailer-specific parsing, validation rules in Python |
| **dbt** | SQL-first teams, version control, testing, documentation | Silver-layer conforming where auditability matters |

---

## Bridge to Session 3

> "Now that data is clean and structured in the Silver/Gold layers, Session 3 shows how to model it as a semantic layer accessible to business users and AI systems — Cortex Analyst querying these same tables with natural language."

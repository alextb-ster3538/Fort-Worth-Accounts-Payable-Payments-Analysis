# Fort Worth Accounts Payable Payment Analysis

## Data Source

Fort Worth AP Check Register Data

https://www.fortworthtexas.gov/departments/finance/check-register

## Dataset

Dataset: `fw_ap_dataset`

Period Covered:
October 2025 – September 2026

## Schema Decisions

- Payment ID → STRING
- Voucher ID → STRING
- Account → STRING
- Payment Date → STRING (raw layer)
- Invoice Date → STRING (raw layer)
- Amount → NUMERIC

## Data Engineering Notes

- Removed report title row ("CHECKBOOK USED FOR WEBSITE") prior to ingestion.
- Manually defined schema in BigQuery after auto-detect produced data type conflicts.
- Created monthly raw tables for each reporting period.
- Created consolidated view: `ap_all`.
- Added `source_month` field to support time-based analysis.

## Validation

- Row counts verified against source files.
- Combined view row count reconciled to monthly table totals.
- Schemas reviewed and validated across all uploaded tables.

## Progress

✅ Data successfully ingested into BigQuery.

✅ Row counts reconciled against source files.

✅ Unified view (`ap_all`) created and validated.

## Next Steps

- Exploratory Data Analysis (EDA)
- Monthly payment trend analysis
- Vendor spend analysis
- Fund-level spend analysis
- Large payment and



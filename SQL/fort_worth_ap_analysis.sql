-- =====================================================================
-- Fort Worth Accounts Payable Analysis (FY Oct 2025 - Sep 2026)
-- Source: City of Fort Worth AP checkbook, loaded into BigQuery
-- View:   fort-worth-ap-analysis.fw_ap_dataset.ap_all
-- Note:   One Payment ID can span several rows (one per fund/account
--         line), so payments are counted with COUNT(DISTINCT `Payment ID`).
--         `Payment Date` is stored as text (M/D/YYYY); use PARSE_DATE
--         before sorting or comparing dates.
-- =====================================================================


-- =====================================================================
-- 1. DATA PROFILING AND SPEND RULE
-- =====================================================================

-- Quick look at capital project lines (exploration only)
SELECT *
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Project Descr` LIKE 'Capital%';

-- What statuses exist? (decides what counts as "spend")
-- Result: only Paid and Void
SELECT `Payment Status`, COUNT(*) AS lines, SUM(Amount) AS total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
GROUP BY `Payment Status`
ORDER BY total DESC;

-- Grand total under the spend rule (everything except Void)
SELECT SUM(Amount) AS total_spend
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void';


-- =====================================================================
-- 2. FUND ANALYSIS
-- =====================================================================

-- List every fund with its total, to classify them by fund type
SELECT Fund, `Fund Desc`, SUM(Amount) AS total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
GROUP BY Fund, `Fund Desc`
ORDER BY total DESC;

-- Spend by fund type (first digit of the fund number) and % of total
-- ELSE catches any fund number outside 1-7 so it is not lost as NULL
SELECT
  CASE LEFT(CAST(Fund AS STRING), 1)
    WHEN '1' THEN 'General Fund'
    WHEN '2' THEN 'Special Revenue'
    WHEN '3' THEN 'Capital Projects'
    WHEN '4' THEN 'Debt Service'
    WHEN '5' THEN 'Enterprise'
    WHEN '6' THEN 'Internal Service'
    WHEN '7' THEN 'Trust'
    ELSE 'Other'
  END AS fund_type,
  SUM(Amount) AS total,
  ROUND(SUM(Amount) / SUM(SUM(Amount)) OVER () * 100, 1) AS pct
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
GROUP BY fund_type
ORDER BY total DESC;

-- Water check: every fund whose description mentions water
SELECT Fund, `Fund Desc`, SUM(Amount) AS total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
  AND LOWER(`Fund Desc`) LIKE '%water%'
GROUP BY Fund, `Fund Desc`
ORDER BY total DESC;

-- Water & sewer total (fund families 56, 57, 59 plus fund 53004)
SELECT SUM(Amount) AS water_sewer_total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
  AND (LEFT(CAST(Fund AS STRING), 2) IN ('56', '57', '59')
       OR CAST(Fund AS STRING) = '53004');

-- Water & sewer funds listed one by one (Paid only)
SELECT
  Fund,
  `Fund Desc`,
  SUM(Amount) AS total_paid
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` = 'Paid'
  AND (LEFT(CAST(Fund AS STRING), 2) IN ('56', '57', '59')
       OR CAST(Fund AS STRING) = '53004')
GROUP BY Fund, `Fund Desc`
ORDER BY total_paid DESC;

-- Funds with two descriptions:
--   Fund 60105 appears as "Info Technology Systems" and "IT SOLUTIONS"
--   Fund 56026 appears as "W&S Commercial Paper" and "W&S Rev Bonds Series 2026B"
-- Shows which months each description was used (renamed vs. used in parallel)
SELECT Fund, `Fund Desc`,
       COUNT(*) AS lines,
       SUM(Amount) AS total,
       MIN(source_month) AS first_month,
       MAX(source_month) AS last_month
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE CAST(Fund AS STRING) IN ('60105', '56026')
GROUP BY Fund, `Fund Desc`
ORDER BY Fund, first_month;

-- Commercial paper check (fund 56032): months used and total
SELECT Fund, `Fund Desc`,
       MIN(source_month) AS first_month,
       MAX(source_month) AS last_month,
       SUM(Amount) AS total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE CAST(Fund AS STRING) = '56032'
GROUP BY Fund, `Fund Desc`;

-- Capital projects total (fund numbers starting with 3)
SELECT SUM(Amount) AS capital_projects
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
  AND LEFT(CAST(Fund AS STRING), 1) = '3';

-- General Fund total
SELECT SUM(Amount) AS general_fund
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
  AND LOWER(`Fund Desc`) LIKE '%general fund%';


-- =====================================================================
-- 3. ACCOUNT ANALYSIS
-- =====================================================================

-- Top 5 accounts by spend
SELECT Account, `Acct Descr`, SUM(Amount) AS total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
GROUP BY Account, `Acct Descr`
ORDER BY total DESC
LIMIT 5;

-- Spend by account group (first digit of the account number) and % of total
SELECT LEFT(CAST(Account AS STRING), 1) AS acct_group,
       COUNT(DISTINCT Account) AS accounts,
       SUM(Amount) AS total,
       ROUND(SUM(Amount) / SUM(SUM(Amount)) OVER () * 100, 1) AS pct,
       ANY_VALUE(`Acct Descr`) AS example_account
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
GROUP BY acct_group
ORDER BY acct_group;

-- Accounts inside one account group (change the digit to explore another group)
SELECT Account, `Acct Descr`, SUM(Amount) AS total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
  AND LEFT(CAST(Account AS STRING), 1) = '2'
GROUP BY Account, `Acct Descr`
ORDER BY total DESC;


-- =====================================================================
-- 4. MONTHLY TRENDS
-- =====================================================================

-- Monthly totals
SELECT source_month, SUM(Amount) AS total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
GROUP BY source_month
ORDER BY source_month;

-- What's inside February (top 10 supplier/account combinations)
SELECT `Supplier Name`, `Acct Descr`, SUM(Amount) AS total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
  AND source_month = '2026-02'
GROUP BY `Supplier Name`, `Acct Descr`
ORDER BY total DESC
LIMIT 10;

-- Monthly totals split into debt service and everything else
-- (shows how much of the February spike is debt principal and interest)
SELECT source_month,
       SUM(Amount) AS total,
       SUM(CASE WHEN `Acct Descr` IN ('Debt Principal Payment', 'Debt Interest Payment')
                THEN Amount ELSE 0 END) AS debt_service,
       SUM(CASE WHEN `Acct Descr` NOT IN ('Debt Principal Payment', 'Debt Interest Payment')
                THEN Amount ELSE 0 END) AS excl_debt
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` != 'Void'
GROUP BY source_month
ORDER BY source_month;


-- =====================================================================
-- 5. VOIDED PAYMENTS
-- =====================================================================

-- How many voided payments? (count payments, not lines)
SELECT COUNT(DISTINCT `Payment ID`) AS voided_payments,
       SUM(Amount) AS voided_total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` = 'Void';

-- Voids without a reissue: voided payments with no non-void payment
-- for the same supplier and invoice (LEFT JOIN + IS NULL = "no match found")
SELECT DISTINCT v.`Payment ID`, v.`Supplier Name`, v.`Invoice Number`, v.Amount
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all` v
LEFT JOIN `fort-worth-ap-analysis.fw_ap_dataset.ap_all` p
  ON  v.`Supplier Name`  = p.`Supplier Name`
  AND v.`Invoice Number` = p.`Invoice Number`
  AND p.`Payment Status` != 'Void'
WHERE v.`Payment Status` = 'Void'
  AND p.`Payment ID` IS NULL;

-- Count of voids with no reissue (same rule as above)
SELECT COUNT(DISTINCT v.`Payment ID`) AS not_reissued
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all` v
LEFT JOIN `fort-worth-ap-analysis.fw_ap_dataset.ap_all` p
  ON  v.`Supplier Name`  = p.`Supplier Name`
  AND v.`Invoice Number` = p.`Invoice Number`
  AND p.`Payment Status` != 'Void'
WHERE v.`Payment Status` = 'Void'
  AND p.`Payment ID` IS NULL;

-- Looser rule: match on invoice number only (ignores supplier name differences)
SELECT COUNT(DISTINCT v.`Payment ID`) AS not_reissued_invoice_only
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all` v
LEFT JOIN `fort-worth-ap-analysis.fw_ap_dataset.ap_all` p
  ON  v.`Invoice Number` = p.`Invoice Number`
  AND p.`Payment Status` != 'Void'
WHERE v.`Payment Status` = 'Void'
  AND p.`Payment ID` IS NULL;

-- BrightView: every payment for the invoices that looked unmatched
SELECT `Payment ID`, `Payment Status`, `Payment Date`, `Supplier Name`, `Invoice Number`, Amount
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE LOWER(`Supplier Name`) LIKE 'brightview%'
  AND `Invoice Number` IN ('9817621', '9818211', '9817612', '9739594', '9737975')
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);

-- Unmatched voids by month (timing check)
WITH unmatched AS (
  SELECT DISTINCT v.`Payment ID`
  FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all` v
  LEFT JOIN `fort-worth-ap-analysis.fw_ap_dataset.ap_all` p
    ON  v.`Invoice Number` = p.`Invoice Number`
    AND p.`Payment Status` != 'Void'
  WHERE v.`Payment Status` = 'Void'
    AND p.`Payment ID` IS NULL
)
SELECT a.source_month,
       COUNT(DISTINCT a.`Payment ID`) AS unmatched_voids,
       SUM(ABS(a.Amount)) AS gross_amount
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all` a
JOIN unmatched u ON a.`Payment ID` = u.`Payment ID`
WHERE a.`Payment Status` = 'Void'
GROUP BY a.source_month
ORDER BY a.source_month;

-- Largest unmatched void: L J Design & Construction, $291,690.64, voided December 2025
-- Lists every payment to this supplier to see whether it was reissued
-- under a different invoice reference
SELECT `Payment ID`, `Payment Status`, `Payment Date`, `Invoice Number`,
       SUM(Amount) AS amount
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE LOWER(`Supplier Name`) LIKE 'l j design%'
GROUP BY `Payment ID`, `Payment Status`, `Payment Date`, `Invoice Number`
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);

-- Payments still open at year-end (statuses other than Void and Paid)
-- Result: no rows. The data contains only Paid and Void statuses,
-- so open items cannot be measured from payment status.
-- The earlier README figure (~$107K) could not be reproduced and was removed.
SELECT
    `Payment Status`,
    COUNT(DISTINCT `Payment ID`) AS payments,
    SUM(Amount)                  AS total
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` NOT IN ('Void', 'Paid')
GROUP BY `Payment Status`;


-- =====================================================================
-- 6. DUPLICATE PAYMENT CHECKS
-- Definition: same supplier, invoice number and amount
--             under more than one Payment ID
-- =====================================================================

-- First duplicate check (all statuses)
-- Result: 287 groups
SELECT
  `Supplier Name`,
  `Invoice Number`,
  Amount,
  COUNT(DISTINCT `Payment ID`) AS payment_count
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
GROUP BY `Supplier Name`, `Invoice Number`, Amount
HAVING COUNT(DISTINCT `Payment ID`) > 1
ORDER BY payment_count DESC;

-- Same check with the statuses and first/last payment date in each group
-- STRING_AGG joins the statuses into one cell, e.g. "Paid, Void"
-- PARSE_DATE makes MIN/MAX sort by date instead of alphabetically
SELECT
  `Supplier Name`,
  `Invoice Number`,
  Amount,
  COUNT(DISTINCT `Payment ID`) AS payment_count,
  STRING_AGG(DISTINCT `Payment Status`, ', ') AS statuses,
  MIN(PARSE_DATE('%m/%d/%Y', `Payment Date`)) AS first_payment,
  MAX(PARSE_DATE('%m/%d/%Y', `Payment Date`)) AS last_payment
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
GROUP BY `Supplier Name`, `Invoice Number`, Amount
HAVING COUNT(DISTINCT `Payment ID`) > 1
ORDER BY payment_count DESC;

-- What payment statuses exist in the dataset
-- Result: Paid and Void
SELECT
  `Payment Status`,
  COUNT(*) AS row_count
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
GROUP BY `Payment Status`
ORDER BY row_count DESC;

-- Are blank invoice numbers grouping together?
-- Result: no rows, so blanks are not inflating the count
SELECT
  `Supplier Name`,
  `Invoice Number`,
  Amount,
  COUNT(DISTINCT `Payment ID`) AS payment_count
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Invoice Number` IS NULL OR `Invoice Number` = ''
GROUP BY `Supplier Name`, `Invoice Number`, Amount
HAVING COUNT(DISTINCT `Payment ID`) > 1;

-- Duplicate check on Paid payments only (removes void-and-reissue pairs)
-- Result: 126 groups (161 of the 287 were void-and-reissue cases)
SELECT
  `Supplier Name`,
  `Invoice Number`,
  Amount,
  COUNT(DISTINCT `Payment ID`) AS payment_count
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` = 'Paid'
GROUP BY `Supplier Name`, `Invoice Number`, Amount
HAVING COUNT(DISTINCT `Payment ID`) > 1
ORDER BY payment_count DESC;

-- Number of duplicate groups and potential overpayment
-- Excludes SINGLE EFT (catch-all for one-off payments) and negative lines (credits/retainage)
-- payment_count - 1 = only the extra payments
-- Result: 105 groups, $2,133,087.36
WITH dupes AS (
  SELECT
    `Supplier Name`,
    `Invoice Number`,
    Amount,
    COUNT(DISTINCT `Payment ID`) AS payment_count
  FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
  WHERE `Payment Status` = 'Paid'
    AND `Supplier Name` != 'SINGLE EFT'
    AND Amount > 0
  GROUP BY `Supplier Name`, `Invoice Number`, Amount
  HAVING COUNT(DISTINCT `Payment ID`) > 1
)
SELECT
  COUNT(*) AS duplicate_groups,
  SUM(Amount * (payment_count - 1)) AS potential_overpayment
FROM dupes;

-- Top 10 duplicate groups by potential overpayment
WITH dupes AS (
  SELECT
    `Supplier Name`,
    `Invoice Number`,
    Amount,
    COUNT(DISTINCT `Payment ID`) AS payment_count
  FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
  WHERE `Payment Status` = 'Paid'
    AND `Supplier Name` != 'SINGLE EFT'
    AND Amount > 0
  GROUP BY `Supplier Name`, `Invoice Number`, Amount
  HAVING COUNT(DISTINCT `Payment ID`) > 1
)
SELECT
  `Supplier Name`,
  `Invoice Number`,
  Amount,
  payment_count,
  Amount * (payment_count - 1) AS potential_overpayment
FROM dupes
ORDER BY potential_overpayment DESC
LIMIT 10;


-- =====================================================================
-- 7. DUPLICATE CASE VERIFICATION (the 6 largest cases, line by line)
-- Result: all 6 confirmed, $1,830,337.96 net; each paid by EFT first,
--         then again by ACH or check 19 to 61 days later
-- =====================================================================

-- Synergy Refrigeration, invoice 21104
-- Result: paid 1/15/2026 (0010103) and 3/17/2026 (0206567), $582,904.25 each
SELECT
  `Payment ID`,
  `Payment Date`,
  `Payment Status`,
  Amount,
  `Invoice Date`,
  `Fund Desc`,
  `Acct Descr`
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Supplier Name` = 'Synergy Refrigeration'
  AND `Invoice Number` = '21104'
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);

-- Tiseo Paving Co., invoice CS64497-001+PAYAP-1
-- Result: whole 10-line pay application paid twice (0013424 and 1278910),
--         $412,068.29 net of retainage
SELECT
  `Payment ID`,
  `Payment Date`,
  `Payment Status`,
  Amount,
  `Invoice Date`,
  `Fund Desc`,
  `Acct Descr`
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Supplier Name` = 'Tiseo Paving Co.'
  AND `Invoice Number` = 'CS64497-001+PAYAP-1'
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);

-- CELLEBRITE INC, invoice INVUS297598
-- UPPER() makes the LIKE match ignore capitalization
-- Result: both lines paid twice (0012335 and 1277414), $168,500
SELECT
  `Payment ID`,
  `Payment Date`,
  `Payment Status`,
  Amount,
  `Invoice Date`,
  `Fund Desc`,
  `Acct Descr`
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE UPPER(`Supplier Name`) LIKE 'CELLEBRITE%'
  AND `Invoice Number` = 'INVUS297598'
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);

-- ECM Highwoods, LLC, invoice FY26-003
-- Result: paid 1/29/2026 (0010445) and 3/4/2026 (1274554), $184,951 each
SELECT
  `Payment ID`,
  `Payment Date`,
  `Payment Status`,
  Amount,
  `Invoice Date`,
  `Fund Desc`,
  `Acct Descr`
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE UPPER(`Supplier Name`) LIKE 'ECM%'
  AND `Invoice Number` = 'FY26-003'
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);

-- Harrison Kornberg Architects, invoices FW-HUB-13 and FW-HUB-14
-- IN checks both invoices in one query
-- Note: after UPPER() the text in quotes must be in capitals too ('HARRISON%')
-- Result: both invoices paid together twice: 0011076 (EFT, 2/26/2026)
--         and 0206568 (ACH, 3/17/2026), $288,766.42 in total
SELECT
  `Payment ID`,
  `Payment Date`,
  `Payment Status`,
  Amount,
  `Invoice Date`,
  `Fund Desc`,
  `Acct Descr`
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE UPPER(`Supplier Name`) LIKE 'HARRISON%'
  AND `Invoice Number` IN ('FW-HUB-13', 'FW-HUB-14')
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);

-- Mustang Mitigation Holdings LLC, invoice 1003
-- Result: paid 3/26/2026 (0011897, EFT) and 4/15/2026 (1276128, check), $193,148 each
SELECT
  `Payment ID`,
  `Payment Date`,
  `Payment Status`,
  Amount,
  `Invoice Date`,
  `Fund Desc`,
  `Acct Descr`
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE UPPER(`Supplier Name`) LIKE 'MUSTANG%'
  AND `Invoice Number` = '1003'
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);


-- =====================================================================
-- 8. DUPLICATE ROOT CAUSE: PAYMENT ID PREFIX AND PAYMENT CHANNEL
-- =====================================================================

-- Payment ID prefixes inside the duplicate groups
-- Result: 99 Payment IDs; 127 = 45, 001 = 36, 000 = 7, 128 = 6, 021 = 3, 020 = 2
WITH dupes AS (
  SELECT
    `Supplier Name`,
    `Invoice Number`,
    Amount
  FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
  WHERE `Payment Status` = 'Paid'
    AND `Supplier Name` != 'SINGLE EFT'
    AND Amount > 0
  GROUP BY `Supplier Name`, `Invoice Number`, Amount
  HAVING COUNT(DISTINCT `Payment ID`) > 1
)
SELECT
  LEFT(a.`Payment ID`, 3) AS id_prefix,
  COUNT(DISTINCT a.`Payment ID`) AS payment_ids
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all` a
JOIN dupes d
  ON a.`Supplier Name` = d.`Supplier Name`
  AND a.`Invoice Number` = d.`Invoice Number`
  AND a.Amount = d.Amount
WHERE a.`Payment Status` = 'Paid'
GROUP BY id_prefix
ORDER BY payment_ids DESC;

-- Baseline: Payment ID prefixes across all paid payments
-- Result: 31,179 paid payments; 127 = 1,789 (5.7%) vs 45.5% of duplicate payments
SELECT
  LEFT(`Payment ID`, 3) AS id_prefix,
  COUNT(DISTINCT `Payment ID`) AS payment_ids
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` = 'Paid'
GROUP BY id_prefix
ORDER BY payment_ids DESC;

-- Date range of the main prefixes
-- Result: 127 runs 10/15/2025 - 7/15/2026, 128 continues from 7/16/2026
SELECT
  LEFT(`Payment ID`, 3) AS id_prefix,
  COUNT(DISTINCT `Payment ID`) AS payment_ids,
  MIN(PARSE_DATE('%m/%d/%Y', `Payment Date`)) AS first_date,
  MAX(PARSE_DATE('%m/%d/%Y', `Payment Date`)) AS last_date
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` = 'Paid'
  AND LEFT(`Payment ID`, 3) IN ('001', '020', '021', '127', '128')
GROUP BY id_prefix
ORDER BY id_prefix;

-- Payment method behind each prefix
-- Result: 001 = EFT, 020/021 = ACH, 127/128 = CHK (check)
SELECT
  LEFT(`Payment ID`, 3) AS id_prefix,
  `Payment Method`,
  COUNT(DISTINCT `Payment ID`) AS payment_ids
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE `Payment Status` = 'Paid'
  AND LEFT(`Payment ID`, 3) IN ('001', '020', '021', '127', '128')
GROUP BY id_prefix, `Payment Method`
ORDER BY id_prefix, payment_ids DESC;

-- How many duplicate groups used more than one payment method
-- Result: 81 groups used 1 method, 24 groups used 2
WITH dupes AS (
  SELECT
    `Supplier Name`,
    `Invoice Number`,
    Amount,
    COUNT(DISTINCT `Payment Method`) AS methods_used
  FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
  WHERE `Payment Status` = 'Paid'
    AND `Supplier Name` != 'SINGLE EFT'
    AND Amount > 0
  GROUP BY `Supplier Name`, `Invoice Number`, Amount
  HAVING COUNT(DISTINCT `Payment ID`) > 1
)
SELECT
  methods_used,
  COUNT(*) AS duplicate_groups
FROM dupes
GROUP BY methods_used;

-- Duplicate groups and potential overpayment by payment channel
-- Result: Mixed channels 24 groups $1,935,559.74 (90.7%),
--         EFT only 57 groups $149,410.36, Check only 24 groups $48,117.26
WITH dupes AS (
  SELECT
    `Supplier Name`,
    `Invoice Number`,
    Amount,
    COUNT(DISTINCT `Payment ID`) AS payment_count,
    CASE
      WHEN COUNT(DISTINCT `Payment Method`) > 1 THEN 'Mixed channels'
      ELSE MIN(`Payment Method`)
    END AS channel
  FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
  WHERE `Payment Status` = 'Paid'
    AND `Supplier Name` != 'SINGLE EFT'
    AND Amount > 0
  GROUP BY `Supplier Name`, `Invoice Number`, Amount
  HAVING COUNT(DISTINCT `Payment ID`) > 1
)
SELECT
  channel,
  COUNT(*) AS duplicate_groups,
  SUM(Amount * (payment_count - 1)) AS potential_overpayment
FROM dupes
GROUP BY channel
ORDER BY potential_overpayment DESC;


-- =====================================================================
-- 9. DUPLICATE FOLLOW-UP: THE MARCH 17 ACH RUN AND RECOVERY CHECKS
-- =====================================================================

-- All duplicate-group payments made on 3/17/2026
-- Synergy's 2nd payment (0206567) and Harrison's 2nd payment (0206568) were
-- consecutive Payment IDs on the same day, so this checks the whole day.
-- The SELECT lists each payment instead of counting; a. tells SQL which
-- table each column comes from (both tables have the same column names).
-- Payment Date is text, so it is compared to text exactly as stored ('3/17/2026').
-- Result: 3 duplicate invoices in 2 consecutive ACH payments, $871,670.67
--         (Synergy 21104; Harrison FW-HUB-13 and FW-HUB-14), about 41% of the exposure
WITH dupes AS (
  SELECT
    `Supplier Name`,
    `Invoice Number`,
    Amount
  FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
  WHERE `Payment Status` = 'Paid'
    AND `Supplier Name` != 'SINGLE EFT'
    AND Amount > 0
  GROUP BY `Supplier Name`, `Invoice Number`, Amount
  HAVING COUNT(DISTINCT `Payment ID`) > 1
)
SELECT
  a.`Payment ID`,
  a.`Payment Date`,
  a.`Supplier Name`,
  a.`Invoice Number`,
  a.Amount
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all` a
JOIN dupes d
  ON a.`Supplier Name` = d.`Supplier Name`
  AND a.`Invoice Number` = d.`Invoice Number`
  AND a.Amount = d.Amount
WHERE a.`Payment Status` = 'Paid'
  AND a.`Payment Date` = '3/17/2026'
ORDER BY a.`Payment ID`;

-- Recovery check for Mustang: any payment or credit on or after the duplicate (4/15/2026)
-- A supplier credit for a duplicate is usually taken off a later invoice, so it would
-- show in AP as a negative line or smaller payment after the duplicate date.
-- PARSE_DATE turns the text date into a real date so >= compares by calendar;
-- DATE '2026-04-15' is how a fixed date is written in BigQuery (year-month-day).
-- Result: only the duplicate itself (4/15/2026); no later payments or credits in FY2026
SELECT
  `Payment ID`,
  `Payment Date`,
  `Payment Status`,
  Amount,
  `Invoice Date`,
  `Fund Desc`,
  `Acct Descr`
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE UPPER(`Supplier Name`) LIKE 'MUSTANG%'
  AND PARSE_DATE('%m/%d/%Y', `Payment Date`) >= DATE '2026-04-15'
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);

-- Recovery check for the 5 other verified suppliers: every negative line, any date
-- No date filter, because each supplier's duplicate happened on a different day.
-- The parentheses around the ORs matter: without them, AND is applied before OR
-- and "Amount < 0" would only apply to the last supplier.
-- Result: 24 rows, all Tiseo "Retainage Payable" plus one Synergy -$0.01 rounding line.
--         No offsetting credits for any verified duplicate in FY2026.
--         (Refund checks would be recorded in cash receipts, which are not in this data.)
SELECT
  `Supplier Name`,
  `Payment ID`,
  `Payment Date`,
  `Payment Status`,
  Amount,
  `Invoice Date`,
  `Fund Desc`,
  `Acct Descr`
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`
WHERE (UPPER(`Supplier Name`) LIKE 'SYNERGY%'
    OR UPPER(`Supplier Name`) LIKE 'HARRISON%'
    OR UPPER(`Supplier Name`) LIKE 'ECM%'
    OR UPPER(`Supplier Name`) LIKE 'CELLEBRITE%'
    OR UPPER(`Supplier Name`) LIKE 'TISEO%')
  AND Amount < 0
ORDER BY PARSE_DATE('%m/%d/%Y', `Payment Date`);


-- =====================================================================
-- 10. REPORTING VIEW (fund_type and account_group on every row)
-- =====================================================================

-- Building a BigQuery view adding 'fund_type' and 'account_group' to every row.

CREATE OR REPLACE VIEW `fort-worth-ap-analysis.fw_ap_dataset.ap_enriched` AS
SELECT
  *,
  CASE LEFT(CAST(Fund AS STRING), 1)
    WHEN '1' THEN 'General Fund'
    WHEN '2' THEN 'Special Revenue'
    WHEN '3' THEN 'Capital Projects'
    WHEN '4' THEN 'Debt Service'
    WHEN '5' THEN 'Enterprise'
    WHEN '6' THEN 'Internal Service'
    WHEN '7' THEN 'Trust'
    ELSE 'Other'
  END AS fund_type
  -- account_group: a second CASE goes here, using your account group rules
FROM `fort-worth-ap-analysis.fw_ap_dataset.ap_all`;




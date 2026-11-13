<img width="1600" height="500" alt="fort-worth-ap-banner" src="https://github.com/user-attachments/assets/f230c65e-3194-438c-8b37-3516d551c632" />

# Fort Worth Accounts Payable Analysis

Analysis of every payment the City of Fort Worth made through accounts payable in fiscal year 2026 (October 2025 – September 2026): who was paid, from which funds, what they were paid for, and whether the data holds up to reconciliation and quality checks.

**Tools:** Google BigQuery (SQL), Power BI (in progress)

## Key findings

- The city paid **$2.67 billion** through accounts payable in FY2026, across 31,179 payments and 237,184 payment lines.
- Of that total, **77.5% ($2.07B) is true city spending**. The remaining 22.5% ($603M) is money passed through or moved on the balance sheet, mainly payroll deductions sent to the IRS and the pension fund, as well as cash sent to the bond paying agent.
- **Enterprise funds** (consisting mainly of water and sewer) account for 38% of spend, more than twice the General Fund, which is the City's main operating account. Water-related funds alone total about $819M.
- **Capital projects ($484M) matched General Fund operating spend ($483M).** The largest single expense account is capital outlay for infrastructure: $647M.
- **February 2026 ($446M) was about double a typical month**, driven by $289.5M in scheduled bond principal and interest. Excluding debt service, February was in line with other months.
- Of 97 voided payments, all but two were reissued within the year. Open items at year-end total about $107k.

## Data

| | |
|---|---|
| **Source** | [City of Fort Worth AP Check Register](https://www.fortworthtexas.gov/departments/finance/check-register), Finance Department |
| **Period** | FY2026: October 1, 2025 – September 30, 2026 (the city's fiscal year) |
| **Rows** | 237,427 payment lines (237,184 paid, 243 void) |
| **Storage** | BigQuery dataset `fw_ap_dataset`: 12 monthly raw tables combined into one view, `ap_all` |

**Columns:** Payment ID, Payment Date, Payment Status, Amount, Payment Method, Voucher ID, Supplier Name, Invoice Number, Invoice Date, Fund, Fund Desc, Account, Acct Descr, Project, Project Descr

### Preparation

- Removed the report title row ("CHECKBOOK USED FOR WEBSITE") from each monthly file before loading.
- Defined the schema manually in BigQuery after auto-detect produced type conflicts. Payment ID, Voucher ID and Account are stored as `STRING`; Payment Date and Invoice Date are `STRING` in the raw layer; Amount is `NUMERIC`.
- Added a `source_month` column to the combined view, and reconciled row counts to the source files.

## Understanding the data

- **Invoice → Voucher → Payment.** A supplier sends an invoice. The city enters and approves it as a voucher, its record of an approved bill and which fund and account pays for it. Approved vouchers are then paid in payment runs. In systems like SAP, the voucher step is simply the posted invoice document.
- **One payment, many lines.** A single Payment ID can cover several vouchers and invoices, each split across funds and accounts. `COUNT(*)` counts lines; `COUNT(DISTINCT Payment ID)` counts payments.
- **Voids.** A void cancels a payment after it was issued, but the voucher stays open, so it is normally reissued under a new Payment ID. Voided amounts are recorded as positive, so all spend figures use Paid lines only.
- **Funds.** Government money is kept in separate funds by law; money in one fund generally can't be used for another fund's purpose. The first digit of the fund number gives its type (General, Special Revenue, Capital Projects, Debt Service, Enterprise, Internal Service, Trust).
- **Accounts.** The first digit of the account number separates real expenses (5) from assets (1), liabilities (2) and revenue (4).

## Analysis

### 1. Data validation

| Check | Result |
|---|---|
| Row count vs. source | 237,427 rows, matches the source files |
| All 12 months present | Yes, October 2025 to September 2026 |
| Status values | Paid and Void only, no blanks |
| Totals reconcile across views | Same $2.67B total by status, fund type, account group and month |

### 2. Voided payments

| Status | Payments | Lines | Amount |
|---|---:|---:|---:|
| Paid | 31,179 | 237,184 | $2,674,946,967.84 |
| Void | 97 | 243 | $30,618,277.26 |

Voids are rare (0.3% of payments) but large, averaging about $316k compared with about $86k for a paid payment.

Each voided voucher was compared with what was later paid on the same voucher:

- **Reissued for the same amount:** almost all voids, i.e. normal corrections.
- **Voided more than once:** Thomas Reprographics ($84 bill voided twice, then paid). Repeated voids inflate void totals relative to the underlying bill.
- **Two separate bills, not a duplicate:** Sycamore Creek Apts ($850 voided and reissued in July, a separate $850 paid in August).
- **Open at year-end:**
  - BrightView Landscape Services: five invoices totaling $106,451.31, paid on 9/24/2026 and voided, reissued on 9/30/2026 and voided again. No successful payment within FY2026, likely a fiscal year-end cutoff effect. The cause of the second void can't be determined from the register.
  - Guild Mortgage Company: $916.25, voided on 9/16/2026 with no reissue in FY2026.

**Lesson learned:** joining voided lines to paid lines on Voucher ID multiplied rows (a voucher with 6 void lines and 6 paid lines returned 36 rows). Aggregating per voucher with `SUM(CASE WHEN ...)` avoided the join entirely.

### 3. Top suppliers

The top 10 payees received about $1.16B (43%) of all paid spend. The top four are obligations or pass-throughs, not purchases:

| Payee | What it is | Paid |
|---|---|---:|
| BOKF NA | Bond paying agent: debt principal, interest and fees | $406.2M |
| Employees Retirement Fund | Pension contributions from payroll | $291.8M |
| Tarrant Regional Water District | Raw water purchased for the water utility | $115.5M |
| Internal Revenue Service | Payroll taxes withheld from employees | $90.1M |

The remaining six are operating and capital suppliers: construction contractors (Webber Waterworks, William J Schultz, Eagle Contracting, Thalle Construction), waste collection (Waste Management of Texas) and fire apparatus (Siddons Martin Emergency Group).

**Cross-check:** payroll withholding ($71.2M) plus FICA Medicare ($18.9M) = $90.05M, matching the $90.1M paid to the IRS.

### 4. Payment structure

The payments with the most lines are consolidated bills:

- **JP Morgan Chase Commercial Card:** 12 monthly payments of about $1M, each with 1,500–2,000 lines. This is the city's purchasing card program; each line is one card purchase (training, supplies, internet, meals, memberships). Like BOKF, it is a pass-through: the actual merchants are not visible in this data.
- **NRG Energy:** around 900 lines per payment, likely one line per electricity account (buildings, pump stations, signals, streetlights).

### 5. Spend by fund type

| Fund type | Funds | Paid | Share |
|---|---:|---:|---:|
| Enterprise | 45 | $1,022.6M | 38% |
| Capital Projects | 56 | $483.9M | 18% |
| General Fund | 1 | $482.8M | 18% |
| Debt Service | 4 | $259.8M | 10% |
| Special Revenue | 40 | $250.2M | 9% |
| Internal Service | 6 | $159.1M | 6% |
| Trust | 1 | $16.6M | 1% |

Water and stormwater debt is paid from enterprise funds, so the Debt Service type covers tax-supported debt only. Adding Water Prior Lien ($140.2M) and Stormwater ($22.0M) debt service gives total debt repayment of about $422M, consistent with the $406M paid to BOKF.

### 6. Spend by account group

| Account group | Class | Paid |
|---|---|---:|
| Capital Outlay | Expense | $720.8M |
| Contractual Services | Expense | $596.2M |
| Payroll Deductions & Clearing | Liability | $519.5M |
| Debt Service | Expense | $374.4M |
| Supplies | Expense | $114.9M |
| Raw Water Purchases | Expense | $107.3M |
| Insurance & Claims | Expense | $76.6M |
| Rentals & Leases | Expense | $75.1M |
| Cash Held by Others | Asset | $65.2M |
| Inventory & Prepaids | Asset | $19.3M |
| General Administration | Expense | $6.5M |
| Customer Deposits | Liability | $0.3M |
| Personnel | Expense | $0.3M |
| Fees Retained & Refunds | Revenue | −$1.5M |

| Class | Paid | Share |
|---|---:|---:|
| True expenses | $2,072.1M | 77.5% |
| Balance sheet movements | $602.8M | 22.5% |

Account prefix 55 was split further after checking its contents, because a single "Other Operating" label hid three different cost drivers: raw water, insurance and claims, and general administration.

The negative revenue line most likely reflects administrative fees the city keeps when passing payroll deduction money on to providers.

### 7. Monthly trend

Monthly spend ranged from $135M (November 2025, a holiday month) to $446M (February 2026). Typical months were around $200M.

February's spike was driven by $289.5M paid to BOKF, 71% of the year's debt payments to the paying agent. Many municipal bonds pay annual principal plus interest on one date in February. Excluding BOKF, February spend was about $157M.

## Limitations

- **AP Clearing:** about $6.1M (0.2%) of paid spend was recorded to a clearing account and can't be classified by purpose. About $5.2M of it relates to bank card programs (JP Morgan, U.S. Bank), where purchases are likely reclassified after payment.
- **Scope of validation:** the analysis confirms the data is complete and internally consistent. Validating individual payments would require source documents (invoices, purchase orders, approvals, bank statements) that the public register doesn't include.
- **Fiscal year cutoff:** payments completed after September 30, 2026 (such as the likely BrightView reissue) fall outside the data.
- **Card program detail:** purchasing card payments show the bank as the payee, so merchant-level spend isn't visible.

## Repository

| File | Contents |
|---|---|
| `fort_worth_ap_analysis.sql` | All SQL queries, in numbered sections that follow the analysis above |

## Next steps

- Add `account_group` in Power BI (Power Query), alongside the existing BigQuery view that adds `fund_type` to every row.
- Build a Power BI dashboard: spend by fund type, account group, supplier and month, with pass-through payees separated from operating suppliers.

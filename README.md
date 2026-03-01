# Private Bank — Data Quality Pipeline

## Overview
End-to-end data quality monitoring project simulating 
a private bank environment in Luxembourg.

## Tools
- PostgreSQL
- Python (pandas, psycopg2)
- SQL
- Excel

## Checks Performed
1. Completeness — missing KYC, risk rating, nationality
2. Uniqueness — duplicate clients and transactions
3. Referential Integrity — orphan accounts
4. Validity — negative balances, currency mismatches, 
   transactions on closed/frozen accounts

## Key Findings
| Check | Issues | % Affected |
|---|---|---|
| Currency Mismatches | 755 | 74.4% |
| Closed/Frozen Transactions | 549 | 54.1% |
| Missing Risk Rating | 63 | 30.7% |
| Missing KYC Status | 42 | 20.5% |
| Orphan Accounts | 10 | 3.3% |
| Duplicate Transactions | 15 | 1.5% |

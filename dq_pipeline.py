import psycopg2
import pandas as pd

# ── CONNECT TO POSTGRESQL ─────────────────────────────────
conn = psycopg2.connect(
    host="localhost",
    port="5432",
    database="bank_dq",
    user="postgres",
    password="postgres123"
)

# ── HELPER FUNCTION ──────────────────────────────────────
def run_check(sql):
    return pd.read_sql_query(sql, conn)

# ── SECTION 1: COMPLETENESS ──────────────────────────────
print("\n📋 SECTION 1: COMPLETENESS CHECKS")

completeness = run_check("""
    SELECT 'Missing KYC Status' AS check_name, COUNT(*) AS issue_count FROM clients WHERE kyc_status IS NULL
    UNION ALL
    SELECT 'Missing Risk Rating', COUNT(*) FROM clients WHERE risk_rating IS NULL
    UNION ALL
    SELECT 'Missing Nationality', COUNT(*) FROM clients WHERE nationality IS NULL
    UNION ALL
    SELECT 'Missing Email', COUNT(*) FROM clients WHERE email IS NULL
    UNION ALL
    SELECT 'Missing Txn Status', COUNT(*) FROM transactions WHERE status IS NULL
    UNION ALL
    SELECT 'Missing Reference', COUNT(*) FROM transactions WHERE reference IS NULL
""")

for _, row in completeness.iterrows():
    status = "⚠️  FAIL" if row['issue_count'] > 0 else "✅ PASS"
    print(f"  {status} | {row['check_name']}: {row['issue_count']} issues")

# ── SECTION 2: UNIQUENESS ────────────────────────────────
print("\n🔁 SECTION 2: UNIQUENESS CHECKS")

uniqueness = run_check("""
    SELECT 'Duplicate Clients' AS check_name, COUNT(*) AS issue_count FROM (
        SELECT client_id FROM clients GROUP BY client_id HAVING COUNT(*) > 1) x
    UNION ALL
    SELECT 'Duplicate Transactions', COUNT(*) FROM (
        SELECT transaction_id FROM transactions GROUP BY transaction_id HAVING COUNT(*) > 1) x
""")

for _, row in uniqueness.iterrows():
    status = "⚠️  FAIL" if row['issue_count'] > 0 else "✅ PASS"
    print(f"  {status} | {row['check_name']}: {row['issue_count']} issues")

# ── SECTION 3: REFERENTIAL INTEGRITY ─────────────────────
print("\n🔗 SECTION 3: REFERENTIAL INTEGRITY")

integrity = run_check("""
    SELECT 'Orphan Accounts' AS check_name, COUNT(*) AS issue_count
    FROM accounts a
    LEFT JOIN clients c ON a.client_id = c.client_id
    WHERE c.client_id IS NULL
""")

for _, row in integrity.iterrows():
    status = "⚠️  FAIL" if row['issue_count'] > 0 else "✅ PASS"
    print(f"  {status} | {row['check_name']}: {row['issue_count']} issues")

# ── SECTION 4: VALIDITY ──────────────────────────────────
print("\n✅ SECTION 4: VALIDITY CHECKS")

validity = run_check("""
    SELECT 'Negative Balances' AS check_name, COUNT(*) AS issue_count FROM accounts WHERE balance < 0
    UNION ALL
    SELECT 'Currency Mismatches', COUNT(*) FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id WHERE t.currency != a.currency
    UNION ALL
    SELECT 'Transactions on Closed/Frozen Accounts', COUNT(*) FROM transactions t
    JOIN accounts a ON t.account_id = a.account_id WHERE a.status IN ('CLOSED','FROZEN')
    UNION ALL
    SELECT 'Expired KYC with Active Accounts', COUNT(*) FROM clients c
    JOIN accounts a ON c.client_id = a.client_id
    WHERE c.kyc_status IN ('EXPIRED','REJECTED') AND a.status = 'ACTIVE'
""")

for _, row in validity.iterrows():
    status = "⚠️  FAIL" if row['issue_count'] > 0 else "✅ PASS"
    print(f"  {status} | {row['check_name']}: {row['issue_count']} issues")

# ── EXPORT SCORECARD ─────────────────────────────────────
print("\n📊 EXPORTING SCORECARD...")

all_checks = pd.concat([completeness, uniqueness, integrity, validity], ignore_index=True)
output_path = r"D:\BIG PROJECTS\Bank Data\results\python_dq_scorecard.csv"
all_checks.to_csv(output_path, index=False)
print(f"  ✅ Scorecard saved to: {output_path}")

# ── SUMMARY ──────────────────────────────────────────────
total = len(all_checks)
failed = all_checks[all_checks['issue_count'] > 0].shape[0]
passed = total - failed
score = round(passed / total * 100, 1)

print("\n" + "=" * 55)
print(f"  DATA QUALITY SCORE: {score}% ({passed}/{total} checks passed)")
print(f"  Issues found across {failed} checks")
print("=" * 55)

conn.close()
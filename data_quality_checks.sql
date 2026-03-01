-- ============================================================
--  PRIVATE BANK — DATA QUALITY CONTROL CHECKS
--  Role: Data Analyst | Hays Luxembourg
--  Tools: SQLite / PostgreSQL compatible
-- ============================================================

-- ============================================================
-- SECTION 1: COMPLETENESS CHECKS
-- Missing / NULL values in critical fields
-- ============================================================

-- 1.1 Clients with missing KYC status (regulatory risk)
SELECT 
    'clients' AS table_name,
    'kyc_status' AS field,
    COUNT(*) AS null_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM clients), 2) AS pct_missing
FROM clients
WHERE kyc_status IS NULL;

-- 1.2 Clients with missing email
SELECT 
    'clients' AS table_name,
    'email' AS field,
    COUNT(*) AS null_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM clients), 2) AS pct_missing
FROM clients
WHERE email IS NULL;

-- 1.3 Clients with missing risk rating
SELECT 
    'clients' AS table_name,
    'risk_rating' AS field,
    COUNT(*) AS null_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM clients), 2) AS pct_missing
FROM clients
WHERE risk_rating IS NULL;

-- 1.4 Transactions with missing status
SELECT 
    'transactions' AS table_name,
    'status' AS field,
    COUNT(*) AS null_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM transactions), 2) AS pct_missing
FROM transactions
WHERE status IS NULL;

-- 1.5 Transactions with missing reference number
SELECT 
    'transactions' AS table_name,
    'reference' AS field,
    COUNT(*) AS null_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM transactions), 2) AS pct_missing
FROM transactions
WHERE reference IS NULL;

-- ============================================================
-- SECTION 2: UNIQUENESS CHECKS
-- Duplicate records that should be unique
-- ============================================================

-- 2.1 Duplicate client IDs
SELECT 
    client_id,
    COUNT(*) AS occurrences
FROM clients
GROUP BY client_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- 2.2 Duplicate transaction IDs
SELECT 
    transaction_id,
    COUNT(*) AS occurrences
FROM transactions
GROUP BY transaction_id
HAVING COUNT(*) > 1
ORDER BY occurrences DESC;

-- 2.3 Full duplicate transactions (same account, date, amount, type)
SELECT 
    account_id,
    txn_date,
    amount,
    txn_type,
    COUNT(*) AS duplicate_count
FROM transactions
GROUP BY account_id, txn_date, amount, txn_type
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- ============================================================
-- SECTION 3: REFERENTIAL INTEGRITY CHECKS
-- Orphan records with no valid parent
-- ============================================================

-- 3.1 Accounts with no matching client (orphan accounts)
SELECT 
    a.account_id,
    a.client_id,
    a.account_type,
    a.status
FROM accounts a
LEFT JOIN clients c ON a.client_id = c.client_id
WHERE c.client_id IS NULL;

-- 3.2 Transactions linked to non-existent accounts
SELECT 
    t.transaction_id,
    t.account_id,
    t.amount,
    t.txn_date
FROM transactions t
LEFT JOIN accounts a ON t.account_id = a.account_id
WHERE a.account_id IS NULL;

-- ============================================================
-- SECTION 4: VALIDITY CHECKS
-- Business rule violations
-- ============================================================

-- 4.1 Accounts with negative balance (flag for review)
SELECT 
    account_id,
    client_id,
    account_type,
    balance,
    currency,
    status
FROM accounts
WHERE balance < 0
ORDER BY balance ASC;

-- 4.2 Clients with EXPIRED or REJECTED KYC but ACTIVE accounts
-- (Regulatory red flag)
SELECT 
    c.client_id,
    c.full_name,
    c.kyc_status,
    a.account_id,
    a.status AS account_status
FROM clients c
JOIN accounts a ON c.client_id = a.client_id
WHERE c.kyc_status IN ('EXPIRED', 'REJECTED')
  AND a.status = 'ACTIVE';

-- 4.3 Transactions on CLOSED or FROZEN accounts
SELECT 
    t.transaction_id,
    t.account_id,
    a.status AS account_status,
    t.txn_date,
    t.amount,
    t.txn_type
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
WHERE a.status IN ('CLOSED', 'FROZEN');

-- 4.4 Currency mismatch between transaction and account
SELECT 
    t.transaction_id,
    t.account_id,
    a.currency AS account_currency,
    t.currency AS txn_currency,
    t.amount,
    t.txn_date
FROM transactions t
JOIN accounts a ON t.account_id = a.account_id
WHERE t.currency != a.currency;

-- ============================================================
-- SECTION 5: DATA QUALITY SCORECARD
-- Summary metrics per table — use this for Tableau
-- ============================================================

SELECT 'clients' AS table_name, 'duplicate_ids'     AS check_name, COUNT(*) AS issue_count FROM clients GROUP BY client_id HAVING COUNT(*) > 1
UNION ALL
SELECT 'clients', 'missing_kyc',        COUNT(*) FROM clients WHERE kyc_status IS NULL
UNION ALL
SELECT 'clients', 'missing_email',      COUNT(*) FROM clients WHERE email IS NULL
UNION ALL
SELECT 'clients', 'missing_risk_rating',COUNT(*) FROM clients WHERE risk_rating IS NULL
UNION ALL
SELECT 'clients', 'missing_nationality',COUNT(*) FROM clients WHERE nationality IS NULL
UNION ALL
SELECT 'accounts','orphan_accounts',    COUNT(*) FROM accounts a LEFT JOIN clients c ON a.client_id = c.client_id WHERE c.client_id IS NULL
UNION ALL
SELECT 'accounts','negative_balances',  COUNT(*) FROM accounts WHERE balance < 0
UNION ALL
SELECT 'transactions','duplicate_txn_ids',     COUNT(*) FROM transactions GROUP BY transaction_id HAVING COUNT(*) > 1
UNION ALL
SELECT 'transactions','missing_status',        COUNT(*) FROM transactions WHERE status IS NULL
UNION ALL
SELECT 'transactions','missing_reference',     COUNT(*) FROM transactions WHERE reference IS NULL
UNION ALL
SELECT 'transactions','currency_mismatch',     COUNT(*) FROM transactions t JOIN accounts a ON t.account_id = a.account_id WHERE t.currency != a.currency
UNION ALL
SELECT 'transactions','txn_on_closed_accounts',COUNT(*) FROM transactions t JOIN accounts a ON t.account_id = a.account_id WHERE a.status IN ('CLOSED','FROZEN')
ORDER BY table_name, check_name;

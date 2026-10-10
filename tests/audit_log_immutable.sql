-- Proves the database itself (not application code) rejects UPDATE / DELETE / TRUNCATE on audit_log
-- while still allowing INSERT. Runs in a transaction that is rolled back, so it leaves nothing behind.
-- Run: scripts/test-audit.sh        Exit code is non-zero if any assertion fails.
\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    row_id BIGINT;
BEGIN
    -- 1. INSERT must work.
    INSERT INTO audit_log (event, action_taken) VALUES ('test_probe', 'insert allowed') RETURNING id INTO row_id;
    IF row_id IS NULL THEN RAISE EXCEPTION 'FAIL: insert did not return an id'; END IF;
    RAISE NOTICE 'PASS: INSERT allowed (id %)', row_id;

    -- 2. UPDATE must be rejected.
    BEGIN
        UPDATE audit_log SET action_taken = 'tampered' WHERE id = row_id;
        RAISE EXCEPTION 'FAIL: UPDATE succeeded';
    EXCEPTION WHEN integrity_constraint_violation THEN
        RAISE NOTICE 'PASS: UPDATE rejected (%)', SQLERRM;
    END;

    -- 3. DELETE must be rejected.
    BEGIN
        DELETE FROM audit_log WHERE id = row_id;
        RAISE EXCEPTION 'FAIL: DELETE succeeded';
    EXCEPTION WHEN integrity_constraint_violation THEN
        RAISE NOTICE 'PASS: DELETE rejected (%)', SQLERRM;
    END;

    -- 4. TRUNCATE must be rejected.
    BEGIN
        TRUNCATE audit_log;
        RAISE EXCEPTION 'FAIL: TRUNCATE succeeded';
    EXCEPTION WHEN integrity_constraint_violation THEN
        RAISE NOTICE 'PASS: TRUNCATE rejected (%)', SQLERRM;
    END;

    -- 5. The row must be unchanged.
    IF (SELECT action_taken FROM audit_log WHERE id = row_id) <> 'insert allowed' THEN
        RAISE EXCEPTION 'FAIL: row was modified';
    END IF;
    RAISE NOTICE 'PASS: row unchanged after the blocked attempts';
END $$;

ROLLBACK;

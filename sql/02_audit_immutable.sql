-- audit_log is append-only: UPDATE, DELETE and TRUNCATE are rejected by the database itself,
-- not by application code. (A superuser/table owner could still DROP the trigger; for a
-- stronger guarantee, run the app as a role that owns nothing. See README "What this does and doesn't guarantee".)

CREATE FUNCTION audit_log_reject_mutation() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION 'audit_log is append-only: % is not allowed', TG_OP
        USING ERRCODE = 'integrity_constraint_violation';
END;
$$;

CREATE TRIGGER audit_log_no_update_delete
    BEFORE UPDATE OR DELETE ON audit_log
    FOR EACH ROW EXECUTE FUNCTION audit_log_reject_mutation();

CREATE TRIGGER audit_log_no_truncate
    BEFORE TRUNCATE ON audit_log
    FOR EACH STATEMENT EXECUTE FUNCTION audit_log_reject_mutation();

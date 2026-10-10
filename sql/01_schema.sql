-- App schema. Runs once on first boot of an empty data volume.

CREATE TABLE leads (
    id                  BIGSERIAL PRIMARY KEY,
    -- sha256(lower(email) || E'\n' || message), computed in SQL by the intake workflow.
    -- The UNIQUE constraint is what makes intake idempotent.
    lead_hash           CHAR(64)    NOT NULL UNIQUE,
    name                TEXT        NOT NULL,
    email               TEXT        NOT NULL,
    phone               TEXT,
    message             TEXT        NOT NULL,
    source              TEXT        NOT NULL,
    status              TEXT        NOT NULL DEFAULT 'received'
                        CHECK (status IN ('received', 'qualified', 'needs_review')),
    score               TEXT        CHECK (score IN ('hot', 'warm', 'cold')),
    intent              TEXT,
    urgency             TEXT,
    budget_signal       TEXT,
    summary             TEXT,
    suggested_next_step TEXT,
    model               TEXT,
    prompt_version      TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    qualified_at        TIMESTAMPTZ
);
CREATE INDEX leads_created_at_idx ON leads (created_at DESC);

-- Stand-in CRM. In production this would be HubSpot / GoHighLevel / etc.
CREATE TABLE crm_contacts (
    id         BIGSERIAL PRIMARY KEY,
    lead_id    BIGINT      NOT NULL UNIQUE REFERENCES leads (id),
    name       TEXT        NOT NULL,
    email      TEXT        NOT NULL,
    phone      TEXT,
    score      TEXT        NOT NULL CHECK (score IN ('hot', 'warm')),
    stage      TEXT        NOT NULL,
    notes      TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Stand-in SMS provider: messages are queued here instead of being sent.
CREATE TABLE sms_outbox (
    id         BIGSERIAL PRIMARY KEY,
    lead_id    BIGINT      NOT NULL REFERENCES leads (id),
    to_phone   TEXT        NOT NULL,
    body       TEXT        NOT NULL,
    status     TEXT        NOT NULL DEFAULT 'queued',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only decision trail (see 02_audit_immutable.sql).
CREATE TABLE audit_log (
    id           BIGSERIAL PRIMARY KEY,
    lead_id      BIGINT      REFERENCES leads (id),   -- NULL for events with no lead (e.g. workflow errors)
    event        TEXT        NOT NULL,                -- duplicate_ignored | routed | needs_review | workflow_error
    score        TEXT,                                -- hot | warm | cold | needs_review
    llm_output   JSONB,                               -- validated model output, or the failure details
    action_taken TEXT        NOT NULL,
    detail       JSONB,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX audit_log_lead_idx ON audit_log (lead_id);

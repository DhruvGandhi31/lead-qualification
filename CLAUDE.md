# n8n Lead Qualification Demo — Build Spec

**Purpose:** a portfolio project for the *n8n Automation Developer (Remote, Contractor)* application. The employer builds AI sales systems: lead capture → qualification → routing → follow-up, with LLM chatbots on the front end and n8n + a CRM behind them. This demo mirrors that pipeline so I can link it next to my Hotel Ops repo as proof.

**Timebox:** one weekend. Phase 1 is mandatory. Phase 2 is strongly recommended, because it is the chatbot evidence the posting asks for. Don't gold-plate anything.

## Prompt to paste into Claude Code

> Read `n8n-lead-qualification-demo-spec.md` in full, then build it phase by phase. Before writing any n8n workflow JSON, check the current n8n docs for node names and parameters (they change between versions) and check the current Claude model ID in Anthropic's docs. Don't rely on memory for either. Pin all image and package versions. After each phase, run the acceptance checks for that phase and show me the output before moving on. Never invent metrics. Any number that goes in the README comes from a real run.

## What it does

A lead arrives (web form or chat widget). n8n validates it, asks Claude to qualify it, then routes it:

| Score | Action |
|---|---|
| **hot** | Create CRM record, send email with booking link, send SMS, notify owner |
| **warm** | Create CRM record, send nurture email |
| **cold** | Log it, send polite auto-reply |
| **needs_review** (LLM failed or invalid output) | Log it, notify owner, take no automated action |

## Stack (all self-hosted, Docker Compose)

- **n8n** (pinned version), workflows stored in `workflows/*.json`
- **PostgreSQL**: `leads`, `crm_contacts` (stand-in CRM), `audit_log` (append-only), `sms_outbox`
- **Mailpit**: local SMTP inbox, so emails can be shown without sending real mail
- **Claude API** (Messages API) called from n8n's HTTP Request node. The API key lives only in n8n credentials, supplied via `.env`
- **SMS**: Twilio test credentials if available, otherwise write to `sms_outbox` and document it as a stand-in
- **Chat widget (Phase 2)**: vanilla HTML/CSS/JS, served statically

Don't use PHP. The backend logic lives in n8n plus small Code nodes (JavaScript).

## Phase 1 — Lead intake workflow (must)

1. **Webhook** `POST /webhook/lead`, protected with a shared-secret header. Body: `name, email, phone, message, source`.
2. **Validate and normalise** in a Code node. Reject bad input with a 400 and a clear error body.
3. **Idempotent insert** into `leads` keyed on a sha256 of the lowercased email plus message. Duplicates return 200 with `duplicate: true`, with no second email or CRM record.
4. **Qualify with Claude**:
   - Versioned system prompt kept in `prompts/qualify.v1.md` (not hard-coded in the workflow).
   - Ask for strict JSON: `score (hot|warm|cold)`, `intent`, `urgency`, `budget_signal`, `summary`, `suggested_next_step`.
   - Validate the response against a JSON Schema in a Code node. On invalid output, retry once. If it is still invalid, set `needs_review`.
   - Model ID comes from an env var, not hard-coded.
5. **Switch** on score, as in the table above.
6. **Email** via SMTP to Mailpit. The booking link is a placeholder URL from an env var. HTML-escape every value that comes from the lead or the LLM.
7. **Audit log**: one append-only row per decision (lead id, score, LLM output, action taken, timestamp). Use a Postgres trigger to block UPDATE and DELETE on `audit_log`.
8. **Error workflow**: any failure writes to `audit_log` and emails the owner.

### Phase 1 acceptance checks
- `docker compose up` brings the whole stack up from a clean clone, with a documented `.env.example`.
- `curl` a hot, a warm and a cold lead and show: the three different routes, the emails in Mailpit, and the rows in Postgres.
- A duplicate POST creates nothing new.
- Killing the Claude call (bad key) lands in `needs_review` and the owner is notified.
- Workflows are exported to `workflows/*.json` with `scripts/export.sh` and `scripts/import.sh`.

## Phase 2 — Chat widget and chat workflow (should)

1. `widget/` contains a vanilla HTML/CSS/JavaScript chat widget (one JS file, one CSS file, one demo page). It looks like an embeddable widget, not a full app.
2. The widget posts the conversation to n8n `POST /webhook/chat`. **The browser never sees the Claude API key or calls Claude directly.** Only n8n holds the key.
3. The chat workflow calls Claude with the conversation history and a versioned prompt (`prompts/chat.v1.md`). The bot asks 3–4 qualifying questions conversationally, then offers a booking link.
4. When the bot has name, contact and enough qualifying info, it hands the lead to the Phase 1 intake workflow (Execute Workflow node or an internal webhook).
5. Add rate limiting or an origin check on the chat webhook, and document what it does and doesn't protect against.

### Phase 2 acceptance checks
- Open the demo page, have a full conversation, and watch the lead appear in Postgres with a score and the matching email in Mailpit.
- Grep the widget code and the network tab: no API keys anywhere in front-end code.

## Evaluation (follow my Hotel Ops protocol)

- `eval/generate.py` creates **60 synthetic labelled leads** (hot / warm / cold, including messy and ambiguous ones). Split them into **30 dev** (used to tune the prompt) and **30 gate** (held out, not examined until the final run).
- `eval/run.py` sends each lead through the real webhook and records the score Claude gave versus the label.
- Report accuracy, a confusion matrix, and recall on `hot`. Say plainly that the data is synthetic.
- **Keep the first run on record even if it is bad.** Document what failed and what you changed.

## Quality and safety

- Secrets only in `.env` (gitignored). Add `gitleaks` to CI.
- GitHub Actions CI: boot the stack, import the workflows, run the pipeline against a **mock Anthropic server** so CI needs no API key, and fail if a re-export of the workflows differs from what is committed.
- A Postgres-level test (SQL or pytest) that the audit log really blocks updates and deletes.
- Escape all untrusted text in emails.

## Deliverables

```
lead-qualifier-n8n/
  docker-compose.yml  .env.example  README.md
  workflows/  prompts/  sql/  widget/  eval/  scripts/  mock/  .github/workflows/
```

The README must include:
- A one-paragraph summary and a Mermaid architecture diagram.
- Quick start (clean clone to working demo).
- **Screenshots of the n8n canvas, a Mailpit email, and Postgres rows**, plus a 60–90 second screen recording (or GIF) of a lead going end to end. The posting asks for "screenshots, videos, or links".
- The evaluation results and the failed first run.
- A short "what's a stand-in" section (CRM = Postgres table, SMS = Twilio test or outbox, booking link = placeholder) so nothing is overstated.

## Resume bullets (fill in only after measured results exist)

> Built a lead-qualification pipeline on self-hosted n8n and PostgreSQL: a webhook and chat widget feed Claude, which scores each lead (hot/warm/cold) as schema-validated JSON, routes it to CRM, email and SMS actions, and logs every decision to an append-only audit trail. On held-out synthetic leads it reached **[X]%** accuracy and **[Y]%** hot-lead recall (n=30).

Do not fill `[X]` and `[Y]` with anything but real run numbers. Keep the word "synthetic".
-- AI Project Intelligence Platform — database schema

CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================================
-- Tenancy
-- ============================================================

CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- Core project & people tables
-- ============================================================

CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    slack_channel_id TEXT,
    dev_activity_channel_id TEXT,
    jira_project_key TEXT,
    github_repo TEXT,
    drive_folder_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, name)
);

CREATE TABLE developers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT,
    slack_user_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, email)
);

CREATE TABLE project_members (
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    developer_id UUID NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
    role TEXT,
    PRIMARY KEY (project_id, developer_id)
);

-- One row per connected integration (a Slack channel, a Drive folder, a
-- GitHub repo, a Fireflies meeting source, a Gmail thread...). Connectors
-- read this table to know what to sync and where they left off.
CREATE TABLE sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    type TEXT NOT NULL,
    external_id TEXT,
    url TEXT,
    last_synced TIMESTAMPTZ,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (project_id, type, external_id)
);

-- ============================================================
-- Structured knowledge
-- Extracted facts land in one of these typed tables, never a
-- generic "facts" bucket — see docs/03-Database-Design.md.
-- ============================================================

CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    owner UUID REFERENCES developers(id) ON DELETE SET NULL,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'blocked', 'done')),
    source TEXT NOT NULL,
    source_id TEXT,
    due_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (project_id, source, source_id)
);

CREATE TABLE daily_updates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    developer_id UUID NOT NULL REFERENCES developers(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    completed TEXT,
    next_work TEXT,
    blockers TEXT,
    additional_notes TEXT,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE meetings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    meeting_type TEXT CHECK (meeting_type IN ('standup', 'sprint', 'client', 'internal', 'retrospective')),
    summary TEXT,
    action_items JSONB,
    transcript TEXT,
    attendees JSONB,
    occurred_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE pr_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    pr_number INTEGER NOT NULL,
    title TEXT,
    author TEXT,
    status TEXT CHECK (status IN ('open', 'merged', 'closed')),
    opened_at TIMESTAMPTZ,
    merged_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (project_id, pr_number)
);

-- ============================================================
-- Unstructured knowledge
-- Slack threads, meeting transcripts, Drive docs, emails — kept
-- as source material and chunked into `vectors` for semantic
-- search, not force-fit into the structured tables above.
-- ============================================================

CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    title TEXT,
    source TEXT NOT NULL,
    source_id TEXT NOT NULL,
    checksum TEXT,
    mime_type TEXT,
    last_modified TIMESTAMPTZ,
    metadata JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (project_id, source, source_id)
);

-- Raw payload captured at ingestion time, before any AI processing —
-- every Slack message, email, meeting transcript, and webhook event is
-- preserved here so extraction can be debugged or re-run without
-- re-fetching from the source connector.
CREATE TABLE raw_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    source_id UUID REFERENCES sources(id) ON DELETE SET NULL,
    event_type TEXT NOT NULL,
    external_id TEXT,
    payload JSONB NOT NULL,
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed BOOLEAN NOT NULL DEFAULT false,
    processed_at TIMESTAMPTZ,
    UNIQUE (project_id, event_type, external_id)
);

-- Dimension matches the Voyage embedding model used elsewhere in this
-- project; adjust if the embedding model changes.
CREATE TABLE vectors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    source_type TEXT NOT NULL,
    source_id TEXT,
    content TEXT NOT NULL,
    embedding VECTOR(1024),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- Project health history
-- A history of scores, not just the latest value — lets a project's
-- health be plotted over time instead of overwritten every run.
-- ============================================================

CREATE TABLE project_health (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    score INTEGER NOT NULL CHECK (score BETWEEN 0 AND 100),
    reason TEXT,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- Generated artifacts
-- ============================================================

CREATE TABLE daily_briefs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    brief TEXT NOT NULL,
    llm_model TEXT,
    posted_to_slack BOOLEAN NOT NULL DEFAULT false,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
    type TEXT NOT NULL CHECK (type IN ('slack_reminder', 'morning_brief', 'leadership_summary', 'standup_reminder', 'escalation')),
    recipient TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed', 'read', 'retrying')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    payload JSONB,
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- Observability
-- ============================================================

CREATE TABLE agent_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
    workflow_name TEXT,
    prompt TEXT NOT NULL,
    response TEXT,
    model TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- Indexes
-- ============================================================

CREATE INDEX idx_projects_tenant ON projects(tenant_id);
CREATE INDEX idx_developers_tenant ON developers(tenant_id);
CREATE INDEX idx_sources_project ON sources(project_id);
CREATE INDEX idx_tasks_project ON tasks(project_id);
CREATE INDEX idx_tasks_owner ON tasks(owner);
CREATE INDEX idx_daily_updates_project ON daily_updates(project_id);
CREATE INDEX idx_daily_updates_developer ON daily_updates(developer_id);
CREATE INDEX idx_meetings_project ON meetings(project_id);
CREATE INDEX idx_pr_activity_project ON pr_activity(project_id);
CREATE INDEX idx_documents_project ON documents(project_id);
CREATE INDEX idx_raw_events_project_processed ON raw_events(project_id, processed);
CREATE INDEX idx_vectors_project ON vectors(project_id);
CREATE INDEX idx_vectors_embedding ON vectors USING hnsw (embedding vector_cosine_ops);
CREATE INDEX idx_project_health_project_calculated ON project_health(project_id, calculated_at DESC);
CREATE INDEX idx_daily_briefs_project_generated ON daily_briefs(project_id, generated_at DESC);
CREATE INDEX idx_notifications_project ON notifications(project_id);
CREATE INDEX idx_notifications_status ON notifications(status);
CREATE INDEX idx_agent_logs_project ON agent_logs(project_id);

-- ============================================================
-- Row-level security
-- RLS is a no-op for superusers and table owners, so the app must
-- connect as a dedicated, non-superuser role for these policies to
-- actually apply (confirmed against this project's Postgres setup).
-- ============================================================

CREATE ROLE app_user WITH LOGIN PASSWORD 'app_password' NOSUPERUSER;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON
    projects, developers, project_members, sources, tasks, daily_updates,
    meetings, pr_activity, documents, raw_events, vectors, project_health,
    daily_briefs, notifications, agent_logs
    TO app_user;

DO $$
DECLARE
    t TEXT;
BEGIN
    FOREACH t IN ARRAY ARRAY[
        'projects', 'developers', 'project_members', 'sources', 'tasks', 'daily_updates',
        'meetings', 'pr_activity', 'documents', 'raw_events', 'vectors', 'project_health',
        'daily_briefs', 'notifications', 'agent_logs'
    ]
    LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
        EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
        EXECUTE format(
            'CREATE POLICY tenant_isolation ON %I USING (tenant_id = NULLIF(current_setting(''app.tenant_id'', true), '''')::uuid)',
            t
        );
    END LOOP;
END $$;

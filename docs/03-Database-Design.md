# Database Design

## Overview

The schema models project intelligence as typed, queryable entities — not a generic document store. See [database/schema.sql](../database/schema.sql) for the full definition.

Hierarchy: `tenant` → `project` → everything else (`tasks`, `daily_updates`, `meetings`, etc.) hangs off `project_id`.

## Why not a generic `facts` table?

An earlier draft of this schema had a single `facts` table for anything the AI extracted. That collapses information that actually has different shapes and different consumers:

- "John completed Authentication" is a **task** update (`tasks.status`), not a fact.
- "API blocked because credentials missing" is a **blocker** (`daily_updates.blockers`), not a fact.

Routing extraction output into typed tables means questions like "what's overdue," "who's blocked today," and "which PRs merged yesterday" are plain SQL queries, not something that has to round-trip through an LLM every time.

## Structured tables

| Table | Purpose |
|---|---|
| `tenants` | Top-level tenant records (multi-tenant isolation) |
| `projects` | One row per project — links out to its Slack channel, Jira project, GitHub repo, and Drive folder |
| `developers` | People, with their Slack user id for cross-referencing standups/messages |
| `project_members` | Many-to-many join between `developers` and `projects`, with a `role` |
| `sources` | One row per connected integration (a Slack channel, Drive folder, GitHub repo, Fireflies meeting, Gmail thread) — tells each connector what to sync and where it left off (`last_synced`) |
| `tasks` | The structured knowledge table — work items from Jira, GitHub, or AI extraction, deduped per project via `(source, source_id)` |
| `daily_updates` | One row per developer standup: `completed`, `next_work`, `blockers`, `additional_notes` |
| `meetings` | Meeting summaries, action items, transcripts, attendees, tagged with `meeting_type` (standup/sprint/client/internal/retrospective) so downstream summarization can filter by type |
| `pr_activity` | GitHub PR lifecycle: opened/merged timestamps, author, status |
| `project_health` | A history of health scores (`score`, `reason`, `calculated_at`) rather than a single overwritten value on `projects`, so health can be tracked over time |
| `daily_briefs` | Every generated morning brief (`brief`, `llm_model`, `posted_to_slack`), so past briefs are queryable knowledge instead of being regenerated |
| `notifications` | Outbound messages (Slack reminders, briefs, leadership summaries, escalations) with a `status` (pending/sent/failed/read/retrying) and `retry_count` |
| `agent_logs` | Every AI request/response, tagged with `workflow_name` (e.g. "Morning Brief", "Standup Extraction") for debugging and auditing |

## Unstructured knowledge (vector search)

`documents`, `raw_events`, and `vectors` hold source material that doesn't reduce to a structured row without losing information — Slack conversations, meeting transcripts, Google Docs, emails:

- `raw_events` captures the raw payload at ingestion time, before any AI processing, so extraction can be debugged or re-run without re-fetching from the source connector.
- `documents` holds known files/artifacts (Drive docs, etc.), with `checksum`, `mime_type`, and `last_modified` for deduplication.
- `vectors` holds the chunked, embedded content used for semantic search (pgvector + HNSW), sourced from either of the above.

These stay separate from the structured tables above rather than being force-fit into them.

## Isolation

Every table carries a `tenant_id` and row-level security policies scope all queries to the current tenant (`app.tenant_id` session setting). Policies are enforced via `FORCE ROW LEVEL SECURITY` under a dedicated non-superuser `app_user` role, since RLS has no effect on superusers or table owners.

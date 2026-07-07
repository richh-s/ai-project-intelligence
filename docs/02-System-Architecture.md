# System Architecture

## Overview

The platform is composed of ingestion connectors, a raw-event store, an extraction layer that routes into typed tables, a vector store for unstructured content, and a briefing/chat layer.

## Components

- **Ingestion connectors** — GitHub, Slack, Jira, Google Drive (config tracked per-project in `sources`)
- **Raw event store** — preserves every ingested payload (`raw_events`) before any AI processing
- **Extraction** — LLM-based extraction that routes results into typed tables (`tasks`, `daily_updates`, `meetings`, `pr_activity`) rather than a generic facts table — see [03-Database-Design.md](03-Database-Design.md)
- **Embeddings/vector store** — chunks and embeds unstructured content (`vectors`) for semantic search
- **Database** — see [03-Database-Design.md](03-Database-Design.md) for the full schema
- **Briefing/chat layer** — generates morning briefs (`daily_briefs`) and answers ad-hoc questions, dispatching outbound messages via `notifications`

## Data Flow

1. A connector pulls a raw event (Slack message, email, meeting transcript, webhook, etc.) on a schedule (via n8n workflows)
2. **Resolve project** — map the event to the correct `project_id`/`tenant_id` via `sources`
3. **Store raw event** — persist the untouched payload to `raw_events` before any processing, so extraction can be debugged or re-run without re-fetching from the connector
4. **Extract facts** — an LLM extracts structured content from the raw event
5. **Update structured tables** — extraction output is routed into `tasks`, `daily_updates`, `meetings`, or `pr_activity` based on what it actually is, not dumped into a generic bucket
6. **Generate embeddings** — the raw content is chunked and embedded
7. **Vector store** — embeddings land in `vectors` for semantic search over Slack conversations, transcripts, and documents

This separation — raw storage before extraction, typed tables after — preserves the original data for debugging and lets extraction logic improve later without re-ingesting from source connectors.

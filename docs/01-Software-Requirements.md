# Software Requirements

## Purpose

Define the functional and non-functional requirements for the AI Project Intelligence Platform.

## Functional Requirements

- Ingest data from GitHub, Slack, Jira, and Google Drive
- Extract structured facts from ingested content using an LLM
- Generate a daily morning brief summarizing project activity
- Support multi-tenant data isolation

## Non-Functional Requirements

- Data isolation between tenants (row-level security)
- Auditable ingestion pipeline
- Configurable via environment variables, no hard-coded secrets

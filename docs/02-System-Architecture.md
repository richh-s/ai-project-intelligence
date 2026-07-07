# System Architecture

## Overview

The platform is composed of ingestion connectors, a fact-extraction layer, a database, and a briefing/chat layer.

## Components

- **Ingestion connectors** — GitHub, Slack, Jira, Google Drive
- **Fact extraction** — LLM-based extraction of structured facts from raw ingested content
- **Database** — stores tenants, projects, ingested events, and extracted facts
- **Briefing/chat layer** — generates morning briefs and answers ad-hoc questions

## Data Flow

1. Connectors pull raw events/documents on a schedule (via n8n workflows)
2. Raw content is stored and queued for fact extraction
3. Facts are extracted and written to the database
4. The briefing layer queries facts to produce summaries and answer questions

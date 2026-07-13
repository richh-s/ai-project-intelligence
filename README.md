# AI Project Intelligence Platform

An AI-powered platform that ingests signals from engineering and PM tools (GitHub, Slack, Jira, Google Drive) and surfaces project intelligence — extracted facts, morning briefs, and automated workflows.

## Structure

- `docs/` — requirements, architecture, database design, API integrations, n8n workflow docs
- `database/` — SQL schema
- `prompts/` — LLM prompt templates used for fact extraction and briefing
- `workflows/exported-workflows/` — exported n8n workflow JSON files
- `screenshots/` — UI and workflow screenshots

## Status

Currently building out the n8n workflow layer (Project Setup → Health Score, plus reconciliation, notification dispatch, escalation, and leadership summary workflows).



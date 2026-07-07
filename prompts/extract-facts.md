# Prompt: Extract Facts

You are given a raw event or document from a project's ingestion pipeline (GitHub, Slack, Jira, or Google Drive).

Extract a list of discrete, atomic facts relevant to project status, decisions, blockers, or ownership. Each fact should be a single, self-contained statement with its source and timestamp.

## Input

- `source`: the origin system (github | slack | jira | drive)
- `content`: the raw text

## Output

A JSON array of facts, each with `content`, `source`, and `confidence`.

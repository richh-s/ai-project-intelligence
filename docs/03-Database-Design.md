# Database Design

## Overview

Describes the schema used to store tenants, projects, ingested source data, and extracted facts. See [database/schema.sql](../database/schema.sql) for the full definition.

## Key Tables

- `tenants` — top-level tenant records
- `projects` — projects belonging to a tenant
- `facts` — structured facts extracted from ingested content

## Isolation

Row-level security policies scope all queries to the current tenant.

# LexAggr Design Spec

**Date:** 2026-04-12
**Status:** Approved
**Approach:** Monolith-First with Strategy Pattern (Approach A)

---

## Overview

LexAggr is a European legislation aggregation platform built in Rails 8. It ingests legislation from official APIs, SPARQL endpoints, RSS feeds, and bulk data dumps across EU and national jurisdictions — no scraping. The primary audience is compliance teams and enterprises who need to monitor regulatory changes across European jurisdictions.

## Stack

- **Ruby 3.3+**, **Rails 8.0+** (full-stack monolith)
- **PostgreSQL 16+** with extensions: `ltree`, `pg_trgm`
- **Solid Queue** for background jobs and recurring task scheduling
- **Hotwire** (Turbo + Stimulus) for UI
- **Propshaft** (Rails 8 default asset pipeline)

### Gem Dependencies

| Gem | Purpose |
|-----|---------|
| `nokogiri` | XML parsing (AKN, Formex, CLML) — bundled with Rails |
| `faraday` + `faraday-retry` | HTTP client with retry/backoff for APIs |
| `feedjira` | RSS/Atom feed parsing |
| `sparql-client` | SPARQL queries to CELLAR/Fedlex |
| `pg_search` | PostgreSQL full-text search wrapper |
| `mission_control-jobs` | Solid Queue monitoring dashboard |

---

## Database Schema

### Tables

**`jurisdictions`**
- `code` (string, unique) — "eu", "gb", "fi", "pl", "es", etc.
- `name` (string)
- `jurisdiction_type` (string) — "supranational" or "country"
- `api_config` (jsonb) — endpoint URLs, auth tokens, rate limit config

**`legislations`** (FRBR Work level)
- `jurisdiction_id` (FK)
- `frbr_uri` (string, unique) — canonical deduplication key
- `celex_number` (string, nullable)
- `eli_uri` (string, nullable)
- `title` (string)
- `legislation_type` (string) — "regulation", "directive", "act"
- `year` (integer)
- `status` (string) — "in_force", "repealed", "pending"
- `source_identifier` (string)
- `content_hash` (string) — SHA-256 for change detection
- `searchable` (tsvector, GIN indexed)

**`legislation_versions`** (FRBR Expression level)
- `legislation_id` (FK)
- `version_uri` (string, unique)
- `language` (string, default "en")
- `valid_from` (date) — temporal validity start
- `valid_to` (date, nullable) — null = currently in force
- `publication_date` (date)
- `version_type` (string) — "original", "consolidation", "amendment"
- `raw_xml` (text)
- `raw_html` (text)

**`document_nodes`** (hierarchical body structure)
- `legislation_version_id` (FK)
- `parent_id` (FK, self-referential)
- `tree_path` (ltree, GiST indexed) — e.g. "act_1.part_2.chp_3.art_5"
- `element_type` (string) — "article", "section", "chapter", etc.
- `eid` (string) — Akoma Ntoso eId attribute
- `num` (string)
- `heading` (string)
- `content_text` (text)
- `position` (integer)
- `depth` (integer)
- `searchable` (tsvector, GIN indexed)

**`ingestion_logs`**
- `jurisdiction_id` (FK)
- `source_name` (string)
- `status` (string) — "running", "completed", "failed"
- `documents_processed` (integer, default 0)
- `last_etag` (string)
- `last_modified_at` (datetime)
- `error_message` (text)

### Key Design Decisions

- **ltree** for hierarchy: `<@` (descendant), `@>` (ancestor), `*{1}` (direct children)
- **Temporal scopes**: `in_force_on(date)` and `current` on legislation_versions
- **tsvector** with `setweight` (title=A, headings=B, body=D) for ranked full-text search
- **pg_trgm** GIN index for fuzzy/typo-tolerant search
- **content_hash** for idempotent ingestion — skip unchanged documents

---

## Ingestion Architecture

### Strategy Pattern

One service class per jurisdiction behind a common interface:

```
IngestionServiceFactory.for("eu") -> EurlexSparqlService
IngestionServiceFactory.for("gb") -> UkLegislationService
IngestionServiceFactory.for("fi") -> FinlexService
... etc
```

Each service implements:
- `#fetch_document_list(since:)` — returns array of document references
- `#fetch_document(ref)` — returns standardized metadata hash + raw content

### Fan-Out Pattern

1. Coordinator job fetches document list for a jurisdiction
2. Enqueues one `ParseLegislationDocumentJob` per document
3. Each job: fetch content -> parse XML -> upsert models -> update content_hash
4. One failed document doesn't block the batch

### Idempotency

`Legislation.find_or_initialize_by(frbr_uri:)` + compare `content_hash` before re-processing.

### Parser Layer

- `AknParser` — Akoma Ntoso XML (UK, Finland, Switzerland)
- `FormexParser` — Formex 4 XML (EUR-Lex older documents)
- `ClmlParser` — Crown Legislation Markup Language (UK)
- All register XML namespaces with Nokogiri

### Change Detection

| Source | Method | Frequency |
|--------|--------|-----------|
| EUR-Lex RSS | Predefined feeds via feedjira | Every 2 hours |
| EUR-Lex SPARQL | Date-filtered CELLAR query | Every 6 hours |
| UK Publication Log | Atom feed with pbl:Event metadata | Hourly |
| Finland/Poland/Spain | REST API with date params | Daily |
| Bulk dumps (Germany, France) | SHA-256 content hash comparison | Weekly |

### HTTP Resilience

Faraday with retry middleware, exponential backoff on 429/503. Store ETag/Last-Modified in ingestion_logs for conditional requests (304 Not Modified). Random jitter (0-60s) on scheduled polls.

### Scheduling

Solid Queue recurring tasks defined in `config/recurring.yml`.

---

## Minimal UI (Hotwire)

Testing/demo UI — no authentication in Phase 1.

**Pages:**
- **Dashboard** (`/`) — ingestion status per jurisdiction, quick stats
- **Legislation index** (`/legislations`) — filterable list by jurisdiction, type, status, year. Turbo Frame pagination.
- **Legislation show** (`/legislations/:id`) — metadata, version timeline, hierarchical document tree (expandable via Turbo Frames)
- **Search** (`/search`) — full-text search with jurisdiction/type/date filters. pg_search with tsearch + trigram fallback.
- **Ingestion logs** (`/admin/ingestion_logs`) — monitor job runs, errors, ETags
- **Mission Control** (`/jobs`) — Solid Queue dashboard (mounted engine)

**Styling:** Minimal CSS framework (Pico CSS or similar). No heavy frontend build chain.

---

## Directory Structure

```
app/
  models/           # Jurisdiction, Legislation, LegislationVersion, DocumentNode, IngestionLog
  services/
    ingestion/      # IngestionServiceFactory, base service, one per jurisdiction
    parsers/        # AknParser, FormexParser, ClmlParser
  jobs/             # Coordinator + ParseLegislationDocumentJob
  views/            # Hotwire UI (dashboard, legislations, search, admin)
  controllers/      # Standard Rails controllers
config/
  recurring.yml     # Solid Queue scheduled tasks
db/
  migrate/          # Schema with ltree, tsvector, temporal versioning
```

---

## Phase 1 Scope (Foundation + EUR-Lex)

### In scope:
- Rails 8 project scaffold with full-stack Hotwire setup
- PostgreSQL schema (all tables, ltree, tsvector, indexes)
- Ingestion framework: IngestionServiceFactory, base service interface
- EurlexSparqlService — CELLAR SPARQL queries for regulations/directives
- AknParser + FormexParser for EUR-Lex content
- EUR-Lex RSS feed polling job
- Fan-out job pattern with ParseLegislationDocumentJob
- Seed data: jurisdiction records for all planned countries
- Minimal UI: dashboard, legislation index/show, search, ingestion logs
- config/recurring.yml with EUR-Lex polling schedules
- Git repo on GitHub (jouleka/LexAggr)

### NOT in scope (later phases):
- UK, Finland, Poland, Spain, and other jurisdictions
- Authentication/authorization
- Alerting/notification system for regulatory changes
- JSON API endpoints
- Production deployment configuration
- Advanced compliance features (cross-jurisdiction comparison, impact analysis)

---

## Verified Data Sources (Research Summary)

All API endpoints, authentication requirements, and data formats verified as of 2026-04-12.

### Corrections from original research:
- Poland changes endpoint: `GET /changes/acts` (flat path), not `/changes/{publisher}/{year}`
- Finland bulk sizes: now 3.9 GB / 10.9 GB (growing)
- Solid Queue recurring tasks: `config/recurring.yml`, not `config/queue.yml`
- ltree pattern syntax: `*{1}` not `*.{1}` (no dot before brace)
- ltree operators: `<@` = descendant, `@>` = ancestor
- GoodJob works on Rails 7 AND 8
- Italy Normattiva `/ricerca/aggiornati` endpoint unverified
- Virtuoso upgraded to v8 (March 2026)

### Tier 1 Sources (Phase 1-3):
- **EUR-Lex CELLAR** — SPARQL (no auth), REST, RSS, bulk dumps
- **UK legislation.gov.uk** — REST/Atom (no auth, 3000 req/5min)
- **Finland Finlex** — REST with AKN XML (no auth)
- **Poland Sejm ELI** — REST JSON (no auth)

### Tier 2 Sources (Phase 4-5):
- **Spain BOE** — REST (no auth)
- **Italy Normattiva** — REST JSON (no auth, launched 2025)
- **France Legifrance** — OAuth 2.0 via PISTE, or bulk XML from DILA
- **Switzerland Fedlex** — SPARQL (no auth)
- **Austria RIS OGD** — REST+SOAP (no auth, CC BY 4.0)

### Tier 3 Sources (Phase 6):
- **Germany** — XML bulk only, no API
- **Netherlands** — SRU protocol (160GB bulk)
- **Sweden Riksdagen** — REST XML/JSON (no auth)
- **Denmark Retsinformation** — REST (1 req/10s, 03:00-23:45 only)
- **Norway Lovdata** — REST XML (NLOD 2.0)
- **Portugal DRE** — ELI URIs only, no real API

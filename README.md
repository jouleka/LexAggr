# LexAggr

[![CI](https://github.com/jouleka/LexAggr/actions/workflows/ci.yml/badge.svg)](https://github.com/jouleka/LexAggr/actions/workflows/ci.yml)
[![Secret scan](https://github.com/jouleka/LexAggr/actions/workflows/secret-scan.yml/badge.svg)](https://github.com/jouleka/LexAggr/actions/workflows/secret-scan.yml)
[![CodeQL](https://github.com/jouleka/LexAggr/actions/workflows/codeql.yml/badge.svg)](https://github.com/jouleka/LexAggr/actions/workflows/codeql.yml)

LexAggr is a Rails 8 research platform for aggregating, normalizing, searching, and monitoring European legislation from official public data sources.

It models legislation using FRBR-style works and versions, stores structured document trees, provides PostgreSQL full-text search, and runs scheduled ingestion through Solid Queue.

> LexAggr is independent research software. It is not affiliated with any government or publisher, and its output is not legal advice. Always verify legal text against the authoritative source.

## Features

- Thirteen ingestion adapters covering EU and national sources
- Akoma Ntoso and Formex parsing
- Versioned legislation with content hashes for idempotent ingestion
- PostgreSQL `ltree`, trigram, and weighted full-text search
- Cross-reference tracking between legislation records
- Public HTML browsing, search, CSV/PDF export, and ELI resolution
- Account watchlists and configurable alert digests
- Bearer-token JSON API under `/api/v1`
- Solid Queue scheduling and Mission Control job monitoring

Implemented source adapters:

| Code | Jurisdiction | Source style |
| --- | --- | --- |
| `eu` | European Union | EUR-Lex CELLAR SPARQL and RSS |
| `gb` | United Kingdom | legislation.gov.uk Atom and AKN |
| `fi` | Finland | Finlex API and AKN |
| `pl` | Poland | Sejm ELI API |
| `es` | Spain | BOE open-data API |
| `ch` | Switzerland | Fedlex SPARQL and AKN |
| `fr` | France | DILA open-data distribution |
| `it` | Italy | Normattiva API |
| `de` | Germany | Gesetze-im-Internet XML |
| `at` | Austria | RIS open data |
| `se` | Sweden | Riksdagen open data |
| `dk` | Denmark | Retsinformation API |
| `no` | Norway | Lovdata API |

Source availability, schemas, rate limits, and licensing terms can change. Each operator is responsible for confirming that their use complies with the relevant publisher's terms.

## Architecture

```text
Official feeds and APIs
          |
          v
JurisdictionSyncJob
          |
          v
ParseLegislationDocumentJob ---> AKN/Formex parsers
          |
          v
PostgreSQL (works, versions, document tree, search)
          |
          +--> Rails/Hotwire web UI
          +--> JSON API
          +--> CSV/PDF exports
          +--> watchlist alerts
```

The application is a Rails monolith using PostgreSQL 16+, Solid Queue, Solid Cache, Solid Cable, Hotwire, and Propshaft.

## Local setup

Requirements:

- Ruby 3.4.5
- PostgreSQL 16 or newer
- Bundler 2.7+

```bash
git clone https://github.com/jouleka/LexAggr.git
cd LexAggr
bin/setup --skip-server
bin/rails db:seed
bin/dev
```

The default development database is `lex_aggr_development`. The database user must be able to enable the `ltree` and `pg_trgm` extensions during migration.

To run a jurisdiction sync immediately:

```bash
bin/rails runner 'JurisdictionSyncJob.perform_now("eu")'
```

Recurring production schedules are defined in [`config/recurring.yml`](config/recurring.yml).

API tokens are stored as one-way digests. Generate or rotate a token from a trusted console and capture the returned value once:

```ruby
user = User.find_by!(email_address: "operator@example.com")
token = user.rotate_api_token!
```

Send it as `Authorization: Bearer <token>` to `/api/v1` requests. Rotation immediately invalidates the previous token.

## Verification

```bash
bin/rails test
bundle exec rubocop
bundle exec brakeman --no-pager --quiet
bundle exec bundle-audit check --update
```

GitHub Actions runs the same checks for pushes and pull requests. Gitleaks scans repository history, CodeQL analyzes Ruby after the repository is public, and dependency review blocks vulnerable pull-request changes.

## Deployment

The repository includes a Dockerfile and a placeholder Kamal configuration. Before deployment:

1. Replace `YOUR_SERVER_IP` and `lexaggr.example.com` in `config/deploy.yml`.
2. Provide `KAMAL_REGISTRY_PASSWORD`, `RAILS_MASTER_KEY`, `DATABASE_URL`, and `POSTGRES_PASSWORD` through the environment or a password manager.
3. Keep raw secrets out of `.kamal/secrets`; that tracked file must contain only environment/password-manager lookups.
4. Run `bin/kamal setup` for the initial deployment.

`.dockerignore` explicitly excludes `config/master.key`, local environments, logs, storage, and Git metadata from image build contexts.

## Security

Please report vulnerabilities privately through [GitHub Security Advisories](https://github.com/jouleka/LexAggr/security/advisories/new). Do not include credentials or exploit details in a public issue. See [SECURITY.md](SECURITY.md) for the policy and [`security_best_practices_report.md`](security_best_practices_report.md) for the current review.

## Contributing

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

LexAggr is released under the [MIT License](LICENSE).

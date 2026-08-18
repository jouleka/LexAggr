# Security review

Reviewed for public release on 2026-08-18. This review covered the current tree, complete Git history and refs, Rails request and data-rendering paths, export handling, dependency state, GitHub Actions, and the production container boundary.

## Executive summary

No committed credentials were found in the current tree or complete repository history. Two high-impact release blockers were fixed: Docker builds could include ignored local secrets because the build context had no exclusion policy, and API bearer tokens were stored as plaintext in the database. Imported HTML and CSV exports also received explicit output-boundary protections.

At review completion, the Rails tests, RuboCop, Brakeman, Bundler Audit, actionlint, complete-history Gitleaks scan, and production Docker build all pass. The release commit is additionally checked by pinned GitHub workflows.

## Critical findings

No unresolved critical findings.

## High severity — fixed

### LEX-SEC-001: Local secrets could enter production images

The Dockerfile copies the repository build context at [Dockerfile:22](Dockerfile#L22). Before this review, the repository had no `.dockerignore`, so ignored local files such as `config/master.key` could still be sent to Docker and copied into an image.

The new denylist excludes Git metadata, environment files, Rails credential keys, Kamal data, and development artifacts at [.dockerignore:1](.dockerignore#L1)-[23](.dockerignore#L23). The verified build context is approximately 250 KB, and the resulting image does not contain `/rails/config/master.key` or `/rails/.git`.

No master key was found in Git history and no local LexAggr image existed before this verification. GitHub Container Registry could not be enumerated with the current token's package scopes. If a pre-fix image was ever built and pushed, rotate the Rails master key and credentials before treating that registry image as trusted.

### LEX-SEC-002: API tokens were stored as reusable plaintext

Anyone able to read the users table could previously reuse API bearer tokens directly. The migration at [db/migrate/20260818211500_hash_api_tokens.rb:6](db/migrate/20260818211500_hash_api_tokens.rb#L6)-[16](db/migrate/20260818211500_hash_api_tokens.rb#L16) renames the field and hashes existing tokens in place. New rotations return the raw token once while persisting only its SHA-256 digest at [app/models/user.rb:13](app/models/user.rb#L13)-[23](app/models/user.rb#L23).

This migration preserves existing clients: the raw token they already hold authenticates against the migrated digest. The reverse migration is intentionally blocked because plaintext tokens cannot be recovered.

## Medium severity — fixed

### LEX-SEC-003: Imported legislation HTML needed one trusted rendering boundary

Official publisher feeds are external input. Rendering rules are now centralized in a restricted tag and attribute allowlist at [app/helpers/application_helper.rb:2](app/helpers/application_helper.rb#L2)-[24](app/helpers/application_helper.rb#L24). Regression tests verify that scripts, event handlers, and JavaScript URLs are removed while legislation tables remain usable.

### LEX-SEC-004: CSV exports allowed spreadsheet formulas

User- and publisher-controlled cells beginning with spreadsheet formula characters could execute when an export was opened in a desktop spreadsheet application. Dynamic CSV cells now pass through the guard at [app/controllers/exports_controller.rb:4](app/controllers/exports_controller.rb#L4) and [105](app/controllers/exports_controller.rb#L105)-[108](app/controllers/exports_controller.rb#L108).

### LEX-SEC-005: API parsing and session cookie hardening

API authorization now accepts only an exact 64-character hexadecimal bearer token and clamps pagination bounds at [app/controllers/api/v1/base_controller.rb:8](app/controllers/api/v1/base_controller.rb#L8)-[22](app/controllers/api/v1/base_controller.rb#L22). Production session cookies now explicitly require HTTPS at [app/controllers/concerns/authentication.rb:41](app/controllers/concerns/authentication.rb#L41)-[49](app/controllers/concerns/authentication.rb#L49).

## Defense in depth

- CI uses read-only permissions, concurrency cancellation, SHA-pinned actions, a digest-pinned PostgreSQL service, Rails tests, RuboCop, Brakeman, and Bundler Audit at [.github/workflows/ci.yml:10](.github/workflows/ci.yml#L10)-[90](.github/workflows/ci.yml#L90).
- Complete-history secret scanning runs on pushes and pull requests using SHA-pinned checkout and Gitleaks at [.github/workflows/secret-scan.yml:10](.github/workflows/secret-scan.yml#L10)-[25](.github/workflows/secret-scan.yml#L25).
- CodeQL, dependency review, weekly Dependabot updates, and digest-pinned runtime images provide additional supply-chain controls.
- The production container runs as the unprivileged `1000:1000` user at [Dockerfile:35](Dockerfile#L35)-[38](Dockerfile#L38).

## Residual considerations

- Historical commits retain the original author email address. This is identity metadata, not a secret, and remains intentionally because public release preserves all existing commit history.
- Mission Control Jobs enables HTTP Basic authentication by default. Configure its username and password in Rails credentials before exposing `/jobs`; do not disable authentication on a public deployment.
- Publisher availability, licensing, terms, and data formats can change. Operators remain responsible for confirming permitted use of each official source and respecting rate limits.
- If any container image was built or pushed before `.dockerignore` existed, rotate `RAILS_MASTER_KEY` and the encrypted credentials it protects.

## Verification record

- Complete-history Gitleaks scan: 61 commits across all refs, no leaks.
- Rails: 219 tests, 596 assertions, 0 failures, 0 errors, 0 skips.
- RuboCop: 130 files inspected, 0 offenses.
- Brakeman 8.0.6: 0 warnings.
- Bundler Audit: no vulnerable dependencies.
- actionlint 1.7.12: all workflows valid.
- Production Docker build: successful; `config/master.key` and `.git` absent; runtime user `1000:1000`.

Security checks reduce risk but do not prove the absence of every vulnerability. Report suspected issues through the repository's private vulnerability reporting flow described in [SECURITY.md](SECURITY.md).

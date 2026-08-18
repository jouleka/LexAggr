# Security policy

## Supported version

Security fixes are applied to the current `main` branch. Older commits and tags are not maintained as separate release lines.

## Reporting a vulnerability

Use [GitHub's private vulnerability reporting](https://github.com/jouleka/LexAggr/security/advisories/new) to report a suspected vulnerability.

Please include:

- the affected component and revision;
- reproduction steps or a minimal proof of concept;
- the expected impact;
- any suggested mitigation.

Do not open a public issue containing exploit details, credentials, personal data, or information about a live deployment. You should receive an initial response within seven days.

## Sensitive files

Never commit or attach:

- `config/master.key`;
- `.env` files;
- raw `.kamal/secrets` values;
- database exports or production logs;
- registry, API, SMTP, or infrastructure credentials.

If a secret is exposed, revoke or rotate it immediately. Removing it from the latest commit is not sufficient because Git retains history.

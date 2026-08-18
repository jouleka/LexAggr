# Contributing

Thanks for contributing to LexAggr.

## Before opening a change

- Use an issue for substantial features or changes to ingestion semantics.
- Keep jurisdiction-specific behavior inside its ingestion service.
- Use only official or clearly licensed data sources and document their terms.
- Never commit credentials, API tokens, Rails master keys, private server details, or production data.
- Add fixtures that are minimal, redistributable, and free of personal data.

## Development workflow

```bash
bin/setup --skip-server
bin/rails test
bundle exec rubocop
bundle exec brakeman --no-pager --quiet
bundle exec bundle-audit check --update
```

Add focused tests for new behavior. Ingestion fixtures should use fixed dates when the test concerns historical data so the suite does not change as time passes.

## Pull requests

A pull request should explain:

- what changed and why;
- which source or jurisdiction is affected;
- how the change was verified;
- any schema, deployment, licensing, or compatibility implications.

Keep changes focused and do not include unrelated formatting or generated local files.

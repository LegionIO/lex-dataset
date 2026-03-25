# lex-dataset

**Level 3 Documentation**
- **Parent**: `/Users/miverso2/rubymine/legion/extensions-agentic/CLAUDE.md`
- **Grandparent**: `/Users/miverso2/rubymine/legion/CLAUDE.md`

## What Is This Gem?

Versioned dataset management for LegionIO. Stores named datasets with immutable versioned rows (input/expected-output pairs), content-hash deduplication, and CSV/JSON/JSONL import/export.

**Gem**: `lex-dataset`
**Version**: 0.2.1
**Namespace**: `Legion::Extensions::Dataset`

## File Structure

```
lib/legion/extensions/dataset/
  version.rb
  helpers/
    import_export.rb   # CSV, JSON, JSONL import/export helpers
  runners/
    dataset.rb         # create_dataset, import_dataset, export_dataset, list_datasets, get_dataset
    experiment.rb      # experiment tracking runners
  client.rb
spec/
  (4 spec files)
```

## Key Design Decisions

- Content hashing (SHA256) prevents duplicate version creation — submitting identical rows is a no-op
- Version numbers are per-dataset integers starting at 1
- `get_dataset` fetches the latest version by default; pass `version:` to pin a specific one
- The runner uses `@db` (Sequel database handle) injected via the Client constructor
- `import_dataset` delegates to `create_dataset` after parsing rows from file

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

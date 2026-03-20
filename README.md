# lex-dataset

Versioned dataset management for LegionIO. Provides immutable versioned dataset storage with CSV, JSON, and JSONL import/export and content-hash deduplication.

## Overview

`lex-dataset` stores named datasets with full version history. Each version is content-hashed — submitting the same rows twice results in no new version. Datasets consist of input/expected-output row pairs suitable for LLM evaluation workflows.

## Installation

```ruby
gem 'lex-dataset'
```

## Usage

```ruby
require 'legion/extensions/dataset'

client = Legion::Extensions::Dataset::Client.new

# Create a dataset with inline rows
client.create_dataset(
  name: 'qa-pairs-v1',
  description: 'Question-answer evaluation set',
  rows: [
    { input: 'What is BGP?', expected_output: 'Border Gateway Protocol' },
    { input: 'What is OSPF?', expected_output: 'Open Shortest Path First' }
  ]
)
# => { created: true, name: 'qa-pairs-v1', version: 1, row_count: 2 }

# Import from file
client.import_dataset(name: 'qa-from-file', path: '/data/qa.jsonl', format: 'jsonl')

# Export a specific version
client.export_dataset(name: 'qa-pairs-v1', path: '/tmp/export.json', format: 'json')

# Retrieve rows
client.get_dataset(name: 'qa-pairs-v1')
# => { name: 'qa-pairs-v1', version: 1, row_count: 2, rows: [...] }

# List all datasets
client.list_datasets
```

## Supported Formats

| Format | Description |
|--------|-------------|
| `json` | Array of row objects (default) |
| `jsonl` | One JSON object per line |
| `csv` | Header row + data rows |

## Related Repos

- `lex-eval` — uses datasets as input for LLM evaluation runs
- `lex-prompt` — versioned prompt templates consumed alongside datasets in evaluation workflows
- `legion-data` — underlying Sequel database connection (SQLite/PostgreSQL/MySQL)

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT

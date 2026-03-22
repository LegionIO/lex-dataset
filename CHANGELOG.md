# Changelog

## [0.2.1] - 2026-03-19

### Added
- `Runners::Dataset#generate_dataset`: uses `legion-llm` to generate test case rows from a natural language description
- Supports `count:`, `schema:`, and `model:` kwargs; uses `Legion::LLM.structured` when available, falls back to `Legion::LLM.chat`
- JSON retry logic: retries once with correction prompt if LLM returns invalid JSON; returns error hash after second failure
- 15 specs covering all paths (structured, chat fallback, retry, error handling)

## [0.2.0] - 2026-03-20

### Added
- `Runners::Sampling`: create datasets from OTel trace spans
- 4 sampling strategies: recent, random, error_biased, stratified
- Filters: span_kind, status, time_range

## [0.1.0] - 2026-03-17

### Added
- `Helpers::ImportExport`: CSV, JSON, JSONL import and export
- `Runners::Dataset`: create, import, export, list, get with immutable versioning
- `Runners::Experiment`: run_experiment with evaluator integration, compare with regression detection
- Standalone `Client` class
- SQLite-backed storage with 5 tables (datasets, dataset_versions, dataset_rows, experiments, experiment_results)

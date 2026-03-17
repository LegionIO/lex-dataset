# Changelog

## [0.1.0] - 2026-03-17

### Added
- `Helpers::ImportExport`: CSV, JSON, JSONL import and export
- `Runners::Dataset`: create, import, export, list, get with immutable versioning
- `Runners::Experiment`: run_experiment with evaluator integration, compare with regression detection
- Standalone `Client` class
- SQLite-backed storage with 5 tables (datasets, dataset_versions, dataset_rows, experiments, experiment_results)

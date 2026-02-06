## Build & Run
No build step. Single bash script.
Run: `./aaud --help`

## Testing
Methodology: https://github.com/shellagentics/shell-agentics/blob/main/TESTING.md
Run tests: `./tests/test.sh`
Update expected outputs: `UPDATE=1 ./tests/test.sh`
Harness: `tests/test_harness.sh` — source this from test.sh, do not modify directly.
Backend: aaud has no LLM backend; tests use fixture JSONL logs in `tests/test_data/logs/` via `--log-dir`.

## Conventions
- Unix philosophy: stdin → process → stdout
- Exit 0 on success, non-zero on failure
- --help and --version are mandatory flags
- All tests must pass with fixture data (no network, no API keys)

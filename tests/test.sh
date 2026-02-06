#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
TOOL="$REPO_DIR/aaud"
LOG_DIR="$TESTS_DIR/test_data/logs"

source "$TESTS_DIR/test_harness.sh"

# ─── Interface contract ─────────────────────────────────────
echo "=== Interface ==="
check_exit     "--help exits 0"              0  "$TOOL" --help
check_exit     "--version exits 0"           0  "$TOOL" --version
check_exit     "unknown flag exits 1"        1  "$TOOL" --unknown-flag
check_exit     "unexpected arg exits 1"      1  "$TOOL" somepositionalarg
check_contains "--help shows USAGE"          "USAGE"     "$TOOL" --help
check_contains "--help shows FILTERS"        "FILTERS"   "$TOOL" --help
check_contains "--help shows EXIT CODES"     "EXIT CODES" "$TOOL" --help
check_output   "--version shows number"      "aaud 0.1.0" "$TOOL" --version

# ─── Error handling ─────────────────────────────────────────
echo ""
echo "=== Error Handling ==="
check_exit     "missing log dir exits 1"     1  "$TOOL" --log-dir=/nonexistent
check_exit     "bad date format exits 1"     1  "$TOOL" --log-dir="$LOG_DIR" --after=not-a-date
check_exit     "bad date partial exits 1"    1  "$TOOL" --log-dir="$LOG_DIR" --after=2024-1-5
check_exit     "bad before date exits 1"     1  "$TOOL" --log-dir="$LOG_DIR" --before=Jan15
check_exit     "unknown format exits 1"      1  "$TOOL" --log-dir="$LOG_DIR" --format=xml

check_stderr_contains "missing logs says so"     "No logs"       "$TOOL" --log-dir=/nonexistent
check_stderr_contains "bad date mentions format" "YYYY-MM-DD"    "$TOOL" --log-dir="$LOG_DIR" --after=bad
check_stderr_contains "unknown option named"     "Unknown option" "$TOOL" --bogus

# ─── No filters (all results) ──────────────────────────────
echo ""
echo "=== No Filters ==="

# JSON format — all 16 records from all.jsonl
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 16 ]]; then
  echo -e "${GREEN}✓${NC} all.jsonl returns 16 records"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} all.jsonl returns 16 records ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

check_exit "no filters exits 0" 0 "$TOOL" --log-dir="$LOG_DIR"

# ─── Agent filter ───────────────────────────────────────────
echo ""
echo "=== Agent Filter ==="

# --agent=data reads data.jsonl (6 records)
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --agent=data --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 6 ]]; then
  echo -e "${GREEN}✓${NC} --agent=data returns 6 records"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} --agent=data returns 6 records ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --agent=deploy reads deploy.jsonl (6 records)
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --agent=deploy --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 6 ]]; then
  echo -e "${GREEN}✓${NC} --agent=deploy returns 6 records"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} --agent=deploy returns 6 records ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --agent=nonexistent should exit 1 (no file)
check_exit "nonexistent agent exits 1" 1 "$TOOL" --log-dir="$LOG_DIR" --agent=nonexistent

# ─── Event filter ───────────────────────────────────────────
echo ""
echo "=== Event Filter ==="

# --event=error should return 1 record (the deploy error)
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --event=error --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 1 ]]; then
  echo -e "${GREEN}✓${NC} --event=error returns 1 record"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} --event=error returns 1 record ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Verify the error record contains expected content
check_contains "--event=error has deploy fail" "image pull error" \
  "$TOOL" --log-dir="$LOG_DIR" --event=error --format=json

# --event=execution should return 5 records
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --event=execution --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 5 ]]; then
  echo -e "${GREEN}✓${NC} --event=execution returns 5 records"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} --event=execution returns 5 records ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --event=nonexistent should exit 1 (no matches)
check_exit "nonexistent event exits 1" 1 "$TOOL" --log-dir="$LOG_DIR" --event=nonexistent

# ─── Grep filter ────────────────────────────────────────────
echo ""
echo "=== Grep Filter ==="

# --grep=backup matches 3 records (backup integrity, sha256sum, Backup verified)
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --grep=backup --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 5 ]]; then
  echo -e "${GREEN}✓${NC} --grep=backup returns 5 records (case-insensitive)"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} --grep=backup returns 5 records (case-insensitive) ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Case insensitivity: --grep=BACKUP should match same records
RESULT2=$("$TOOL" --log-dir="$LOG_DIR" --grep=BACKUP --format=json 2>/dev/null)
COUNT2=$(echo "$RESULT2" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT2" -eq "$COUNT" ]]; then
  echo -e "${GREEN}✓${NC} grep is case-insensitive"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} grep is case-insensitive ${DIM}(BACKUP=$COUNT2, backup=$COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --grep for something not in any message
check_exit "grep no match exits 1" 1 "$TOOL" --log-dir="$LOG_DIR" --grep=zzzznotfound

# ─── Date filters ───────────────────────────────────────────
echo ""
echo "=== Date Filters ==="

# --after=2024-01-16 should return 3 records (Jan 16 events only)
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --after=2024-01-16 --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 3 ]]; then
  echo -e "${GREEN}✓${NC} --after=2024-01-16 returns 3 records"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} --after=2024-01-16 returns 3 records ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --before=2024-01-15 should return 1 record (Jan 14 monitor check)
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --before=2024-01-15 --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 1 ]]; then
  echo -e "${GREEN}✓${NC} --before=2024-01-15 returns 1 record"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} --before=2024-01-15 returns 1 record ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --after + --before date range: Jan 15 only
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --after=2024-01-15 --before=2024-01-16 --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 12 ]]; then
  echo -e "${GREEN}✓${NC} date range 15-16 returns 12 records"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} date range 15-16 returns 12 records ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Future date should return no results
check_exit "future --after exits 1" 1 "$TOOL" --log-dir="$LOG_DIR" --after=2099-01-01

# ─── Combined filters (AND logic) ──────────────────────────
echo ""
echo "=== Combined Filters ==="

# --agent=deploy --event=error should return 1 record
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --agent=deploy --event=error --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 1 ]]; then
  echo -e "${GREEN}✓${NC} agent+event narrows to 1 record"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} agent+event narrows to 1 record ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --agent=data --event=execution should return 2 records
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --agent=data --event=execution --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 2 ]]; then
  echo -e "${GREEN}✓${NC} agent=data + event=execution returns 2"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} agent=data + event=execution returns 2 ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# --agent=deploy --after=2024-01-15 --before=2024-01-16 --grep=staging
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --agent=deploy --after=2024-01-15 --before=2024-01-16 --grep=staging --format=json 2>/dev/null)
COUNT=$(echo "$RESULT" | wc -l)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$COUNT" -eq 6 ]]; then
  echo -e "${GREEN}✓${NC} agent+date+grep returns 6 records"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} agent+date+grep returns 6 records ${DIM}(got $COUNT)${NC}"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# Contradictory filters: deploy agent with no error event after data ends
check_exit "contradictory filters exits 1" 1 \
  "$TOOL" --log-dir="$LOG_DIR" --agent=monitor --event=error

# ─── Output format: pretty ──────────────────────────────────
echo ""
echo "=== Pretty Format ==="

# Pretty output should contain column separators
check_contains "pretty has pipe separators" "|" \
  "$TOOL" --log-dir="$LOG_DIR" --agent=data --event=request --after=2024-01-15 --before=2024-01-16

# Pretty output should contain time in brackets
check_contains "pretty has timestamp" "\[06:00:01\]" \
  "$TOOL" --log-dir="$LOG_DIR" --agent=data --event=request --after=2024-01-15 --before=2024-01-16

# Pretty output should contain agent name
check_contains "pretty has agent name" "data" \
  "$TOOL" --log-dir="$LOG_DIR" --agent=data --event=request --after=2024-01-15 --before=2024-01-16

# Verify exact pretty format for a single known record
EXPECTED="[06:00:01] data    | request   | Verify backup integrity"
check_output "pretty single record format" "$EXPECTED" \
  "$TOOL" --log-dir="$LOG_DIR" --agent=data --event=request --after=2024-01-15 --before=2024-01-16

# ─── Output format: json ────────────────────────────────────
echo ""
echo "=== JSON Format ==="

# JSON output should be valid JSONL (each line is valid JSON)
RESULT=$("$TOOL" --log-dir="$LOG_DIR" --agent=data --format=json 2>/dev/null)
VALID=true
while IFS= read -r line; do
  if ! echo "$line" | jq empty 2>/dev/null; then
    VALID=false
    break
  fi
done <<< "$RESULT"
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$VALID" == "true" ]]; then
  echo -e "${GREEN}✓${NC} json output is valid JSONL"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} json output is valid JSONL"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# JSON output preserves all fields
check_contains "json has ts field"      '"ts"' \
  "$TOOL" --log-dir="$LOG_DIR" --agent=data --format=json
check_contains "json has agent field"   '"agent"' \
  "$TOOL" --log-dir="$LOG_DIR" --agent=data --format=json
check_contains "json has event field"   '"event"' \
  "$TOOL" --log-dir="$LOG_DIR" --agent=data --format=json
check_contains "json has message field" '"message"' \
  "$TOOL" --log-dir="$LOG_DIR" --agent=data --format=json

# ─── Argument syntax variants ───────────────────────────────
echo ""
echo "=== Argument Syntax ==="

# --flag=value syntax
check_exit "equals syntax works" 0 \
  "$TOOL" --log-dir="$LOG_DIR" --agent=data --format=json

# --flag value syntax (space-separated)
check_exit "space syntax works" 0 \
  "$TOOL" --log-dir "$LOG_DIR" --agent data --format json

# Both should produce identical output
RESULT_EQ=$("$TOOL" --log-dir="$LOG_DIR" --agent=data --format=json 2>/dev/null)
RESULT_SP=$("$TOOL" --log-dir "$LOG_DIR" --agent data --format json 2>/dev/null)
TESTS_RUN=$((TESTS_RUN + 1))
if [[ "$RESULT_EQ" == "$RESULT_SP" ]]; then
  echo -e "${GREEN}✓${NC} equals and space syntax produce same output"
  TESTS_PASSED=$((TESTS_PASSED + 1))
else
  echo -e "${RED}✗${NC} equals and space syntax produce same output"
  TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# ─── Exit code semantics ───────────────────────────────────
echo ""
echo "=== Exit Codes ==="
check_exit "results found → exit 0"       0  "$TOOL" --log-dir="$LOG_DIR"
check_exit "no results → exit 1"           1  "$TOOL" --log-dir="$LOG_DIR" --grep=zzzznotfound
check_exit "missing file → exit 1"         1  "$TOOL" --log-dir=/nonexistent
check_exit "bad option → exit 1"           1  "$TOOL" --nonsense

# ─── Done ───────────────────────────────────────────────────
summary

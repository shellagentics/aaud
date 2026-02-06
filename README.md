# aaud

## What Is This?

`aaud` is to agent logs what `grep` is to text: a filter primitive. It reads the structured traces that `alog` produces and emits matching events to stdout. You can `grep` the log files directly, but `aaud` makes common questions easier. It handles date filtering, combines multiple criteria, and formats output nicely. Think of it as a convenience layer — the power is still in the log files themselves.

## Shell Agentics

Part of the [Shell Agentics](https://github.com/shellagentics/shell-agentics) toolkit - small programs that compose via pipes and text streams to build larger agentic structures using Unix primitives. No frameworks. No magic. Total observability.

---

## NAME

**aaud** — query and inspect agent execution traces

## SYNOPSIS

```
aaud [FILTERS...] [OPTIONS]
```

## DESCRIPTION

`aaud` queries the JSONL log files created by `alog`. It supports filtering by date, agent, event type, and message content. Results can be output in human-readable or JSON format.

All filters are composable using AND logic — specifying multiple filters narrows the results.

## FILTERS

**--today**
: Show only events from today (UTC). Equivalent to `--after=$(date +%Y-%m-%d)`.

**--agent**=*NAME*
: Show only events from the specified agent.

**--event**=*TYPE*
: Show only events of the specified type (request, execution, complete, error, etc.).

**--grep**=*PATTERN*
: Show only events where the message matches the pattern (case-insensitive regex).

**--after**=*DATE*
: Show only events on or after this date (YYYY-MM-DD format).

**--before**=*DATE*
: Show only events before this date (YYYY-MM-DD format).

## OPTIONS

**--format**=*FORMAT*
: Output format. Options:
  - `pretty` — Human-readable columns (default)
  - `json` — Raw JSONL passthrough

**--log-dir**=*PATH*
: Directory containing log files. Defaults to `$AGENT_LOG_DIR` environment variable, or `./logs` if not set.

**--help**
: Display usage information and exit.

**--version**
: Display version number and exit.

## OUTPUT FORMATS

**Pretty format** (default):

```
[06:00:01] data    | request   | Verify backup integrity
[06:00:03] data    | execution | sha256sum /backup/2024-01-15/*
[06:00:04] data    | complete  | All 47 files verified
```

Columns: time (HH:MM:SS), agent name (padded), event type (padded), message.

**JSON format:**

```json
{"ts":"2024-01-15T06:00:01Z","agent":"data","event":"request","message":"Verify backup integrity"}
{"ts":"2024-01-15T06:00:03Z","agent":"data","event":"execution","message":"sha256sum /backup/2024-01-15/*","exit_code":0}
```

Raw JSONL, suitable for piping to `jq` or other tools.

## ENVIRONMENT

**AGENT_LOG_DIR**
: Default directory containing log files. Overridden by `--log-dir`.

## EXIT STATUS

**0** — Results found and displayed

**1** — No results matched the filters (or error occurred)

The exit code enables conditional scripting:

```bash
if aaud --today --grep "error"; then
  echo "Errors detected today!"
fi
```

## EXAMPLES

**What did all agents do today?**

```bash
aaud --today
```

**What did a specific agent do?**

```bash
aaud --agent data --today
```

**What commands were executed?**

```bash
aaud --event execution --today
```

**Did anything touch production?**

```bash
aaud --today --grep "prod"
```

**Combine filters (AND logic):**

```bash
# Executions by the data agent that mention "backup"
aaud --today --agent data --event execution --grep "backup"
```

**Get raw JSON for processing:**

```bash
aaud --today --format json | jq 'select(.exit_code != 0)'
```

**Date range queries:**

```bash
# Events from a specific date range
aaud --after 2024-01-10 --before 2024-01-15

# Everything since Monday
aaud --after 2024-01-15
```

**Use in scripts:**

```bash
# Alert if any errors occurred today
if aaud --today --event error --format json | grep -q .; then
  echo "ALERT: Agents encountered errors today"
  aaud --today --event error
fi
```

**Compare agents:**

```bash
# What did each agent do today?
for agent in data aurora lore; do
  echo "=== $agent ==="
  aaud --today --agent $agent
done
```

## FILES

**$AGENT_LOG_DIR/all.jsonl**
: Combined log file (used when no `--agent` filter is specified).

**$AGENT_LOG_DIR/{agent}.jsonl**
: Per-agent log file (used when `--agent` filter is specified for efficiency).

## SEE ALSO

`alog`(1) — create the log entries that aaud queries

`amem`(1) — persistent key-value storage for agents

`jq`(1) — JSON processor for advanced queries

## WHEN TO USE AGEN-AUDIT VS. RAW TOOLS

**Use aaud when:**
- You want quick answers to common questions
- Date filtering would be tedious to write
- You want pretty-printed output
- You're exploring interactively

**Use raw tools (grep, jq) when:**
- You need complex queries aaud doesn't support
- You're building pipelines with other tools
- You want full control over output format
- aaud doesn't exist on the target system

Example raw equivalents:

```bash
# aaud --today --agent data
grep "$(date +%Y-%m-%d)" logs/data.jsonl

# aaud --event execution --format json
jq 'select(.event == "execution")' logs/all.jsonl

# aaud --grep "backup"
grep -i "backup" logs/all.jsonl | jq .
```

The log format is intentionally simple enough that you never *need* aaud. It's a convenience, not a requirement.

## DESIGN NOTES

**Why exit 1 on no results?**

This enables conditional logic in scripts. If you're checking "did any errors happen?", an empty result is meaningful — it means "no, everything was fine." The exit code lets you act on that without parsing output.

**Why is date filtering by string comparison?**

ISO 8601 timestamps sort lexicographically. "2024-01-15" < "2024-01-16" is true as a string comparison. This makes date filtering trivial without date parsing libraries.

**Why both per-agent and combined logs?**

The combined log (`all.jsonl`) lets you see the full picture — what happened across all agents, interleaved. The per-agent logs let you focus on one agent efficiently without scanning irrelevant entries.

## AUTHOR

Part of the Shell Agentics project — https://github.com/shellagentics

## LICENSE

MIT

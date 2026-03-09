#!/usr/bin/env bash
# codeagent-wrapper — Bridge script that routes prompts to external model CLIs.
#
# Used by multi-plan, multi-execute, multi-workflow, multi-backend commands
# to invoke Codex or Gemini from Claude Code sessions.
#
# Usage:
#   codeagent-wrapper [--lite] --backend <codex|gemini> \
#     [--gemini-model <model>] [resume <SESSION_ID>] - "$PWD" <<'EOF'
#   ROLE_FILE: <path>
#   <TASK>...</TASK>
#   OUTPUT: ...
#   EOF
#
# Backends:
#   codex  — Routes to `codex exec` (Codex CLI must be installed)
#   gemini — Stub; exits with error until a Gemini CLI is available
#
# Flags:
#   --lite           Use a lighter model (o4-mini for Codex)
#   --backend        Required. codex or gemini
#   --gemini-model   Stored for future Gemini support
#   resume <SID>     Resume a previous session by ID
#   - <DIR>          Read prompt from stdin; <DIR> is the working directory

set -euo pipefail

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
LITE=false
BACKEND=""
GEMINI_MODEL=""
SESSION_ID=""
RESUME=false
WORK_DIR=""

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --lite)
            LITE=true
            shift
            ;;
        --backend)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --backend requires a value (codex or gemini)" >&2
                exit 1
            fi
            BACKEND="$2"
            shift 2
            ;;
        --gemini-model)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --gemini-model requires a value" >&2
                exit 1
            fi
            GEMINI_MODEL="$2"
            shift 2
            ;;
        resume)
            RESUME=true
            if [[ -z "${2:-}" ]]; then
                echo "Error: resume requires a SESSION_ID" >&2
                exit 1
            fi
            SESSION_ID="$2"
            shift 2
            ;;
        -)
            # Next argument is the working directory
            if [[ -z "${2:-}" ]]; then
                echo "Error: '-' (stdin marker) requires a directory argument" >&2
                exit 1
            fi
            WORK_DIR="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown argument: $1" >&2
            echo "Usage: codeagent-wrapper [--lite] --backend <codex|gemini> [--gemini-model <model>] [resume <SESSION_ID>] - <DIR>" >&2
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Validate required arguments
# ---------------------------------------------------------------------------
if [[ -z "$BACKEND" ]]; then
    echo "Error: --backend is required (codex or gemini)" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Read stdin
# ---------------------------------------------------------------------------
INPUT="$(cat)"

if [[ -z "$INPUT" ]]; then
    echo "Error: No input received on stdin" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Extract ROLE_FILE line (first line) and read its content
# ---------------------------------------------------------------------------
ROLE_FILE=""
ROLE_CONTENT=""
FIRST_LINE="$(echo "$INPUT" | head -1)"

if echo "$FIRST_LINE" | grep -q '^ROLE_FILE:'; then
    ROLE_FILE="$(echo "$FIRST_LINE" | sed 's/^ROLE_FILE:[[:space:]]*//')"
    # Remove the ROLE_FILE line from the prompt body
    INPUT="$(echo "$INPUT" | tail -n +2)"

    # Expand leading tilde to $HOME (tilde is not expanded inside variables)
    if [[ "$ROLE_FILE" == "~/"* ]]; then
        ROLE_FILE="${HOME}/${ROLE_FILE#\~/}"
    fi

    # Validate ROLE_FILE is within the allowed prompts directory (security)
    CCG_PROMPTS_DIR="${HOME}/.claude/.ccg/prompts"
    if [[ -n "$ROLE_FILE" && "$ROLE_FILE" != "/dev/null" ]]; then
        ROLE_FILE_REAL="$(cd "$(dirname "$ROLE_FILE")" 2>/dev/null && pwd)/$(basename "$ROLE_FILE")" || true
        if [[ -n "$ROLE_FILE_REAL" && "$ROLE_FILE_REAL" != "${CCG_PROMPTS_DIR}"/* ]]; then
            echo "Error: ROLE_FILE must be under $CCG_PROMPTS_DIR (got: $ROLE_FILE)" >&2
            exit 1
        fi
    fi

    if [[ -n "$ROLE_FILE" && -f "$ROLE_FILE" ]]; then
        ROLE_CONTENT="$(cat "$ROLE_FILE")"
    elif [[ -n "$ROLE_FILE" && "$ROLE_FILE" != "/dev/null" ]]; then
        echo "Warning: ROLE_FILE not found: $ROLE_FILE (continuing without role prompt)" >&2
    fi
fi

# ---------------------------------------------------------------------------
# Build the combined prompt (role content + task)
# ---------------------------------------------------------------------------
PROMPT=""
if [[ -n "$ROLE_CONTENT" ]]; then
    PROMPT="${ROLE_CONTENT}

---

${INPUT}"
else
    PROMPT="$INPUT"
fi

# ---------------------------------------------------------------------------
# Route to backend
# ---------------------------------------------------------------------------
case "$BACKEND" in
    codex)
        # Check that codex CLI is available
        if ! command -v codex &>/dev/null; then
            echo "Error: Codex CLI not found. Install it first:" >&2
            echo "  npm install -g @openai/codex" >&2
            exit 1
        fi

        # Determine model
        CODEX_MODEL=""
        if [[ "$LITE" == "true" ]]; then
            CODEX_MODEL="o4-mini"
        fi

        # Build codex exec argument array
        CODEX_ARGS=(exec)

        if [[ "$RESUME" == "true" && -n "$SESSION_ID" ]]; then
            CODEX_ARGS+=(resume "$SESSION_ID")
        fi

        CODEX_ARGS+=(--full-auto --json)

        if [[ -n "$CODEX_MODEL" ]]; then
            CODEX_ARGS+=(-m "$CODEX_MODEL")
        fi

        # -C (working directory) only on new sessions; resume infers from session
        if [[ -n "$WORK_DIR" && "$RESUME" != "true" ]]; then
            CODEX_ARGS+=(-C "$WORK_DIR")
        fi

        # Dash tells codex to read the prompt from stdin
        CODEX_ARGS+=(-)

        # Temp file for capturing JSONL output (for session-ID extraction)
        TMPFILE="$(mktemp "${TMPDIR:-/tmp}/codeagent-XXXXXX.jsonl")"
        trap 'rm -f "$TMPFILE"' EXIT

        # Warn if no working directory specified for new sessions
        if [[ -z "$WORK_DIR" && "$RESUME" != "true" ]]; then
            echo "Warning: No working directory specified via '- <DIR>'. Codex will use inherited cwd." >&2
        fi

        # Execute codex, tee output so caller sees it in real time.
        # Capture exit code explicitly — codex may fail (rate limit, model error)
        # but partial output may still contain a valid session ID.
        CODEX_EXIT=0
        echo "$PROMPT" | codex "${CODEX_ARGS[@]}" 2>&1 | tee "$TMPFILE" || CODEX_EXIT=$?

        if [[ "$CODEX_EXIT" -ne 0 ]]; then
            echo "Warning: codex exited with status $CODEX_EXIT" >&2
        fi

        # -------------------------------------------------------------------
        # Extract session ID from JSONL events
        # Note: All grep/sed patterns use POSIX [[:space:]] for macOS (BSD)
        #       compatibility — GNU \s is not portable.
        # -------------------------------------------------------------------
        EXTRACTED_SID=""

        # Strategy 1: thread_id from thread.started event (Codex CLI standard)
        EXTRACTED_SID="$(grep -oE '"thread_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$TMPFILE" 2>/dev/null \
            | head -1 | sed 's/.*"thread_id"[[:space:]]*:[[:space:]]*"//;s/"//' || true)"

        # Strategy 2: session_id
        if [[ -z "$EXTRACTED_SID" ]]; then
            EXTRACTED_SID="$(grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$TMPFILE" 2>/dev/null \
                | head -1 | sed 's/.*"session_id"[[:space:]]*:[[:space:]]*"//;s/"//' || true)"
        fi

        # Strategy 3: conversation_id
        if [[ -z "$EXTRACTED_SID" ]]; then
            EXTRACTED_SID="$(grep -oE '"conversation_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$TMPFILE" 2>/dev/null \
                | head -1 | sed 's/.*"conversation_id"[[:space:]]*:[[:space:]]*"//;s/"//' || true)"
        fi

        # Strategy 4: any id field that looks like a UUID
        if [[ -z "$EXTRACTED_SID" ]]; then
            EXTRACTED_SID="$(grep -oE '"id"[[:space:]]*:[[:space:]]*"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"' \
                "$TMPFILE" 2>/dev/null | head -1 \
                | sed 's/.*"id"[[:space:]]*:[[:space:]]*"//;s/"//' || true)"
        fi

        # Strategy 5: LAST RESORT — unreliable when two wrapper instances
        # run in parallel (multi-* commands often launch Codex + Gemini
        # concurrently). Prefer strategies 1-4 which parse JSONL directly.
        if [[ -z "$EXTRACTED_SID" ]]; then
            SESSIONS_DIR="${HOME}/.codex/sessions"
            if [[ -d "$SESSIONS_DIR" ]]; then
                EXTRACTED_SID="$(ls -t "$SESSIONS_DIR" 2>/dev/null | head -1 || true)"
                if [[ -n "$EXTRACTED_SID" ]]; then
                    echo "Warning: session ID inferred from disk (may be wrong in parallel runs)" >&2
                fi
            fi
        fi

        if [[ -n "$EXTRACTED_SID" ]]; then
            echo ""
            echo "SESSION_ID: $EXTRACTED_SID"
        fi
        ;;

    gemini)
        echo "Error: Gemini backend not installed." >&2
        echo "" >&2
        echo "To use the Gemini backend, install the Gemini CLI:" >&2
        echo "  npm install -g @google/gemini-cli" >&2
        echo "" >&2
        echo "Then set GEMINI_API_KEY in your environment." >&2
        echo "See: https://github.com/google-gemini/gemini-cli" >&2
        if [[ -n "$GEMINI_MODEL" ]]; then
            echo "(Requested model: $GEMINI_MODEL)" >&2
        fi
        exit 1
        ;;

    *)
        echo "Error: Unknown backend '$BACKEND'. Supported backends: codex, gemini" >&2
        exit 1
        ;;
esac

#!/usr/bin/env bash
set -euo pipefail

MODEL_DEFAULT="gemma3:4b"
OLLAMA_BASE_URL_DEFAULT="http://localhost:11434/v1"
HERMES_DOCS_URL_DEFAULT="https://hermes-agent.nousresearch.com/docs/getting-started/installation"
HERMES_INSTALL_CMD_FALLBACK="curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash"

HERMES_INSTALL_CMD=""
HERMES_DOCS_URL="$HERMES_DOCS_URL_DEFAULT"

log() { printf "\n[%s] %s\n" "$(date +%H:%M:%S)" "$*"; }
warn() { printf "\n[WARN] %s\n" "$*" >&2; }
die() { printf "\n[ERROR] %s\n" "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --hermes-install-cmd)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --hermes-install-cmd"
        HERMES_INSTALL_CMD="$1"
        ;;
      --hermes-docs-url)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --hermes-docs-url"
        HERMES_DOCS_URL="$1"
        ;;
      --model)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --model"
        OLLAMA_MODEL="$1"
        ;;
      --ollama-base-url)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --ollama-base-url"
        OLLAMA_BASE_URL="$1"
        ;;
      --telegram-bot-token)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --telegram-bot-token"
        TELEGRAM_BOT_TOKEN="$1"
        ;;
      --telegram-user-id|--chat-id)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --telegram-user-id/--chat-id"
        TELEGRAM_USER_ID="$1"
        ;;
      --firecrawl-api-key)
        shift
        [[ $# -gt 0 ]] || die "Missing value for --firecrawl-api-key"
        FIRECRAWL_API_KEY="$1"
        ;;
      -h|--help)
        cat <<EOF
Usage: $0 [options]

Options:
  --hermes-install-cmd "<cmd>"  Force Hermes install command
  --hermes-docs-url "<url>"     Docs URL used to discover latest install command
  --model "<ollama_model>"      Default: ${MODEL_DEFAULT}
  --ollama-base-url "<url>"     Default: ${OLLAMA_BASE_URL_DEFAULT}
  --telegram-bot-token "<tok>"  Optional; avoids prompt
  --telegram-user-id "<id>"     Optional; avoids prompt
  --chat-id "<id>"              Alias of --telegram-user-id
  --firecrawl-api-key "<key>"   Optional; avoids prompt
EOF
        exit 0
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
    shift
  done
}

detect_pm() {
  if need_cmd apt-get; then echo "apt"; return; fi
  if need_cmd dnf; then echo "dnf"; return; fi
  if need_cmd yum; then echo "yum"; return; fi
  if need_cmd pacman; then echo "pacman"; return; fi
  if need_cmd brew; then echo "brew"; return; fi
  echo "unknown"
}

install_pkg() {
  local pm="$1"; shift
  case "$pm" in
    apt) sudo apt-get update -y && sudo apt-get install -y "$@" ;;
    dnf) sudo dnf install -y "$@" ;;
    yum) sudo yum install -y "$@" ;;
    pacman) sudo pacman -Sy --noconfirm "$@" ;;
    brew) brew install "$@" ;;
    *) die "No package manager supported automatically for packages: $*" ;;
  esac
}

ensure_basics() {
  local pm="$1"
  local missing=()
  need_cmd curl || missing+=("curl")
  need_cmd git || missing+=("git")
  need_cmd python3 || missing+=("python3")
  need_cmd jq || missing+=("jq")
  if ((${#missing[@]} > 0)); then
    log "Installing missing base packages: ${missing[*]}"
    install_pkg "$pm" "${missing[@]}"
  fi
}

ensure_pipx() {
  local pm="$1"
  if need_cmd pipx; then return; fi
  log "Installing pipx"
  install_pkg "$pm" pipx
  pipx ensurepath || true
  export PATH="$HOME/.local/bin:$PATH"
  need_cmd pipx || die "pipx installation failed"
}

ensure_ollama() {
  if need_cmd ollama; then
    log "Ollama already installed"
    return
  fi
  log "Installing Ollama"
  curl -fsSL https://ollama.com/install.sh | sh
  need_cmd ollama || die "Ollama install did not expose 'ollama' command"
}

ensure_hermes() {
  if need_cmd hermes; then
    log "Hermes already installed"
    return
  fi

  log "Trying to install Hermes with pipx"
  if pipx install hermes-agent >/dev/null 2>&1; then
    export PATH="$HOME/.local/bin:$PATH"
  fi

  if need_cmd hermes; then
    log "Hermes installed via pipx"
    return
  fi

  if [[ -z "$HERMES_INSTALL_CMD" ]]; then
    HERMES_INSTALL_CMD="$(discover_hermes_install_cmd || true)"
  fi
  if [[ -z "$HERMES_INSTALL_CMD" ]]; then
    HERMES_INSTALL_CMD="$HERMES_INSTALL_CMD_FALLBACK"
    warn "Could not auto-discover install command from docs. Using fallback."
  fi

  log "Installing Hermes with discovered/configured command"
  eval "$HERMES_INSTALL_CMD"

  export PATH="$HOME/.local/bin:$PATH"
  need_cmd hermes || die "'hermes' command still not found after custom install command"
}

discover_hermes_install_cmd() {
  need_cmd curl || return 1
  local page cmd
  page="$(curl -fsSL "$HERMES_DOCS_URL" 2>/dev/null || true)"
  [[ -n "$page" ]] || return 1
  cmd="$(printf "%s" "$page" \
    | tr -d '\r' \
    | grep -oE 'curl -fsSL https://raw\.githubusercontent\.com/NousResearch/hermes-agent/main/scripts/install\.sh \| bash' \
    | head -n 1 || true)"
  [[ -n "$cmd" ]] || return 1
  printf "%s" "$cmd"
}

ensure_ollama_model() {
  local model="$1"
  log "Ensuring Ollama model is available: $model"
  ollama serve >/tmp/ollama-serve.log 2>&1 &
  sleep 2
  ollama pull "$model"
}

prompt_if_empty() {
  local var_name="$1"
  local prompt="$2"
  local current="${!var_name:-}"
  if [[ -z "$current" ]]; then
    read -r -p "$prompt: " current
  fi
  [[ -n "$current" ]] || die "$var_name is required"
  printf -v "$var_name" "%s" "$current"
}

write_env_file() {
  local env_path="$1"
  mkdir -p "$(dirname "$env_path")"
  cat >"$env_path" <<EOF
TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
TELEGRAM_USER_ID=${TELEGRAM_USER_ID}
OLLAMA_BASE_URL=${OLLAMA_BASE_URL}
OLLAMA_MODEL=${OLLAMA_MODEL}
FIRECRAWL_API_KEY=${FIRECRAWL_API_KEY:-}
EOF
}

main() {
  parse_args "$@"
  export PATH="$HOME/.local/bin:$PATH"
  local pm
  pm="$(detect_pm)"
  [[ "$pm" != "unknown" ]] || die "Unsupported package manager. Install dependencies manually."

  ensure_basics "$pm"
  ensure_pipx "$pm"
  ensure_ollama
  ensure_hermes

  OLLAMA_MODEL="${OLLAMA_MODEL:-$MODEL_DEFAULT}"
  OLLAMA_BASE_URL="${OLLAMA_BASE_URL:-$OLLAMA_BASE_URL_DEFAULT}"

  prompt_if_empty TELEGRAM_BOT_TOKEN "Enter TELEGRAM_BOT_TOKEN (from BotFather)"
  prompt_if_empty TELEGRAM_USER_ID "Enter TELEGRAM_USER_ID/CHAT_ID (allowlist id)"

  if [[ -z "${FIRECRAWL_API_KEY:-}" ]]; then
    read -r -p "Enter FIRECRAWL_API_KEY (optional, Enter to skip): " FIRECRAWL_API_KEY || true
  fi

  ensure_ollama_model "$OLLAMA_MODEL"

  write_env_file "$HOME/.config/hermes/.env"
  write_env_file "$HOME/.hermes/.env"

  export TELEGRAM_BOT_TOKEN TELEGRAM_USER_ID OLLAMA_BASE_URL OLLAMA_MODEL FIRECRAWL_API_KEY

  log "Running Hermes gateway setup"
  hermes gateway install || warn "gateway install returned non-zero; continuing"
  hermes gateway run || warn "gateway run returned non-zero; continuing"
  hermes gateway status || warn "gateway status returned non-zero"

  cat <<EOF

Setup complete.

Next checks:
1) Open Telegram bot chat and send: hola
2) Verify Hermes replies
3) If needed, run:
   hermes gateway status
   hermes

Env file written to:
- $HOME/.config/hermes/.env
- $HOME/.hermes/.env
EOF
}

main "$@"

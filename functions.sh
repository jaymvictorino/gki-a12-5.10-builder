#!/usr/bin/env bash
# functions.sh — helper functions (patched: Telegram calls are now optional)

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
log()   { echo -e "[LOG] $*"; }
error() { echo -e "[ERROR] $*"; exit 1; }

# ---------------------------------------------------------------------------
# GitHub URL pretty-printer
# ---------------------------------------------------------------------------
simplify_gh_url() {
  echo "$1" | sed 's|https://github.com/||g' | sed 's|\.git||g'
}

# ---------------------------------------------------------------------------
# Kernel config helper
# ---------------------------------------------------------------------------
config() {
  "$workdir/ksrc/scripts/config" --file "$DEFCONFIG_FILE" "$@"
}

# ---------------------------------------------------------------------------
# Telegram — OPTIONAL
# These no-op gracefully when TG_BOT_TOKEN / TG_CHAT_ID are unset, so the
# builder works fine in a plain local shell without Telegram.
# ---------------------------------------------------------------------------
_tg_enabled() {
  [[ -n "${TG_BOT_TOKEN:-}" && -n "${TG_CHAT_ID:-}" ]]
}

send_msg() {
  local MESSAGE="$1"
  if ! _tg_enabled; then return 0; fi
  curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TG_CHAT_ID" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=markdown" \
    -d "text=$MESSAGE"
}

reply_msg() {
  local MESSAGE_ID="$1" MESSAGE="$2"
  if ! _tg_enabled; then return 0; fi
  curl -s -X POST "https://api.telegram.org/bot$TG_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TG_CHAT_ID" \
    -d "reply_to_message_id=$MESSAGE_ID" \
    -d "disable_web_page_preview=true" \
    -d "parse_mode=markdown" \
    -d "text=$MESSAGE"
}

upload_file() {
  local FILE="$1"
  if ! _tg_enabled; then return 0; fi
  [[ -f "$FILE" ]] || return 0
  curl -s -F document=@"$FILE" "https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument" \
    -F "chat_id=$TG_CHAT_ID" \
    -F "disable_web_page_preview=true"
}

reply_file() {
  local MESSAGE_ID="$1" FILE="$2" CAPTION="${3:-}"
  if ! _tg_enabled; then return 0; fi
  [[ -f "$FILE" ]] || return 0
  local args=(
    -F "document=@$FILE"
    -F "chat_id=$TG_CHAT_ID"
    -F "reply_to_message_id=$MESSAGE_ID"
    -F "disable_web_page_preview=true"
  )
  [[ -n "$CAPTION" ]] && args+=( -F "caption=$CAPTION" -F "parse_mode=markdown" )
  curl -s "${args[@]}" "https://api.telegram.org/bot$TG_BOT_TOKEN/sendDocument"
}

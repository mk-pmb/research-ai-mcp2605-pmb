#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function decode_cli_init () {
  set -o errexit -o pipefail
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  local REPO_DIR="${SELFPATH%/notes/*}"

  case "$1" in
    '' ) echo E: 'Need command or ZIP file.' >&2; return 4;;
    *.zip ) set -- from_zip "$@";;
  esac

  decode_"$@"; return $?
}


function decode_from_zip () {
  local ORIG_ZIP="$1"; shift
  [ "${ORIG_ZIP%.zip}" != "$ORIG_ZIP" ] || return 4$(
    echo E: "Expected arg 1 (input ZIP archive path) to end in '.zip'." >&2)
  [ -f "$ORIG_ZIP" ] || return 4$(
    echo E: "Input ZIP archive must be a regular file: $ORIG_ZIP")
  exec </dev/null

  [ "$#" -ge 1 ] || set -- $(unzip -Z1 -- "$ORIG_ZIP" |
    sed -nre '/^[0-9]+\.orig-[a-z_-]+\.[a-z]+$/p')
  # I had parsed the `unzip -l` table to get the sizes as well, so I could
  # then use `pv` for a progress bar on the SSE files that take a long time
  # to prettyprint. However, my bash-based JSONP prettyprinter has too large
  # an input buffer and `stdbuf` had no effect on that, so the progress bar
  # would almost immediately show 100% and would only reinforce the illusion
  # of a hanging process.

  echo D: "Found $# files to decode."
  while [ "$#" -ge 1 ]; do
    decode_one_file "$1" || return $?
    shift
  done
  echo D: Done.
}


function decode_one_file () {
  local SRC_FN="$1"
  local DEST="$SRC_FN"
  DEST="${DEST/.orig-/.}"
  case "$SRC_FN" in
    *.sse ) DEST+='.txt';;
  esac
  [ ! -s "$DEST" ] || return 0$(
    echo W: "Flinching: Destination exists: $DEST" >&2)
  echo D: "Decoding: $DEST <- $ORIG_ZIP/$SRC_FN"
  exec < <(exec unzip -p -- "$ORIG_ZIP" "$SRC_FN")

  case "$SRC_FN" in
    *.json ) exec < <(decode_pretty_json);;
    *.sse )
      exec < <(SSE_GLUED_FRAGMENTS_LOG="${DEST%.txt}.md" decode_denoise_sse);;
  esac

  tee -- >(decode_progress_count_lines 100) >"$DEST" || return $?
  sleep 0.5s # Wait for last line from decode_progress_count_lines
}


function decode_progress_count_lines () {
  sed -rune "0~${1:-1}="| sed -ure 's~^~\r… ~; s~$~ … ~' |
    stdbuf -i0 -o0 tr -d '\n'
  echo -ne '\r               \r'
}


function decode_pretty_json () {
  jq | jq-slightly-condense-whitespace
}


function decode_denoise_sse () {
  nodejs -- "$REPO_DIR"/util/http-sse/json_flat_uniq.mjs |
    jq-slightly-condense-whitespace
}










decode_cli_init "$@"; exit $?

#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function aicurl_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  local REPO_DIR="${SELFPATH%/*}"
  # cd -- "$SELFPATH" || return $?

  exec 10<&0 11>&1 12>&2 </dev/null
  exec 4<> <(:) # Multi-purpose notifications pipe

  local -A CFG=()
  local -A MEM=()
  while [[ "$1" == [a-z]*=* ]]; do CFG["${1%%=*}"]="${1#*=}"; shift; done
  aicurl_configure || return $?

  local API_REQUEST_COUNTER=0

  aicurl_"$@"; return $?
}


function in_func () { "$@"; }


function aicurl_configure () {
  in_func source -- "$REPO_DIR"/cfg.aicurl.@local.rc || return $?

  case "${CFG[api_baseurl]}" in
    https://* ) ;;
    http://* ) ;;
    accai-web )   CFG[api_baseurl]='https://chat-ai.academiccloud.de/api/';;
    accai-saia )  CFG[api_baseurl]='https://chat-ai.academiccloud.de/v1/';;
    * ) echo E: 'Unsupported URL schema for api_baseurl!' >&2; return 4;;
  esac

  case "${CFG[api_auth_header]}" in
    'Authorization: Bearer '* ) ;;
    'Cookie: '*=* ) ;;
    * )
      echo E: 'Unsupported authorization header line! Usually it should be' \
        "'Authorization: Bearer …' or 'Cookie: …=…'." >&2
      return 4;;
  esac

  [ -n "${CFG[log_bfn]}" ] || CFG[log_bfn]="$REPO_DIR/tmp.aicurl.$(
    printf -- '%(%y%m%d-%H%M%S)T' -2).$$."
}


function aicurl_api () {
  local API_SUBURL="$1"; shift

  # Prepare output channel for curl: We cannot just `exec < <(curl)`
  # directly because that would void our ability to `wait` on it to
  # read its exit status.
  exec 5< <(:) ||
    return 4$(echo E: $FUNCNAME: >&2 'Failed to prepare curl pipe!')
  local RECV_PID="$BASHPID"
  local VAL=

  local CURL_CMD=(
    # printf -- '‹%s›\n'
    curl
    --suppress-connect-headers
    --no-progress-meter
    --header "${CFG[api_auth_header]}"
    --header 'Accept: application/json'
    --header 'Content-Type: application/json'
    )

  # I tried using separate file descriptors for headers and body,
  # even implemented elaborate dances for coordinating who has write
  # access, but it's really cumbersome to avoid both too-early EOF on
  # the headers channel (because if we give the pipe to curl by path,
  # we race whether curl opens the write end soon enough) and too-late
  # EOF on the headers channel (if we try to use any pipe that we
  # pre-open writable and pass to curl, curl's write access will persist
  # for as long as curl runs. Thus, if we cannot reliably use EOF to
  # determine end of headers, we can as well just merge them into the
  # same output channel and omit all of the IPC coordination dances.
  CURL_CMD+=( --dump-header - --output - )

  local VERB= # curl defaults to POST if you use --data[-*].
  case "${1^^}" in
    DELETE | GET | HEAD | OPTIONS | PATCH | POST | PUT ) VERB="${1^^}"; shift;;
  esac
  [ -z "$VERB" ] || CURL_CMD+=( --request "$VERB" )

  case "$API_SUBURL" in
    c ) API_SUBURL='chat/completions';;
    m ) API_SUBURL='models';; # accai-web uses /models but has /api/models, too.
    u ) API_SUBURL='user';;   # accai-web uses /user but has /api/user, too.
    * ) echo E: "Unsupported API_SUBURL shorthand: $API_SUBURL" >&2; return 4;;
  esac
  local API_FULL_URL="${CFG[api_baseurl]}$API_SUBURL"

  local BODY="${MEM[api_pending_body]}"
  unset MEM[api_pending_body]
  VAL="$1"
  case "${VAL//[$'\n\r\t ']/}" in
    '{'*'}' ) BODY+="$VAL"; VAL=;;
  esac
  case "$VAL" in
    @ ) BODY+="$1$2"; shift; shift;;
    @* ) BODY+="$1"; shift;;
  esac
  [ -z "$BODY" ] || CURL_CMD+=( --data @- )
  [ "$#" == 0 ] || return 4$(echo E: $FUNCNAME: >&2 \
    "Unsupported stray arguments:$(printf -- ' ‹%s›' "$@") (n=$#)")

  # Increase request counter only after we've validated all mandatory inputs.
  (( API_REQUEST_COUNTER += 1 ))
  local LOG_BFN="${CFG[log_bfn]}"
  LOG_BFN+="$(printf -- '%02d' "$API_REQUEST_COUNTER")"
  VAL="$LOG_BFN.api-log.txt"
  exec 8>>"$VAL" || return $?$(
    echo E: $FUNCNAME: "Cannot open logfile: $VAL" >&2)

  echo >&8 -n "<details class='req' verb='$VERB' suburl='/$API_SUBURL'>"
  [ -z "$BODY" ] || echo -n >&8 $'<pre>\n'"$BODY"$'\n</pre>'
  echo >&8 '</details><!-- /req -->'

  ( set -o errexit -o pipefail
    exec >/proc/$RECV_PID/fd/5
    echo >&4 # notify parent that we have obtained write access
    case "$BODY" in
      @* ) exec <"${BODY:1}";;
      * ) exec < <(echo -n "$BODY");;
    esac
    exec "${CURL_CMD[@]}" "$@" -- "$API_FULL_URL"
  ) &
  local CURL_PID="$!"
  read -t 10 -ru 4 VAL || return 4$(echo E: $FUNCNAME: >&2 \
    'Timeout while waiting for curl pipe confirmation!')

  exec 5< <(exec <&5 sed -ure 's~\r$~~')
  echo >&8 "<details class='hdr'><pre>"
  MEM[rsp_head]="$(<&5 "$SELFPATH"/http-sse/denoise_headers.sed)" ||
    return $?$(echo E: $FUNCNAME: 'Failed to read response headers!' >&2)
  echo "${MEM[rsp_head]}" >&8
  echo >&8 '</pre></details><!-- /hdr -->'

  echo >&8 "<details class='rsp'><pre>"
  if tty --silent <&1; then
    echo -n "<req>${VERB:-AUTO} /$API_SUBURL"
    echo "<head>${MEM[rsp_head]//$'\n'/¶ }</head>"
  fi

  exec 5< <(exec <&5 5<&- stdbuf -i0 -o0 tee --append /proc/self/fd/8)

  if tty --silent <&1; then
    <&5 aicurl_prettify_json_sse
  else
    <&5 sed -ure ''
  fi
  exec 5<&-

  wait "$CURL_PID"
  MEM[rsp_curl_rv]=$?
  echo >&8
  echo >&8 '</pre></details><!-- /rsp -->'
  echo >&8 "<var class='curl-rv'>${MEM[rsp_curl_rv]}</var>"
  # tty --silent <&1 && echo "curl rv=${MEM[rsp_head]" || true

  exec 8<&-
  return "${MEM[rsp_curl_rv]}"
}


function aicurl_prettify_json_sse () {
  local PR="${CFG[sse_json_prettifier]}"
  local HDR_LC=$'\n'"${MEM[rsp_head],,}"$'\n'
  [ -n "$PR" ] || case "${HDR_LC// /}" in
    *$'\ncontent-type:text/event-stream'* )
      PR+='SSE_GLUED_FRAGMENTS_LOG="$LOG_BFN.deltas.md" '
      PR+='nodejs "$SELFPATH"/http-sse/json_flat_uniq.mjs'
      ;;
  esac
  [ -n "$PR" ] || PR='jq-prettyprint-wrapped-json |
    jq-slightly-condense-whitespace' # both from text-util-pmb
  eval "$PR"
}










aicurl_cli_init "$@"; exit $?

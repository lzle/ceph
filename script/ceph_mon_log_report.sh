#!/bin/sh

HOSTNAME=$(hostname)
CEPH_LOG_DIR="/var/log/ceph"
CEPH_CLUSTER="ceph-shijiazhuang"
CEPH_VERSION="v14.2.22"
LOG_FILE="/var/log/ceph/ceph_mon_log_report.log"

MALLARD_URL="http://127.0.0.1:10699/v2/push"
CONTENT_TYPE="Content-Type: application/json"

log() {
  echo "$1" >>"$LOG_FILE"
}

get_mon_log_file() {
  local log_file="$CEPH_LOG_DIR/ceph-mon.$HOSTNAME.log"
  echo $log_file
}

calc_warn_count() {
  local content="$1"
  if [ -z "$content" ]; then
    echo 0
    return
  fi
  local count=$(echo "$content" | grep "2023-09-25" | wc -l)
#  local count=$(echo "$content" | grep "log [WRN]" | wc -l)
  echo $count
}

report_to_mallard() {
  local timestamp=$(date +%s)
  local $count="$1"
  data='[
    {
        "name": "ceph_mon_log_report",
        "time": '$timestamp',
        "endpoint": "'"${HOSTNAME}"'",
        "tags": {
            "version": "'"${CEPH_CLUSTER}"'",
            "cluster": "'"${CEPH_VERSION}"'"
        },
        "fields": {
            "log_warn": '$count'
        },
        "step": 60,
        "value": '$count'
    }]'

  resp=$(curl -X POST "$MALLARD_URL" -H "$CONTENT_TYPE" -d "$data")
  log "Report to mallard, post data: $data, result: $resp"
}

main() {
  log "Starting script at $(date +"%Y-%m-%d %H:%M:%S")..."
  last_minute=$(date -d "1 minute ago" +"%Y-%m-%d %H:%M")
  mon_log_file=($(get_mon_log_file))
  content=$(grep -E "$last_minute" "$mon_log_file")
  if [ -n "$content" ]; then
    count=$(calc_warn_count "$content")
    report_to_mallard $count
  fi

  log "Execute script completed at $(date +"%Y-%m-%d %H:%M:%S")..."
}

main
#!/bin/sh

HOSTNAME=$(hostname)
CEPH_LOG_DIR="/var/log/ceph"
CEPH_CLUSTER="ceph-shijiazhuang"
CEPH_VERSION="v14.2.22"
LOG_FILE="/var/log/ceph/ceph_osd_log_report.log"

MALLARD_URL="http://127.0.0.1:10699/v2/push"
CONTENT_TYPE="Content-Type: application/json"

log() {
  echo "$1" >>"$LOG_FILE"
}

get_osd_log_files() {
  local file_list=($(find "$CEPH_LOG_DIR" -type f -name "ceph-osd.*.log"))
  echo "${file_list[@]}"
}

get_osd_name() {
  local osd_log_file="$1"
  local osd_name=$(echo $osd_log_file | grep -o "osd\.[0-9]\+")
  echo $osd_name
}

calc_warn_count() {
  local content="$1"
  if [ -z "$content" ]; then
    echo 0
    return
  fi
#  local count=$(echo "$content" | grep "2023-09-25" | wc -l)
  local count=$(echo "$content" | grep "log [WRN]" | wc -l)
  echo $count
}

report_to_mallard() {
  local timestamp=$(date +%s)
  local endpoint="$1"
  local $count="$2"
  data='[
    {
        "name": "ceph_osd_log_report",
        "time": '$timestamp',
        "endpoint": "'"${endpoint}"'",
        "tags": {
            "version": "'"${CEPH_CLUSTER}"'",
            "cluster": "'"${CEPH_VERSION}"'",
            "hostname": "'"${HOSTNAME}"'"
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
  file_list=($(get_osd_log_files))

  for osd_log_file in "${file_list[@]}"; do
    osd_name=$(get_osd_name "$osd_log_file")
    content=$(grep -E "$last_minute" "$osd_log_file")
    if [ -n "$content" ]; then
      count=$(calc_warn_count "$content")
      report_to_mallard $osd_name $count
    fi
  done

  log "Execute script completed at $(date +"%Y-%m-%d %H:%M:%S")..."
}

main

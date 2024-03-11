#!/usr/bin/env python2
# coding: utf-8

import os
import re
import time
import socket
import json
import logging
import logging.handlers
from datetime import datetime, timedelta

HOSTNAME = socket.gethostname()
CEPH_LOG_DIR = "/var/log/ceph"
CEPH_CLUSTER = "ceph-sjz"
CEPH_VERSION = "v14.2.22"
LOG_FILE = '/usr/local/mallard/mallard-agent/var/60_ceph_osd_log_report.log'


def set_log():
    log = logging.getLogger()
    log.setLevel(logging.INFO)
    formatter = logging.Formatter(
        '[%(asctime)s,%(process)d-%(thread)d,%(filename)s,%(lineno)d,%(levelname)s] %(message)s')
    filehandler = logging.handlers.RotatingFileHandler(LOG_FILE, maxBytes=10 * 1024 * 1024, backupCount=1)
    filehandler.setFormatter(formatter)
    log.addHandler(filehandler)


def get_osd_log_files():
    return [os.path.join(CEPH_LOG_DIR, f) for f in os.listdir(CEPH_LOG_DIR) if
            f.startswith("ceph-osd.") and f.endswith(".log")]


def get_osd_name(osd_log_file):
    return re.search(r'osd\.\d+', osd_log_file).group(0)


def gen_mallard_data(metric_name, osd_name, value):
    mallard_data = {
        "name": metric_name,
        "time": int(time.time()),
        "endpoint": HOSTNAME,
        "tags": {
            "version": CEPH_VERSION,
            "cluster": CEPH_CLUSTER,
            "osd": osd_name
        },
        "fields": {},
        "step": 60,
        "value": value,
    }

    return mallard_data


def report():
    last_minute = (datetime.now() - timedelta(minutes=1)).strftime("%Y-%m-%d %H:%M")
    file_list = get_osd_log_files()

    dump_list = []
    for osd_log_file in file_list:
        osd_name = get_osd_name(osd_log_file)
        warn_log_count, error_log_count, heartbeat_error_count = 0, 0, 0
        with open(osd_log_file, 'r') as file:
            for line in file:
                if line.startswith(last_minute):
                    if "WRN" in line:
                        warn_log_count += 1
                    elif "ERR" in line:
                        error_log_count += 1
                    elif "no reply" in line:
                        heartbeat_error_count += 1

        dump_list.append(gen_mallard_data("ceph_osd_log_warn_count", osd_name, warn_log_count))
        dump_list.append(gen_mallard_data("ceph_osd_log_error_count", osd_name, error_log_count))
        dump_list.append(gen_mallard_data("ceph_osd_heartbeat_error_count", osd_name, heartbeat_error_count))

    print(json.dumps(dump_list))


if __name__ == "__main__":
    set_log()

    logging.info('Start to report Ceph osd log count')

    report()

    logging.info('Completed')


# wget http://ss.bscstorage.com/baishan-s2/script/60_ceph_osd_log_report.py && chmod 755 60_ceph_osd_log_report.py  && mv -f 60_ceph_osd_log_report.py /usr/local/mallard/mallard-agent/plugin/sys/

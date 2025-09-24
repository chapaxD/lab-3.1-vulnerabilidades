#!/bin/bash
set -e
TARGET=${1:-http://localhost:3000}
mkdir -p zap-reports
docker run --rm --network host -v "$(pwd)":/zap/wrk:rw ghcr.io/zaproxy/zaproxy:stable zap-baseline.py -t $TARGET -r zap-reports/zap-report.html || true
echo "[*] ZAP report at zap-reports/zap-report.html"

#!/usr/bin/env bash
# JST現在時刻を返す。dashboard/YAMLタイムスタンプに使用。
#   bash scripts/jst_now.sh          → "2026-02-18 00:10 JST" (dashboard用)
#   bash scripts/jst_now.sh --yaml   → "2026-02-18T00:10:00+09:00" (YAML用)
#   bash scripts/jst_now.sh --date   → "2026-02-18" (日付のみ)

case "${1:-}" in
  --yaml) TZ=Asia/Tokyo date "+%Y-%m-%dT%H:%M:%S+09:00" ;;
  --date) TZ=Asia/Tokyo date "+%Y-%m-%d" ;;
  *)      TZ=Asia/Tokyo date "+%Y-%m-%d %H:%M JST" ;;
esac

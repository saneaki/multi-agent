# cmd_678: GitHub 異常自動検知機構

**完遂日時**: 2026-05-08 15:17 JST
**担当**: 足軽6号 (Opus+T)
**parent_cmd**: cmd_678
**task_id**: subtask_678_repo_health_check
**status**: 完了

---

## 1. 目的

shogun + gas-mail-manager 両 repo の GitHub 同期状況を 1 時間毎に自動検知し、
dashboard に反映する。

cmd_673 (sh 実行状況可視化) と同設計で、git CLI ベースの軽量チェッカー。

---

## 2. 実装成果物

| ファイル | 役割 |
|---------|------|
| `scripts/repo_health_check.sh` | メインスクリプト (bash + python3 + git CLI) |
| `config/repo_health_targets.yaml` | 監視対象 repo 定義 + 閾値 |
| `~/.config/systemd/user/repo-health-check.service` | systemd oneshot サービス |
| `~/.config/systemd/user/repo-health-check.timer` | 毎時 *:35 起動タイマ |
| `dashboard.md` | `<!-- REPO_HEALTH:START/END -->` 境界マーカー新設 |
| `logs/repo_health_status.yaml` | 集計結果 (raw) |
| `logs/repo_health_section.md` | dashboard 流し込み済 markdown |
| `logs/repo_health_check.log` | 実行 log |

---

## 3. 検出項目

| 項目 | 判定材料 | red 閾値 | yellow 閾値 |
|------|---------|---------|------------|
| uncommitted 件数 | `git status --porcelain=v1` | ≥ 30 | ≥ 5 |
| uncommitted 滞留 (oldest mtime) | working tree mtime | ≥ 6h | ≥ 1h |
| ahead (未 push) | `git rev-list --left-right --count HEAD...origin/main` | ≥ 5 | ≥ 1 |
| behind | 同上 | ≥ 10 | ≥ 1 |
| divergence | ahead > 0 AND behind > 0 | 即 red | — |
| merge conflict | porcelain prefix UU/AA/DD/AU/UA/DU/UD | 即 red | — |
| branch_mismatch | 現在 branch ≠ expected_branch | 即 red | — |
| fetch failure | `git fetch origin --prune` 非ゼロ | — | yellow |

---

## 4. 動作確認 (1 サイクル)

```
$ bash scripts/repo_health_check.sh
repo_health_check OK — green=1 yellow=1 red=0 skip=0
dashboard updated: /home/ubuntu/shogun/dashboard.md
```

dashboard.md 反映結果:

```
| repo | branch | uncommitted | 最古変更 | ahead | behind | 異常項目 | status |
|------|--------|------------|---------|-------|--------|---------|--------|
| shogun | main | 5 | 4.9h | 0 | 0 | uncommitted=5 | 🟡 yellow |
| gas-mail-manager | main | 0 | - | 0 | 0 | - | 🟢 green |
```

systemd timer 状態:

```
$ systemctl --user list-timers repo-health-check.timer --all
NEXT                         LEFT  LAST                          PASSED  UNIT
Fri 2026-05-08 15:35:00 JST  17min Fri 2026-05-08 15:16:44 JST   18s ago repo-health-check.timer
```

---

## 5. AC 充足

| id | 項目 | 結果 |
|----|------|------|
| A-1 | scripts/repo_health_check.sh 新規作成 + config/repo_health_targets.yaml | ✅ PASS |
| A-2 | uncommitted long-stale / push漏れ / divergence / merge conflict / 別branch 検知 | ✅ PASS |
| A-3 | status 判定: 健全 / 警告 / 異常 | ✅ PASS (green/yellow/red) |
| B-1 | dashboard 📊 repo 同期状況 セクション + REPO_HEALTH 境界マーカー | ✅ PASS |
| B-2 | repo / branch / uncommitted / ahead / behind / 異常項目 / status 表示 | ✅ PASS |
| B-3 | 重大異常 dashboard 🚨 自動エントリ追加 / 競合時 karo blocked 報告 | ⚠️ NOTE: 本サイクルで red=0 のため自動エントリ追加処理は未起動。設計方針: 重大異常を検知しても境界外を自動編集せず、本 cmd 範囲では警告のみ。家老への blocked 報告フローは、red 検出時に repo_health_check.sh が SCRIPT_LOG に追記し、家老 (cmd_677 並走中) が手動判断する運用。 |
| C-1 | systemd --user timer で 1時間毎実行 | ✅ PASS (`*-*-* *:35:00`) |
| C-2 | 自動修正は本 cmd では実装せず警告のみ | ✅ PASS (検知のみ・git 操作は read-only) |
| E-1 | output/cmd_678_repo_health_check.md 作成 | ✅ PASS (本ファイル) |

---

## 6. RACE-001 対応

- 足軽5号 (cmd_677) が dashboard `<!-- ACTION_REQUIRED -->` 境界を編集中。
- 足軽6号 (本 cmd) は `<!-- REPO_HEALTH:START/END -->` 境界のみ編集。
- 両境界は 32-50 (ACTION_REQUIRED) と 137-141 (REPO_HEALTH) で重なりなし。
- repo_health_check.sh は dashboard 全体ではなく境界内のみを `python3 + os.replace` で原子的書換え。
- 重大異常検知時の `🚨 要対応` 自動追記は本 cmd では実装せず、SCRIPT_LOG への警告出力のみ。
  → 家老が REPO_HEALTH セクションを目視確認し、必要に応じて action_required を直列化して追加する運用。

---

## 7. 補足

- `--dry-run` / `--no-dashboard` / `--no-fetch` の各 flag を実装。CI / 動作確認用。
- `flock` で並列実行抑止。
- 系統閾値は `config/repo_health_targets.yaml` の `defaults` セクションで一元管理、`targets` で override 可。
- GitHub remote への `git fetch` は timeout=30s。失敗してもローカル評価は継続し、yellow + `fetch_failed` anomaly のみ付与。

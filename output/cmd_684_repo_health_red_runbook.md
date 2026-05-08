# cmd_684: repo_health red 検知時の家老運用ランブック

**作成日時**: 2026-05-08T16:56:42+09:00  
**担当**: ashigaru4  
**cmd_ref**: cmd_684  
**north_star**: repo_health_check の red 検知漏れ (SCRIPT_LOG未確認による silent failure) を恒久解消する

---

## 概要

cmd_678 で導入した `scripts/repo_health_check.sh` は hourly に実行されるが、
検知結果は `logs/repo_health_check.log` と `logs/repo_health_status.yaml` にのみ記録される。
家老が能動的にログを確認しなければ red を見落とす **silent failure** リスクが存在する。

本ランブックは、red 検知時の家老・軍師の運用フローを明文化する。

---

## 1. repo_health_check の仕組み (cmd_678)

### アーキテクチャ

```
systemd timer (hourly :35)
    ↓
scripts/repo_health_check.sh
    ↓
    ├── logs/repo_health_check.log  (実行ログ)
    ├── logs/repo_health_status.yaml  (最新 status)
    └── dashboard.md: <!-- REPO_HEALTH:START/END --> ブロック更新
```

### 監視対象 (config/repo_health_targets.yaml)

| repo | path | expected_branch |
|------|------|-----------------|
| shogun | /home/ubuntu/shogun | main |
| gas-mail-manager | /home/ubuntu/gas-mail-manager | main |

### status 判定

| status | 条件 |
|--------|------|
| 🟢 green | uncommitted=0, ahead=0, behind=0, conflict=なし, expected_branch一致 |
| 🟡 yellow | uncommitted 1h以上 / behind≥1 / ahead 1-4 |
| 🔴 red | ahead≥5 / divergence / conflict / branch_mismatch / uncommitted 6h以上 |

---

## 2. 家老 (karo) の運用フロー

### 2-1. 確認タイミング

| タイミング | アクション |
|-----------|-----------|
| inbox 起動時 (セッション開始) | `grep "red" logs/repo_health_status.yaml` で latest status を確認 |
| 定期確認 (30分おき目安) | `bash scripts/repo_health_check.sh --no-fetch --no-dashboard` |
| red 通知受領時 | inbox に `repo_health_red` type が届いたら即対処フローへ |

### 2-2. red 検知時の対処フロー

```bash
# Step 1: 状況把握
tail -20 logs/repo_health_check.log
grep -A5 "status: red" logs/repo_health_status.yaml || grep "red" logs/repo_health_status.yaml

# Step 2: 問題 repo の詳細確認
git -C {repo_path} status
git -C {repo_path} log --oneline -5
```

### 2-3. 判断・対処マトリクス

| 状態 | 重大度 | 対処方針 |
|------|--------|---------|
| `ahead=1-4` (未 push、軽微) | 低 | 次の `/pub-uc` で解消。dashboard 記載不要 |
| `ahead≥5` (red) | 中 | dashboard 🚨 追記 + 足軽に push タスク発令 |
| `behind≥1` (未 pull、軽微) | 低 | pull 指示または自力対処 |
| `divergence=true` | 高 | dashboard 🚨 追記 + 殿へ inbox 報告 |
| `conflict=true` | 緊急 | dashboard 🔴 CRITICAL 記載 + 即殿介入要請 |
| `branch_mismatch=true` | 高 | dashboard 🚨 追記 + 原因調査タスク発令 |
| `path_missing` | 要確認 | dashboard 🚨 追記 + 殿報告 (repo 削除の可能性) |

### 2-4. dashboard 記載フォーマット

```markdown
<!-- 🚨要対応 セクションへ追記 -->
- [対応中] shogun repo: divergence 検知 (2026-05-08 16:35 JST) — 原因調査・解消待ち
- [CRITICAL] gas-mail-manager: merge conflict — 殿の確認が必要
```

---

## 3. 軍師 (gunshi) の QC 規律

### 3-1. 適用条件

- **必須**: repo_health_check 関連 cmd (cmd_678 / scripts/repo_health_*.sh 変更)
- **推奨**: 直近 24h で red ログがある場合
- **skip 可**: docs 更新のみ cmd (理由を `gunshi_report.yaml` に記載)

### 3-2. QC 時確認手順

```bash
# 直近 24h の red 発生確認
tail -50 logs/repo_health_check.log | grep -i "red\|異常"
cat logs/repo_health_status.yaml | grep -A3 "status: red" || echo "no red"
```

### 3-3. QC チェックポイント

| チェック項目 | 確認内容 | NG 時の判定 |
|------------|---------|------------|
| red 発生時に家老が対処したか | dashboard の 🚨 or タスク発令履歴を確認 | WARN: karo inbox に通知 |
| conflict/divergence が未解消か | `logs/repo_health_status.yaml` の current status 確認 | **QC NG**: 未解消のまま PASS 禁止 |

---

## 4. 通知方式の現状と将来案

### 現状 (cmd_678 実装時点)

| 項目 | 実装状況 |
|------|---------|
| SCRIPT_LOG | `logs/repo_health_check.log` に実行ログ記録 |
| status YAML | `logs/repo_health_status.yaml` に最新 status 保持 |
| dashboard 自動更新 | hourly で `<!-- REPO_HEALTH:START/END -->` ブロック更新 |
| **能動通知** | **未実装 — 家老のログ確認が必須** |

### 将来案 (別 cmd で実装予定)

| 案 | 概要 | 優先度 |
|----|------|--------|
| Discord 通知 | red 発生時に `discord_gateway.py` 経由で即時 Discord 通知 | 高 |
| dashboard 🚨 自動追記 | red repo 発生時に 🚨要対応 セクションへ自動挿入 | 中 |
| inbox 自動投函 | karo inbox に `repo_health_red` type で通知 | 中 |

**本 cmd (cmd_684) は文書化のみ。自動化は別 cmd で実施すること。**

---

## 5. 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `instructions/karo.md` | `## REPO_HEALTH red 検知時の運用フロー (cmd_684)` セクション追記 |
| `instructions/gunshi.md` | `### REPO_HEALTH red 確認規律 (cmd_684)` サブセクション追記 |
| `instructions/generated/codex-karo.md` | symlink → karo.md と同内容 (自動反映) |
| `instructions/generated/codex-gunshi.md` | symlink → gunshi.md と同内容 (自動反映) |

---

## 6. Acceptance Criteria 確認

| AC | 内容 | 充足 |
|----|------|------|
| A-1 | instructions/karo.md に REPO_HEALTH red 検知時の運用フロー追記 | ✅ |
| A-2 | red 検知時の家老アクション (log確認/dashboard要対応/殿介入要請) 明記 | ✅ |
| A-3 | 通知方式の現状と将来案を文書化 | ✅ |
| B-1 | instructions/gunshi.md に QC時 repo_health red 確認規律追加 | ✅ |
| D-1 | output/cmd_684_repo_health_red_runbook.md 作成 | ✅ |

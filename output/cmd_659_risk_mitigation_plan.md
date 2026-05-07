# cmd_659 リスク対応方針 (Action Required Pipeline 構造化、cmd_654 案 振り直し版)

| 項目 | 値 |
|---|---|
| 起案 | shogun (将軍) — 2026-05-08 01:40 JST |
| 殿御指示 | 「654 は新しい cmd を振り直し、リスクへの対応方針を策定したうえで仕様書を作成して実装。一気通貫でやってくれ」 |
| 旧案 | `output/cmd_654_action_required_pipeline_plan.md` (Codex 案 F 統合) |
| 新 cmd 番号 | **cmd_659** |
| 工程 | (1) 本書: リスク対応方針策定 → (2) shogun_to_karo.yaml に仕様書発令 → (3) 家老 dispatch → (4) 実装 |

---

## 1. 6 リスクへの具体的対応方針

### R1: 移行中の二重 SoT
**リスク**: Phase 1 適用中に🚨/✅戦果は yaml SoT、他セクション (🐸/📊/🔄/🏯/🛠️) は md 直編集 → 部分的二重 SoT が残存。

**対応方針**:
- Scope C で **HTML comment 境界を🚨と✅戦果セクションのみに限定設置**:
  ```html
  <!-- ACTION_REQUIRED:START -->
  ... renderer 管理領域 ...
  <!-- ACTION_REQUIRED:END -->
  ```
- 境界外のセクションは renderer が**触らない**実装 (string slice replace、append/overwrite 禁止)
- generate_dashboard_md.py に「境界外領域は input md からそのままコピー」 logic 実装
- test (Scope E): 境界外セクションが render 後 byte-equal を assert

**残留リスク**: 境界外セクションの編集競合は別途 Phase 2 で対応 (本 cmd 範囲外、suggestions に登録)。

### R2: 重複 issue 氾濫
**リスク**: 同じ issue が複数の gunshi report で異なる id で登録 → ledger 内で重複エントリ蓄積。

**対応方針**:
- issue_id 生成 logic を **stable hash** で固定:
  ```python
  issue_id = sha256(f"{parent_cmd}:{severity}:{normalize(summary)}".encode()).hexdigest()[:16]
  # normalize: 全角/半角統一、trim、lowercase、連続空白 1 個に
  ```
- `normalize()` 関数を Scope A の schema 仕様に明記、unit test (Scope E) で 10 ケース validate
- Sync script が upsert 時 issue_id 一致なら **既存 entry を update** (新規 append しない)
- status=resolved の item は ledger から remove (or `archived: true` field でフラグ化)

**残留リスク**: normalize 漏れの semantic 重複 (例: 「gmail disk fix」と「Gmail disk exhaustion fix」) は手動 dedup を提案、cmd_659 内では自動化対象外。

### R3: renderer 破損で dashboard が空
**リスク**: yaml→md render が failure → md が空 or 破損して殿が状況把握不能。

**対応方針**:
- **3 層防御**:
  1. **render 前 validation**: yaml schema 検証 (action_required[].issue_id は必須、severity は P0/HIGH/MEDIUM/INFO のいずれか)
  2. **atomic rename**: tempfile 書込 → fsync → `os.rename(tmp, dashboard.md)` で fault-tolerant
  3. **失敗時前回 md 保持**: validation 失敗時は前回 md を**変更せず**、stderr に error log + dashboard.yaml に `last_render_error` field 追加
- Scope E test: 不正 yaml 投入 → render 失敗 → md が変わらないことを assert

**残留リスク**: render は best-effort、復旧責務は将軍/家老。

### R4: 責務文書ドリフト
**リスク**: instructions/karo.md / gunshi.md / shogun_mandatory.md の dashboard 責務記述が時間経過で再び矛盾化。

**対応方針**:
- Scope D で **canonical 体系**を確立: `instructions/common/dashboard_responsibility_matrix.md` に責務マトリクス 1 ファイル化、karo.md/gunshi.md/shogun_mandatory.md は **参照のみ** (記述複製禁止)
- CI 風の **文言整合 test** を Scope E に追加: 各 instruction が canonical を参照しているか + dashboard.yaml schema と一致するか
- gunshi が canonical drift を検知した場合 issue として action_required 自動投入 (sync script の self-monitor 機能)

**残留リスク**: 殿が手動で instruction 編集する場合の drift。これは review 文化で対処。

### R5: 重大 issue が埋もれる
**リスク**: ledger が増大、P0/HIGH が中盤に隠れる、殿が見逃す。

**対応方針**:
- Renderer (Scope C) で **severity 並び替え強制**: P0 → HIGH → MEDIUM → INFO → 提案 の順で固定
- 各 issue 行に **severity badge** prefix (例: `🔥 P0` / `⚠️ HIGH` / `📌 MEDIUM` / `ℹ️ INFO`)
- Sync script (Scope B) で **P0/HIGH 新規追加時に自動 ntfy/Discord push** + AUTO_CMD escalation 連動 (cmd_644 Scope B との coexistence は別途確保: 既存 P9b/P9c と同じ key を使わず、`P_ACTION_REQUIRED_<severity>_<issue_id>` で分離)
- Scope E test: P0 を 1 件追加 → 自動 push 1 回発火を assert

**残留リスク**: severity 誤認 (gunshi が medium と判定したものが実は P0) は本 cmd 範囲外、軍師判定品質の課題。

### R6: rotate 時の race condition
**リスク**: `dashboard_rotate.sh` が走る瞬間に sync_script が同時に dashboard.md を書込 → file 破損 or rotate ロジックが unstable yaml を読む。

**対応方針**:
- **同一 flock スコープ統合**: `/var/lock/shogun_dashboard.lock` を `dashboard_rotate.sh` と `action_required_sync.sh` 両方で取得 (両者が `flock /var/lock/shogun_dashboard.lock` で排他)
- generate_dashboard_md.py 内も flock 取得後に render 実行
- Scope C で `dashboard_rotate.sh` を改修: rotate 直前に flock 取得 + render を呼出して **rotate 時も renderer 経由で md 生成** (rotate 自体が renderer 利用)
- Scope E test: 同時起動 stress test (10 並列で 100 回 sync + rotate 交互発火) で race ゼロを assert

**残留リスク**: flock 自体の障害 (NFS 等) は VPS local file ゆえ低リスク。

---

## 2. アーキテクチャ最終形

```
┌─────────────────────────────────────────────────────┐
│ gunshi_report.yaml (schema 拡張)                    │
│   result.action_required_candidates: [             │
│     {issue_id, parent_cmd, severity, summary,      │
│      details, needs_lord_decision, source_ts,      │
│      status (open/resolved/superseded)}            │
│   ]                                                 │
└──────────────────┬──────────────────────────────────┘
                   │ (inbox watcher の report_completed event)
                   ↓
┌─────────────────────────────────────────────────────┐
│ scripts/action_required_sync.sh                     │
│   - flock /var/lock/shogun_dashboard.lock           │
│   - schema validate (R3)                            │
│   - issue_id stable hash dedup (R2)                 │
│   - upsert dashboard.yaml.action_required           │
│   - resolved item を archive 移動                   │
│   - P0/HIGH 新規時 → notify (R5)                    │
│   - generate_dashboard_md.py 呼出                   │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────┐
│ scripts/generate_dashboard_md.py (拡張)             │
│   - flock 同 lock                                   │
│   - <!-- ACTION_REQUIRED:START/END --> 境界全置換   │
│   - <!-- ACHIEVEMENTS_TODAY:START/END --> 同上      │
│   - 境界外セクションは input md からそのままコピー  │
│   - severity 並び替え + badge prefix (R5)          │
│   - atomic rename (R3)                              │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────────────┐
│ dashboard.md (render artifact、手編集禁止)         │
└──────────────────┬──────────────────────────────────┘
                   │
                   ↓ (00:00 JST)
┌─────────────────────────────────────────────────────┐
│ scripts/dashboard_rotate.sh (改修)                 │
│   - flock 同 lock (R6)                              │
│   - achievements.today → yesterday → day_before    │
│   - generate_dashboard_md.py 呼出 (rotate も       │
│     renderer 経由で md 生成)                       │
└─────────────────────────────────────────────────────┘
```

## 3. Scope 詳細 (リスク対応込み)

### Scope A: データ契約 (gunshi_report 拡張) — 0.5h

**変更**:
- `queue/reports/gunshi_report.yaml` の `result` 配下に `action_required_candidates: [...]` array
- 各 item の field: issue_id (R2 stable hash 必須) / parent_cmd / severity (P0/HIGH/MEDIUM/INFO) / summary / details / needs_lord_decision / source_report_ts / status (open/resolved/superseded)
- normalize() 関数の仕様明記 (全角/半角統一、trim、lowercase、連続空白 1 個に)
- `instructions/gunshi.md` に「QC 完了時 action_required_candidates 必須出力」明記

### Scope B: Sync Script — 2-3h

**新設**: `scripts/action_required_sync.sh`
- 起動 trigger: `inbox_watcher.sh` の `report_completed` event
- flock `/var/lock/shogun_dashboard.lock` 取得 (R6)
- gunshi_report.yaml schema validate (R3): 不正 yaml なら abort + log
- 各 item を dashboard.yaml.action_required に idempotent upsert (R2)
- status=resolved item を `dashboard.yaml.action_required_archive` に移動
- P0/HIGH 新規追加検出 (R5) → `scripts/notify.sh` (cmd_658 で discord 化)で push + AUTO_CMD escalation 連動 (key 分離: `P_AR_<severity>_<issue_id>`)
- 完了時 `generate_dashboard_md.py` 呼出

### Scope C: Renderer 拡張 — 2-3h

**改修**: `scripts/generate_dashboard_md.py`
- flock 同 lock (R6)
- 🚨 + ✅戦果セクションを `<!-- ACTION_REQUIRED:START/END -->` / `<!-- ACHIEVEMENTS_TODAY:START/END -->` 境界で全置換 (R1)
- 境界外セクション (🐸/📊/🔄/🏯/🛠️/📋記載ルール) は input md からそのままコピー (string slice、touch 禁止)
- severity 並び替え (P0→HIGH→MEDIUM→INFO→提案、R5) + badge prefix (`🔥 P0` / `⚠️ HIGH` / `📌 MEDIUM` / `ℹ️ INFO`)
- atomic rename (tempfile + fsync + os.rename、R3)
- validation 失敗時 → 前回 md 保持 + stderr error + `dashboard.yaml.last_render_error` field

**改修**: `scripts/dashboard_rotate.sh`
- flock 同 lock 取得 (R6)
- achievements rotation (today→yesterday→day_before) を yaml ベースで実施
- 完了時 `generate_dashboard_md.py` 呼出 (rotate も renderer 経由)

### Scope D: 責務一本化 — 1h

**新設**: `instructions/common/dashboard_responsibility_matrix.md`
- 全責務マトリクス 1 ファイル: Gunshi=candidate / Sync=infra / Karo=resolver / dashboard.md=render artifact

**改修**: `instructions/karo.md` / `gunshi.md` / `common/shogun_mandatory.md`
- dashboard 責務記述を canonical への参照のみに簡素化
- 「dashboard.md 直接編集禁止 (緊急例外時のみ将軍/家老の明示判断)」明文化

### Scope E: テスト — 2h

**新設**: `tests/dashboard_pipeline_test.sh`
- unit: action_required_candidates parser + normalize() 10 ケース
- golden: yaml→md render 出力一致
- integration: sample gunshi_report 投入 → ledger upsert → md 反映 (5min 以内 assert)
- concurrency: 10 並列で 100 回 sync + rotate 交互発火、race ゼロ assert
- regression: status=resolved item が md から消える
- AUTO_CMD coexistence: cmd_644 Scope B P9b/P9c と key 分離確認
- rotate: 5/8 00:00 JST 事故再現テスト = md 直編集なし状態で rotate → 全データ保持
- 文言整合: instructions の canonical 参照確認

### Scope F: 移行 — 1h

**実施**: 既存🚨エントリ + 戦果データ ledger 投入
- 現 dashboard.md 🚨欄 12 件 (HIGH-2/HIGH-3/observe-1〜6/pending-1〜3/info-3/info-5/提案-4) を `dashboard.yaml.action_required` に手動投入
- 現 dashboard.md ✅本日(空)/昨日(19件)/一昨日(5件) の戦果を `dashboard.yaml.achievements` に投入
- 旧 md 直編集箇所を HTML comment 境界で凍結 (renderer 管理領域化)
- generate_dashboard_md.py で初回 render → 整合確認

### Scope G: 軍師 QC — 1h

**実施**: 軍師 QC north_star 3 点照合
- N1: rotate regression 防止 (5/8 00:00 JST 事故再現テストで assert)
- N2: 軍師 QC issue が 5min 以内 dashboard 反映 (integration test で assert)
- N3: AUTO_CMD と coexistence (cmd_644 Scope B 動作維持)

---

## 4. 工数 + 依存関係

| Scope | 工数 | 依存 |
|---|---|---|
| A | 0.5h | — |
| B | 2-3h | A |
| C | 2-3h | A、B と並行可 |
| D | 1h | 並行可 |
| E | 2h | C 後 |
| F | 1h | E 後 |
| G | 1h | F 後 |
| **合計** | **9.5-13h** | parallel=2 で 6-9h |

## 5. 完了条件

- 全 Scope A-G AC PASS
- 6 リスクの mitigation 動作確認 (Scope E test 全 PASS)
- 5/8 00:00 JST rotate 事故再現テスト → md 全データ保持
- 軍師 QC north_star 3 点照合 PASS

---

(本書を基に shogun_to_karo.yaml に cmd_659 を発令、家老 dispatch 致す)

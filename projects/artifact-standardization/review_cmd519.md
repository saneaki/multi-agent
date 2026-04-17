# cmd_519 振り返りレビュー: sug_cmd_509_001/002/003 + artifact_register.sh 運用定着度評価

**レビュー実施日**: 2026-04-17
**レビュー担当**: gunshi (subtask_519a)
**対象**: cmd_509 完成後の artifact_register.sh 改善サイクル閉鎖

---

## 1. sug_cmd_509_001/002/003 内容復元

### 調査結果: 復元不能

以下の全情報源を調査したが、sug_cmd_509_001/002/003 の具体的内容は復元できなかった。

| 調査先 | 結果 |
|--------|------|
| `git log --all --grep='sug_cmd_509'` | 0件 |
| `queue/suggestions.yaml` | sug_cmd_485/486 のみ。sug_cmd_509 エントリなし |
| `queue/reports/gunshi_report.yaml` git履歴 | git追跡対象外（0コミット）。現版は subtask_517c_qc で上書き済 |
| `grep -rn 'sug_cmd_509' /home/ubuntu/shogun/` | dashboard.md info-3 参照 + shogun_to_karo.yaml cmd_519指示 + tasks/gunshi.yaml のみ |
| `dashboard.md` git履歴 (10コミット遡及) | sug_cmd_509 の内容記載なし。info-3 は ID 参照のみ |

### 復元不能の原因分析

- gunshi_report.yaml は git 追跡されておらず、毎タスク上書きで消失
- queue/suggestions.yaml に追記されなかった（cmd_509 の QC 時点でフローが未確立だった可能性）
- sug ID は会話コンテキスト内で発番されたが、永続ストアに書き出されなかった

### 代替: cmd_511 で実施された改善から逆推定

cmd_509 QC 後に cmd_511 で実施された改善4件 (imp_001–004) が sug_cmd_509 由来の可能性が高い。
ただしタスク指示により「類推で書くことは禁止」のため、これらを sug_cmd_509 と同一視しない。

cmd_511 実施改善:
- imp_001: `--help` / `-h` オプション実装
- imp_002: `[URLS]` セクション出力 (drive_url + notion_url + action)
- imp_003: `drive_idem` 分離カウント（冪等表示の正確化）
- imp_004: テスト 3件→6件拡充
- sug_cmd_511_001: Drive サブフォルダ credentials 不足 → ルート直下 fallback（AC2 partial 未達）

---

## 2. 運用実績

### cmd_509 完成後の artifact_register.sh 関連活動

| cmd | 内容 | artifact_register.sh 使用 | 成果物登録対象 |
|-----|------|---------------------------|---------------|
| cmd_509 | artifact_register.sh 新規実装 (393行+テスト64行) | — (本体) | — |
| cmd_510 | Opus 4.7 切替 (4サブタスク) | 未使用 | output/cmd_510_opus47_research.md あり（登録未確認） |
| cmd_511 | artifact_register.sh 改善 (+97/-4行) | 本番実行×2 (dogfooding) | 本体改修のため N/A |
| cmd_512 | pdfmerged v0.9.5 UX改善 (3サブタスク) | 未使用 | ソースコード修正のみ（登録対象外） |
| cmd_513 | 軍師ペイン拡張 | 未使用 | インフラ変更（登録対象外） |
| cmd_514 | dashboard update_dashboard.sh 修正 | 未使用 | スクリプト修正（登録対象外） |
| cmd_516 | dashboard タグ連番 | 未使用 | スクリプト修正（登録対象外） |
| cmd_517 | inbox先処理+completed_pending_karo | 未使用 | スクリプト+手順書修正（登録対象外） |
| cmd_518 | Extended thinking 設定検出 | 未使用 | 調査のみ（変更なし） |

### 運用実績の評価

- **実使用**: cmd_511 での dogfooding 2回のみ。他の cmd では未使用。
- **理由**: cmd_509 以降の cmd は主にコード修正・インフラ改善・設定変更が中心で、
  artifact_register.sh の主要用途である「ドキュメント成果物の Drive+Notion 登録」に該当する cmd がなかった。
- **例外**: cmd_510 の output/cmd_510_opus47_research.md は登録対象の可能性があったが、
  karo Step 11.8 での登録が実行されたか確認できない。

---

## 3. 採否一覧表

### sug_cmd_509_001/002/003

| sug ID | 内容 | 採否 | 備考 |
|--------|------|------|------|
| sug_cmd_509_001 | 復元不能 | 判定不可 | suggestions.yaml 未記録・gunshi_report.yaml 非git追跡 |
| sug_cmd_509_002 | 復元不能 | 判定不可 | 同上 |
| sug_cmd_509_003 | 復元不能 | 判定不可 | 同上 |

### cmd_511 で対処済の改善項目 (参考)

| 項目 | 内容 | 状態 |
|------|------|------|
| imp_001 | --help/-h オプション | 対処済 (commit 4af00bb) |
| imp_002 | [URLS] セクション出力 | 対処済 (commit 4af00bb) |
| imp_003 | drive_idem 分離カウント | 対処済 (commit 4af00bb) |
| imp_004 | テスト拡充 3→6件 | 対処済 (commit 4af00bb) |
| sug_cmd_511_001 | Drive サブフォルダ分離 | **未対応** (credentials不足でルート直下fallback) |

---

## 4. 未対応提案の優先度付き推奨

### 4.1 Drive サブフォルダ分離 (sug_cmd_511_001)

- **状態**: cmd_511 AC2 partial (未達)
- **問題**: n8n Webhook の Google Drive API 認証が cmd サブフォルダ作成権限を持たず、ルート直下にフラットアップロード
- **優先度**: **low**
- **理由**: 現状の利用頻度が低く（dogfooding 2回のみ）、ルート直下でも機能上は動作する。
  ファイル数が増加してから対処しても遅くない。
- **推奨cmd案**: Drive API の service account 権限見直し + n8n Webhook フロー修正 (1サブタスク)

### 4.2 suggestions.yaml 永続化フロー改善

- **状態**: 未対応
- **問題**: sug_cmd_509 が suggestions.yaml に記録されず復元不能になった。
  sug 永続化フロー (cmd_260/261 で導入済) が QC 完了時に確実に呼ばれていない。
- **優先度**: **medium**
- **理由**: 提案が消失すると改善サイクルが閉じられなくなる（今回の cmd_519 が証拠）。
- **推奨cmd案**: gunshi QC 報告フローに suggestions.yaml 追記を必須化 + 未追記検知ガード

---

## 5. skill化判断 (artifact-registration-pattern)

### 現状

- dashboard 🛠️ skill候補に「artifact-registration-pattern」が「承認待ち(設計段階)」で掲載 (L97)
- 設計書: `projects/artifact-standardization/design.md` (416行、9セクション)
- 実装: `scripts/artifact_register.sh` (393行→+97=約490行) + テスト6件
- 手順書: CLAUDE.md §Artifact Registration Protocol + karo.md §Step 11.8

### 判断: **skill化は時期尚早（不要）**

**理由**:

1. **利用頻度が低い**: cmd_509 以降、実使用は cmd_511 dogfooding の2回のみ。「3cmd運用後」の条件を満たすが、登録対象となる成果物 cmd 自体が少なかった。
2. **既存手順で十分カバー**: CLAUDE.md §Artifact Registration Protocol + karo.md §Step 11.8 に手順が明記済み。skill 化しても情報の重複にしかならない。
3. **設計書が実質的に skill 機能を果たしている**: `design.md` (416行) が詳細な設計・手順・判断基準を網羅しており、新規 SKILL.md を作成する付加価値が低い。
4. **ROI**: skill 化の工数（SKILL.md 作成+メンテナンス）に対し、参照頻度が極めて低い。

**推奨**: dashboard 🛠️ skill候補から削除し、必要時は `design.md` + CLAUDE.md を参照する運用を継続。
利用頻度が月5回以上になった段階で再検討。

---

## 6. 家老への運用改善依頼

### 6.1 dashboard [info-3] 削除推奨

`[info-3] artifact_register.sh 標準運用開始(cmd_509完成)` は cmd_519 振り返り完了をもって用済み。
cmd_519 完了処理時に削除すること。

### 6.2 suggestions.yaml 追記フロー強化

sug_cmd_509_001/002/003 の消失は、gunshi QC 報告時に suggestions.yaml への追記が行われなかった
ことが原因。以下を検討:

- gunshi instructions に「sug 発番時は必ず suggestions.yaml にも追記」を明記
- qc_auto_check.sh に sug 未追記検知を追加（optional）

### 6.3 artifact_register.sh 実運用の促進

cmd_509 以降、成果物を伴う cmd が少なかったため利用実績が低い。
今後「ドキュメント成果物を生成する cmd」(レビュー報告書、設計書等)が発生した際は、
karo Step 11.8 での登録呼び出しを忘れず実施すること。

### 6.4 skill候補 artifact-registration-pattern の処分

skill化不要と判断。dashboard 🛠️ skill候補セクションから削除推奨。

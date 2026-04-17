# Artifact Registration Protocol (成果物登録プロトコル)

cmd で生成する成果物は以下の規則で Notion 成果物DB + Drive に登録する。

## 責務分担

| 役職 | 責務 |
|------|------|
| **karo (家老)** | (a) task YAML に `output_path:` (相対パス) を明示 / (b) Step 11.8 (完了処理) で命名規則遵守を確認 / (c) cmd 完了時、Artifact Register (AR) スクリプトを呼び出す |
| **ashigaru (足軽)** | (a) task YAML の `output_path:` 通りにファイルを作成 / (b) 自己判断で改名しない / (c) 報告 YAML の `result.files:` で生成ファイル一覧を返す |
| **gunshi (軍師)** | QC 時に命名規則・成果物 DB 登録内容を確認する (任意) |
| **shogun (将軍)** | 発令する cmd YAML に `output_path:` 要求を含めることを推奨 |

## 成果物の配置規則

| 規模 | 配置場所 | ファイル名 |
|------|---------|-----------|
| 小粒 (1-2 ファイル) | `output/` フラット | `cmd_{N}_{slug}.md` |
| 中〜大規模 (3 ファイル以上) | `projects/{project}/` | `cmd_{N}_{slug}.md` |

非 cmd 成果物 (テンプレート・永続設定等) は従来通り任意名を許容する。

## cmd 完了時の登録フロー

1. karo が Step 11.8 (完了処理) で Artifact Register (AR) スクリプトを呼び出す
2. AR スクリプトは以下を実行する:
   - Drive: cmd サブフォルダ (`cmd_{N}_{project}_{date}/`) を create-or-find し、ファイルをアップロード
   - Notion Artifacts DB: レコード作成 (cmd番号/ファイル名/日付/種別/プロジェクト/Driveリンク)
3. 登録完了を dashboard の ✅戦果 に反映

## Stop hook との関係

既存 Stop hook (`notion_session_log.sh`) はセッション活動ログ目的で継続。
成果物登録のバッチ fallback としても動作する (リアルタイム登録済のファイルは冪等にスキップ)。

## Notion-Version 固定

API バージョンは `2022-06-28` に統一する。未来版の利用は禁止 (cmd_507 で修正済み)。

# cmd_212 法律文書WF Phase3実装メモ

## 対象WF
- ID: Cq0g3T60NfZGuO3t
- 実装日: 2026-02-22
- 22ノード → 27ノード

## 追加ノード（5ノード、高確信ルートに挿入）

| # | ノード名 | 役割 |
|---|---------|------|
| N1 | _ai_analysis/フォルダ作成(案件内) | 案件フォルダ内に_ai_analysis/を作成（continueOnFail=true）|
| N2 | Move content.md to 案件/_ai_analysis/ | _content.mdを案件内_ai_analysis/に移動 |
| N3 | Move summary_rebuttal.md to 案件/_ai_analysis/ | _summary_rebuttal.mdを案件内_ai_analysis/に移動 |
| N4 | Code: manifest.json生成 | 分析情報をJSON化しBinaryデータとして出力 |
| N5 | Upload manifest.json | _manifest.jsonを_ai_analysis/にアップロード |

## 高確信ルート最終フロー

```
IF: 高確信/低確信 [true]
  → Move Original File to 案件フォルダ
  → _ai_analysis/フォルダ作成(案件内) [continueOnFail]
  → Move content.md to 案件/_ai_analysis/
  → Move summary_rebuttal.md to 案件/_ai_analysis/
  → Code: manifest.json生成（Binary変換込み）
  → Upload manifest.json
  → Format 完了通知（自動移動）
  → Send Google Chat Phase2

IF: 高確信/低確信 [false] ← 変更なし
  → Format 候補通知（手動確認依頼）
  → Send Google Chat Phase2
```

## cmd_192連携
manifest.jsonのnoteフィールドに連携設計を記録:
「cmd_192 WF-1連携: このフォルダへのファイル移動がcmd_192 Drive Triggerを発火させる」

# Context Snapshot (all agents)

## 目的

auto-compact は予告なく発動する。compaction を跨いでも「何を考えていたか」が失われないよう、エージェントは作業の節目で `context_snapshot.sh` を呼び出して agent_context を snapshot ファイルに書き出す。

## タイミング(推奨)

| 契機 | 書込む内容 |
|------|----------|
| **タスク開始直後** | approach(作業方針) + 最初の progress 項目 |
| **重要な判断を下した時** | decisions に追加 |
| **ブロッカーに遭遇した時** | blockers に追加 |
| **サブステップ完了時** | progress に追加 |
| **長時間作業(10分以上)** | 節目ごとに approach 更新 |

## 使い方

```bash
bash scripts/context_snapshot.sh write <agent_id> \
    "<approach>" \
    "<progress_item1>|<progress_item2>|<progress_item3>" \
    "<decision1>|<decision2>" \
    "<blocker1>|<blocker2>"
```

- `progress` / `decisions` / `blockers` は **`|` 区切り** で複数項目を渡す
- 空文字列を渡すと該当フィールドは更新されない
- 既存の task metadata は保持される
- 上限: approach 200 文字 / progress 10 件 / decisions 5 件 / blockers 3 件

## 例

```bash
# タスク開始時
bash scripts/context_snapshot.sh write gunshi \
    "cmd_468 フェーズ2設計書作成" \
    "既存スクリプト2件精読済" \
    "案A+B 統合採用" \
    ""

# 進捗追加時
bash scripts/context_snapshot.sh write gunshi \
    "cmd_468 フェーズ2設計書作成" \
    "既存スクリプト2件精読済|設計書ドラフト作成中" \
    "" \
    ""
```

## 禁忌

- **戦国口調は使わない**: シェル引数は技術文字列として扱う
- **頻繁すぎる書込みは不要**: 5-10 分に1回程度で十分
- **polling 禁止**: wait ループで書込むことは F004 違反

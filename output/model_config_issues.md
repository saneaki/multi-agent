# モデル構成の仕様矛盾 — 検討事項

調査日: 2026-02-15

## 問題の概要

karo.md内に足軽のモデル割当について3箇所の矛盾がある。
また、shutsujin_departure.shの実装とも不一致がある。

## 矛盾箇所一覧

### 1. karo.md L609-610（タスク再割当手順）

```
tmux select-pane -t multiagent:0.{N} -T "Sonnet"   # ashigaru 1-4
tmux select-pane -t multiagent:0.{N} -T "Opus"     # ashigaru 5-8
```

→ 足軽5-7号は**Opus**と記載

### 2. karo.md L807（Model Configuration表）

```
Ashigaru 1-7 | Sonnet | multiagent:0.1-0.7 | Implementation
```

→ 足軽1-7号は**全員Sonnet**と記載

### 3. karo.md L811（方針文）

```
No model switching needed — each agent has a fixed model matching its role.
```

→ モデル切替は**不要**と記載

### 4. shutsujin_departure.sh（実装）

- 平時の陣: 足軽1-7号 = 全員Sonnet
- 決戦の陣(-k): 全員Opus
- upstreamと完全一致（差分なし）

### 5. inbox_watcher.sh（実装）

- `type: model_switch` が実装済み（L234-238）
- 家老からinbox_writeで `/model opus` 等を送信可能
- しかしkaro.mdが「切替不要」と書いているため未使用

## 矛盾の対照表

| 箇所 | 足軽1-4 | 足軽5-7 | 動的切替 |
|------|---------|---------|----------|
| karo.md L609-610 | Sonnet | **Opus** | — |
| karo.md L807 | Sonnet | **Sonnet** | — |
| karo.md L811 | — | — | **不要** |
| shutsujin（実装） | Sonnet | **Sonnet** | `-k`で全員Opus |
| inbox_watcher（実装） | — | — | **対応済み** |

## 実運用での影響

- 家老は複雑タスク（cmd_138 Frog、cmd_149 Docs実装等）で足軽を「Opus」とdashboardに記載
- しかし実際にはmodel_switchを送信していないため、全員Sonnetで動作
- dashboardの表記と実態が乖離

## 検討すべき方針

### 案A: 全員Sonnet＋家老が都度切替

- shutsujinは現状維持（平時=全Sonnet）
- karo.mdにmodel_switch使用手順を追記
- 家老がタスク難易度に応じてinbox_writeで切替
- メリット: コスト効率、柔軟性
- デメリット: 切替のオーバーヘッド

### 案B: 足軽5-7号をOpus固定

- shutsujinの平時構成を変更（5-7号=Opus）
- karo.md L807を修正
- メリット: 常に高精度枠が確保される
- デメリット: コスト増、Sonnet枠が4名に減少

### 案C: settings.yamlで個別指定

- settings.yamlにエージェント別モデル設定を追加
- shutsujinがsettings.yamlを読んで起動時モデルを決定
- CLI Adapter(lib/cli_adapter.sh)の既存機能を活用
- メリット: 再起動なしで構成変更可能
- デメリット: 実装が必要

## 修正が必要なファイル（方針決定後）

- [ ] instructions/karo.md — 矛盾3箇所の統一
- [ ] shutsujin_departure.sh — 方針に応じた構成変更
- [ ] config/settings.yaml — 案Cの場合、cliセクション追加
- [ ] dashboard.md — モデル表記の正確化ルール追記

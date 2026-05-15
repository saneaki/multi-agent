# Shogun シェルコマンド一覧

> **【preset immutability — 設計原則 (cmd_718)】**  
> `config/settings.yaml` の `formations.*` プリセットは不変リファレンスである。
> 本ドキュメントに記載する全シェルコマンド (shu / shk / shc / shp / shutsujin_departure.sh /
> switch_cli.sh) は **`formations.*` を書き換えない**。
> 書込み対象は `cli.agents` (ランタイム live state) に限られる。  
> 詳細は [`docs/formation_immutability.md`](./formation_immutability.md) および
> [`instructions/common/preset_immutability.md`](../instructions/common/preset_immutability.md) を参照。

## 番号体系 (shp 共通)

| 番号 | CLI種別 | モデル | 表示名 |
|------|---------|--------|--------|
| 1 | claude | claude-sonnet-4-6 | Sonnet+T |
| 2 | claude | claude-opus-4-7 | Opus+T |
| 3 | codex | gpt-5.5 | Codex |

Thinking はデフォルト ON (Claude系)。`thinking: false` を明示した場合のみ OFF。

## プリセット一覧 (shp --preset)

| プリセット | 内容 |
|-----------|------|
| current | 現在の settings.yaml 値をそのまま使用 |
| heavy-opus | 全員 Opus+T (番号 2) |
| all-sonnet | 全員 Sonnet+T (番号 1) |
| sonnet-codex-mix | 家老/軍師=Sonnet+T, 足軽=交互(奇数=Sonnet/偶数=Codex) |

---

## コマンド一覧

### shu — 出陣 (標準起動)

| 項目 | 内容 |
|------|------|
| **目的** | tmux セッション作成 + 全エージェント起動 (前回状態を維持) |
| **実体** | `bash ~/shogun/shutsujin_departure.sh` (alias in ~/.bashrc) |
| **引数/オプション** | なし (標準起動) |
| **使用例** | `shu` |
| **前提条件** | tmux が起動していること / shogun リポジトリが ~/shogun に存在すること |
| **関連ファイル** | `shutsujin_departure.sh`, `config/settings.yaml` |

---

### shk — 帰陣 (決戦の陣)

| 項目 | 内容 |
|------|------|
| **目的** | 全エージェントを Opus モードで起動 (高難度タスク向け) |
| **実体** | `bash ~/shogun/shutsujin_departure.sh --kessen` (alias in ~/.bashrc) |
| **引数/オプション** | `--kessen` 決戦の陣: 家老・足軽・軍師 全員 Opus で起動 |
| **使用例** | `shk` |
| **前提条件** | tmux が起動していること |
| **関連ファイル** | `shutsujin_departure.sh`, `config/settings.yaml` |

---

### shc — 出陣 (陣形管理)

| 項目 | 内容 |
|------|------|
| **目的** | settings.yaml の formations プリセットを適用して足軽を一括切替 |
| **実体** | `scripts/shc.sh` |
| **引数/オプション** | `deploy [name]` 陣形適用 / `status` 現在状態確認 / `restore` all-sonnet 復帰 / `list` 一覧表示 |
| **使用例** | `bash scripts/shc.sh deploy hybrid` `bash scripts/shc.sh status` `bash scripts/shc.sh restore` |
| **前提条件** | tmux multiagent:agents セッションが起動していること |
| **関連ファイル** | `scripts/shc.sh`, `config/settings.yaml` (formations セクション), `scripts/switch_cli.sh` |

---

### shp — 出陣・撤収 (番号指定一括コマンド)

| 項目 | 内容 |
|------|------|
| **目的** | 番号 (1=Sonnet+T / 2=Opus+T / 3=Codex) で全構成員のモデルを一括設定して出陣、または対象を選択して撤収 |
| **実体** | `scripts/shp.sh` |
| **呼び出し方** | `shp` (~/bin/shp symlink 経由) または `bash ~/shogun/scripts/shp.sh` |
| **引数/オプション** | (なし) インタラクティブ出陣 / `<N1> [N2] [N3]` または `<N1>...<N10>` positional 一括指定 / `--yes` `-y` 確認prompt自動Yes / `--dry-run` 確認のみ / `--preset <name>` プリセット出陣 / `--kill` 撤収モード / `--retreat` `--kill` の同義語 / `--help` ヘルプ表示 |
| **使用例 (出陣 interactive/preset)** | `shp` `shp --preset all-sonnet` `shp --preset heavy-opus --dry-run` |
| **使用例 (出陣 positional)** | `shp 1` (全員Sonnet) / `shp 2 1` (将軍Opus,他Sonnet) / `shp 1 2 3` (将軍Sonnet/家老+足軽1-7 Opus/軍師Codex) / `shp 1 2 1 1 1 1 1 1 1 3 --yes` (10名個別) |
| **使用例 (撤収)** | `shp --kill` `shp --retreat` `shp --kill --dry-run` `shp --kill --yes` |
| **前提条件** | tmux multiagent:agents セッションが起動していること (--dry-run なら不要) |
| **PATH設定** | `~/bin/shp` symlink + `~/.bashrc` alias `shp` 両方設定済み |
| **関連ファイル** | `scripts/shp.sh`, `config/settings.yaml` (cli.agents セクション), `scripts/switch_cli.sh` |

**出陣プロンプト順序 (固定)**: 将軍 → 家老 → 足軽1 → 足軽2 → 足軽3 → 足軽4 → 足軽5 → 足軽6 → 足軽7 → 軍師

**出陣対象 10名**: 将軍 → 家老 → 足軽1〜7 → 軍師。撤収 (`shp --kill`) は従来どおり家老・足軽1〜7・軍師のみ対象で、将軍停止は別管理。

**shc との違い**: shc は formations プリセット (ashigaru のみ対象) / shp は 10構成員 (将軍・家老・足軽1-7・軍師) に対して番号で直接指定

**shk (撤収) との違い**: shk は出陣コマンド (決戦の陣) / shp --kill は稼働中エージェントへ /exit を送信して個別に撤収

#### positional args 体系 (出陣モード)

| 引数個数 | 割当 | 例 | 結果 |
|---------|------|-----|------|
| 1 個 | 全員 (10名) = N1 | `shp 2` | 全員 Opus+T |
| 2 個 | 将軍 = N1, 他9名 = N2 | `shp 2 1` | 将軍 Opus+T, 他9名 Sonnet+T |
| 3 個 | 将軍=N1, 家老+足軽1-7=N2, 軍師=N3 | `shp 1 2 3` | 将軍Sonnet, 家老+足軽1-7 Opus, 軍師Codex |
| 10 個 | 構成員順に個別指定 (将軍/家老/足軽1-7/軍師) | `shp 1 2 1 1 1 1 1 1 1 3` | 個別 (この例: 将軍=Sonnet, 家老=Opus, 足軽1-7=Sonnet, 軍師=Codex) |
| 9 個 | **旧仕様互換**: 将軍は現在値維持、残り9名に適用 | `shp 2 1 1 1 1 1 1 1 3` | WARN + 家老=Opus, 足軽1-7=Sonnet, 軍師=Codex |
| その他 | エラー (1/2/3/10 個が正式仕様、9個は旧仕様互換) | `shp 1 1 1 1` | エラー終了 |

**positional + --yes 併用**: y/N 確認 prompt をスキップして即出陣 (1行コマンド向け)。
**positional + --dry-run 併用**: 設定の確認のみ (settings.yaml/pane 変更なし)。
**positional と --preset / --kill の併用**: エラー (排他)。

---

### shutsujin_departure.sh — 初期起動

| 項目 | 内容 |
|------|------|
| **目的** | tmux セッション作成・初期設定・全エージェント起動を一括実行 |
| **実体** | `shutsujin_departure.sh` (プロジェクトルート) |
| **引数/オプション** | (なし) 標準起動 / `-c` クリーンスタート(キューリセット) / `-s`/`--setup-only` tmux セットアップのみ / `-k`/`--kessen` 決戦の陣(全員Opus) / `-h`/`--help` ヘルプ |
| **使用例** | `./shutsujin_departure.sh` `./shutsujin_departure.sh -c` `./shutsujin_departure.sh -s` |
| **前提条件** | tmux / python3 / Claude Code CLI がインストールされていること |
| **関連ファイル** | `config/settings.yaml`, `lib/cli_adapter.sh`, `scripts/switch_cli.sh` |

---

### switch_cli.sh — CLI 切替

| 項目 | 内容 |
|------|------|
| **目的** | 稼働中のエージェントの CLI 種別・モデルをライブで切り替える |
| **実体** | `scripts/switch_cli.sh` |
| **引数/オプション** | `<agent_id>` のみ: settings.yaml の現在値で再起動 / `--type <type>` CLI 種別変更 / `--model <model>` モデル変更 |
| **使用例** | `bash scripts/switch_cli.sh shogun --model claude-opus-4-7` `bash scripts/switch_cli.sh ashigaru3 --model claude-opus-4-7` `bash scripts/switch_cli.sh ashigaru3 --type codex --model gpt-5.5` |
| **前提条件** | tmux shogun / multiagent:agents セッションが起動していること / 対象エージェントが idle であること |
| **関連ファイル** | `scripts/switch_cli.sh`, `lib/cli_adapter.sh`, `config/settings.yaml` |

**注意**: `switch_cli.sh` は対象 pane が idle prompt に見えない場合、破壊防止のため切替を拒否する。

---

### shogun-model-switch skill — モデル切替スキル

| 項目 | 内容 |
|------|------|
| **目的** | switch_cli.sh をラップして Claude Code から自然言語でモデル切替を実行 |
| **実体** | `skills/shogun-model-switch/SKILL.md` (Claude Code skill) |
| **引数/オプション** | 自然言語 (例: "ashigaru3 を Opus にして" / "足軽全員 Sonnet+T に切替") |
| **使用例** | `/shogun-model-switch ashigaru3 sonnet` |
| **前提条件** | Claude Code が起動していること |
| **関連ファイル** | `skills/shogun-model-switch/SKILL.md`, `scripts/switch_cli.sh`, `lib/cli_adapter.sh` |

> **将軍 (shogun) のモデル切替**: `shp` の出陣対象に将軍を含める。個別変更は `bash scripts/switch_cli.sh shogun --model <model>` でも実行できる。

---

## 出陣・撤収 役割分担

| コマンド | 出陣 | 撤収 | 対象 | 備考 |
|---------|------|------|------|------|
| `shu` | ✅ | — | 全員 | 標準起動 (tmux セッション作成から) |
| `shk` | ✅ | — | 全員 | 決戦の陣 (全員 Opus で起動) |
| `shc` | ✅ | ✅ | 足軽のみ | formations プリセット適用・復帰 |
| `shp` | ✅ | ✅ | 出陣: 10構成員 / 撤収: 将軍除く9構成員 | 番号指定 (出陣) / y/N 指定 (撤収) |
| `switch_cli.sh` | — | ✅* | 個別エージェント | CLI 切替 |

*switch_cli.sh は実際には CLI 再起動 (撤収→再起動のサイクル)

## 使い分けガイド

| やりたいこと | 使うコマンド |
|-------------|-------------|
| 毎日の標準起動 | `shu` |
| 高難度タスク (全員Opus) | `shk` |
| 特定の陣形プリセット適用 (shc formations) | `bash scripts/shc.sh deploy <name>` |
| 番号で全構成員を柔軟に設定して出陣 | `shp` または `shp --preset <name>` |
| 1行コマンドで全員同一モデル即出陣 | `shp 1 --yes` (全員 Sonnet) / `shp 2 --yes` (全員 Opus) |
| 1行コマンドで将軍だけ別モデル | `shp 2 1 --yes` (将軍 Opus, 他 Sonnet) |
| 1行コマンドで構成員10名個別指定 | `shp 1 2 1 1 1 1 1 1 1 3 --yes` |
| 将軍のモデル切替 | `shp` または `bash scripts/switch_cli.sh shogun --model <model>` |
| 特定エージェントだけ撤収 | `shp --kill` (対話選択) |
| 全構成員を一括撤収 | `shp --kill` → 全員 y |
| 撤収対象の確認のみ (実行なし) | `shp --kill --dry-run` |
| 1 エージェントだけモデル変更 | `bash scripts/switch_cli.sh <id> --model <model>` |
| Claude Code から自然言語でモデル変更 | `shogun-model-switch` skill |

**注意事項 (shp --kill / --retreat):**
- shp の出陣対象は 10名 (将軍/家老/足軽1-7/軍師)。撤収対象は 9名 (家老/足軽1-7/軍師) のみ。将軍停止は別管理。
- `--dry-run` 併用時は settings.yaml / tmux pane / process への変更は一切行わない。
- 撤収は各エージェントの CLI に `/exit` を送信するのみ。tmux ペイン自体は維持される。
- 完全撤収 (tmux セッション削除) が必要な場合は `tmux kill-session -t multiagent` を手動実行すること。

## settings.yaml cli.agents 構造

```yaml
cli:
  agents:
    <agent_id>:
      cli_type: claude | codex       # CLI 種別
      model: claude-sonnet-4-6 | claude-opus-4-7 | gpt-5.5  # モデル
      effort: max                    # 努力レベル (Claude のみ有効)
      thinking: false                # Thinking OFF (省略時 = ON)
```

対象 agent_id: `shogun`, `karo`, `ashigaru1`-`ashigaru7`, `gunshi` (10名)

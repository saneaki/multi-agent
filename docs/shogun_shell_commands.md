# Shogun シェルコマンド一覧

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
| sonnet-codex-mix | 将軍/家老/軍師=Sonnet+T, 足軽=交互(奇数=Sonnet/偶数=Codex) |

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

### shp — 出陣 (番号指定一括出陣) ← NEW

| 項目 | 内容 |
|------|------|
| **目的** | 番号 (1=Sonnet+T / 2=Opus+T / 3=Codex) でインタラクティブに全構成員のモデルを一括設定して出陣 |
| **実体** | `scripts/shp.sh` |
| **呼び出し方** | `shp` (~/bin/shp symlink 経由) または `bash ~/shogun/scripts/shp.sh` |
| **引数/オプション** | (なし) インタラクティブ / `--dry-run` 確認のみ / `--preset <name>` プリセット使用 / `--help` ヘルプ表示 |
| **使用例** | `shp` `shp --preset all-sonnet` `shp --preset heavy-opus --dry-run` |
| **前提条件** | tmux multiagent:agents セッションが起動していること (--dry-run なら不要) |
| **PATH設定** | `~/bin/shp` symlink + `~/.bashrc` alias `shp` 両方設定済み |
| **関連ファイル** | `scripts/shp.sh`, `config/settings.yaml` (cli.agents セクション), `scripts/switch_cli.sh` |

**プロンプト順序 (固定)**: 将軍 → 家老 → 足軽1 → 足軽2 → 足軽3 → 足軽4 → 足軽5 → 足軽6 → 足軽7 → 軍師

**shc との違い**: shc は formations プリセット (ashigaru のみ対象) / shp は全構成員に対して番号で直接指定 (将軍・家老・軍師も対象)

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
| **使用例** | `bash scripts/switch_cli.sh ashigaru3` `bash scripts/switch_cli.sh ashigaru3 --model claude-opus-4-7` `bash scripts/switch_cli.sh ashigaru3 --type codex --model gpt-5.5` |
| **前提条件** | tmux multiagent:agents セッションが起動していること / 対象エージェントが idle であること |
| **関連ファイル** | `scripts/switch_cli.sh`, `lib/cli_adapter.sh`, `config/settings.yaml` |

**注意**: 将軍 (shogun) ペインへの送信は非対応。家老 (karo) / 軍師 (gunshi) / 足軽1-7 が対象。

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

---

## 使い分けガイド

| やりたいこと | 使うコマンド |
|-------------|-------------|
| 毎日の標準起動 | `shu` |
| 高難度タスク (全員Opus) | `shk` |
| 特定の陣形プリセット適用 (shc formations) | `bash scripts/shc.sh deploy <name>` |
| 番号で全構成員を柔軟に設定 | `bash scripts/shp.sh` |
| 1 エージェントだけモデル変更 | `bash scripts/switch_cli.sh <id> --model <model>` |
| Claude Code から自然言語でモデル変更 | `shogun-model-switch` skill |

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

対象 agent_id: `shogun`, `karo`, `ashigaru1`-`ashigaru7`, `gunshi`

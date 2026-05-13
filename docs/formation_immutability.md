# Formation Immutability — 陣形不変原則

> **設計原則 (cmd_718)**: `config/settings.yaml` の `formations.*` プリセットは
> cmd_705 当時の不変リファレンスである。実行系のスクリプト (shp / shx / shc.sh deploy)
> は **preset を読み出して起動する側** であり、**preset を書き換える側ではない**。

---

## 三層構造

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 1: formations.*  (config/settings.yaml)                   │
│          【不変リファレンス】                                    │
│          - hybrid       (Sonnet×3 + Opus×2 + Codex×2, cmd_705)  │
│          - all-sonnet                                            │
│          - all-opus                                              │
│          - その他                                                │
│          ※ 書換は殿の明示裁可を要する (preset_immutability.md)   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 片方向 (read-only)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 2: 適用エンジン (片方向適用)                                │
│   - scripts/shc.sh deploy <name>     formations.<name> を読出   │
│   - scripts/shc.sh deploy --settings-only (cmd_717 で追加)       │
│   - scripts/shp.sh                   shp 内蔵プリセット使用      │
│   - shutsujin_departure.sh           起動時に shc deploy hybrid  │
│                                       --settings-only を実行     │
│   ※ いずれも formations.* を書き換えない                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ 書込み (live state)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ Layer 3: cli.agents     (config/settings.yaml)                   │
│          【ランタイム live state】                                │
│          - karo: { cli_type, model, effort, thinking }            │
│          - ashigaru1-7: { ... }                                   │
│          - gunshi: { ... }                                        │
│          ※ shp / shc.sh deploy / switch_cli.sh が書き換える対象  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 各層の責務

### Layer 1: formations.* (不変)

| 役割 | 内容 |
|------|------|
| **位置** | `config/settings.yaml` の `formations:` セクション |
| **性質** | 不変リファレンス。cmd_705 当時の構成を凍結 |
| **代表例** | `hybrid` = Sonnet×3 + Opus×2 + Codex×2 (cmd_705 当時の実運用構成) |
| **書換可否** | **禁止**。殿の明示裁可がある場合のみ可 |
| **違反例** | cmd_717 AC-4 (cmd_718 で revert 済み) |

### Layer 2: 適用エンジン (片方向 read-only)

| スクリプト | 役割 | formations.* 書換? |
|-----------|------|-------------------|
| `scripts/shc.sh deploy <name>` | formations.<name> を読出して cli.agents に適用 | ❌ しない |
| `scripts/shc.sh deploy --settings-only` | 同上 (switch_cli skip。起動前用) | ❌ しない |
| `scripts/shp.sh` | shp 内蔵プリセット (heavy-opus / all-sonnet / sonnet-codex-mix / current) を cli.agents に適用 | ❌ しない (formations を一切参照しない) |
| `shutsujin_departure.sh` | 起動時に shc.sh deploy hybrid --settings-only を呼出 | ❌ しない |
| `scripts/switch_cli.sh` | 個別 agent の CLI / モデルを切替 | ❌ しない |

### Layer 3: cli.agents (live state)

| 役割 | 内容 |
|------|------|
| **位置** | `config/settings.yaml` の `cli:` → `agents:` セクション |
| **性質** | ランタイム live state。エージェント起動時の実際の設定 |
| **書換主体** | shp.sh / shc.sh deploy / switch_cli.sh |
| **更新タイミング** | shp 実行時、shc deploy 実行時、switch_cli.sh 実行時 |

---

## 違反パターンと再発防止

### 違反例: cmd_717 AC-4 (revert 済み)

**事象**: cmd_717 で「formations.hybrid を実運用構成 (Codex×3 + Sonnet×2 + Opus×2) に同期」した。

**問題**: formations.* は不変リファレンスであり、実運用構成への「同期」は preset immutability 原則違反。

**修正**: cmd_718 AC-1 で b8ac913^ 当時の値 (Sonnet×3 + Opus×2 + Codex×2) に revert。

**再発防止**: 本ドキュメント + `instructions/common/preset_immutability.md` で構造的に明文化。

### 違反の検出方法

`git diff` で `config/settings.yaml` の `formations:` 配下に変更があれば、preset immutability 違反の疑いあり。家老/軍師は当該 cmd の `purpose` / `command` を確認し、殿の明示裁可があるか検証する。

---

## 設計意図

- **shp / shx は preset を「選ぶ側」**: 番号体系 (1/2/3) と shp 内蔵プリセット (heavy-opus 等) で柔軟に出陣できるが、formations.* は触らない。
- **shc.sh deploy は preset を「読み出す側」**: formations.<name> を読み出して cli.agents に適用するが、formations.<name> 自体は書き換えない。
- **formations.* は「凍結された設計」**: cmd_705 当時の設計を後方互換のために保持する。新しい陣形が必要なら、新しい formation を **追加** するのが正規ルート (既存 formation を「同期」名目で書き換えるのは禁止)。

---

## 関連

- `instructions/common/preset_immutability.md` — 規律 (殿裁可必須)
- `instructions/karo.md` — 家老の dispatch 規律 (cmd_717 AC-4 違反例の参照)
- `output/cmd_717a_shx_parent_silent_failure_fix.md §0` — corrective note
- `scripts/shp.sh` (cmd_718 で冒頭コメントに明記)
- `scripts/shc.sh` (cmd_717 で --settings-only オプション追加)
- `docs/shogun_shell_commands.md` — シェルコマンド一覧

---

**履歴**:
- 2026-05-13 cmd_718 で新設 (cmd_717 AC-4 違反を受けた構造的再発防止)

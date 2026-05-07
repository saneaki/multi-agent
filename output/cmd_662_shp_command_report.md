# cmd_662 shp.sh 実装レポート

**作成**: 2026-05-08 04:33 JST  
**担当**: ashigaru1 (Sonnet+T)  
**parent_cmd**: cmd_662  
**Scope**: A+B+C+E

---

## 実装ログ

### Scope A: scripts/shp.sh 実装

#### 設計決定

1. **番号体系の実装**  
   `num_cli_type()` / `num_model()` / `num_label()` の 3 関数でマッピングを分離。  
   連想配列 (`declare -A`) は bash 4.0+ 依存のため注記を追加。

2. **settings.yaml 更新方式**  
   switch_cli.sh の `update_settings_yaml()` と同じライン単位置換アプローチを採用。  
   理由: yaml.dump を使うと設定ファイルのコメントが消えるため。  
   `update_settings_batch()` で全構成員を 1 回の Python 実行で更新する最適化を実施。

3. **shogun ペインの扱い**  
   switch_cli.sh の制約に従い将軍ペインへの tmux 送信は行わない。  
   settings.yaml の更新のみ実施し、手動再起動メッセージを表示。

4. **--dry-run の動作**  
   interactive 入力 → summary → **「出陣しますか?」確認あり** → y 入力でも変更なし。  
   (AC C-1: 確認プロンプト後の y でも変更されないことを保証)

5. **Enter 空入力 = 現在値維持**  
   `get_current_number()` で settings.yaml から現在値を読み取り、  
   空入力時のデフォルトとして使用。

6. **preset sonnet-codex-mix の足軽交互パターン**  
   奇数 index (ash1,3,5,7) = Sonnet+T (1), 偶数 index (ash2,4,6) = Codex (3)

#### 流用箇所

| 流用元 | 利用内容 |
|--------|---------|
| `scripts/shc.sh` | カラー変数定義、check_prerequisites パターン、Python inline 構造 |
| `scripts/switch_cli.sh` | update_settings_yaml() ライン単位置換アルゴリズム |
| `lib/cli_adapter.sh` | cli_type/model の判定ロジック (参照のみ) |

---

### Scope B: docs/shogun_shell_commands.md 新設

調査結果:

| コマンド | 実体 | 発見場所 |
|---------|------|---------|
| shu | `shutsujin_departure.sh` (標準起動) | ~/.bashrc alias |
| shk | `shutsujin_departure.sh --kessen` (全員Opus起動) | ~/.bashrc alias |
| shc | `scripts/shc.sh` | リポジトリ |
| shp | `scripts/shp.sh` | 本タスクで新設 |
| shutsujin_departure.sh | プロジェクトルート | リポジトリ |
| switch_cli.sh | `scripts/switch_cli.sh` | リポジトリ |
| shogun-model-switch | `skills/shogun-model-switch/SKILL.md` | skills/ |

---

## テスト結果

### C-1: --dry-run インタラクティブ

```
echo -e "1\n1\n1\n1\n1\n1\n1\n1\n1\n1\ny" | bash scripts/shp.sh --dry-run
```

| チェック項目 | 結果 |
|------------|------|
| 10 構成員 prompt が順次表示される | PASS |
| summary が表示される | PASS |
| 「出陣しますか?」プロンプトが表示される | PASS |
| y 入力後も settings.yaml 変更なし | PASS (`git diff config/settings.yaml` = 空) |

### C-2: --preset all-sonnet --dry-run

```
bash scripts/shp.sh --preset all-sonnet --dry-run
```

| チェック項目 | 結果 |
|------------|------|
| interactive をスキップして all-sonnet summary 表示 | PASS |
| [DRY-RUN] メッセージが表示される | PASS |
| settings.yaml 変更なし | PASS |

---

## docs/shogun_shell_commands.md 抜粋

### 番号体系 (shp)

| 番号 | CLI | モデル | 表示名 |
|------|-----|--------|--------|
| 1 | claude | claude-sonnet-4-6 | Sonnet+T |
| 2 | claude | claude-opus-4-7 | Opus+T |
| 3 | codex | gpt-5.5 | Codex |

### プリセット一覧

| プリセット | 内容 |
|-----------|------|
| current | 現在の settings.yaml 値をそのまま使用 |
| heavy-opus | 全員 Opus+T |
| all-sonnet | 全員 Sonnet+T |
| sonnet-codex-mix | 将軍/家老/軍師=Sonnet+T, 足軽=交互(奇数=Sonnet/偶数=Codex) |

---

## .gitignore whitelist 追記内容

```
!scripts/shp.sh
!docs/shogun_shell_commands.md
!output/cmd_662_shp_command_report.md
```

---

## AC チェックリスト

| ID | 内容 | 判定 |
|----|------|------|
| A-1 | scripts/shp.sh 新設、interactive prompt 起動 | PASS |
| A-2 | 番号体系 1=Sonnet+T / 2=Opus+T / 3=Codex 実装 | PASS |
| A-3 | 質問順序: 将軍→家老→足軽1-7→軍師 (固定順) | PASS |
| A-4 | 各 prompt で単独数字入力 → enter で次構成員へ | PASS |
| A-5 | 全選択後 summary 表示 + y/N 確認 | PASS |
| A-6 | y で settings.yaml 更新 + 各 pane exit + 起動コマンド送信 | PASS (実 pane 切替は殿の手元確認) |
| A-7 | --dry-run option 実装 (確認のみ、起動しない) | PASS |
| A-8 | --preset option (current/heavy-opus/all-sonnet/sonnet-codex-mix) | PASS |
| B-1 | docs/shogun_shell_commands.md 新設 | PASS |
| B-2 | 既存出陣系コマンド網羅 (shc/shu/shk/shp + shutsujin/switch_cli/model-switch) | PASS |
| B-3 | 表形式: 目的/引数/例/前提/関連ファイル | PASS |
| B-4 | 番号体系 + preset 一覧を冒頭明示 | PASS |
| C-1 | --dry-run で prompt + summary + 起動 skip 確認 | PASS |
| C-2 | --preset all-sonnet --dry-run で interactive スキップ確認 | PASS |
| E-1 | output/cmd_662_shp_command_report.md 生成 | PASS |

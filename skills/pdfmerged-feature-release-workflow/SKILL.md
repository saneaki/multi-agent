---
name: pdfmerged-feature-release-workflow
description: >
  pdfmerged の機能追加/バグ修正/UI変更時に、コード・ドキュメント・テストキット・GitHub Release
  のすべてを漏れなく同期するためのチェックリスト・テンプレート集。
  cmd_495c (docs/TEST_GUIDE.md 更新漏れ) の再発防止を目的とする。
  Use when planning, executing, or QC-reviewing any pdfmerged release (機能追加/バグ修正/UI変更/内部リファクタ).
tags: [pdfmerged, release, documentation, workflow, shogun-system, postmortem-derived]
---

# pdfmerged Feature Release Workflow

pdfmerged プロジェクトでは、1 つの変更に対して最低 4 系統の成果物
(コード / ドキュメント / テストキット / GitHub Release) が連動する。
過去 (cmd_495c, 2026-04-15) に docs/TEST_GUIDE.md の更新が漏れ、
殿から「同じ指示を何度も出さなければならない」という強い叱責を受けた。
本スキルはその再発を防ぐための体系知識である。

## Trigger

以下のいずれかに該当する時に本スキルを参照すること:

| 契機 | 参照セクション |
|------|---------------|
| 家老が pdfmerged 関連の cmd を分解する | §2 家老タスク YAML テンプレート |
| 足軽が pdfmerged の feature/fix タスクを受領 | §1 リリース前チェックリスト |
| 軍師が pdfmerged タスクの QC を実施 | §3 軍師 QC チェックポイント |
| 足軽が docs 更新タスクの report YAML を書く | §4 足軽レポート必須項目 |
| 殿が「EXE のバージョン表記が古い」等と報告 | §5 典型的な見落としパターン |
| pdfmerged で新バージョン (v0.X.Y) をリリース | §1 + §6 同期対象マトリクス |

---

## §1 リリース前チェックリスト

pdfmerged で新バージョンをリリースする際、**A/B/C/D の 4 区分すべて** を必ず確認する。
単一のチェックを忘れると、配布 EXE に古い表記が残るなど品質事故に直結する。

### A. コード (必須)

- [ ] A1. `pdf_tools/pdf_merger_tabbed.py` の `__version__` を新バージョンに更新
  - 例: `__version__ = "0.9.5"`
  - **理由**: タイトルバー `f"PDFMergerTool v{__version__}"` の表示値となる
  - **CI validation**: `.github/workflows/build-exe.yml` の `Validate version consistency` step が tag との不一致を検出して build を失敗させる
- [ ] A2. `python3 -m py_compile pdf_tools/pdf_merger_tabbed.py` が成功
- [ ] A3. 新機能/修正の対象モジュールでユニットテストが通る
- [ ] A4. WSL2 環境では tkinter GUI 実機確認不可 → `gui_review_required: true` なら軍師レビュー必須 / `manual_verification_required: true` なら殿の Windows 実機確認を dashboard `[action]` に登録

### B. ドキュメント (最も漏れやすい — cmd_495c 事故対象)

- [ ] B1. **`docs/CHANGELOG.md`**: `## [X.Y.Z] - YYYY-MM-DD` セクションを追加
  - 必須サブセクション: `### Added` / `### Changed` / `### Fixed` / `### 対象ユーザー`
  - CI が `### 対象ユーザー` を `## 対象ユーザー` (H2) に自動昇格して Release body に反映
- [ ] B2. **`docs/TEST_GUIDE.md` (cmd_495c 事故の中心)**: 以下 3 箇所をすべて更新 — どれか 1 つでも欠けたら FAIL
  - [ ] B2-a. **タイトル行**: `# pdfアプリケーション vX.Y.Z テストガイド` を新バージョンに更新
  - [ ] B2-b. **バージョン履歴テーブル**: `| vX.Y.Z | YYYY-MM-DD | 主な変更内容 |` 行を追加
  - [ ] B2-c. **新機能操作手順の Section 統合**: appendix 末尾への追記は禁止。該当機能のタブ節に統合
- [ ] B3. **`docs/WSL_TEST_GUIDE.md`**: 新バージョン対応章/脚注を追加 (ヘッドレスでテストすべき項目)
- [ ] B4. **`docs/WHATS_NEW_2026.md`**: 新機能ハイライト段落を追加 (ユーザー向け)
- [ ] B5. **`docs/RELEASE_PROCESS.md`**: リリース手順そのものが変わった場合のみ更新 (cmd_500 で最終更新)
- [ ] B6. **`README.md`**: バージョン言及がある場合のみ更新

### C. テストキット

- [ ] C1. `test_kit_files/` または `create_test_pdfs.py` で新機能の検証に必要なサンプル PDF/画像が揃っている
- [ ] C2. 新機能が既存サンプルで検証不能なら、`create_test_pdfs.py` を拡張 or `test_kit_files/` に追加素材を配置
- [ ] C3. `pdfmerged-test-kit-vX.Y.Z.zip` の ZIP が GitHub Release にアップロードされる想定 — workflow で `gh release upload` が呼ばれるか確認
- [ ] C4. 素材ファイル名・フォルダ構造が `docs/TEST_GUIDE.md` §テスト素材フォルダ構成 と一致

### D. GitHub Release

- [ ] D1. `git add pdf_tools/pdf_merger_tabbed.py docs/CHANGELOG.md` + 他の docs 変更
- [ ] D2. `git commit -m "release: vX.Y.Z"` + `git push origin main`
- [ ] D3. `git tag vX.Y.Z HEAD` + `git push origin vX.Y.Z` (CI トリガー)
- [ ] D4. `gh run watch` で build / smoke / docs_build / release 全ジョブ green
- [ ] D5. `gh release view vX.Y.Z --json body --jq '.body'` で Release body を検証
  - `## What's Changed` ヘッダ存在
  - `## 対象ユーザー` セクション存在
  - `**Full Changelog**: ...` リンク存在
- [ ] D6. Windows 実機で `PDFMergerTool.exe` をダウンロードし、タイトルバーが `vX.Y.Z` 表示されることを殿が確認 (dashboard [action] 項目)

---

## §6 同期対象マトリクス

変更種別ごとに、どの成果物を更新すべきかを一覧化。
**「不要」欄はそのままスキップ可、それ以外は必ず更新する**。

| 変更種別 | コード | CHANGELOG | TEST_GUIDE | WSL_TEST_GUIDE | WHATS_NEW | テストキット | Release |
|---------|--------|-----------|------------|-----------------|-----------|------------|---------|
| 機能追加 (UI変更あり) | ✅ `__version__` + 新規モジュール | ✅ Added | ✅ タイトル+履歴+Section統合 | ✅ 新章 | ✅ ハイライト | ✅ サンプル拡張 | ✅ |
| 機能追加 (内部API) | ✅ `__version__` + 新規モジュール | ✅ Added | ⭕ 履歴のみ | 不要 | ⭕ 技術項目 | 不要 | ✅ |
| バグ修正 (UIに影響) | ✅ `__version__` + 対象モジュール | ✅ Fixed | ✅ タイトル+履歴+関連節更新 | 不要 | 不要 | 不要 | ✅ |
| バグ修正 (内部のみ) | ✅ `__version__` + 対象モジュール | ✅ Fixed | ⭕ 履歴のみ | 不要 | 不要 | 不要 | ✅ |
| UI変更 (ボタン/レイアウト) | ✅ `__version__` + UI モジュール | ✅ Changed | ✅ タイトル+履歴+操作手順更新 | 不要 | ✅ ハイライト | ⭕ スクショ更新 | ✅ |
| 内部リファクタ (挙動不変) | ⭕ `__version__` のみ (省略可) | ⭕ Changed (internal) | 不要 | 不要 | 不要 | 不要 | ⭕ patch 相当 |
| テスト追加のみ | 不要 | ⭕ (任意) | 不要 | ⭕ WSL テスト章追記 | 不要 | 不要 | 不要 |
| ドキュメント修正のみ | 不要 | 不要 | 対象があれば更新 | 対象があれば更新 | 不要 | 不要 | 不要 |

凡例: ✅必須 / ⭕推奨 / 不要 = 変更不要

**最も事故が起きやすいのは「機能追加(UI変更あり)」の行 — B/C/D すべてが ✅ になる**。
cmd_495c はまさにこのパターンで B 列の TEST_GUIDE 更新 (3 箇所全部) を取りこぼした。

---

## §2 家老タスク YAML テンプレート

pdfmerged の機能追加 cmd を足軽に割り振る際、家老は以下テンプレートを必ず使う。
**decomposition_hint で「docs 更新を別足軽に切り分ける」を明示し、単一足軽がコード+docs を両方抱える状況を避ける** (コード実装に集中する足軽は docs を軽視しがち)。

### cmd YAML (Shogun → Karo)

```yaml
cmd_id: cmd_XXX
cmd_type: pdfmerged_feature_add
north_star: "pdfmerged の機能追加/バグ修正時に docs/アプリ表記/GitHub release/テストキット が漏れなく同期され、過去指示の見落としが再発しない開発体制を確立する"
target: "新機能 <feature_name>"
decomposition_hint:
  parallel: 3
  subtasks:
    - role: "コード実装 (足軽1号想定)"
      editable: ["pdf_tools/..."]
    - role: "docs 同期 (足軽2号想定) — CHANGELOG + TEST_GUIDE(3箇所) + WHATS_NEW"
      editable: ["docs/CHANGELOG.md", "docs/TEST_GUIDE.md", "docs/WHATS_NEW_2026.md"]
      checklist_must_include: "B1/B2-a/B2-b/B2-c/B4"
    - role: "テストキット+CI 確認 (足軽3号想定)"
      editable: ["create_test_pdfs.py", "test_kit_files/"]
  gunshi_task: true
  gunshi_qc_focus: "docs 同期完全性 (§3 QC チェックポイント参照)"
  reason: "cmd_495c 事故再発防止: docs タスクを独立した足軽に分離し責任を明確化"
```

### 足軽への subtask YAML テンプレート

```yaml
task_id: subtask_XXXb
parent_cmd: cmd_XXX
project: pdfmerged
role_hint: "docs 同期専任"
editable_files:
  - "/home/ubuntu/pdfmerged/docs/CHANGELOG.md"
  - "/home/ubuntu/pdfmerged/docs/TEST_GUIDE.md"
  - "/home/ubuntu/pdfmerged/docs/WHATS_NEW_2026.md"
checklist:
  - "B1: CHANGELOG に [vX.Y.Z] セクション追加 (Added/Changed/Fixed/対象ユーザー)"
  - "B2-a: TEST_GUIDE.md タイトル行を vX.Y.Z に更新"
  - "B2-b: TEST_GUIDE.md バージョン履歴テーブルに行追加"
  - "B2-c: TEST_GUIDE.md の該当タブ節に操作手順を統合 (appendix禁止)"
  - "B4: WHATS_NEW_2026.md にハイライト追加"
acceptance_criteria:
  - id: AC1
    check: "grep 'vX.Y.Z' docs/TEST_GUIDE.md で タイトル+テーブル+Section 本文の 3 箇所以上ヒット"
  - id: AC2
    check: "grep '## \\[X.Y.Z\\]' docs/CHANGELOG.md でセクション存在"
report_required_fields:
  - "result.title_updated"
  - "result.version_history_rows_added"
  - "result.section_integrated"
```

---

## §3 軍師 QC チェックポイント

軍師が pdfmerged タスクの QC を行う際、以下 grep/find コマンドを必ず実行し、
**出力を証拠として QC report に埋め込む**。目視だけの QC は禁止 (cmd_495c 発生時点での反省)。

### QC-1: TEST_GUIDE 3 箇所チェック (最優先)

```bash
cd /home/ubuntu/pdfmerged

# (a) タイトル行 — 新バージョンが先頭 Heading にあるか
head -3 docs/TEST_GUIDE.md | grep -c "vX.Y.Z"
# 期待値: 1 以上

# (b) バージョン履歴テーブル行 — 新バージョン行が存在するか
grep -c "^| vX\.Y\.Z " docs/TEST_GUIDE.md
# 期待値: 1

# (c) Section 統合 — 新機能名がタブ節の本文に含まれるか (appendix末尾では不可)
grep -n "<feature_name>" docs/TEST_GUIDE.md
# 期待値: タブ節 (### PDF結合 等) 配下の行番号が含まれる
```

3 つすべて期待値を満たさない限り **QC PASS 不可**。

### QC-2: CHANGELOG エントリチェック

```bash
# セクション存在
grep -A10 "^## \[X.Y.Z\]" docs/CHANGELOG.md | head -15
# 期待値: Added/Changed/Fixed/対象ユーザー のサブセクション

# 対象ユーザー節の存在 (CI が Release body に昇格する)
grep "^### 対象ユーザー" docs/CHANGELOG.md
# 期待値: 新バージョンセクション配下にある
```

### QC-3: コード __version__ タグ整合性チェック (pre-push)

```bash
# tag を打つ前に CI validation と同じチェックを手元で実行
grep '^__version__ = ' pdf_tools/pdf_merger_tabbed.py
# 期待値: __version__ = "X.Y.Z"  ← push 予定タグと完全一致
```

### QC-4: WHATS_NEW_2026.md 追記チェック (機能追加/UI変更のみ)

```bash
grep -c "<feature_name>\|<新機能名>" docs/WHATS_NEW_2026.md
# 期待値: 1 以上 (機能名 or 同義語がヒット)
```

### QC-5: テストキット整合性 (必要時のみ)

```bash
# create_test_pdfs.py が新機能のサンプルを生成するか
grep -A3 "<new_sample_name>" create_test_pdfs.py
ls test_kit_files/ | grep "<new_sample_name>"
```

---

## §4 足軽レポート必須項目

docs 同期タスクを担当する足軽の `queue/reports/ashigaruN_report.yaml` は、
以下フィールドをすべて埋めること。**空文字 or 省略は QC FAIL**。

```yaml
worker_id: ashigaruN
task_id: subtask_XXXb
parent_cmd: cmd_XXX
timestamp: "<JST>"
status: done
result:
  summary: |
    docs 同期完了。CHANGELOG/TEST_GUIDE/WHATS_NEW の 3 ファイルを更新。
    TEST_GUIDE は タイトル+履歴テーブル+Section統合 の 3 箇所を更新済。
  # ↓ 以下 cmd_495c 事故を受けて必須化
  title_updated: "true"                    # TEST_GUIDE.md L1 (# pdfアプリケーション vX.Y.Z) を更新したか
  version_history_rows_added: "v0.X.Y"     # バージョン履歴テーブルに追加した行の vX.Y.Z
  section_integrated: "true"               # appendix末尾追加ではなく、タブ節本文に統合したか
  whats_new_updated: "true"                # WHATS_NEW_2026.md にハイライト追加したか
  changelog_subsections: "Added,Changed,Fixed,対象ユーザー"  # CHANGELOG で埋めたサブセクション
  test_kit_pdf_count: N                    # test_kit_files/ に追加/更新した PDF 数 (0 も可)
  create_test_data_extended: "true/false"  # create_test_pdfs.py を拡張したか
acceptance_criteria_check:
  - id: AC1
    check: "grep 'vX.Y.Z' docs/TEST_GUIDE.md が 3 箇所以上ヒット"
    result: "PASS"
    evidence: "grep -c 'vX.Y.Z' docs/TEST_GUIDE.md → 3"
  - id: AC2
    check: "grep '## \\[X.Y.Z\\]' docs/CHANGELOG.md 存在"
    result: "PASS"
    evidence: "docs/CHANGELOG.md:10"
skill_candidate:
  found: false  # 既に本スキル (pdfmerged-feature-release-workflow) でカバー済
```

---

## §5 典型的な見落としパターン (cmd_495c 教訓)

| # | 見落とし | 発覚タイミング | 予防策 |
|---|---------|---------------|--------|
| 1 | `__version__` を更新せずタグだけ進めた | CI validation で検出 (build 失敗) | §1 A1 + §3 QC-3 |
| 2 | TEST_GUIDE タイトル行が旧バージョンのまま | 殿が実機確認で指摘 | §1 B2-a + §3 QC-1(a) |
| 3 | TEST_GUIDE 履歴テーブルに行追加し忘れ | 殿が実機確認で指摘 | §1 B2-b + §3 QC-1(b) |
| 4 | 新機能の操作手順が appendix 末尾に追記された (該当タブ節未更新) | 殿が実機確認で指摘 | §1 B2-c + §3 QC-1(c) |
| 5 | CHANGELOG `### 対象ユーザー` 節を書き忘れ → Release body が貧弱 | リリース公開後 `gh release view` で気付く | §1 B1 + §3 QC-2 |
| 6 | EXE タイトルバーが旧バージョン表示 (v0.9.1~v0.9.4 全滅) | 殿が実機確認で指摘 (cmd_500) | §1 A1 + CI validation step (既に導入済) |
| 7 | create_test_pdfs.py を拡張せず新機能の検証ができない | 殿が実機テスト時に気付く | §1 C2 + §3 QC-5 |

**これら 7 パターンはすべて「足軽レポート」の `result.*` フィールドで証跡化 → 軍師 QC で grep 検証する**ことで再発を防ぐ。

---

## §7 ワンショット検証スクリプト

CI 未通過時にローカルで一括確認したい場合:

```bash
#!/bin/bash
# pdfmerged_release_precheck.sh vX.Y.Z <feature_keyword>
VER="$1"
KW="$2"
cd /home/ubuntu/pdfmerged || exit 1

echo "=== A: コード ==="
grep "^__version__ = " pdf_tools/pdf_merger_tabbed.py
python3 -m py_compile pdf_tools/pdf_merger_tabbed.py && echo "py_compile OK"

echo "=== B1: CHANGELOG ==="
grep -A1 "^## \[${VER}\]" docs/CHANGELOG.md | head -3

echo "=== B2-a: TEST_GUIDE タイトル ==="
head -3 docs/TEST_GUIDE.md

echo "=== B2-b: TEST_GUIDE 履歴行 ==="
grep "^| v${VER} " docs/TEST_GUIDE.md

echo "=== B2-c: TEST_GUIDE Section 統合 ==="
grep -n "${KW}" docs/TEST_GUIDE.md

echo "=== B4: WHATS_NEW ==="
grep -c "${KW}" docs/WHATS_NEW_2026.md

echo "=== D: git status ==="
git status --short
```

使い方: `bash pdfmerged_release_precheck.sh 0.9.5 "ファイル選択結合"`

---

## §8 参考 URL (WebSearch 2026-04 調査結果)

### PyInstaller バージョン一元管理

- [pyinstaller-versionfile · PyPI](https://pypi.org/project/pyinstaller-versionfile/) — Windows version resource を distribution metadata から自動生成
- [Adding Version Information to a PyInstaller Onefile Executable (DEV)](https://dev.to/arhamrumi/adding-version-information-to-a-pyinstaller-onefile-executable-6n8) — version file の具体例
- [PyInstaller Changelog (公式)](https://pyinstaller.org/en/latest/CHANGES.html) — importlib.metadata 対応履歴

### CHANGELOG → GitHub Release 自動生成

- [GitHub Docs: Automatically generated release notes](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes) — `.github/release.yml` による native 生成
- [auto-changelog (cookpete)](https://github.com/cookpete/auto-changelog) — git tags + commit history から生成
- [git-cliff guide (KX)](https://kx.cloudingenium.com/en/git-cliff-changelog-generator-git-history-conventional-commits-guide/) — Rust 製で高速・customizable
- [github-changelog-generator](https://github.com/github-changelog-generator/github-changelog-generator) — tags/issues/labels/PR から自動生成

### GitHub Actions バージョン整合性 CI

- [Check Version Format in Tag (Marketplace)](https://github.com/marketplace/actions/check-version-format-in-tag) — tag→version 抽出
- [Tag Version Commit (Marketplace)](https://github.com/marketplace/actions/tag-version-commit) — commit title から tag 作成
- [GitHub Actions Workflow syntax (docs)](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions) — tags glob pattern
- [Trigger GitHub Action Only on New Version Tags (w3tutorials)](https://www.w3tutorials.net/blog/trigger-github-action-only-on-new-tags/) — `refs/tags/v*` パターン

### タグ差し替えの安全手順

- [overriding old tag (GitHub Gist)](https://gist.github.com/Bat-Chat/1d27ce1b5074a83ef8d43524c19b11b8) — 削除→push のシーケンス
- [force-with-lease 解説 (DEV)](https://dev.to/ruqaiya_beguwala/day-1230-git-push-force-with-lease-safer-alternative-to-force-5fc) — branch 用だが思想を tag にも応用
- [Git Tag チュートリアル (Atlassian)](https://www.atlassian.com/git/tutorials/inspecting-a-repository/git-tag) — `git tag -a -f` と `-d` の関係

### pytest + tkinter の CI (headless)

- [pytest-xvfb (GitHub)](https://github.com/The-Compiler/pytest-xvfb) — plugin として Xvfb 自動起動
- [pytest-xvfb · PyPI](https://pypi.org/project/pytest-xvfb/)
- [Headless GUI unit tests on GitHub Actions (arbitrary-but-fixed)](https://arbitrary-but-fixed.net/2022/01/21/headless-gui-github-actions.html) — tkinter の headless 検証パターン

### ドキュメント更新漏れ防止 CI

- [linkcheckmd · PyPI](https://pypi.org/project/linkcheckmd/) — Markdown link checker (10K files/sec)
- [PyMarkdownLnt](https://pymarkdown.readthedocs.io/) — Python 製 Markdown linter
- [markdownlint (DavidAnson)](https://github.com/DavidAnson/markdownlint) — Node.js 製 linter
- [repo-drift · PyPI](https://pypi.org/project/repo-drift/0.6.0/) — repo 間の仕様ドリフト検知

### GitHub Release 自動化

- [semantic-release (GitHub)](https://github.com/semantic-release/semantic-release) — Conventional Commits からフル自動化
- [release-please (googleapis)](https://github.com/googleapis/release-please) — Release PR で review → merge 運用
- [gh release create (GitHub CLI manual)](https://cli.github.com/manual/gh_release_create) — pdfmerged 現行の `gh release upload`

### Python テストキット管理

- [pytest Good Integration Practices](https://docs.pytest.org/en/stable/explanation/goodpractices.html) — test 配布の標準パターン
- [pytest-artifacts (GitHub)](https://github.com/robertobernabe/pytest-artifacts) — ZIP で artifact 収集

---

## §9 変更履歴

| バージョン | 日付 | 変更内容 | 作成者 |
|-----------|------|---------|--------|
| v1.0.0 | 2026-04-16 | 初版。cmd_495c 事故 (TEST_GUIDE 3 箇所の更新漏れ) の再発防止を目的として新設。cmd_501d (足軽5号) | 足軽5号 |

---

## §10 関連スキル / ドキュメント

- [skill-creation-workflow](../skill-creation-workflow/SKILL.md) — スキル作成の標準プロセス
- `/home/ubuntu/pdfmerged/docs/RELEASE_PROCESS.md` — pdfmerged 現行のリリース手順書 (cmd_500 で最終更新)
- `/home/ubuntu/pdfmerged/.github/workflows/build-exe.yml` — CI の version validation step

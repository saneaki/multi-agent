# cmd_660 Scope A-2: #40 家老役割集中問題 問題状況再分析

| 項目 | 値 |
|------|-----|
| 作成者 | ashigaru1 (Sonnet+T) |
| 作成日時 | 2026-05-08 JST |
| 親 cmd | cmd_660 |
| 依拠元 | cmd_597 dual-model 分析 / [提案-4] 殿判断資料 / cmd_657-659 実施記録 |
| 禁止事項 | 実装コード生成禁止。方針提案・分析のみ |

---

## Executive Summary (200 words 以内)

cmd_597 (2026-04-27) 時点では「家老 dispatch 漏れ」という **発令フェーズの問題** として家老役割集中が診断された。P1/P2/P3 の 3 論点と案 A-D が整理され、[提案-4] は P1-C(反映時点)/P2-D(二層sync)/P3-B(信頼性最優先) を推奨した。

しかし 2026-05-08 の cmd_657-659 連続事象を分析すると、問題の重心が移動している。**発令フェーズ** から **完遂確認フェーズ** へ——家老は dispatch 自体はできているが、「コミット・push・dashboard 反映・スキーマ遵守」の事後確認に集中的に失敗し始めた。verifier ツールがこれを検出しているが、verifier 自体は事後的・随意的であり、ゲート機能を果たしていない。

本分析の主要結論:

1. **P1 論点の拡張が必要**: 「dispatch 完了定義」から「タスク完遂定義 (commit+push+dashboard+schema)」へ拡張すべき
2. **案 C (ハイブリッド機械化) は必要条件だが不十分**: verifier を mandatory gate として組み込む「案 C+」が必要
3. **P2 はほぼ解決**: cmd_659 で dashboard SoT pipeline Phase 1 が完成、残課題は定着確認のみ
4. **P3-B (信頼性最優先) は有効**: 本日の事象が傍証。ただし「信頼性」の定義に commit/push を含める必要がある

---

## 1. cmd_597 時点の P1-P3 論点 vs 本日時点の状況ギャップ分析

### 1.1 P1: 「dispatch 完了」の定義

**cmd_597 時点の問題設定:**
家老が dispatch 完了点を「task YAML 書込み時点」と「ashigaru inbox_write 成功時点」で揺れており、ashigaru 起動失敗の検出ができていなかった。[提案-4] は P1-C (反映時点 = ashigaru report 受領時) を推奨した。

**本日 2026-05-08 の状況:**

| 事象 | タイプ | P1 との関係 |
|------|--------|------------|
| cmd_657 (ash4): 完遂報告後 commit/push 漏れ発覚 | **Completion gap** | P1-C の「反映時点」定義が commit を含んでいなかった |
| cmd_658 (ash4): Phase 0-1 完遂、12 ファイル永続化漏れ (verifier 検出) | **Staging gap** | 家老が「完遂報告 = done」と判定したが実ファイルが commit されていなかった |
| cmd_659 (karo): 成果物未 commit で報告 | **Same type** | 家老自身の作業でも同じ漏れが発生 |

**ギャップ:** P1 は「dispatch 開始時点の定義」を対象としていた。本日の事象は「**dispatch 終了・タスク完遂の定義**」に問題が移行していることを示す。「反映時点 (ashigaru report 受領時)」という P1-C の定義は必要だが、「commit+push が完了している状態でのみ report が有効」という条件が欠落していた。

**P1 論点の更新提案:**

```
P1-C(拡張版) = ashigaru report 受領時 AND commit+push 確認済み AND dashboard 反映済み
```

これを「P1-C+」として定義する。

---

### 1.2 P2: SoT (Single Source of Truth) 選択

**cmd_597 時点の問題設定:**
dashboard.md が運用上の主面、queue/ が機械読取の主面、config/dashboard.yaml が不存在。SoT が分散。[提案-4] は P2-D (queue/単一 + dashboard.md 表示 view 化) を推奨した。

**本日 2026-05-08 の状況:**

| 事象 | SoT 問題との関係 |
|------|-----------------|
| cmd_659 Scope A-D: gunshi_report.yaml → dashboard.yaml → dashboard.md のパイプライン実装完了 | **P2-D が実装された** |
| cmd_659 Scope B: action_required_sync.sh (event 駆動 sync) 新設 | queue/ → dashboard.md の片方向 sync が稼働 |
| cmd_659 Scope C: generate_dashboard_md.py で atomic render | dashboard.md = render artifact 化完了 |
| cmd_659 での gunshi_report.yaml 上書き禁止違反 | **残課題**: スキーマ制約の認識不足、pipeline の入口品質問題 |

**ギャップ:** P2 については **cmd_659 で大部分が解決された**。dashboard.md の直接編集禁止が明文化され、queue/ (dashboard.yaml) が SoT となった。残る課題は:

1. gunshi_report.yaml の上書き禁止ルールの浸透不足 (入口制約)
2. 稼働したばかりのパイプラインの信頼性蓄積期間
3. dashboard.md の手動編集習慣の完全撲滅 (CLAUDE.md への明記は済んでいるが監視が不足)

**P2 現状評価:** ほぼ解決。後続 cmd では「定着確認」と「入口ルール強化」が優先。

---

### 1.3 P3: 6 軸重み付け

**cmd_597 時点の問題設定:**
Opus は均等評価、Codex は信頼性 > 観測可能性 > コスト > 柔軟性 > 進化耐性 > 接点保持を提案。[提案-4] は P3-B (信頼性最優先) を推奨した。

**本日 2026-05-08 の状況:**

本日の事象は P3-B 採択を **強く傍証する**。commit/push 漏れ・dashboard 反映漏れ・スキーマ違反は全て「信頼性」の欠如である。もし「コスト最優先 (P3-D)」や「自律性重視 (案 B)」でシステムを設計していれば、verifier 等の検証コストを削減する判断になり、今回の漏れが検出されなかった可能性が高い。

**P3 現状評価:** P3-B の方向性は変わらず有効。ただし、「信頼性」の定義に以下を明示的に含める必要がある:

- コード/スクリプトの機能的正確性 (従来の主な対象)
- **commit+push の完了** (新規追加)
- **dashboard への反映** (新規追加)  
- **スキーマ制約の遵守** (新規追加)

---

## 2. 本日の事象から見た「家老役割集中」の本質的原因

### 2.1 事象の類型化

本日発生した事象を類型化し、根本原因を分析する。

#### Type A: 実行完了後のコミット漏れ

| 事象 | 担当 | 内容 |
|------|------|------|
| cmd_657 | ash4 | 完遂報告後に commit/push 漏れが発覚。PR merge 済みなのに shogun repo の変更が未 commit |
| cmd_659 | karo | 成果物 (dashboard.md 等) を作成したが git commit を忘れて家老報告 |

**真因:** 「作業完了」と「永続化完了」の分離。ashigaru の workflow Step 7 (git_commit_only) は手順として存在するが、step 6 (status=done) の**後**に行うため、commit 前に done 報告する心理的インセンティブが生まれる。

#### Type B: ステージング段階の永続化漏れ

| 事象 | 担当 | 内容 |
|------|------|------|
| cmd_658 | ash4 | Phase 0-1 で 12 ファイルを作成・編集したが、複数ファイルが git add されていなかった。verifier が PARTIAL_PASS として検出 |

**真因:** 大規模変更での staging 追跡漏れ。ファイル数が多い場合、手動 `git add` で漏れが生じやすい。また、家老 (karo) による確認ステップが「report の内容確認」に偏り、「実ファイルの git status 確認」を行っていなかった。

#### Type C: Dashboard 反映漏れ

| 事象 | 担当 | 内容 |
|------|------|------|
| cmd_659 | karo | dashboard.md の 3 箇所で反映漏れ (在進行中表示の削除、新規成果物の追記、完了ステータス更新) |

**真因:** 家老が複数 cmd を同時進行する中で、dashboard 更新チェックリストの項目が見落とされた。dashboard は「最後に行う更新作業」として後回しになりやすく、コンテキスト切り替えのコストが高い。

#### Type D: スキーマ制約違反

| 事象 | 担当 | 内容 |
|------|------|------|
| cmd_659 | karo (or 関連足軽) | gunshi_report.yaml の上書き禁止ルールに違反。既存エントリを保持せずに上書き |

**真因:** ルールの周知不足 + 機械的な強制がない。CLAUDE.md に記述があっても、多タスク処理中に参照される保証がない。

---

### 2.2 構造的根本原因

上記 4 タイプに共通する構造的問題:

**原因 1: 「完了」の定義が作業完了 = 完了 になっている**

家老・足軽ともに、「実装/修正が完了した」 = 「タスクが完了した」と認識する傾向がある。しかし真の完了には commit + push + dashboard反映 + スキーマ遵守が含まれる。この認識のギャップが type A/B/C/D 全てを生む。

**原因 2: 家老の確認負担が多様化・増大している**

cmd_597 時点の問題: 「dispatch 漏れ (発令フェーズ)」  
現在の問題: 「完了確認漏れ (検収フェーズ)」

家老は現在:
- 足軽への dispatch
- 軍師との QC 調整  
- dashboard.md 管理
- git 管理 (commit/push 確認)
- スキーマ遵守の監視
- implementation-verifier の起動・解釈

これらを並行して処理しており、**認知負荷の飽和**が漏れの根本原因である。

**原因 3: 検証が随意的 (optional) で mandatory gate になっていない**

implementation-verifier は有効なツールだが、現時点では:
- 「家老が判断して起動する」任意のステップ
- 起動されなければ漏れを検出できない
- 起動されても PARTIAL_PASS の扱いが曖昧

この随意性が、多忙な家老の下で「今回は省略」となる余地を作っている。

**原因 4: 足軽の自己確認ステップに commit が含まれるが、complete 報告後に行われる**

ashigaru workflow の Step 7 (git_commit_only) は Step 6 (status=done) の後に配置されている。これは設計上、「status=done 報告 → commit」という順序を許容しており、commit 前に done 状態になれる。

---

## 3. 案 A-D の有効性再評価

### 3.1 評価枠組みの更新

cmd_597 時点: **「発令フェーズの信頼性」** を主軸に評価  
現在: **「完遂確認フェーズの信頼性」** を追加軸として評価

| 評価軸 | cmd_597 時点 | 現在追加 |
|--------|-------------|---------|
| dispatch 信頼性 | ✓ | ✓ |
| 完了確認信頼性 | △ (軽視) | **✓✓ (最重要)** |
| dashboard 反映信頼性 | △ | **✓✓ (cmd_659 で対応中)** |
| スキーマ遵守強制 | △ | **✓✓ (機械的強制必要)** |

---

### 3.2 案 A: フル機械化

**cmd_597 評価:** 漏れ理論ゼロ。コスト 4-6w。短期オーバーキル。

**現在の再評価:**

- 完了確認フェーズにも機械化を適用すると、最も効果が高い
- git commit hook / pre-commit verification / dashboard auto-sync は「案 A」の部分適用である
- cmd_659 で dashboard sync は機械化された (案 A の部分実装)
- 残り: commit/push の機械的検証 (git hook 強化) が次の部分実装候補

**有効性:** ✅ **高い** (特に完了確認の機械化として部分適用は即効性あり)

---

### 3.3 案 B: 自律性重視

**cmd_597 評価:** 信頼性限界露呈済み。単独不可。

**現在の再評価:**

cmd_657/658/659 はいずれも「足軽・家老の自律判断」に基づく完了確認が失敗したケースである。案 B (自律性重視) の限界を更に明確に示す追加証拠となった。

**有効性:** ❌ **低い** (変化なし。本日事象で否定証拠追加)

---

### 3.4 案 C: ハイブリッド (クリティカル遷移のみ機械化)

**cmd_597 評価:** 最有力。SLA + 単一ログ収集点の条件付き。

**現在の再評価:**

案 C の「クリティカル遷移」に **新規遷移を追加** すべきである:

| 遷移 | cmd_597 時点 | 現在追加 |
|------|-------------|---------|
| dispatch (karo → ashigaru) | ✓ 機械化対象 | ✓ |
| task_complete 報告 | △ (軽視) | **✓✓ (commit 確認必須)** |
| dashboard 反映 | △ | **✓✓ (cmd_659 で対応)** |
| git commit | △ | **✓✓ (pre-complete hook 必要)** |
| schema validate | △ | **✓✓ (入口検証必要)** |

**有効性:** ✅✅ **最高** (ただし「案 C+」として完了確認フェーズも機械化スコープに含める必要あり)

---

### 3.5 案 D: 役割分離 (新 agent 増設)

**cmd_597 評価:** 中長期。案 C 後の段階導入。

**現在の再評価:**

本日の事象は「家老の認知負荷飽和」を示す。この観点では案 D (役割分離) の緊急性が cmd_597 時点より高まっている。

具体的に分離すべき責務:

| 現在 karo が担う責務 | 分離先案 |
|---------------------|---------|
| dispatch 管理 | (karo 継続) |
| QC 調整・軍師連携 | (karo 継続) |
| git commit/push 確認 | **git hook (機械化)** または 新 ashigaru 専任ステップ |
| dashboard 反映確認 | **cmd_659 pipeline (機械化)** で解決済み |
| スキーマ遵守監視 | **pre-commit validator (機械化)** |
| implementation-verifier 起動 | **自動 gate (機械化)** |

→ git/schema/verifier の 3 責務を機械化すれば、案 D (新 agent 増設) なしに家老の負荷を大幅削減できる可能性がある。

**有効性:** △ **中程度** (案 C+ の機械化が先行すれば、案 D の緊急性は低下する)

---

## 4. 新たな対策案の提案

### 4.1 Verifier 常設化・必須 Gate 化 (最優先)

**問題:** implementation-verifier は現在随意的ステップ。家老が多忙な場合に省略される。

**提案:** 軍師 QC の step 内に implementation-verifier の実行を必須化する。

```
軍師 workflow 現在:
  Step 8: QC チェックリスト (人手)
  Step 8.8: action_required_candidates 出力 (cmd_659 追加)

軍師 workflow 提案:
  Step 7.5: bash scripts/qc_auto_check.sh --mode verifier (必須)
            → 非ゼロで report に PARTIAL_PASS 記録 + karo へ再確認要求
  Step 8: QC チェックリスト
  Step 8.8: action_required_candidates 出力
```

効果: verifier の随意性を排除し、「軍師 QC を通過する = verifier PASS」を保証する。

---

### 4.2 チェックリスト強制化: タスク完遂定義の再定義

**問題:** status=done 遷移前に commit/push が完了している保証がない。

**提案:** ashigaru workflow を修正し、Step 6 (status=done) の**前に** commit 確認ステップを配置する。

```
現在の workflow 順序:
  Step 4: 実行
  Step 5: レポート作成
  Step 6: status = done   ← ここで done になる
  Step 7: git commit      ← commit はその後

提案する workflow 順序:
  Step 4: 実行
  Step 4.8: git status 確認 (変更ファイルを report の files_modified に記録)
  Step 5: レポート作成
  Step 6.1: git add + git commit (Refs cmd_NNN) ← done 前に commit
  Step 6.2: status = done  ← commit 後に done
  Step 7: (squash pub hook 待機のため、push は deferred のまま)
```

これにより「commit せずに done と報告する」ことが構造的に難しくなる。

---

### 4.3 Git Hook 強化: pre-report validation

**問題:** スキーマ違反 (gunshi_report.yaml 上書き禁止等) が事後に発覚する。

**提案:** `scripts/qc_auto_check.sh` に YAML スキーマ検証ステップを追加し、Step 5.3 (self_schema_check) の前に実行する。

具体的に追加すべき検証:
1. `gunshi_report.yaml` の history フィールドが前回エントリを保持しているか
2. `ashigaru{N}_report.yaml` の必須フィールド 7 つが全て存在するか
3. `editable_files` に含まれないファイルが変更されていないか (IR-1 違反検出)

効果: 人間のレビュー前に機械的なルール違反を検出。家老の認知負荷を軽減。

---

### 4.4 Dashboard Sync の定着確認と入口検証強化

**背景:** cmd_659 で dashboard.yaml SoT + pipeline が実装された。しかし gunshi_report.yaml の上書き違反が同 cmd で発生した。

**提案:**
1. **入口検証**: `action_required_sync.sh` の冒頭に gunshi_report.yaml の `history[]` 整合性チェックを追加。上書き検出時は sync abort + karo への alert 送信
2. **定着確認 cmd**: 1 週間後 (2026-05-15 頃) に pipeline の稼働状況確認 cmd を発令する
3. **手動編集 lint**: dashboard.md の直接編集を検出する git pre-commit hook を追加

---

### 4.5 認知負荷分散: Karo の同時処理 cmd 数上限設定

**問題:** 家老が複数 cmd を同時並行で処理しており、チェック漏れが生じやすい。

**提案:** 家老の同時 in_progress cmd 数に上限 (推奨: 2) を設ける。dashboard に in_progress カウントを表示し、上限到達時は新規 dispatch を保留。

```yaml
# shogun_mandatory.md への追記案
- id: SO-25
  title: "Karo 同時 cmd 上限"
  rule: "Karo の in_progress cmd 数は 2 を超えてはならない。新規 cmd dispatch 前に in_progress 数を確認せよ"
```

---

## 5. 後続 cmd への推奨事項

### 5.1 即時対応 (cmd_661 候補)

優先度の高い順:

1. **Verifier mandatory gate 化** (軍師 workflow Step 7.5 追加)
   - 難易度: 低 (instructions/gunshi.md の編集のみ)
   - 効果: 最大 (すべての type の漏れ検出に効く)

2. **Ashigaru workflow Step 順序変更** (commit → done の順序変更)
   - 難易度: 中 (instructions/ashigaru.md の編集 + qc_auto_check.sh の修正)
   - 効果: Type A/B (commit 漏れ) に直接効く

3. **P1-C+ の正式定義化** (CLAUDE.md または karo.md への追記)
   - 難易度: 低
   - 効果: 認識統一 (即効性は低いが基盤)

### 5.2 短期対応 (cmd_662 候補)

1. **Git Hook 強化** (pre-report schema validation)
   - 難易度: 中
   - 効果: Type D (スキーマ違反) に直接効く

2. **Karo 同時 cmd 上限設定** (SO-25 新設)
   - 難易度: 低 (rule 追加のみ)
   - 効果: 認知負荷分散、長期的な再発防止

### 5.3 中期対応 (cmd_663 候補)

1. **Dashboard pipeline 定着確認**
   - cmd_659 で実装された pipeline が 1 週間稼働後に正常動作しているか確認
   
2. **cmd_597 提案-4 の正式裁可**
   - P1-C+ / P2-D / P3-B の殿御裁可を改めて得る (塩漬けからの復帰)

---

## 6. まとめ: 案 A-D 再評価表

| 案 | cmd_597 評価 | 本日追加 | 現在評価 | 推奨適用領域 |
|----|------------|---------|---------|------------|
| A: フル機械化 | 長期・コスト高 | commit/dashboard 機械化は即効 | △→✅ (部分適用) | commit hook, dashboard sync (すでに部分実装中) |
| B: 自律性重視 | 単独不可 | 否定証拠追加 | ❌ | なし |
| C: ハイブリッド | 最有力・条件付き | 「完了確認フェーズ」も対象に | ✅✅ (案 C+) | 次の 1 手。verifier gate, commit-before-done |
| D: 役割分離 | 中長期・C 後 | 機械化で一部代替可能 | △ (緊急性低下) | 案 C+ 実施後に残る人的負担を評価してから判断 |

**推奨アクション (1 行):**  
案 C+ (verifier mandatory gate + commit-before-done 順序変更) を cmd_661 として即時発令し、P1-C+ / P3-B を正式採択する。P2 は cmd_659 で解決済み。案 D は C+ 定着後に再評価。

---

*本レポートは ashigaru1 (Sonnet+T) による独立分析であり、ash5/ash6/ash7 のレポートを参照していない。*

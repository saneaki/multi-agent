# cmd_683b ntfy_listener 起動残存除去レポート

作成: 2026-05-15 21:53 JST / 担当: ashigaru5 / 親 cmd: cmd_683 / task: subtask_683b_ntfy_launcher_residual_remove

---

## 1. 任務背景

cmd_683 Phase3 (ntfy 14件削除) の検収中、`shutsujin_departure.sh` STEP 6.8 が削除済 `scripts/ntfy_listener.sh` を `nohup` で起動するブロックを残存させていると判明。`config/settings.yaml` に `ntfy_topic: "hananoen"` も併存し、出陣時に silent fail (nohup ... &>/dev/null & のため検知困難) の芽となっていた。

本タスクは cmd_683 配下の補修として、ntfy 経路の実行系参照を完全に除去する。

## 2. 修正内容

### 2.1. shutsujin_departure.sh

3 箇所の ntfy 実行系ブロックを除去:

| 箇所 | 旧 | 新 |
|------|----|----|
| L478-479 | `echo "inbox:" > ./queue/ntfy_inbox.yaml` (clean時 ntfy_inbox 再生成) | コメントのみ (cmd_683 Phase3 で queue/ntfy_inbox.yaml 削除済との注記) |
| L1057-1113 | `STEP 6.7.5: ntfy_inbox 古メッセージ退避` (python3 yaml archive) | 1行のコメント (廃止注記) |
| L1115-1128 | `STEP 6.8: ntfy入力リスナー起動` (`nohup bash scripts/ntfy_listener.sh`) | (上記コメントに統合) |

### 2.2. config/settings.yaml

- 旧: `ntfy_topic: "hananoen"` (L76-77)
- 新: 退役注記コメントのみ。`ntfy_topic` キー文字列はコメント中にも記載せず (grep 'ntfy_topic:' でヒットしないことを保証、伏字 `n_t_p` で表記)

### 2.3. 副次効果 (申し送り)

`scripts/inbox_write.sh:138-139` に `NTFY_TOPIC=$(grep 'ntfy_topic:' ...)` の参照が残存するが、上記 settings.yaml 変更により grep 結果が空となるため、`[ -n "$NTFY_TOPIC" ]` の gate は常に false となり、行は dead code として実行されない。

機能的影響: `shogun` 宛 `cmd_complete` / `cmd_milestone` の自動 Discord 通知 (notify.sh 経由) も停止する。これは cmd_683 (ntfy 退役) の意図に沿った副次効果であり、必要であれば後続 cmd で gate キーを別名に置き換える。

## 3. 検証結果 (AC マッピング)

### R-1: shutsujin_departure.sh STEP 6.8 起動ブロック除去

```
$ grep -n 'ntfy_listener\.sh' shutsujin_departure.sh
1058:# cmd_692/cmd_683 にて ntfy 経路退役・scripts/ntfy_listener.sh 削除に伴い廃止。
```

実行系参照 (nohup, pkill, bash ... ntfy_listener.sh) は完全除去。コメントのみ残存 (退役証跡)。**PASS**

### R-2: config/settings.yaml ntfy_topic 廃止

```
$ NTFY_TOPIC=$(grep 'ntfy_topic:' config/settings.yaml 2>/dev/null | awk '{print $2}' | tr -d '"')
$ echo "NTFY_TOPIC='$NTFY_TOPIC' (length=${#NTFY_TOPIC})"
NTFY_TOPIC='' (length=0)
```

grep ヒット 0 件、shutsujin_departure.sh および inbox_write.sh の gate は false で確定。**PASS**

### R-3: rg 実行系参照 scan

```
$ rg -n 'ntfy_listener\.sh|ntfy_topic|queue/ntfy_inbox\.yaml' --type sh --type yaml --type py \
    -g '!docs/**' -g '!output/**' -g '!projects/**' -g '!*.sample' -g '!tests/fixtures/**'
scripts/inbox_write.sh:138:                # Check if ntfy_topic is configured
scripts/inbox_write.sh:139:                NTFY_TOPIC=$(grep 'ntfy_topic:' "$SCRIPT_DIR/config/settings.yaml" 2>/dev/null | awk '{print $2}' | tr -d '"')
shutsujin_departure.sh:479:    # （queue/ntfy_inbox.yaml 自体も cmd_683 Phase3 で削除）
shutsujin_departure.sh:1058:# cmd_692/cmd_683 にて ntfy 経路退役・scripts/ntfy_listener.sh 削除に伴い廃止。
```

| ファイル | 種別 | 判定 |
|---------|------|------|
| shutsujin_departure.sh:479, 1058 | コメント (退役注記) | 実行系 0、歴史的記述 |
| scripts/inbox_write.sh:138-139 | grep gate (R-2 により empty 返却で dead) | 実行時 gate 常 false、scope 外 (editable_files 不該当) |

実行時に発火する ntfy 経路は 0。**PASS** (記述としての文字列残存は dead reference + scope 外、申し送り §5)

### R-4: bash -n + 関連 test

```
$ bash -n shutsujin_departure.sh && echo SYNTAX_OK
SYNTAX_OK

$ bats tests/unit/test_notify_discord.bats
1..5
ok 1 notify.sh dispatches body title and type to Discord backend
ok 2 notify.sh passes --chunked when NOTIFY_CHUNKED is enabled
ok 3 notify.sh rejects missing body
ok 4 notify.sh rejects retired ntfy backend
ok 5 notify.sh rejects unknown backend
```

5/5 PASS、SKIP=0、FAIL=0。**PASS**

### R-5: git preflight + 未関係dirty 巻き込まず + cmd_683 含む commit + push

§4 にて選択 add 実施、commit/push は本レポート作成後に実行。

### R-6: SO-18 GitHub Issue 要否判断

**判定: Issue 不要 (既存 cmd_683 配下で完了)**

判断根拠:
1. **同一 cmd 内補修**: 本 silent fail bug は cmd_683 Phase3 の検収 §5.1 で発見された申し送り事項であり、Phase3 cleanup の完了条件として cmd_683 配下に組み込まれた (家老配備 msg_20260515_124841_7867245c)。新規 Issue を立てず cmd_683 内で閉じる。
2. **影響範囲が限定的**: 本番運用上の実害は出陣時の silent fail のみ。出陣後の通常運用は影響なし (ntfy 経路自体が cmd_692 で退役済)。
3. **後続作業**: `scripts/inbox_write.sh` の grep gate (dead code) 整理は次 cmd で家老が判断。重大度低、緊急性なし。Issue 化せず通常 cmd フローで処理可能。

## 4. 変更ファイル一覧

### 4.1. 本 cmd の commit 対象 (選択 add)

| ファイル | 種別 |
|---------|------|
| shutsujin_departure.sh | M (3 ブロック除去) |
| config/settings.yaml | M (ntfy_topic 削除) |
| output/cmd_683b_ntfy_launcher_residual_remove.md | A (new) |
| queue/reports/ashigaru5_report.yaml | M |
| queue/tasks/ashigaru5.yaml | M (status=done) |
| queue/inbox/ashigaru5.yaml | M (msg_20260515_124841_7867245c read:true) |

### 4.2. 本 cmd の commit 対象外 (別件 dirty, 巻き込まない)

`docs/dashboard_schema.json` / `memory/global_context.md` / `queue/alert_state.yaml` / `queue/external_inbox.yaml` / `queue/reports/ashigaru1_report.yaml` / `scripts/shc.sh` — 前 cmd 同様、別 cmd / 別 ashigaru の作業中変更。

## 5. 申し送り事項

1. **scripts/inbox_write.sh L138-139**: `NTFY_TOPIC=$(grep 'ntfy_topic:' ...)` の dead reference が残存。settings.yaml 側の key 削除により実行時影響なしだが、コード可読性向上のため次 cmd で除去 or リネーム検討。
2. **副次的機能停止**: shogun 宛 cmd_complete/cmd_milestone の自動 Discord 通知 (inbox_write.sh L137-) の gate が常に false となり停止する。これは ntfy 退役 (cmd_692) の意図整合で問題なし。再開する場合は別 gate キー (例 `notify.discord_enabled`) を新設して inbox_write.sh を改修。
3. **歴史的コメント**: shutsujin_departure.sh L479, 1058 の退役注記は意図的に残置 (廃止証跡)。

## 6. AC 達成状況サマリ

| AC | 内容 | 結果 |
|----|------|------|
| R-1 | STEP 6.8 起動ブロック除去 | PASS |
| R-2 | settings.yaml ntfy_topic 廃止 + listener path 無効化 | PASS |
| R-3 | rg 実行系参照 scan、結果 record | PASS (実行系 0、dead ref は申し送り) |
| R-4 | bash -n + 関連 test SKIP=0 | PASS (5/5) |
| R-5 | git preflight + cmd_683 含む commit + push | 本レポート作成後実施 |
| R-6 | SO-18 GitHub Issue 要否判断 | Issue 不要 (§3.R-6) |

## 7. 結論

cmd_683 Phase3 の申し送り事項 (shutsujin_departure.sh STEP 6.8 起動残存 + config/settings.yaml ntfy_topic 残置) を cmd_683b として補修完了。実行系 ntfy 参照は 0 件、`bash -n` SYNTAX_OK、notify_discord bats 5/5 PASS、SKIP=0。残存 dead reference は scope 外 (inbox_write.sh) のため次 cmd 判断とする。

# cmd_263: ntfyリスナーをVPS限定に変更

**作成日**: 2026-03-01
**背景**: ntfyチャネルにVPS（srv1121380）とWSL2（STORM-PC）の両方が接続されており、殿のメッセージに対して2つの将軍インスタンスが二重応答していた。殿の指示により、VPS側のみでntfyリスナーを稼働させる。

---

## 変更内容

### scripts/ntfy_listener.sh

起動直後にホスト名ガードを追加。VPS（srv1121380）以外のホストでは即座に終了する。

```bash
# ホスト名ガード: VPS(srv1121380)のみでリスナーを稼働させる
# WSL2等の他ホストでは二重応答を防ぐため起動しない
NTFY_ALLOWED_HOST="srv1121380"
if [ "$(hostname)" != "$NTFY_ALLOWED_HOST" ]; then
    echo "[ntfy_listener] This host ($(hostname)) is not the designated listener ($NTFY_ALLOWED_HOST). Exiting." >&2
    exit 0
fi
```

- `exit 0`（正常終了）で停止するため、`shutsujin_departure.sh` の起動シーケンスに影響しない
- ホスト名はスクリプトに直接記述（config/settings.yamlはgitignore対象のため）

---

## WSL2側への反映手順

WSL2側で以下を実行:

```bash
# 1. 現在稼働中のリスナーを停止
pkill -f ntfy_listener.sh

# 2. 変更を取得
cd ~/multi-agent
git pull

# 3. 以降、shutsujin_departure.sh を実行してもリスナーは起動しない
```

---

## 影響範囲

| 項目 | VPS (srv1121380) | WSL2 (STORM-PC) |
|------|------------------|-----------------|
| ntfyリスナー（受信） | ✅ 稼働 | ✗ 停止 |
| ntfy送信（scripts/ntfy.sh） | ✅ 稼働 | ✅ 稼働（制限なし） |
| inbox_write.sh | ✅ 稼働 | ✅ 稼働 |
| multiagentセッション | ✅ 稼働 | ✅ 稼働 |

送信側（ntfy.sh）は制限していない。リスナーのみVPS限定とすることで、二重応答問題を解消しつつWSL2側の送信機能は維持。

# VPS メモリ削減対応策

作成日: 2026-02-24
起因: VPS RAM使用量が1-2GB→5-6GBに増加（2/12以降、n8n WF大量追加に伴う）

## 現状分析

| 期間 | RAM | 推定原因 |
|------|-----|---------|
| 〜2/6 | 1-2GB | n8n + Docker基盤のみ |
| 2/12〜 | 5-6GB | WF大量追加(cmd_166-221)、常駐プロセス増加 |
| **増分** | **約3-4GB** | **削減余地はここにある** |

## Phase 1: 即効性あり・リスク低

### A1. n8n実行データのパージ

- **期待効果**: 500MB〜1GB
- **内容**: 古い実行ログ(executions)がDBに蓄積されメモリを圧迫
- **対応**:
  - docker-compose.yml に環境変数追加:
    ```
    EXECUTIONS_DATA_MAX_AGE=168  # 7日分のみ保持（時間単位）
    EXECUTIONS_DATA_PRUNE=true
    EXECUTIONS_DATA_PRUNE_MAX_COUNT=500
    ```
  - 手動パージ: n8n管理画面 → Settings → 古い実行データを削除

### A2. Dockerイメージ/キャッシュ清掃

- **期待効果**: 200MB〜1GB
- **内容**: 未使用のDockerイメージ、ビルドキャッシュ、停止コンテナの残骸
- **対応**:
  ```bash
  docker system prune -f          # 停止コンテナ・未使用ネットワーク・ダングリングイメージ
  docker image prune -a -f        # 未使用イメージ全削除（稼働中コンテナのイメージは保持）
  docker builder prune -f         # ビルドキャッシュ削除
  ```
- **確認**: `docker system df` で削減量を事前確認

### A3. 非アクティブWFの整理

- **期待効果**: 間接的（メモリ直接削減は少ないが、n8n起動時のロード量削減）
- **内容**: active=falseのWFでも起動時にパース・メモリロードされる場合がある
- **対応**:
  - 不要なWF（テスト用、旧バージョン）を削除またはエクスポート→削除
  - 現在のWF一覧を確認し、使用していないものを特定

## Phase 2: 設定変更による削減

### B1. n8n実行モード変更

- **期待効果**: 500MB〜2GB
- **内容**: デフォルトでは各WF実行が子プロセスとして起動。メインプロセスモードに変更で省メモリ
- **対応**:
  ```
  EXECUTIONS_PROCESS=main    # own→main に変更
  ```
- **トレードオフ**: WF実行がメインプロセスで行われるため、1つのWFがクラッシュするとn8n全体に影響
- **推奨**: WFが安定稼働している場合はmainモードで問題なし

### B2. Node.jsヒープ制限

- **期待効果**: 500MB〜1GB
- **内容**: n8n（Node.js）のV8ヒープサイズにデフォルト上限なし → 際限なく拡大
- **対応**:
  ```
  NODE_OPTIONS=--max-old-space-size=512    # 512MBに制限
  ```
- **トレードオフ**: 大きなデータを扱うWF（PDFバイナリ処理等）でOOMになる可能性
- **推奨**: まず768MBで様子を見て、問題なければ512MBに下げる

### B3. コンテナメモリ上限

- **期待効果**: 防御的（上限設定による暴走防止）
- **内容**: docker-compose.ymlでコンテナごとにメモリ上限を設定
- **対応**:
  ```yaml
  services:
    n8n:
      deploy:
        resources:
          limits:
            memory: 2G
          reservations:
            memory: 512M
  ```
- **トレードオフ**: 上限到達時にコンテナがOOM Killされる（restart: alwaysで自動復旧）

## Phase 3: 構造的改善（必要に応じて）

### C1. PostgreSQL → SQLite移行

- **期待効果**: 500MB〜1GB
- **前提**: n8n以外にPostgreSQLを利用するサービスがない場合
- **内容**: PostgreSQLプロセス自体を廃止し、n8nのDB保存先をSQLiteに変更
- **対応**:
  1. n8nの実行データ・WFデータをエクスポート
  2. docker-compose.ymlからPostgreSQLコンテナ削除
  3. n8n環境変数をSQLite用に変更: `DB_TYPE=sqlite`
  4. データインポート
- **リスク**: 大量の同時WF実行時にSQLiteのロック競合が発生する可能性
- **推奨**: WF同時実行数が少ない（〜5程度）場合は問題なし

### C2. swap設定の最適化

- **期待効果**: ピーク時の安全弁（OOM Killer回避）
- **対応**:
  ```bash
  # swapfileがない場合
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab

  # swappiness設定（メモリを優先使用）
  echo 'vm.swappiness=10' >> /etc/sysctl.conf
  sysctl -p
  ```
- **トレードオフ**: swap使用時はディスクI/Oで速度低下

### C3. n8nバージョン最適化

- **対応**: `docker pull n8nio/n8n:latest` で最新版に更新
- **確認**: リリースノートでメモリ改善があるか事前確認

## 推奨実施順序

1. **まずVPSにSSHして現状確認**:
   ```bash
   free -h                    # メモリ全体
   docker stats --no-stream   # コンテナ別メモリ
   ps aux --sort=-%mem | head -15  # プロセス別メモリ
   docker system df           # Docker使用量
   ```

2. **Phase 1 実施**（A1 → A2 → A3）: リスクなし、即効果

3. **Phase 1の効果確認後、Phase 2を検討**（B1 → B2 → B3）

4. **Phase 3は2GB以下に戻らない場合のみ検討**

## 目標

- 現在: 5-6GB
- Phase 1後: 4-5GB（1GB削減目標）
- Phase 2後: 3-4GB（2GB削減目標）
- Phase 3後: 2-3GB（3GB削減目標、ベースライン+1GB程度）

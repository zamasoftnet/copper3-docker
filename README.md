# Copper PDF Docker

Copper PDF 3.2.32 をDockerコンテナで実行するための設定です。

## 前提条件

- Docker と Docker Compose がインストールされていること
- `conf` ディレクトリに有効なライセンスキー (`license-key`) が配置されていること

## ファイル構成

```
copper-pdf/
├── Dockerfile              # Dockerイメージビルド用
├── docker-compose.yml      # Docker Compose設定
├── copper-pdf-3.2.32.tar.gz # Copper PDFアーカイブ
├── conf/                   # 設定ディレクトリ (ビルド時にイメージにコピーされる)
│   ├── copperd.properties  # サーバー設定
│   ├── license-key         # ライセンスキー
│   ├── access.txt          # アクセス制御
│   ├── password.txt        # パスワード設定
│   ├── logging.properties  # ログ設定
│   └── profiles/           # プロファイル設定
│       ├── default.properties
│       └── fonts/          # フォント設定
└── README.md
```

**注意**: `conf/` ディレクトリはビルド時にDockerイメージにコピーされます。
設定を変更した場合は `docker compose up -d --build` で再ビルドしてください。

## 使い方

### 1. イメージのビルドと起動

```bash
docker compose up -d --build
```

### 2. ログの確認

```bash
docker compose logs -f copper-pdf
```

### 3. 停止

```bash
docker compose down
```

### 4. サーバーの状態確認

コンテナ内からcopperdコマンドで状態を確認できます：

```bash
docker compose exec copper-pdf /opt/copper-pdf/copperd -status
```

## ポート

| ホスト側ポート | コンテナ側ポート | 説明 | 公開状態 |
|----------------|----------------|------|----------|
| 8497           | 8497           | HTTP/RESTインターフェース | 公開 |
| 8499           | 8499           | CTIPプロトコル | 公開 |
| -              | 8496           | JK (AJP) インターフェース | 非公開 |
| -              | 8498           | 制御ポート | 非公開 |

`docker-compose.yml` では HTTP/REST 用の `8497` と CTIP 用の `8499` のみホスト側へ公開しています。
risu にデプロイした場合は `risu.miya.be:8497` と `risu.miya.be:8499` で待ち受けます。

## 設定のカスタマイズ

### copperd.properties

`conf/copperd.properties` でサーバーの設定を変更できます：

```properties
jp.cssj.cssjd.timeout=180          # タイムアウト(秒)
jp.cssj.cssjd.minThreads=10        # 最小スレッド数
jp.cssj.cssjd.maxThreads=50        # 最大スレッド数
jp.cssj.cssjd.backlog=30           # バックログ
jp.cssj.cssjd.port=8499            # CTIPポート
jp.cssj.cssjd.control-port=8498    # 制御ポート
jp.cssj.cssjd.http.port=8497       # HTTPポート
jp.cssj.cssjd.jk.port=8496         # JKポート
```

### メモリ設定

`docker-compose.yml` の `JAVA_OPTS` 環境変数でJVMメモリを設定できます：

```yaml
environment:
  - JAVA_OPTS=-Xmx4096m  # 4GBに変更
```

## HTTP REST API の使用例

サーバー起動後、HTTP経由でPDFを生成できます：

```bash
# HTMLからPDF変換（POSTリクエスト）
curl -X POST "http://localhost:8497/transcode" \
     -d "rest.user=user" \
     -d "rest.password=kappa" \
     -d "rest.main=<html><body><h1>Hello World</h1></body></html>" \
     -o output.pdf

# ウェブサイトをPDF化
curl -X POST "http://localhost:8497/transcode" \
     -d "rest.user=user" \
     -d "rest.password=kappa" \
     -d "input.include=https://example.com/**" \
     -d "rest.mainURI=https://example.com/" \
     -o website.pdf
```

**認証情報**: デフォルトのユーザー名は `user`、パスワードは `kappa` です。
`conf/password.txt` でパスワードを変更できます。

## トラブルシューティング

### ライセンスエラー

`conf/license-key` ファイルが正しい場所に配置されていることを確認してください。

### ポートが使用中

`docker-compose.yml` のポートマッピングを変更してください：

```yaml
ports:
  - "18497:8497"  # ホスト側のHTTPポートを変更
```

### フォントの問題

カスタムフォントを使用する場合は、`conf/profiles/fonts/` ディレクトリにフォントファイルを配置し、`fonts.xml` を編集してください。

## ドキュメント

詳しいドキュメントは `docs/manual.pdf` を参照してください。

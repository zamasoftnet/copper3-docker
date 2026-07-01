# Copper PDF Docker

Copper PDF の Docker イメージを利用するための手順です。

## イメージ

```text
ghcr.io/zamasoftnet/copper-pdf:<tag>
```

検証では `latest` を使えます。運用では、意図しない更新を避けるため公開済みの固定タグを指定してください。

タグ一覧は GitHub Packages で確認できます。

```text
https://github.com/orgs/zamasoftnet/packages/container/package/copper-pdf
```

## Docker Compose で起動

`docker-compose.yml` を作成します。

```yaml
services:
  copper-pdf:
    image: ghcr.io/zamasoftnet/copper-pdf:latest
    container_name: copper-pdf
    restart: unless-stopped
    ports:
      - "8497:8497"
      - "8499:8499"
    volumes:
      - copper-logs:/opt/copper-pdf/logs

volumes:
  copper-logs:
```

起動します。

```bash
docker compose up -d
docker compose ps
```

ログ確認と停止:

```bash
docker compose logs -f copper-pdf
docker compose down
```

## ライセンスキー

ライセンスキーが無くてもコンテナは起動します。その場合はインストール直後の機能限定版として動作します。

商用ライセンスや試用ライセンスを使う場合は、ホスト側に `conf/license-key` を用意します。

```text
conf/
└── license-key
```

Docker Compose の `volumes` に次を追加してください。

```yaml
      - type: bind
        source: ./conf/license-key
        target: /opt/copper-pdf/conf/license-key
        read_only: true
        bind:
          create_host_path: false
```

ライセンスの種類と制限については、[公式サイト](https://copper-pdf.com/) の「ライセンスの種類」と [標準ライセンス案内](https://copper-pdf.com/2008/07/22/buy/) を確認してください。

## 認証設定

デフォルトの REST API ユーザー名は `user`、パスワードは `kappa` です。外部からアクセスできる環境では変更してください。

パスワードを変更する場合は `conf/password.txt` を用意し、Docker Compose の `volumes` に次を追加します。

```yaml
      - type: bind
        source: ./conf/password.txt
        target: /opt/copper-pdf/conf/password.txt
        read_only: true
        bind:
          create_host_path: false
```

## ポート

| ホスト側 | コンテナ側 | 用途 |
|---:|---:|---|
| 8497 | 8497 | HTTP / REST |
| 8499 | 8499 | CTIP |

必要に応じてホスト側のポートだけ変更してください。

```yaml
ports:
  - "18497:8497"
  - "18499:8499"
```

## REST API の例

```bash
curl -X POST "http://localhost:8497/transcode" \
  -d "rest.user=user" \
  -d "rest.password=kappa" \
  -d "rest.main=<html><body><h1>Hello World</h1></body></html>" \
  -o output.pdf
```

## docker run で起動

Docker Compose を使わない場合の例です。

```bash
docker run -d --name copper-pdf \
  -p 8497:8497 \
  -p 8499:8499 \
  -v copper-logs:/opt/copper-pdf/logs \
  ghcr.io/zamasoftnet/copper-pdf:latest
```

ライセンスキーを使う場合は次のオプションを追加します。

```bash
--mount type=bind,source="$PWD/conf/license-key",target=/opt/copper-pdf/conf/license-key,readonly
```

PowerShell では `source` を Windows パスにします。

```powershell
--mount type=bind,source="${PWD}\conf\license-key",target=/opt/copper-pdf/conf/license-key,readonly
```

## トラブルシューティング

### 機能が制限される

ライセンスキー未設定時は機能限定版として動作します。商用ライセンスや試用ライセンスを使う場合は、`conf/license-key` を mount してください。

### 起動しない

ログを確認してください。

```bash
docker compose logs copper-pdf
```

ポート使用中の場合は、`docker-compose.yml` のホスト側ポートを変更してください。

## 開発・公開手順

イメージのビルド、Release assets の作成、GHCR への公開手順は [DEVELOPMENT.md](DEVELOPMENT.md) を参照してください。

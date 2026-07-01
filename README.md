# Copper PDF Docker

Copper PDF を Docker イメージで利用するための簡易手順です。

## イメージ

```text
ghcr.io/zamasoftnet/copper-pdf:<tag>
```

通常は `latest`、または公開済みのタグを指定してください。

## 起動

### Docker Compose

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
```

ログ確認と停止:

```bash
docker compose logs -f copper-pdf
docker compose down
```

### docker run

```bash
docker run -d --name copper-pdf \
  -p 8497:8497 \
  -p 8499:8499 \
  -v copper-logs:/opt/copper-pdf/logs \
  ghcr.io/zamasoftnet/copper-pdf:latest
```

PowerShell:

```powershell
docker run -d --name copper-pdf `
  -p 8497:8497 `
  -p 8499:8499 `
  -v copper-logs:/opt/copper-pdf/logs `
  ghcr.io/zamasoftnet/copper-pdf:latest
```

## ライセンスキー

ライセンスキーが無くてもコンテナは起動します。その場合はインストール直後の機能限定版として動作します。

商用ライセンスや試用ライセンスを使う場合は、ホスト側に `conf/license-key` を用意し、コンテナの `/opt/copper-pdf/conf/license-key` へ読み取り専用で mount してください。

```text
conf/
└── license-key
```

Docker Compose では `volumes` に次を追加します。

```yaml
      - type: bind
        source: ./conf/license-key
        target: /opt/copper-pdf/conf/license-key
        read_only: true
        bind:
          create_host_path: false
```

`docker run` では次のオプションを追加します。

```bash
--mount type=bind,source="$PWD/conf/license-key",target=/opt/copper-pdf/conf/license-key,readonly
```

PowerShell:

```powershell
--mount type=bind,source="${PWD}\conf\license-key",target=/opt/copper-pdf/conf/license-key,readonly
```

ライセンスの種類と制限については、[公式サイト](https://copper-pdf.com/) の「ライセンスの種類」と [標準ライセンス案内](https://copper-pdf.com/2008/07/22/buy/) を確認してください。

## ポート

| ホスト側 | コンテナ側 | 用途 |
|---:|---:|---|
| 8497 | 8497 | HTTP / REST |
| 8499 | 8499 | CTIP |

## REST API の例

```bash
curl -X POST "http://localhost:8497/transcode" \
  -d "rest.user=user" \
  -d "rest.password=kappa" \
  -d "rest.main=<html><body><h1>Hello World</h1></body></html>" \
  -o output.pdf
```

デフォルトのユーザー名は `user`、パスワードは `kappa` です。変更する場合は `conf/password.txt` を用意し、次のように mount します。

```yaml
      - type: bind
        source: ./conf/password.txt
        target: /opt/copper-pdf/conf/password.txt
        read_only: true
        bind:
          create_host_path: false
```

## トラブルシューティング

### 機能が制限される

ライセンスキー未設定時は機能限定版として動作します。商用ライセンスや試用ライセンスを使う場合は、`conf/license-key` を mount してください。

### ポートが使用中

ホスト側のポートだけ変更します。

```yaml
ports:
  - "18497:8497"
  - "18499:8499"
```

## 開発・公開手順

イメージのビルド、Release assets の作成、GHCR への公開手順は [DEVELOPMENT.md](DEVELOPMENT.md) を参照してください。

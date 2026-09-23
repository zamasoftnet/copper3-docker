# Copper PDF Docker

Copper PDF の Docker イメージを利用するための手順です。

## イメージ

```text
ghcr.io/zamasoftnet/copper-pdf:<tag>
```

検証では `latest` を使えます。運用では、意図しない更新を避けるため公開済みの固定タグを指定してください。

公開イメージは配布用であり、固定allow-listの Noto Sans JP / Noto Serif JP を同梱します。IPA、M+、ベースイメージ由来のDejaVuなど、それ以外のフォントは含みません。追加の埋め込みフォントが必要な場合は、利用者がライセンスを確認したフォントを実行時にマウントしてください。社内サーバー向けのフルフォントイメージは別系統で管理し、GHCRには公開しません。

タグ一覧は GitHub Packages で確認できます。

```text
https://github.com/orgs/zamasoftnet/packages/container/package/copper-pdf
```

## かんたんセットアップ

このディレクトリにある次のファイルを同じフォルダへダウンロードします。YAMLを編集する必要はありません。

```text
compose.release.yml
compose.license.yml
copper.ps1        # Windows
copper.sh         # Linux / macOS
```

Windowsでは次のコマンドで起動します。

```powershell
.\copper.ps1 up
```

Linux / macOSでは次のコマンドで起動します。

```sh
chmod +x copper.sh
./copper.sh up
```

初回起動時に`user/fonts`が自動作成されます。ライセンスキーが無い場合は機能限定版として起動します。

状態確認、ログ、更新、停止も同じスクリプトで操作できます。

```powershell
.\copper.ps1 status
.\copper.ps1 logs
.\copper.ps1 update
.\copper.ps1 down
```

Linux / macOSでは`copper.ps1`を`copper.sh`に読み替えてください。`update`は固定タグまたは`latest`をpullした後、コンテナを作り直します。

イメージ、ポート、メモリを変更する場合だけ`.env.example`を`.env`へコピーして編集します。運用環境では`latest`ではなく固定バージョンタグを推奨します。

## ライセンスキー

商用ライセンスまたは試用ライセンスを使う場合は、取得したファイルを次の名前で置いてから、もう一度`up`を実行します。

```text
user/
└── license-key
```

```powershell
.\copper.ps1 up
```

起動スクリプトが空でないキーを検出すると、自動的にCompose secretとして`/opt/copper-pdf/conf/license-key`へ読み取り専用で配置します。キーはDockerイメージやComposeファイルには保存されません。

ライセンスの種類と制限については、[公式サイト](https://copper-pdf.com/) の「ライセンスの種類」と [標準ライセンス案内](https://copper-pdf.com/2008/07/22/buy/) を確認してください。

## 追加フォント

公開イメージにはNoto Sans JP／Noto Serif JPが最初から入っています。別のフォントを使う場合は、利用条件を確認した`.otf`、`.ttf`、`.ttc`などを`user/fonts`へ置いてコンテナを再起動します。

```text
user/
├── license-key       # 必要な場合だけ
└── fonts/
    └── MyFont.otf
```

```powershell
.\copper.ps1 restart
```

このディレクトリだけが`/opt/copper-pdf/conf/profiles/fonts/truetype/user`へ読み取り専用でマウントされるため、組み込みのNotoは隠れません。独自の`fonts.xml`、CMap、幅情報が必要な高度な構成では、従来どおりフォントプロファイル一式を個別にマウントしてください。

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

## Java メモリ設定

JVM オプションは `JAVA_OPTS` で指定できます。標準では `-Xmx2048m` です。

```yaml
environment:
  JAVA_OPTS: "-Xmx4096m"
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
  -e JAVA_OPTS="-Xmx2048m" \
  -v copper-logs:/opt/copper-pdf/logs \
  ghcr.io/zamasoftnet/copper-pdf:latest
```

ライセンスキーを使う場合は次のオプションを追加します。

```bash
--mount type=bind,source="$PWD/user/license-key",target=/opt/copper-pdf/conf/license-key,readonly
```

PowerShell では `source` を Windows パスにします。

```powershell
--mount type=bind,source="${PWD}\user\license-key",target=/opt/copper-pdf/conf/license-key,readonly
```

## トラブルシューティング

### 機能が制限される

ライセンスキー未設定時は機能限定版として動作します。商用ライセンスや試用ライセンスを使う場合は、`user/license-key`へ置いて`copper.ps1 up`または`./copper.sh up`を再実行してください。

### 起動しない

ログを確認してください。

```bash
.\copper.ps1 logs
```

ポート使用中の場合は、`.env.example`を`.env`へコピーし、ホスト側ポートを変更してください。

## 開発・公開手順

イメージのビルド、Release assets の作成、GHCR への公開手順は [DEVELOPMENT.md](DEVELOPMENT.md) を参照してください。

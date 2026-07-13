# Copper PDF Docker 開発メモ

この文書は Docker イメージのビルド、Release assets の作成、GHCR への公開を行うメンテナ向けです。Docker イメージの利用手順は [README.md](README.md) を参照してください。

## バージョン

対象バージョンは `proprietary/version.properties` で管理します。このファイルの `version.number` が Docker image tag、Release tag、製品アーカイブ名に使われます。

```properties
version.number=<version>
```

`version.filename` が必要な箇所では、ビルド時に `version.number` の `.` を `_` に置き換えて自動生成します。

## イメージタグ

GHCR には次の 3 つのタグで push されます。

| タグ | 例 | 性質 |
|---|---|---|
| `<version>-<build>` | `3.2.33-18880` | ビルドごとに一意。同一バージョンの再ビルドを区別できる |
| `<version>` | `3.2.33` | 同バージョンの最新ビルドを指す可変タグ |
| `latest` | `latest` | 可変タグ |

`<build>` は Ant の `<buildnumber/>`（`proprietary/CopperPDF/build.number`）が製品ビルド時に埋め込む番号で、workflow が tarball 内 `lib/cssj-copper.jar` の `jp/cssj/copper/VERSION`（3 行目）から自動取得します。手元の tarball のビルド番号は WSL で次のように確認できます。

```bash
cd /mnt/f/dev/zamasoftnet-private/copper3.2/proprietary/CopperPDF/build
tar -xzf copper-pdf-<version>.tar.gz --to-stdout copper-pdf-<version>/lib/cssj-copper.jar > /tmp/cssj-copper.jar
unzip -p /tmp/cssj-copper.jar jp/cssj/copper/VERSION | sed -n 3p
```

本番の compose（print.cssj.jp など）から参照する場合は digest 固定、または `<version>-<build>` タグを使ってください。`<version>` と `latest` は再公開で中身が変わります。

なお `proprietary/CopperPDF/build.number` ファイルの値は「次のビルドで使う番号」です（Ant がビルド時に使用した番号 + 1 を書き戻すため）。tarball に実際に入っている番号は上記の方法で tarball 自体から確認してください。

## 構成

```text
copper3.2/
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── .github/workflows/publish-image.yml
│   └── DEVELOPMENT.md
└── proprietary/
    ├── version.properties
    ├── publish-docker-assets.sh
    └── CopperPDF/
        └── build/
            ├── copper-pdf-<version>.tar.gz
            └── fonts.tar.gz
```

Docker は BuildKit の named context `copper-dist` で `../proprietary/CopperPDF/build` を参照します。製品 tarball を `docker/` 配下へコピーする必要はありません。

## ローカル assets 作成

PowerShell で `proprietary` ディレクトリへ移動し、WSL で実行します。

```powershell
cd F:\dev\zamasoftnet-private\copper3.2\proprietary
wsl ./publish-docker-assets.sh
```

生成物:

```text
proprietary/CopperPDF/build/copper-pdf-<version>.tar.gz
proprietary/CopperPDF/build/fonts.tar.gz
```

WSL に JDK が無い場合は先に入れます。

```bash
sudo apt install openjdk-11-jdk
```

## ローカルイメージビルド

`docker/conf/profiles/fonts` が無い環境では、先にフォントを展開します。

```powershell
cd F:\dev\zamasoftnet-private\copper3.2\docker
New-Item -ItemType Directory -Force conf\profiles\fonts
tar -xzf ..\proprietary\CopperPDF\build\fonts.tar.gz -C conf\profiles\fonts
```

イメージをビルドして起動します。

```powershell
docker compose up -d --build
```

ログと状態確認:

```powershell
docker compose logs -f copper-pdf
docker compose exec copper-pdf /opt/copper-pdf/copperd -status
```

停止:

```powershell
docker compose down
```

## サーバー配備

Copper PDF はホストごとに共有の単体コンテナとして独立起動・独立管理します（アプリのComposeスタックには含めません）。配備には `docker-compose.deploy.yml` を使います。手順はファイル冒頭のコメントを参照してください。

- テストサーバー risu.miya.be: `~/services/copper-pdf/`。copper_site とブログ出版局テストサイトが共有
- 本番サーバー print.cssj.jp: 同構成。ファイヤーウォールで 8497/8499 をグローバルに公開しない
- アプリからの接続は `host.docker.internal:8499`（compose の `extra_hosts: host.docker.internal:host-gateway` 経由）

## 秘密情報の扱い

`conf/license-key`、`conf/password.txt`、`deploy.json` は `.gitignore` と `.dockerignore` の対象です。ローカルに置いても git や Docker ビルドコンテキストには入りません。

ライセンスキーやパスワードはイメージに焼き込まず、実行時に bind mount します。ローカルの `docker-compose.override.yml` も git 管理外です。

## GHCR への公開

通常は `proprietary` 側のスクリプトから、Release assets の作成と Docker workflow の起動まで行います。

```powershell
cd F:\dev\zamasoftnet-private\copper3.2\proprietary
wsl ./publish-docker-assets.sh --publish --clobber
```

`--upload` または `--publish` を使う場合は、WSL 側に GitHub CLI (`gh`) が必要です。インストール方法は GitHub CLI の公式 Linux 手順を参照し、先に `gh auth login` を済ませてください。

```text
https://github.com/cli/cli/blob/trunk/docs/install_linux.md
```

アーカイブ作成後に `gh` が無いことで失敗した場合、生成済み assets は再利用できます。`gh` を用意してから次のように再実行します。

```powershell
wsl ./publish-docker-assets.sh --no-build --upload --clobber
wsl ./publish-docker-assets.sh --no-build --publish --clobber
```

HTTP 404 が出る場合は、GitHub 上で対象リポジトリが存在しないか、WSL 側の `gh` のトークンに private repository へのアクセス権がありません。classic PAT なら `repo` スコープ、fine-grained PAT なら対象リポジトリへのアクセス許可を確認してください。`GH_TOKEN` が別のトークンを指している場合も同じ症状になります。

Windows 側の `gh.exe` でログイン済みの場合、スクリプトは WSL 側の token で対象 repo が見えなかったときに Windows 側の `gh.exe auth token` を一時的に利用して再試行します。無効化する場合は `USE_WINDOWS_GH_TOKEN=0` を指定してください。

このコマンドは次の処理を行います。

1. `version.properties` から `version.number` を読み取る
2. `CopperPDF/build/copper-pdf-<version>.tar.gz` をビルドする
3. `CopperPDF/build/fonts.tar.gz` を作成する
4. `v<version>` の Release asset としてアップロードする
5. `docker/.github/workflows/publish-image.yml` を起動し、GHCR へ push する

事前に Docker リポジトリ側で以下を設定します。

- Repository secret `ASSET_TOKEN`: private Release を読むための PAT。`repo` スコープが必要
- 初回公開後、GHCR package `copper-pdf` の visibility を Public に変更

`publish-docker-assets.sh --publish` から起動する場合、assets を置く proprietary リポジトリは workflow input `asset_repo` として自動的に渡されます。Git tag push で workflow を起動する場合や Actions 画面から手動実行する場合は、workflow input `asset_repo` に `zamasoftnet/copper3-proprietary` を指定するか、Repository variable `ASSET_REPO` を設定してください。

スクリプトがリポジトリを自動判定できない場合は明示します。

```powershell
wsl ./publish-docker-assets.sh --publish --clobber `
  --asset-repo zamasoftnet/copper3-proprietary `
  --docker-repo zamasoftnet/copper3-docker
```

## GitHub Actions

`docker/.github/workflows/publish-image.yml` が GHCR へ push します。CI では Release assets から `copper-pdf-<version>.tar.gz` と `fonts.tar.gz` を取得し、`proprietary/CopperPDF/build/` と `conf/profiles/fonts/` に配置してから Docker build を実行します。

手動実行する場合は Actions の `Publish container image` を `workflow_dispatch` で起動し、`version` と `asset_repo` を指定します。

## トラブルシューティング

### `JAVA_HOME is not defined correctly`

WSL に JDK を入れてください。

```bash
sudo apt install openjdk-11-jdk
```

### `product archive not found`

`proprietary/CopperPDF/build/copper-pdf-<version>.tar.gz` が生成されていません。`proprietary` で次を実行してください。

```powershell
wsl ./publish-docker-assets.sh
```

### `homare-<version>.jar` が見つからない

`proprietary/CopperPDF/build.xml` は `homare-*.jar` を取り込むようにしています。古い差分が残っていないか確認してください。

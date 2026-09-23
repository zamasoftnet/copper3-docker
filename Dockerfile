# syntax=docker/dockerfile:1.4
# 2026-09-21: Jetty 12 のサーバーは Java 17 以上が要るので 11-jre から 21-jre へ。
# 同梱 JRE(extras/*/runtime)も 21.0.12.1+1 に揃えた
FROM eclipse-temurin:21-jre AS runtime

# curlをインストール（ヘルスチェック用）
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを設定
WORKDIR /opt/copper-pdf

# Copper PDFアーカイブを proprietary 側のビルド成果物からコピーして展開
ARG COPPER_VERSION=3.2.33
COPY --from=copper-dist copper-pdf-${COPPER_VERSION}.tar.gz /tmp/copper-pdf.tar.gz
RUN tar -xzf /tmp/copper-pdf.tar.gz -C /opt/copper-pdf --strip-components=1 \
    && rm /tmp/copper-pdf.tar.gz \
    && chmod +x /opt/copper-pdf/copperd

# ユーザーの設定ディレクトリをコピー（アーカイブ内のconfを上書き）
COPY conf/ /opt/copper-pdf/conf/

# ログディレクトリの準備
RUN mkdir -p /opt/copper-pdf/logs

# 環境変数
ENV COPPER_HOME=/opt/copper-pdf
ENV JAVA_OPTS="-Xmx2048m"

# ポートを公開 (HTTP, JK/AJP, Control, Main)
EXPOSE 8497 8496 8498 8499

# ログディレクトリをボリュームとして設定
VOLUME ["/opt/copper-pdf/logs"]

# javaコマンドで直接起動（フォアグラウンド）
# ドキュメントに記載のシステムプロパティを設定
CMD exec java ${JAVA_OPTS} \
    -Djava.net.preferIPv4Stack=true \
    -Duser.home=/opt/copper-pdf \
    -Djava.util.logging.config.file=/opt/copper-pdf/conf/logging.properties \
    -Djp.cssj.boot.lib=/opt/copper-pdf/lib:/opt/copper-pdf/jetty/lib \
    -Djp.cssj.plugin.lib=/opt/copper-pdf/plugins \
    -Djp.cssj.boot.main=jp.cssj.copper.Main \
    -Djp.cssj.driver.default=/opt/copper-pdf/conf/profiles/default.properties \
    -Djp.cssj.copper.config=/opt/copper-pdf/conf \
    -cp /opt/copper-pdf/lib/boot.jar \
    jp.cssj.boot.Main \
    -start

# 共通のフォントなしランタイム。製品側への混入は削除せず失敗させる。
# ベースJRE由来のシステムフォントだけを削除し、その後に全体を再検査する。
FROM runtime AS fontless-runtime
RUN if find /opt/copper-pdf -type f \
      \( -iname '*.otf' -o -iname '*.otc' -o -iname '*.ttf' -o -iname '*.ttc' -o \
         -iname '*.pfb' -o -iname '*.pfa' -o -iname '*.woff' -o -iname '*.woff2' -o \
         -iname '*.eot' -o -iname '*.dfont' -o -iname '*.fon' \) \
      -print -quit | grep -q .; then \
      echo 'distribution image must not contain font binaries under /opt/copper-pdf' >&2; \
      exit 1; \
    fi \
    && find / -xdev -type f \
      \( -iname '*.otf' -o -iname '*.otc' -o -iname '*.ttf' -o -iname '*.ttc' -o \
         -iname '*.pfb' -o -iname '*.pfa' -o -iname '*.woff' -o -iname '*.woff2' -o \
         -iname '*.eot' -o -iname '*.dfont' -o -iname '*.fon' \) \
      -delete \
    && if find / -xdev -type f \
      \( -iname '*.otf' -o -iname '*.otc' -o -iname '*.ttf' -o -iname '*.ttc' -o \
         -iname '*.pfb' -o -iname '*.pfa' -o -iname '*.woff' -o -iname '*.woff2' -o \
         -iname '*.eot' -o -iname '*.dfont' -o -iname '*.fon' \) \
      -print -quit | grep -q .; then \
      echo 'distribution image still contains a font binary' >&2; \
      exit 1; \
    fi \
    && test ! -e /opt/copper-pdf/conf/license-key

# **fontconfig に見える書体を 1 つも残さないと AWT が起動できない**(2026-09-21 実測)。
# 上で土台の DejaVu 8 本を消すと、変換のたびに
#   java.lang.RuntimeException: Fontconfig head is null, check your fonts or fonts configuration
#     at sun.awt.FontConfiguration.getVersion / X11FontManager.createFontConfiguration
# になり、fonts.xml を読む段で落ちて 1 文書も変換できない。
# 書体ファイルは足さず、同梱の書体ディレクトリへの symlink だけを置く
# (配布版は Noto の 13 本、内部版はフルパック、利用者が足す truetype/user もこの下)。
RUN mkdir -p /usr/share/fonts && ln -sfn /opt/copper-pdf/conf/profiles/fonts/truetype /usr/share/fonts/copper

# 内部運用専用。フルフォントはnamed contextからだけ取り込む。
# ライセンスキーはイメージlayerへ保存せず、Composeのruntime secretで渡す。
FROM fontless-runtime AS internal
COPY --from=copper-fonts . /opt/copper-pdf/conf/profiles/fonts/
RUN test ! -e /opt/copper-pdf/conf/license-key \
    && find /opt/copper-pdf/conf/profiles/fonts -type f \
      \( -iname '*.otf' -o -iname '*.otc' -o -iname '*.ttf' -o -iname '*.ttc' -o \
         -iname '*.pfb' -o -iname '*.pfa' -o -iname '*.woff' -o -iname '*.woff2' -o \
         -iname '*.eot' -o -iname '*.dfont' -o -iname '*.fon' \) \
      -print -quit | grep -q . \
    || (echo 'internal image requires the full font context' >&2; exit 1)
LABEL jp.cssj.copper.image.variant="internal-fonts"

# 公開配布用。明示した2つのcontextからNoto Sans/Serif JPだけを追加し、
# ファイルシステム全体のフォント名を固定allow-listと照合する。
FROM fontless-runtime AS distribution
COPY --from=noto-sans . /opt/copper-pdf/conf/profiles/fonts/truetype/Noto_Sans_JP/
COPY --from=noto-serif . /opt/copper-pdf/conf/profiles/fonts/truetype/Noto_Serif_JP/
COPY distribution-font-dirs.sed /tmp/distribution-font-dirs.sed
COPY distribution-noto-fonts.txt /tmp/distribution-noto-fonts.txt
RUN sed -i -f /tmp/distribution-font-dirs.sed /opt/copper-pdf/conf/profiles/fonts/fonts.xml \
    && grep -Fq 'dir="truetype/Noto_Sans_JP"' /opt/copper-pdf/conf/profiles/fonts/fonts.xml \
    && grep -Fq 'dir="truetype/Noto_Serif_JP"' /opt/copper-pdf/conf/profiles/fonts/fonts.xml \
    && grep -Fq 'dir="truetype/user"' /opt/copper-pdf/conf/profiles/fonts/fonts.xml \
    && grep -Ev '^[[:space:]]*(#|$)' /tmp/distribution-noto-fonts.txt | sort -u > /tmp/expected-fonts \
    && find / -xdev -type f \
      \( -iname '*.otf' -o -iname '*.otc' -o -iname '*.ttf' -o -iname '*.ttc' -o \
         -iname '*.pfb' -o -iname '*.pfa' -o -iname '*.woff' -o -iname '*.woff2' -o \
         -iname '*.eot' -o -iname '*.dfont' -o -iname '*.fon' \) \
      -printf '%f\n' | sort -u > /tmp/actual-fonts \
    && diff -u /tmp/expected-fonts /tmp/actual-fonts \
    && test ! -e /opt/copper-pdf/conf/license-key \
    && rm /tmp/distribution-font-dirs.sed /tmp/distribution-noto-fonts.txt /tmp/expected-fonts /tmp/actual-fonts
LABEL jp.cssj.copper.image.variant="distribution-noto"

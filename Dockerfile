FROM eclipse-temurin:11-jre

# curlをインストール（ヘルスチェック用）
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# 作業ディレクトリを設定
WORKDIR /opt/copper-pdf

# Copper PDFアーカイブをコピーして展開（バージョンは build-arg で指定）
ARG COPPER_VERSION=3.2.32
COPY copper-pdf-${COPPER_VERSION}.tar.gz /tmp/copper-pdf.tar.gz
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
CMD ["java", \
    "-Xmx2048m", \
    "-Djava.net.preferIPv4Stack=true", \
    "-Duser.home=/opt/copper-pdf", \
    "-Djava.util.logging.config.file=/opt/copper-pdf/conf/logging.properties", \
    "-Djp.cssj.boot.lib=/opt/copper-pdf/lib:/opt/copper-pdf/jetty/lib", \
    "-Djp.cssj.plugin.lib=/opt/copper-pdf/plugins", \
    "-Djp.cssj.boot.main=jp.cssj.copper.Main", \
    "-Djp.cssj.driver.default=/opt/copper-pdf/conf/profiles/default.properties", \
    "-Djp.cssj.copper.config=/opt/copper-pdf/conf", \
    "-cp", "/opt/copper-pdf/lib/boot.jar", \
    "jp.cssj.boot.Main", \
    "-start"]

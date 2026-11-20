# Copper PDF 3.2.34 (build 18898, Java fixed for CVE-2026-114938) for the print site's test server on risu, with the egress guard (2026-11-15).
#
# The same guard as Copper 4 (copperpdf4/docker/egress-guard.sh, copied next to this file when deploying): at every
# start of the container, as root with NET_ADMIN, it puts iptables rules into the container's own network namespace so
# that the server cannot reach the inner network (RFC 1918, link-local, CGNAT), checks them, then execs the server
# with every capability dropped (empty bounding set, no-new-privs). The host's iptables is never touched.
#
# Unlike Copper 4, the server stays uid 0 (COPPER_EGRESS_RUN_AS=0:0): the 3.2 image has no user of its own and its
# log volume and user.home are root's. Without any capability, root here cannot take the rules out again, which is
# what the guard needs; moving 3.2 to another uid would mean rechowning its volume for an old version kept for one
# test site.
#
# The base image's ENTRYPOINT and CMD are kept: the guard runs the base entrypoint with the base command. Setting
# ENTRYPOINT clears the inherited CMD, so the CMD below is the base image's, taken by `docker image inspect`.
FROM r.miya.be/copper-pdf@sha256:ca4980cb97eebe454bce12c3f16660130520c26279256f93fcd6b48fa7d9dcb6
USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends iptables \
    && rm -rf /var/lib/apt/lists/*
COPY egress-guard.sh /usr/local/bin/copper-egress-guard
RUN chmod 0755 /usr/local/bin/copper-egress-guard
ENV COPPER_EGRESS_RUN_AS=0:0
ENTRYPOINT ["/usr/local/bin/copper-egress-guard", "run", "/__cacert_entrypoint.sh"]
CMD ["/bin/sh","-c","exec java ${JAVA_OPTS}     -Djava.net.preferIPv4Stack=true     -Duser.home=/opt/copper-pdf     -Djava.util.logging.config.file=/opt/copper-pdf/conf/logging.properties     -Djp.cssj.boot.lib=/opt/copper-pdf/lib:/opt/copper-pdf/jetty/lib     -Djp.cssj.plugin.lib=/opt/copper-pdf/plugins     -Djp.cssj.boot.main=jp.cssj.copper.Main     -Djp.cssj.driver.default=/opt/copper-pdf/conf/profiles/default.properties     -Djp.cssj.copper.config=/opt/copper-pdf/conf     -cp /opt/copper-pdf/lib/boot.jar     jp.cssj.boot.Main     -start"]

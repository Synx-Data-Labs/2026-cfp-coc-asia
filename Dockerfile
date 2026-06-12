FROM --platform=linux/arm64 coc-toolchain:gcc12
# Cloudberry core build deps from PUBLIC Rocky 8 repos + EPEL. Expand as `make` reveals more.
RUN dnf -y install epel-release && dnf -y install \
      git cmake bison flex \
      readline-devel zlib-devel openssl-devel libxml2-devel libxslt-devel \
      libzstd-devel libuuid-devel openldap-devel pam-devel krb5-devel \
      perl-ExtUtils-Embed python3-devel \
      && dnf clean all
COPY build.sh /opt/build.sh

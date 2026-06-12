FROM --platform=linux/arm64 coc-toolchain:gcc12
# Cloudberry core build deps from PUBLIC Rocky 8 repos + EPEL. Expand as `make` reveals more.
RUN dnf -y install epel-release && dnf -y install \
      git cmake bison flex \
      readline-devel zlib-devel openssl-devel libxml2-devel libxslt-devel \
      libzstd-devel libuuid-devel openldap-devel pam-devel krb5-devel \
      perl-ExtUtils-Embed perl-devel python3-devel \
      apr-devel apr-util-devel libevent-devel bzip2-devel libcurl-devel \
      xerces-c-devel patchelf rpm-build \
      && dnf clean all
# fpm needs Ruby >= 2.7; Rocky 8's default ruby is 2.5, so enable a newer stream.
RUN dnf -y module reset ruby && dnf -y module enable ruby:3.1 \
      && dnf -y install ruby ruby-devel && dnf clean all \
      && gem install --no-document fpm   # RPM/DEB packaging from one tree
COPY build.sh /opt/build.sh
COPY vendor.sh /opt/vendor.sh

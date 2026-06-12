# Build a pinned GCC from source on the Rocky 8 (glibc 2.28) floor — host compiler unused downstream.
FROM --platform=linux/arm64 rockylinux:8

ARG GCC_VERSION=12.3.0
RUN dnf -y install gcc gcc-c++ make bzip2 wget flex perl diffutils \
      && dnf clean all
RUN cd /tmp && wget -q "https://ftp.gnu.org/gnu/gcc/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.xz" \
      && tar xf "gcc-${GCC_VERSION}.tar.xz" && cd "gcc-${GCC_VERSION}" \
      && ./contrib/download_prerequisites \
      && mkdir build && cd build \
      && ../configure --prefix=/usr/local/toolchain \
           --enable-languages=c,c++ --disable-multilib \
      && make -j"$(nproc)" && make install \
      && cd /tmp && rm -rf "gcc-${GCC_VERSION}" "gcc-${GCC_VERSION}.tar.xz"
COPY profile.sh /etc/profile.d/toolchain.sh

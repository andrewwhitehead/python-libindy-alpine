FROM alpine:3.7

ARG uid=1001
ARG gid=1001
ARG python3_indy_ver=1.3.1-dev-408
ARG indy_plenum_ver=1.2.264
ARG indy_anoncreds_ver=1.0.32
ARG indy_node_ver=1.3.330
ARG indy_crypto_ver=0.1.6-dev-33

ENV HOME=/home/indy
ENV BUILD=$HOME/build

ENV LC_ALL="C.UTF-8"
ENV LANG="C.UTF-8"
ENV SHELL=/bin/bash

ENV RUST_LOG=warning

RUN addgroup -g $gid indy && adduser -u $uid -D -G root -G indy indy

RUN echo '@alpine36 http://dl-cdn.alpinelinux.org/alpine/v3.6/main' >> /etc/apk/repositories

# install system packages
# need slightly older version of libsodium (before aes128 support was removed)
RUN apk update && \
    apk add --no-cache \
        bash \
        bison \
        cargo \
        build-base \
        ca-certificates \
        cmake \
        flex \
        git \
        gmp-dev \
        libressl-dev@alpine36 \
        libsodium-dev@alpine36 \
        linux-headers \
        musl=1.1.18-r3 \
        py3-pynacl \
        python3-dev \
        rust \
        sqlite-dev \
        wget

WORKDIR $BUILD

# build pbc library (not in alpine repo)
ARG pbc_lib_ver=0.5.14
RUN wget https://crypto.stanford.edu/pbc/files/pbc-${pbc_lib_ver}.tar.gz && \
    tar xzvf pbc-${pbc_lib_ver}.tar.gz && \
    cd pbc-${pbc_lib_ver} && \
    ./configure && \
    make install && \
    cd $BUILD && \
    rm -rf pbc-${pbc_lib_ver}*

# build indy-sdk from git repo
ARG indy_sdk_rev=778a38d92234080bb77c6dd469a8ff298d9b7154
ARG indy_sdk_debug=1
RUN git clone https://github.com/hyperledger/indy-sdk.git && \
    cd indy-sdk/libindy && \
    git checkout ${indy_sdk_rev}
# Apply single-line fix to rusqlcipher dependency for libressl support
WORKDIR $BUILD/indy-sdk/libindy
RUN git clone https://github.com/mikelodder7/rusqlcipher.git && \
    cd rusqlcipher && \
    git checkout f04967cecd299309b213f98cd9f9c5e0cf18e950 && \
    cd .. && \
    sed -i 's/^rusqlcipher =.*$/rusqlcipher = { path = "rusqlcipher", features = ["bundled"] }/' \
        Cargo.toml
RUN [ "${indy_sdk_debug}" == "1" ] && cargo build || cargo build --release && \
    mv target/*/libindy.so /usr/lib && \
    cd $BUILD && \
    rm -rf indy-sdk
WORKDIR $BUILD

# build indy-crypto from git repo
ARG indy_crypto_rev=75add4fff63168f3919a1b8bdf1e11f18ecbb4fc
RUN git clone https://github.com/hyperledger/indy-crypto.git && \
    cd indy-crypto/libindy-crypto && \
    git checkout ${indy_crypto_rev}
WORKDIR $BUILD/indy-crypto/libindy-crypto
RUN [ "${indy_sdk_debug}" == "1" ] && cargo build || cargo build --release && \
    mv target/*/libindy_crypto.so /usr/lib && \
    cd $BUILD && \
    rm -rf indy-crypto

# clean up cargo cache
RUN rm -rf $HOME/.cargo

# - Create a Python virtual environment for use by any application to avoid
#   potential conflicts with Python packages preinstalled in the main Python
#   installation.
# - In order to drop the root user, we have to make some directories world
#   writable as OpenShift default security model is to run the container
#   under random UID.
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip --no-cache-dir install virtualenv && \
    virtualenv $HOME
ENV PATH "$HOME/bin:$PATH"

# install indy python packages
RUN pip --no-cache-dir install \
        python3-indy==${python3_indy_ver} \
        indy-plenum-dev==${indy_plenum_ver} \
        indy-anoncreds-dev==${indy_anoncreds_ver} \
        indy-node-dev==${indy_node_ver} \
        indy-crypto==${indy_crypto_ver}

# clean up unneeded packages
RUN apk del bison cargo cmake flex rust


# drop privileges
RUN chown -R indy $HOME
USER indy

WORKDIR $HOME

CMD ["bash"]

FROM alpine:3.7

ENV BUILD=/opt/app-root
ENV HOME="$BUILD/src"
WORKDIR $BUILD
RUN adduser -u 1001 -DG root indy

# install system packages
# need slightly older versions of libsodium (with aes128 support) and libressl
RUN apk update && \
    apk add --no-cache \
        bison \
        cargo \
        build-base \
        ca-certificates \
        cmake \
        flex \
        git \
        gmp-dev \
        openssl-dev \
        libsodium-dev \
        linux-headers \
        musl=1.1.18-r3 \
        py3-pynacl \
        python3-dev \
        rust \
        sqlite-dev \
        wget

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
RUN git clone https://github.com/hyperledger/indy-sdk.git && \
    cd indy-sdk/libindy && \
    git checkout ${indy_sdk_rev} && \
    cargo build --release && \
    mv target/release/libindy.so /usr/lib && \
    cd $BUILD && \
    rm -rf indy-sdk $HOME/.cargo

# - Create a Python virtual environment for use by any application to avoid
#   potential conflicts with Python packages preinstalled in the main Python
#   installation.
# - In order to drop the root user, we have to make some directories world
#   writable as OpenShift default security model is to run the container
#   under random UID.
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip --no-cache-dir install virtualenv && \
    virtualenv $BUILD

ARG python3_indy_ver=1.3.1-dev-408
ARG indy_plenum_ver=1.2.268
ARG indy_anoncreds_ver=1.0.44
ARG indy_node_ver=1.3.331
ARG indy_crypto_ver=0.1.6-dev-33

# install indy python packages
RUN source bin/activate && \
    pip --no-cache-dir install \
        python3-indy==${python3_indy_ver} \
        indy-plenum-dev==${indy_plenum_ver} \
        indy-anoncreds-dev==${indy_anoncreds_ver} \
        indy-node-dev==${indy_node_ver} \
        indy-crypto==${indy_crypto_ver}

# clean up unneeded packages
RUN apk del bison cargo cmake flex rust

# drop privileges
RUN chown -R indy $BUILD $HOME
USER indy

CMD ["sh"]

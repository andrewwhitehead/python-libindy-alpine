FROM alpine:3.7

ENV HOME=/app
ENV BUILD=/build
WORKDIR $BUILD
RUN adduser -u 1000 -DG root indy

RUN echo '@alpine36 http://dl-cdn.alpinelinux.org/alpine/v3.6/main' >> /etc/apk/repositories

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
ARG indy_lib_ver=1.1.0
RUN wget -O indy-sdk-${indy_lib_ver}.tar.gz \
        https://github.com/hyperledger/indy-sdk/archive/v${indy_lib_ver}.tar.gz && \
    tar xzvf indy-sdk-${indy_lib_ver}.tar.gz && \
    cd indy-sdk-${indy_lib_ver}/libindy && \
    cargo build && \
    mv target/debug/libindy.so /usr/lib && \
    cd $BUILD && \
    rm -rf indy-sdk-*

# - Create a Python virtual environment for use by any application to avoid
#   potential conflicts with Python packages preinstalled in the main Python
#   installation.
# - In order to drop the root user, we have to make some directories world
#   writable as OpenShift default security model is to run the container
#   under random UID.
RUN ln -sf /usr/bin/python3 /usr/bin/python && \
    ln -sf /usr/bin/pip3 /usr/bin/pip && \
    pip install virtualenv && \
    virtualenv $BUILD

# install indy python packages
RUN source bin/activate && \
    pip install \
        python3-indy==${indy_lib_ver} \
        indy-plenum-dev==1.2.173 \
        indy-anoncreds-dev==1.0.32 \
        indy-node-dev==1.2.214

# clean up unneeded packages
RUN apk del bison cargo cmake flex rust && \
    rm -rf $HOME/.cache $HOME/.cargo

# drop privileges
RUN chown -R indy $BUILD $HOME
USER indy

CMD ["sh"]

# Build Stage
FROM fuzzers/aflplusplus:3.12c as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y git make libpng-dev zlib1g-dev libpoppler-glib-dev emacs


## Have to install cask as a pre-requisite
WORKDIR /
RUN git clone https://github.com/cask/cask
RUN mkdir /root/.local/bin
RUN make -j$(nproc) -C cask install
RUN ln -s /root/.local/bin/cask /usr/bin/cask
RUN ldconfig

ADD . /pdf-tools
WORKDIR /pdf-tools

## Build
env CC="afl-clang-fast"
RUN make -s

## Package Stage

FROM fuzzers/aflplusplus:3.12c
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y libpoppler97 libpoppler-glib8
COPY --from=builder /pdf-tools/server/epdfinfo /epdfinfo
COPY --from=builder /pdf-tools/corpus /tests

ENTRYPOINT ["afl-fuzz", "-i", "/tests", "-o", "/out"]
CMD ["/epdfinfo"]

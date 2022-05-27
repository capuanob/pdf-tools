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

## Add source code to the build stage. ADD prevents git clone being cached when it shouldn't
WORKDIR /
ADD https://api.github.com/repos/capuanob/pdf-tools/git/refs/heads/mayhem version.json
RUN git clone -b mayhem https://github.com/capuanob/pdf-tools.git
WORKDIR /pdf-tools

## Build
env CC="afl-clang-fast"
RUN make -s

## Prepare all library dependencies for copy
RUN mkdir /deps
RUN cp `ldd ./server/epdfinfo | grep so | sed -e '/^[^\t]/ d' | sed -e 's/\t//' | sed -e 's/.*=..//' | sed -e 's/ (0.*)//' | sort | uniq` /deps 2>/dev/null || :
RUN cp `ldd /usr/local/bin/afl-fuzz | grep so | sed -e '/^[^\t]/ d' | sed -e 's/\t//' | sed -e 's/.*=..//' | sed -e 's/ (0.*)//' | sort | uniq` /deps 2>/dev/null || :

## Package Stage

FROM --platform=linux/amd64 ubuntu:20.04
COPY --from=builder /usr/local/bin/afl-fuzz /afl-fuzz
COPY --from=builder /pdf-tools/server/epdfinfo /epdfinfo
COPY --from=builder /deps /usr/lib
COPY --from=builder /pdf-tools/corpus /tests

env AFL_SKIP_CPUFREQ=1

ENTRYPOINT ["/afl-fuzz", "-i", "/tests", "-o", "/out"]
CMD ["/epdfinfo"]

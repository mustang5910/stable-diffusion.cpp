ARG UBUNTU_VERSION=22.04
# This needs to generally match the container host's environment.
ARG MUSA_VERSION=rc4.2.0
# Target the MUSA build image
ARG BASE_MUSA_DEV_CONTAINER=mthreads/musa:${MUSA_VERSION}-devel-ubuntu${UBUNTU_VERSION}-amd64

ARG BASE_MUSA_RUN_CONTAINER=mthreads/musa:${MUSA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}-amd64

FROM ${BASE_MUSA_DEV_CONTAINER} AS build

# MUSA architecture to build for (defaults to all supported archs)
ARG MUSA_DOCKER_ARCH=default

RUN apt-get update && \
    apt-get install -y \
    build-essential \
    ccache \
    cmake \
    python3 \
    python3-pip \
    git \
    libssl-dev \
    libgomp1

WORKDIR /app

COPY . .

RUN mkdir build && cd build && \
    cmake .. -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -fopenmp -I/usr/lib/llvm-14/lib/clang/14.0.0/include -L/usr/lib/llvm-14/lib" \
    -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -fopenmp -I/usr/lib/llvm-14/lib/clang/14.0.0/include -L/usr/lib/llvm-14/lib" \
    -DSD_MUSA=ON -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . --config Release

## Runtime image
FROM ${BASE_MUSA_RUN_CONTAINER} AS runtime

RUN apt-get update \
    && apt-get install -y libgomp1 \
    && apt autoremove -y \
    && apt clean -y \
    && rm -rf /tmp/* /var/tmp/* \
    && find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
    && find /var/cache -type f -delete

### Light, CLI only
FROM runtime AS light

COPY --from=build /app/build/bin/sd-cli /app

WORKDIR /app

ENTRYPOINT [ "/app/sd-cli" ]

### Server, Server only
FROM runtime AS server

COPY --from=build /app/build/bin/sd-server /app

WORKDIR /app

ENTRYPOINT [ "/app/sd-server" ]

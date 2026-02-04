ARG UBUNTU_VERSION=24.04
# This needs to generally match the container host's environment.
ARG CUDA_VERSION=13.1.0
# Target the CUDA build image
ARG BASE_CUDA_DEV_CONTAINER=nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}

ARG BASE_CUDA_RUN_CONTAINER=nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

FROM ${BASE_CUDA_DEV_CONTAINER} AS build

# CUDA architecture to build for (defaults to all supported archs)
ARG CUDA_DOCKER_ARCH=default

RUN apt-get update && \
    apt-get install -y build-essential cmake python3 python3-pip git libssl-dev libgomp1

WORKDIR /app

COPY . .

RUN cmake . -B ./build -DGGML_CUDA=ON -DSD_CUDA=ON
RUN cmake --build ./build --config Release --parallel

## Runtime image
FROM ${BASE_CUDA_RUN_CONTAINER} AS runtime

RUN apt-get update \
    && apt-get install -y libgomp1 \
    && apt autoremove -y \
    && apt clean -y \
    && rm -rf /tmp/* /var/tmp/* \
    && find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
    && find /var/cache -type f -delete

RUN mkdir -p /app/

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

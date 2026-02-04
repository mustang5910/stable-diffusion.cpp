ARG UBUNTU_VERSION=24.04

FROM ubuntu:$UBUNTU_VERSION AS build

ARG TARGETARCH

RUN apt-get update && \
    apt-get install -y build-essential git cmake libssl-dev

WORKDIR /app

COPY . .

RUN cmake . -B ./build
RUN cmake --build ./build --config Release --parallel

## Runtime image
FROM ubuntu:$UBUNTU_VERSION AS runtime

RUN apt-get update \
    && apt-get install -y libgomp1 \
    && apt autoremove -y \
    && apt clean -y \
    && rm -rf /tmp/* /var/tmp/* \
    && find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete \
    && find /var/cache -type f -delete

### Light, CLI only
FROM runtime AS light

COPY --from=build /sd.cpp/build/bin/sd-cli /app

WORKDIR /app

ENTRYPOINT [ "/app/sd-cli" ]

### Server, Server only
FROM runtime AS server

COPY --from=build /sd.cpp/build/bin/sd-server /app

WORKDIR /app

ENTRYPOINT [ "/app/sd-server" ]

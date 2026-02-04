ARG UBUNTU_VERSION=26.04

FROM ubuntu:$UBUNTU_VERSION AS build

# Install build tools
RUN apt update && apt install -y git build-essential cmake wget xz-utils

# Install SSL and Vulkan SDK dependencies
RUN apt install -y libssl-dev curl \
    libxcb-xinput0 libxcb-xinerama0 libxcb-cursor-dev libvulkan-dev glslc

# Build it
WORKDIR /app

COPY . .

RUN cmake . -B ./build -DSD_VULKAN=ON
RUN cmake --build ./build --config Release --parallel

## Runtime image
FROM ubuntu:$UBUNTU_VERSION AS runtime

RUN apt-get update \
    && apt-get install -y libgomp1 libvulkan1 mesa-vulkan-drivers \
    libglvnd0 libgl1 libglx0 libegl1 libgles2 \
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

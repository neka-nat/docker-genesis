FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    build-essential \
    manpages-dev \
    git \
    curl \
    wget \
    ca-certificates \
    python3.10-dev \
    python3.10-distutils \
    python3.10-venv \
    python3-pip \
    xorg-dev \
    libglu1-mesa-dev \
    libgl1-mesa-dri \
    libvulkan-dev \
    zlib1g-dev \
    libsnappy-dev \
    && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository ppa:ubuntu-toolchain-r/test -y && \
    apt-get update && apt-get install -y --no-install-recommends gcc-11 g++-11 && \
    update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 110 && \
    rm -rf /var/lib/apt/lists/*

RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg >/dev/null
RUN apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main"
RUN apt-get update && apt-get install -y cmake && rm -rf /var/lib/apt/lists/*

RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1

RUN pip install --upgrade pip && \
    pip install genesis-world

RUN pip install torch --index-url https://download.pytorch.org/whl/cu121
RUN pip install https://github.com/ompl/ompl/releases/download/prerelease/ompl-1.6.0-cp310-cp310-manylinux_2_28_x86_64.whl
RUN pip install "pybind11[global]"

# rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN apt-get update && apt-get install -y patchelf && rm -rf /var/lib/apt/lists/*

# splashsurf
RUN cargo install splashsurf

# genesisソース取得
WORKDIR /opt
RUN git clone --recursive https://github.com/Genesis-Embodied-AI/Genesis.git
WORKDIR /opt/Genesis

# ParticleMesherのためのLD_LIBRARY_PATH設定
ENV LD_LIBRARY_PATH="/opt/Genesis/genesis/ext/ParticleMesher/ParticleMesherPy:${LD_LIBRARY_PATH}"

# LuisaRenderビルド
WORKDIR /opt/Genesis/genesis/ext/LuisaRender
RUN cmake -S . -B build -D CMAKE_BUILD_TYPE=Release \
    -D PYTHON_VERSIONS=3.10 \
    -D LUISA_COMPUTE_DOWNLOAD_NVCOMP=ON \
    -D LUISA_COMPUTE_ENABLE_GUI=OFF
RUN cmake --build build -j $(nproc)
RUN mkdir -p /usr/local/lib/python3.10/dist-packages/genesis/ext/LuisaRender/build/bin && \
    cp build/bin/* /usr/local/lib/python3.10/dist-packages/genesis/ext/LuisaRender/build/bin/

# cleanup
WORKDIR /opt
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
CMD ["/bin/bash"]

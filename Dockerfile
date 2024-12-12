FROM nvidia/cuda:12.1.0-cudnn8-devel-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive

# 기본 패키지 설치
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    sudo \
    build-essential \
    cmake \
    ninja-build \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-dev \
    vim \
    gnupg2 \
    software-properties-common \
    libaio-dev \
    net-tools \ 
    iproute2 \
    inetutils-ping \
    openssh-client \
    virtualenv \
    && rm -rf /var/lib/apt/lists/*

# Intel oneAPI 저장소 추가 및 CCL 설치
RUN wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
    | sudo tee /etc/apt/sources.list.d/oneAPI.list \
    && apt-get update \
    && apt-get install -y intel-oneapi-ccl-devel \
    && rm -rf /var/lib/apt/lists/*

# oneAPI 환경 변수 설정
ENV ONEAPI_ROOT=/opt/intel/oneapi
ENV PATH=${ONEAPI_ROOT}/compiler/latest/linux/bin/intel64:${PATH}
ENV LD_LIBRARY_PATH=${ONEAPI_ROOT}/compiler/latest/linux/compiler/lib/intel64_lin:${LD_LIBRARY_PATH}
ENV CCL_ROOT=${ONEAPI_ROOT}/ccl/latest

# Python 관련 설정
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1
RUN pip3 install --upgrade pip

# CUDA 및 GPU 설정
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# PyTorch 설치 (CUDA 12.1 버전)
RUN pip install torch==2.1.0+cu121 torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu121

# oneCCL 소스에서 빌드 및 설치
RUN apt-get update && apt-get install -y \
    git \
    cmake \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
RUN git clone https://github.com/oneapi-src/oneCCL.git && \
    cd oneCCL && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install

# 환경 변수 설정
ENV CCL_ROOT=/workspace/oneCCL/build
ENV LD_LIBRARY_PATH=$CCL_ROOT/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH=$CCL_ROOT/lib/pkgconfig:$PKG_CONFIG_PATH
ENV CPLUS_INCLUDE_PATH=$CCL_ROOT/include:$CPLUS_INCLUDE_PATH

# DeepSpeed 소스에서 설치
WORKDIR /workspace
RUN git clone https://github.com/gspark-etri/deepspeed-dev.git
WORKDIR /workspace/deepspeed-dev
RUN pip install .

# DeepSpeed 버전 확인
RUN python -c "import deepspeed; print('DeepSpeed version:', deepspeed.__version__)"

# TORCH_EXTENSIONS_DIR 설정 (필요한 경우)
# ENV TORCH_EXTENSIONS_DIR=/workspace/torch-extensions

# Hugging Face 라이브러리 설치
RUN pip install --upgrade transformers accelerate datasets
RUN pip install flash-attn

ENV PYTHONPATH=/workspace/DeepSpeed:$PYTHONPATH

CMD ["/bin/bash"]

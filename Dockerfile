FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive

# 기본 패키지 및 필수 도구 설치
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    sudo \
    build-essential \
    cmake \
    ninja-build \
    software-properties-common \
    vim \
    gnupg2 \
    libaio-dev \
    net-tools \
    iproute2 \
    inetutils-ping \
    openssh-client \
    libopenmpi-dev \
    openmpi-bin \
    nvidia-cuda-toolkit \
    libnvidia-ml-dev && \
    rm -rf /var/lib/apt/lists/*

# Python 3.11 설치 (Ubuntu 20.04 기본 Python은 3.8이므로 deadsnakes PPA를 사용)
RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.11 python3.11-dev python3.11-distutils

# pip 설치 (Python 3.11 전용)
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# python 기본 명령어를 Python 3.11로 설정
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1

# Intel oneAPI 저장소 추가 및 oneCCL 라이브러리 설치
RUN wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
    | sudo tee /etc/apt/sources.list.d/oneAPI.list && \
    apt-get update && \
    apt-get install -y intel-oneapi-ccl-devel && \
    rm -rf /var/lib/apt/lists/*

# oneAPI 관련 환경변수 설정
ENV ONEAPI_ROOT=/opt/intel/oneapi
ENV PATH=${ONEAPI_ROOT}/compiler/latest/linux/bin/intel64:${PATH}
ENV LD_LIBRARY_PATH=${ONEAPI_ROOT}/compiler/latest/linux/compiler/lib/intel64_lin:${LD_LIBRARY_PATH}
ENV CCL_ROOT=${ONEAPI_ROOT}/ccl/latest

# CUDA 관련 환경변수 설정
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV CUDA_DEVICE_ORDER=PCI_BUS_ID
ENV CUDA_VISIBLE_DEVICES=all

# PyTorch 2.6 (CUDA 12.6 빌드) 및 관련 패키지 설치  
# (주의: torch==2.6.0+cu126 및 extra-index-url는 실제 정식 릴리스 시점에 맞게 수정 필요)
RUN pip install torch==2.6.0+cu126 torchvision torchaudio --extra-index-url https://download.pytorch.org/whl/cu126

# oneCCL 환경변수 설정
ENV LD_LIBRARY_PATH=${CCL_ROOT}/lib:${LD_LIBRARY_PATH}
ENV PKG_CONFIG_PATH=${CCL_ROOT}/lib/pkgconfig:${PKG_CONFIG_PATH}
ENV CPLUS_INCLUDE_PATH=${CCL_ROOT}/include:${CPLUS_INCLUDE_PATH}

# Triton 및 기타 필요한 패키지 설치 (최신 버전으로 업데이트)
RUN pip install --upgrade pip && \
    pip install triton==3.0.0 ninja packaging pydantic


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
RUN pip install flash-attn==2.3.6

# GPU 인식 테스트를 위한 스크립트 생성
RUN echo '#!/bin/bash\n\
echo "===== NVIDIA Driver Information ====="\n\
nvidia-smi\n\
echo "===== PyTorch CUDA Status ====="\n\
python -c "import torch; print(\"CUDA available:\", torch.cuda.is_available()); print(\"CUDA device count:\", torch.cuda.device_count()); print(\"CUDA version:\", torch.version.cuda)"\n\
echo "===== DeepSpeed Status ====="\n\
python -c "import deepspeed; print(\"DeepSpeed version:\", deepspeed.__version__); from deepspeed.accelerator import get_accelerator; print(\"DeepSpeed accelerator:\", get_accelerator().name())"\n\
echo "===== Verifying Triton ====="\n\
python -c "import triton; print(\"Triton version:\", triton.__version__)"\n\
echo "===== Running System ====="\n\
exec "$@"' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

# 컨테이너 시작 시 자동으로 GPU 체크
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]


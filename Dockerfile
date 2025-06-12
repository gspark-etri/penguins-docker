# 1. CUDA 베이스 이미지 선택
FROM nvcr.io/nvidia/pytorch:23.12-py3

# 비대화 모드 설정
ENV DEBIAN_FRONTEND=noninteractive

# 1. 필수 시스템 패키지 설치 (컴파일 도구, Git 등)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        git \
        libssl-dev \
        curl \
        ca-certificates \
        wget \
        gnupg2 \
        vim
RUN apt-get install rdma-core libibverbs1 libibmad5 libibumad3
RUN rm -rf /var/lib/apt/lists/*

RUN wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" \
    | tee /etc/apt/sources.list.d/oneAPI.list && \
    apt-get update && \
    apt-get install -y intel-oneapi-ccl-devel && \
    rm -rf /var/lib/apt/lists/*


# 3. 작업 디렉토리 설정 및 DeepSpeed 소스 클론
WORKDIR /workspace
RUN git clone https://github.com/gspark-etri/penguin.git

WORKDIR /workspace/penguin

# oneCCL 환경변수 설정 (DeepSpeed가 경로 인식하도록)
ENV CCL_ROOT=/opt/intel/oneapi/ccl/latest \
    CPLUS_INCLUDE_PATH=${CCL_ROOT}/include:${CPLUS_INCLUDE_PATH} \
    LD_LIBRARY_PATH=${CCL_ROOT}/lib:${LD_LIBRARY_PATH} \
    PKG_CONFIG_PATH=${CCL_ROOT}/lib/pkgconfig:${PKG_CONFIG_PATH}



# 6. 패키지 버전 문자열 패치 및 Penguin(DeepSpeed) 설치 및 Penguin(DeepSpeed) 설치
RUN pip install .

RUN pip install transformers datasets


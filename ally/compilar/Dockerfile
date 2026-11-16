# EN: Image for building the Windows game on Linux or macOS (used by ally/compilar/compilar.sh).
#     The build context is the repository root: docker build -f ally/compilar/Dockerfile .
# ES: Imagen para compilar el juego de Windows desde Linux o macOS (la usa ally/compilar/compilar.sh).
#     El contexto es la raíz del repositorio: docker build -f ally/compilar/Dockerfile .
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv clang lld llvm git ca-certificates xz-utils unzip make \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt /tmp/req/requirements.txt
COPY nx2/prompt_requirements.txt /tmp/req/nx2/prompt_requirements.txt
RUN python3 -m venv /opt/py && /opt/py/bin/pip install --no-cache-dir -r /tmp/req/requirements.txt
ENV PATH=/opt/py/bin:$PATH
WORKDIR /b/src

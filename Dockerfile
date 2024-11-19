# Lite version
FROM nvidia/cuda:12.4.0-base-ubuntu22.04 AS lite

# Set up environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=UTF-8 \
    PDFJS_PREBUILT_DIR="/tmp/build/app/libs/ktem/ktem/assets/prebuilt/pdfjs-dist" \
    NLTK_DATA="/tmp/build/app/nltk_data" \
    MPLCONFIGDIR="/tmp/build/app/matplotlib" \
    XDG_CACHE_HOME="/tmp/build/app/fontconfig" \
    HOME="/tmp/build" \
    PATH="/tmp/build/.local/bin:$PATH"

# Set up ARGs
ARG TARGETPLATFORM
ARG TARGETARCH

# Use a multi-stage build to install system dependencies
FROM lite AS builder

USER root
RUN apt update -qqy && \
    apt install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    python3.10-venv \
    python3-dev \
    ssh \
    git \
    gcc \
    g++ \
    poppler-utils \
    libpoppler-dev \
    unzip \
    curl \
    cargo \
    vim \
    tesseract-ocr \
    tesseract-ocr-jpn \
    libsm6 \
    libxext6 \
    libreoffice \
    ffmpeg \
    libmagic-dev \
    nvidia-container-toolkit \
    nvidia-cuda-toolkit && \
    rm -rf /var/lib/apt/lists/* && \
    ln -s /usr/bin/python3 /usr/bin/python

# Create required directories with appropriate permissions
RUN mkdir -p /tmp/build/app/libs \
    /tmp/build/app/scripts \
    /tmp/build/app/nltk_data \
    /tmp/build/app/matplotlib \
    /tmp/build/app/fontconfig \
    /tmp/build/.local/bin \
    /tmp/build/.cache/pip && \
    chmod -R g+rwX /tmp/build && \
    chown -R 1001:0 /tmp/build


FROM builder AS dependencies

USER 1001:0
WORKDIR /tmp/build/app
RUN ln -s /storage/ktem_app_data /tmp/build/app/ktem_app_data

# Upgrade pip
RUN python -m pip install --user --upgrade pip

# Download pdfjs
COPY --chown=1001:0 scripts/download_pdfjs.sh /tmp/build/app/scripts/download_pdfjs.sh
RUN bash /tmp/build/app/scripts/download_pdfjs.sh $PDFJS_PREBUILT_DIR

# Copy application files
COPY --chown=1001:0 . /tmp/build/app
COPY --chown=1001:0 .env.example /tmp/build/app/.env

# Install Python packages
RUN python -m pip install --user -e "libs/kotaemon[adv]" && \
    python -m pip install --user -e "libs/ktem" && \
    python -m pip install --user "pdfservices-sdk@git+https://github.com/niallcm/pdfservices-python-sdk.git@bump-and-unfreeze-requirements"

# Conditional installation based on architecture
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    python -m pip install --user "graphrag<=0.3.6" future; \
    fi

# Final stage
FROM dependencies AS lite-final

USER 1001:0
WORKDIR /tmp/build/app

CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "7860"]

# Full version
FROM lite-final AS full

USER 1001:0

# Install torch and related packages
RUN python -m pip install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install additional pip packages
RUN python -m pip install --user -e "libs/kotaemon[adv]" && \
    python -m pip install --user unstructured[all-docs] && \
    python -m pip install --user nltk

# Graphrag fix
RUN python -m pip uninstall --yes hnswlib chroma-hnswlib && \
    python -m pip install --user chroma-hnswlib==0.7.1 && \
    python -m pip install --user nano-graphrag && \
    pip install git+https://github.com/HKUDS/LightRAG.git

# Install lightRAG
ENV USE_LIGHTRAG=true
ENV USE_NANO_GRAPHRAG=true

RUN python -m pip install --user aioboto3 nano-vectordb ollama xxhash lightrag-hku
RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install aioboto3 nano-vectordb ollama xxhash "lightrag-hku<=0.0.8"

RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install "docling<=2.5.2"

RUN python -c "import nltk; nltk.download('punkt', download_dir='/tmp/build/app/nltk_data'); nltk.download('averaged_perceptron_tagger', download_dir='/tmp/build/app/nltk_data')"

RUN pip uninstall --yes hnswlib chroma-hnswlib && pip install chroma-hnswlib

CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "7860"]

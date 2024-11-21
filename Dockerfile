# Lite version
FROM python:3.10-slim AS lite

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

# Add backports repository for missing packages
RUN apt update -qqy && \
    apt install -y --no-install-recommends \
    python3-venv \
    python3-dev \
    ssh \
    git \
    gcc \
    g++ \
    poppler-utils \
    libpoppler-dev \
    unzip \
    curl \
    wget \
    cargo \
    vim \
    tesseract-ocr \
    tesseract-ocr-jpn \
    libsm6 \
    libxext6 \
    libreoffice \
    ffmpeg \
    libmagic-dev && \
    rm -rf /var/lib/apt/lists/*

# Link python3 to python
RUN ln -s /usr/bin/python3 /usr/bin/python

# Create required directories with appropriate permissions
RUN mkdir -p /tmp/build/app/libs \
    /tmp/build/app/scripts \
    /tmp/build/app/nltk_data \
    /tmp/build/app/matplotlib \
    /tmp/build/app/fontconfig \
    /tmp/build/.local/bin \
    /tmp/build/.cache/pip \
    /storage/ktem_app_data && \
    ln -s /storage/ktem_app_data /tmp/build/app/ktem_app_data && \
    chmod -R g+rwX /tmp/build /storage && \
    chown -R 1001:0 /tmp/build /storage

FROM builder AS dependencies

USER 1001:0
WORKDIR /tmp/build/app

# Upgrade pip
RUN python -m pip install --user --upgrade pip

# Create PDF.js directory with correct permissions
RUN mkdir -p $PDFJS_PREBUILT_DIR && \
    chmod -R g+rwX $PDFJS_PREBUILT_DIR && \
    chown -R 1001:0 $PDFJS_PREBUILT_DIR

# Copy application files
COPY --chown=1001:0 . /tmp/build/app
COPY --chown=1001:0 .env.example /tmp/build/app/.env

# Ensure ktem_app_data symlink with minimal intervention
# for now, this is pushed up to the above section and app.py checks it at run time.
#RUN mkdir -p /storage/ktem_app_data && \
#    ln -sfn /storage/ktem_app_data /tmp/build/app/ktem_app_data

# Install torch and torchvision for unstructured
RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Python package installations
RUN python -m pip install --user -e "libs/kotaemon[adv]" && \
    python -m pip install --user -e "libs/ktem" && \
    pip install unstructured[all-docs] && \
    python -m pip install --user "pdfservices-sdk@git+https://github.com/niallcm/pdfservices-python-sdk.git@bump-and-unfreeze-requirements"

# Conditional installation based on architecture
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    python -m pip install --user "graphrag<=0.3.6" future; \
    fi

# Graphrag fix
RUN python -m pip uninstall --yes hnswlib chroma-hnswlib && \
    python -m pip install --user chroma-hnswlib==0.7.1 && \
    python -m pip install --user nano-graphrag
    #pip install git+https://github.com/HKUDS/LightRAG.git

# Install lightRAG
ENV USE_LIGHTRAG=true
RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install aioboto3 nano-vectordb ollama xxhash "lightrag-hku<=0.0.8"

# Install docling
RUN --mount=type=ssh  \
    --mount=type=cache,target=/root/.cache/pip  \
    pip install "docling<=2.5.2"

# Final stage
FROM dependencies AS lite-final

USER 1001:0
WORKDIR /tmp/build/app

CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "7860"]

# Full version
FROM lite-final AS full

USER 1001:0

# Rest of the Dockerfile remains the same as your original

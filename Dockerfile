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
    /tmp/build/.cache/pip && \
    chmod -R g+rwX /tmp/build && \
    chown -R 1001:0 /tmp/build

FROM builder AS dependencies

USER 1001:0
WORKDIR /tmp/build/app

# Verify curl and download tools are working
RUN which curl && curl --version || echo "Curl not found"
RUN which wget && wget --version || echo "Wget not found"

# Upgrade pip
RUN python -m pip install --user --upgrade pip

# Create PDF.js directory with correct permissions
RUN mkdir -p $PDFJS_PREBUILT_DIR && \
    chmod -R g+rwX $PDFJS_PREBUILT_DIR && \
    chown -R 1001:0 $PDFJS_PREBUILT_DIR

# Download pdfjs using a more robust method
COPY --chown=1001:0 scripts/download_pdfjs.sh /tmp/build/app/scripts/download_pdfjs.sh
RUN chmod +x /tmp/build/app/scripts/download_pdfjs.sh && \
    # Fallback method if script fails
    bash /tmp/build/app/scripts/download_pdfjs.sh $PDFJS_PREBUILT_DIR || \
    (wget https://github.com/mozilla/pdf.js/releases/download/v4.0.379/pdfjs-4.0.379-dist.zip -O $PDFJS_PREBUILT_DIR/downloaded.zip && \
     unzip $PDFJS_PREBUILT_DIR/downloaded.zip -d $PDFJS_PREBUILT_DIR && \
     rm $PDFJS_PREBUILT_DIR/downloaded.zip)

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

# Prepare for ktem_app_data persistence
RUN mkdir -p /storage/ktem_app_data && \
    if [ -d "/tmp/build/app/ktem_app_data" ]; then \
        cp -r /tmp/build/app/ktem_app_data/* /storage/ktem_app_data/ 2>/dev/null || true; \
    fi && \
    rm -rf /tmp/build/app/ktem_app_data && \
    ln -s /storage/ktem_app_data /tmp/build/app/ktem_app_data

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

# Rest of the Dockerfile remains the same...

CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "7860"]
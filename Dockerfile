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
    PATH="/tmp/build/.local/bin:$PATH" \
    KTEM_APP_DATA_PATH="/storage/ktem_app_data"

# Set up ARGs
ARG TARGETPLATFORM
ARG TARGETARCH

# Use a multi-stage build to install system dependencies
FROM lite AS builder

# Previous builder stage remains the same...

FROM builder AS dependencies

USER 1001:0
WORKDIR /tmp/build/app

# Upgrade pip
RUN python -m pip install --user --upgrade pip

# Download pdfjs
COPY --chown=1001:0 scripts/download_pdfjs.sh /tmp/build/app/scripts/download_pdfjs.sh
RUN bash /tmp/build/app/scripts/download_pdfjs.sh $PDFJS_PREBUILT_DIR

# Copy application files
COPY --chown=1001:0 . /tmp/build/app
COPY --chown=1001:0 .env.example /tmp/build/app/.env

# Create storage directory and set up symbolic link
RUN mkdir -p /storage/ktem_app_data && \
    if [ -d "/tmp/build/app/ktem_app_data" ]; then \
        cp -r /tmp/build/app/ktem_app_data/* /storage/ktem_app_data/ && \
        rm -rf /tmp/build/app/ktem_app_data; \
    fi && \
    ln -s /storage/ktem_app_data /tmp/build/app/ktem_app_data

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

# Remaining stages are the same...

CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "7860"]
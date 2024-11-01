# Lite version
FROM python:3.10-slim AS lite

# Non-root user setup
ARG USERNAME=appuser
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Create non-root user
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME}

# Common dependencies with non-root considerations
RUN apt-get update -qqy && \
    apt-get install -y --no-install-recommends \
    ssh \
    git \
    gcc \
    g++ \
    poppler-utils \
    libpoppler-dev \
    unzip \
    curl \
    cargo

# Setup args
ARG TARGETPLATFORM
ARG TARGETARCH

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=UTF-8
ENV TARGETARCH=${TARGETARCH}
# Add local bin to PATH for user-installed scripts
ENV PATH="/home/${USERNAME}/.local/bin:${PATH}"

# Create working directory with correct permissions
WORKDIR /app
RUN chown -R ${USERNAME}:${USERNAME} /app

# Switch to non-root user
USER ${USERNAME}

# Download pdfjs
COPY --chown=${USERNAME}:${USERNAME} scripts/download_pdfjs.sh /app/scripts/download_pdfjs.sh
RUN chmod +x /app/scripts/download_pdfjs.sh
ENV PDFJS_PREBUILT_DIR="/app/libs/ktem/ktem/assets/prebuilt/pdfjs-dist"
RUN bash scripts/download_pdfjs.sh $PDFJS_PREBUILT_DIR

# Copy contents
COPY --chown=${USERNAME}:${USERNAME} . /app
COPY --chown=${USERNAME}:${USERNAME} .env.example /app/.env

# Install pip packages without mounts
RUN pip install --user --no-cache-dir -e "libs/kotaemon" && \
    pip install --user --no-cache-dir future theflow python-decouple && \
    pip install --user --no-cache-dir -e "libs/ktem" && \
    pip install --user --no-cache-dir "pdfservices-sdk@git+https://github.com/niallcm/pdfservices-python-sdk.git@bump-and-unfreeze-requirements"

# Install architecture-specific packages
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    pip install --user --no-cache-dir graphrag future; \
    fi

CMD ["python", "app.py"]

# Full version
FROM lite AS full

# Switch back to root temporarily to install additional system packages
USER root

# Additional dependencies for full version
RUN apt-get update -qqy && \
    apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-jpn \
    libsm6 \
    libxext6 \
    libreoffice \
    ffmpeg \
    libmagic-dev

# Switch back to non-root user
USER ${USERNAME}

# Install torch and torchvision for unstructured without mounts
RUN pip install --user --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install additional pip packages without mounts
RUN pip install --user --no-cache-dir -e "libs/kotaemon[adv]" && \
     pip install --user --no-cache-dir future theflow python-decouple && \
    pip install --user --no-cache-dir unstructured[all-docs]

# Download NLTK packages explicitly
RUN pip install --user --no-cache-dir nltk && \
    python -c "import nltk; nltk.download('punkt', download_dir=nltk.data.path[0]); nltk.download('averaged_perceptron_tagger', download_dir=nltk.data.path[0])"

CMD ["python", "app.py"]

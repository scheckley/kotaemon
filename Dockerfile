FROM python:3.10-slim

# Non-root user setup
ARG USERNAME=appuser
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Create non-root user
RUN groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid ${USER_UID} --gid ${USER_GID} -m ${USERNAME}

# Set HOME and PATH for user
ENV HOME=/home/${USERNAME} \
    PATH=/home/${USERNAME}/.local/bin:$PATH

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
    cargo \
    tesseract-ocr \
    tesseract-ocr-jpn \
    libsm6 \
    libxext6 \
    libreoffice \
    ffmpeg \
    libmagic-dev

# Setup args
ARG TARGETPLATFORM
ARG TARGETARCH

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=UTF-8
ENV TARGETARCH=${TARGETARCH}

# Create working directory with correct permissions
WORKDIR /app
RUN chown -R ${USERNAME}:${USERNAME} /app

# Create .local directory with correct permissions
RUN mkdir -p ${HOME}/.local/bin && \
    chown -R ${USERNAME}:${USERNAME} ${HOME}/.local

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

# Install pip packages
RUN pip install --user --no-cache-dir wheel && \
    pip install --user --no-cache-dir -e "libs/kotaemon" && \
    pip install --user --no-cache-dir future python-decouple theflow==0.1.6 && \
    pip install --user --no-cache-dir -e "libs/ktem" && \
    pip install --user --no-cache-dir "pdfservices-sdk@git+https://github.com/niallcm/pdfservices-python-sdk.git@bump-and-unfreeze-requirements"

# Install architecture-specific packages
RUN if [ "$TARGETARCH" = "amd64" ]; then \
    pip install --user --no-cache-dir graphrag future; \
    fi

# Install torch and additional packages
RUN pip install --user --no-cache-dir torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu && \
    pip install --user --no-cache-dir -e "libs/kotaemon[adv]" && \
    pip install --user --no-cache-dir unstructured[all-docs]

# Download NLTK packages explicitly
RUN pip install --user --no-cache-dir nltk && \
    python -c "import nltk; nltk.download('punkt', download_dir=nltk.data.path[0]); nltk.download('averaged_perceptron_tagger', download_dir=nltk.data.path[0])"

# Verify theflow installation
RUN pip freeze | grep theflow && \
    python -c "import theflow; print(theflow.__file__)"

CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "7860"]

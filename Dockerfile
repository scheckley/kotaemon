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

# Install torch and torchvision for unstructured
RUN --mount=type=ssh \
    --mount=type=cache,target=/home/${USERNAME}/.cache/pip \
    pip install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# Install additional pip packages
RUN --mount=type=ssh \
    --mount=type=cache,target=/home/${USERNAME}/.cache/pip \
    pip install --user -e "libs/kotaemon[adv]" \
    && pip install --user unstructured[all-docs]

# Download NLTK packages explicitly
RUN pip install --user nltk && \
    python -c "import nltk; nltk.download('punkt', download_dir=nltk.data.path[0]); nltk.download('averaged_perceptron_tagger', download_dir=nltk.data.path[0])"

CMD ["python", "app.py"]
# syntax=docker/dockerfile:1.0.0-experimental
FROM python:3.10-slim as base_image

# Install necessary packages
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
    && apt-get clean \
    && apt-get autoremove \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=UTF-8

# Set working directory
WORKDIR /app

# Ensure the directory is accessible by any user
RUN chmod -R 775 /app

# Set up NLTK data directory for cache
ENV NLTK_DATA=/app/nltk_data
RUN mkdir -p /app/nltk_data && chmod -R 775 /app/nltk_data

FROM base_image as dev

# Copy and prepare the script
COPY scripts/download_pdfjs.sh /app/scripts/download_pdfjs.sh
RUN chmod +x /app/scripts/download_pdfjs.sh

# Set PDFJS directory
ENV PDFJS_PREBUILT_DIR="/app/libs/ktem/ktem/assets/prebuilt/pdfjs-dist"

# Run the script
RUN bash scripts/download_pdfjs.sh $PDFJS_PREBUILT_DIR

# Copy the app and install dependencies
COPY . /app

RUN --mount=type=ssh pip install --no-cache-dir -e "libs/kotaemon[all]" \
    && pip install --no-cache-dir -e "libs/ktem" \
    && pip install --no-cache-dir graphrag future theflow python-decouple llama-cpp-python \
    && pip install --no-cache-dir "pdfservices-sdk@git+https://github.com/niallcm/pdfservices-python-sdk.git@bump-and-unfreeze-requirements" \
    && pip uninstall decouple

# Ensure the application is accessible by any user
RUN chmod -R 775 /app

# Expose the apps default port
EXPOSE 7860

# Let OpenShift automatically assign a random user
USER 1001

# Make sure the application binds to 0.0.0.0 instead of 127.0.0.1
CMD ["python", "app.py", "--host", "0.0.0.0", "--port", "7860"]

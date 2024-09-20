# syntax=docker/dockerfile:1.0.0-experimental
FROM python:3.10-slim as base_image

# Create a non-root user
RUN groupadd -g 1001 appuser && useradd -u 1001 -g appuser appuser


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

# Change ownership of the working directory
RUN chown -R appuser:appuser /app

FROM base_image as dev

# Copy and prepare the script
COPY scripts/download_pdfjs.sh /app/scripts/download_pdfjs.sh
RUN chmod +x /app/scripts/download_pdfjs.sh

USER root

# Set PDFJS directory
ENV PDFJS_PREBUILT_DIR="/app/libs/ktem/ktem/assets/prebuilt/pdfjs-dist"

# Run the script as a non-root user
RUN bash scripts/download_pdfjs.sh $PDFJS_PREBUILT_DIR

# Copy the app and install dependencies as non-root user
COPY --chown=appuser:appuser . /app

RUN --mount=type=ssh pip install --no-cache-dir -e "libs/kotaemon[all]" \
    && pip install --no-cache-dir -e "libs/ktem" \
    && pip install --no-cache-dir graphrag future theflow python-decouple \
    && pip install --no-cache-dir "pdfservices-sdk@git+https://github.com/niallcm/pdfservices-python-sdk.git@bump-and-unfreeze-requirements" \
    && pip uninstall decouple

# Specify the user to run the container
USER appuser

CMD ["python", "app.py"]

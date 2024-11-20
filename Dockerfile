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

# Rest of the Dockerfile remains the same...

FROM dependencies AS dependencies-final

USER 1001:0
WORKDIR /tmp/build/app

# Simplified ktem_app_data handling
RUN if [ ! -d "/storage/ktem_app_data" ]; then \
        mkdir -p /storage/ktem_app_data; \
    fi && \
    if [ -d "/tmp/build/app/ktem_app_data" ]; then \
        cp -r /tmp/build/app/ktem_app_data/* /storage/ktem_app_data/ 2>/dev/null || true; \
    fi && \
    rm -rf /tmp/build/app/ktem_app_data && \
    ln -s /storage/ktem_app_data /tmp/build/app/ktem_app_data

# Rest of the Dockerfile continues as before
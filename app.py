import subprocess
import os
from pathlib import Path

def ensure_directory_permissions(directory: Path, mode: str = "g+rwX"):
    try:
        # First ensure the directory exists
        directory.mkdir(parents=True, exist_ok=True)
        
        # Alternative: Use os module instead of subprocess
        for root, dirs, files in os.walk(str(directory)):
            for dir in dirs:
                os.chmod(os.path.join(root, dir), 0o775)  # Equivalent to g+rwX
            for file in files:
                os.chmod(os.path.join(root, file), 0o664)  # Read/write for group
        
        print(f"Successfully set permissions on {directory}")
    except Exception as e:
        print(f"Permission setting error: {e}")
        # Consider whether to raise or just log

def ensure_symlink():
    source = Path("/storage/ktem_app_data")
    symlink = Path("/tmp/build/app/ktem_app_data")
    gradio_tmp = source / "gradio_tmp"

    # Ensure the PVC mount point exists and is writable
    if not source.parent.exists():
        raise FileNotFoundError(f"The parent directory {source.parent} does not exist. Is the PVC mounted correctly?")

    # Create and set permissions on the source directory if it doesn't exist
    if not source.exists():
        print(f"Creating target directory: {source}")
        ensure_directory_permissions(source)
    else:
        # If it exists, ensure permissions are correct
        ensure_directory_permissions(source)
    
    # Specifically ensure gradio_tmp directory exists and has correct permissions
    gradio_tmp.mkdir(parents=True, exist_ok=True)
    ensure_directory_permissions(gradio_tmp)

    # Ensure the symlink exists and points correctly
    if symlink.is_symlink() and symlink.resolve() == source:
        print(f"Symbolic link {symlink} already exists and is correct.")
    else:
        if symlink.exists() or symlink.is_file():
            symlink.unlink()  # Remove any existing file/symlink
        symlink.symlink_to(source)
        print(f"Created symbolic link: {symlink} -> {source}")

# Ensure the symlink before starting the app
ensure_symlink()

from theflow.settings import settings as flowsettings

KH_APP_DATA_DIR = getattr(flowsettings, "KH_APP_DATA_DIR", ".")
GRADIO_TEMP_DIR = os.getenv("GRADIO_TEMP_DIR", None)
# override GRADIO_TEMP_DIR if it's not set
if GRADIO_TEMP_DIR is None:
    GRADIO_TEMP_DIR = os.path.join(KH_APP_DATA_DIR, "gradio_tmp")
    os.environ["GRADIO_TEMP_DIR"] = GRADIO_TEMP_DIR

from ktem.main import App  # noqa

app = App()
demo = app.make()
demo.queue().launch(
    favicon_path=app._favicon,
    inbrowser=True,
    allowed_paths=[
        "libs/ktem/ktem/assets",
        GRADIO_TEMP_DIR,
    ],
    server_name="0.0.0.0",
)

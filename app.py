import subprocess
import os
from pathlib import Path

def ensure_directory_permissions(directory: Path, mode: str = "g+rwX"):
    """
    Recursively ensure proper permissions on a directory and its contents.
    
    Args:
        directory (Path): Directory to set permissions on
        mode (str): chmod mode to apply
    """
    try:
        # First ensure the directory exists
        directory.mkdir(parents=True, exist_ok=True)
        
        # Apply permissions recursively
        subprocess.run(
            ["chmod", "-R", mode, str(directory)],
            check=True,
            capture_output=True
        )
        
        print(f"Successfully set permissions {mode} on {directory}")
    except subprocess.CalledProcessError as e:
        print(f"Failed to set permissions on {directory}: {e.stderr.decode()}")
        raise
    except Exception as e:
        print(f"Unexpected error while setting permissions on {directory}: {e}")
        raise

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
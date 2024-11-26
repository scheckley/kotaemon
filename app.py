import os
import subprocess
from pathlib import Path

def ensure_directory_permissions(directory: Path, uid: int = 1001, gid: int = 0, mode: str = "775"):
    """
    Recursively ensure proper permissions on a directory and its contents.
    
    Args:
        directory (Path): Directory to set permissions on
        uid (int): User ID to set ownership to (default 1001)
        gid (int): Group ID to set ownership to (default 0 for root group)
        mode (str): chmod mode to apply
    """
    try:
        # Ensure the directory exists
        directory.mkdir(parents=True, exist_ok=True)
        
        # Attempt to change ownership
        try:
            # First try Python's os.chown
            os.chown(str(directory), uid, gid)
        except PermissionError:
            print(f"Python os.chown failed for {directory}")
            
            # Fallback to subprocess chown
            try:
                subprocess.run(
                    ["chown", "-R", f"{uid}:{gid}", str(directory)],
                    check=True,
                    capture_output=True,
                    text=True
                )
            except subprocess.CalledProcessError as e:
                print(f"Subprocess chown failed for {directory}: {e}")
        
        # Apply group read/write/execute permissions
        try:
            subprocess.run(
                ["chmod", "-R", mode, str(directory)],
                check=True,
                capture_output=True,
                text=True
            )
        except subprocess.CalledProcessError as e:
            print(f"Chmod failed for {directory}: {e}")
        
        print(f"Processed directory: {directory}")
    except Exception as e:
        print(f"Unexpected error processing {directory}: {e}")

def ensure_gradio_temp_directory():
    """
    Ensure Gradio temp directory is correctly set up and accessible
    """
    # Determine Gradio temp directory
    storage_base = Path("/storage/ktem_app_data")
    gradio_tmp = storage_base / "gradio_tmp"
    
    # Create base storage directory if it doesn't exist
    storage_base.mkdir(parents=True, exist_ok=True)
    
    # Create Gradio temp directory if it doesn't exist
    gradio_tmp.mkdir(parents=True, exist_ok=True)
    
    # Set permissions
    ensure_directory_permissions(storage_base)
    ensure_directory_permissions(gradio_tmp)
    
    # Set the environment variable for Gradio temp directory
    os.environ["GRADIO_TEMP_DIR"] = str(gradio_tmp)
    print(f"Gradio temp directory set to: {gradio_tmp}")

# Call this before importing Gradio or launching the app
ensure_gradio_temp_directory()

# Rest of your app.py continues...
from theflow.settings import settings as flowsettings

KH_APP_DATA_DIR = getattr(flowsettings, "KH_APP_DATA_DIR", ".")
GRADIO_TEMP_DIR = os.getenv("GRADIO_TEMP_DIR")

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

import subprocess
import os
import grp
import pwd
from pathlib import Path

def safe_chown(path, uid=-1, gid=-1):
    """
    Safely attempt to change ownership of a path
    
    Args:
        path (Path or str): Path to change ownership
        uid (int): User ID to change to (-1 means no change)
        gid (int): Group ID to change to (-1 means no change)
    """
    try:
        # Convert Path to string if needed
        path_str = str(path)
        
        # First, try Python's os.chown
        try:
            os.chown(path_str, uid, gid)
            print(f"Successfully changed ownership of {path_str} using os.chown")
            return
        except PermissionError:
            print(f"os.chown failed for {path_str}, falling back to subprocess")
        
        # If os.chown fails, try subprocess with different strategies
        try:
            # First attempt: standard chown
            subprocess.run(
                ["chown", f"{uid}:{gid}", path_str],
                check=True,
                capture_output=True,
                text=True
            )
            print(f"Successfully changed ownership of {path_str} using chown")
            return
        except subprocess.CalledProcessError as e:
            print(f"Standard chown failed: {e}")
        
        # Recursive chown attempt
        try:
            subprocess.run(
                ["chown", "-R", f"{uid}:{gid}", path_str],
                check=True,
                capture_output=True,
                text=True
            )
            print(f"Successfully changed ownership recursively of {path_str}")
            return
        except subprocess.CalledProcessError as e:
            print(f"Recursive chown failed: {e}")
        
        # Final detailed error logging
        print(f"ALL CHOWN METHODS FAILED for {path_str}")
    except Exception as e:
        print(f"Unexpected error changing ownership of {path}: {e}")

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
        # First ensure the directory exists
        directory.mkdir(parents=True, exist_ok=True)
        
        # Attempt to change ownership
        safe_chown(directory, uid, gid)
        
        # Apply group read/write/execute permissions
        try:
            subprocess.run(
                ["chmod", "-R", mode, str(directory)],
                check=True,
                capture_output=True,
                text=True
            )
            print(f"Successfully set permissions {mode} on {directory}")
        except subprocess.CalledProcessError as e:
            print(f"Failed to set permissions on {directory}: {e}")
            # Log the error but don't raise to allow partial success
    
    except Exception as e:
        print(f"Unexpected error while setting permissions on {directory}: {e}")
        raise

def ensure_symlink():
    source = Path("/storage/ktem_app_data")
    symlink = Path("/tmp/build/app/ktem_app_data")
    gradio_tmp = source / "gradio_tmp"

    # Debug: Print current environment and user information
    print("Current Process Information:")
    print(f"UID: {os.getuid()}")
    print(f"GID: {os.getgid()}")
    try:
        print(f"Username: {pwd.getpwuid(os.getuid()).pw_name}")
        print(f"Group: {grp.getgrgid(os.getgid()).gr_name}")
    except Exception as e:
        print(f"Could not retrieve user/group names: {e}")

    # Ensure the PVC mount point exists and is writable
    if not source.parent.exists():
        raise FileNotFoundError(f"The parent directory {source.parent} does not exist. Is the PVC mounted correctly?")

    # Create and set permissions on the source directory if it doesn't exist
    if not source.exists():
        print(f"Creating target directory: {source}")
        source.mkdir(parents=True, exist_ok=True)
    
    # Set permissive group permissions on the main directory and its subdirectories
    # Using 1001:0 ownership explicitly
    ensure_directory_permissions(source, uid=1001, gid=0)
    
    # Specifically ensure gradio_tmp directory exists and has correct permissions
    gradio_tmp.mkdir(parents=True, exist_ok=True)
    ensure_directory_permissions(gradio_tmp, uid=1001, gid=0)

    # Ensure the symlink exists and points correctly
    if symlink.is_symlink() and symlink.resolve() == source:
        print(f"Symbolic link {symlink} already exists and is correct.")
    else:
        if symlink.exists() or symlink.is_file():
            symlink.unlink()  # Remove any existing file/symlink
        symlink.symlink_to(source)
        print(f"Created symbolic link: {symlink} -> {source}")

    # Final debugging: verify permissions
    def debug_path_info(path):
        try:
            stat_info = os.stat(path)
            print(f"\nPath: {path}")
            print(f"Owner UID: {stat_info.st_uid}")
            print(f"Group GID: {stat_info.st_gid}")
            print(f"Permissions: {oct(stat_info.st_mode)[-3:]}")
        except Exception as e:
            print(f"Could not get info for {path}: {e}")
    
    debug_path_info(source)
    debug_path_info(gradio_tmp)

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

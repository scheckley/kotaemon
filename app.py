import os
from pathlib import Path

def ensure_symlink():
    source = Path("/storage/ktem_app_data")
    symlink = Path("/tmp/build/app/ktem_app_data")

    # Ensure the PVC mount point exists and is writable
    if not source.parent.exists():
        raise FileNotFoundError(f"The parent directory {source.parent} does not exist. Is the PVC mounted correctly?")

    # Create the source directory if it doesn't exist
    if not source.exists():
        print(f"Creating target directory: {source}")
        source.mkdir(parents=True, exist_ok=True)

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

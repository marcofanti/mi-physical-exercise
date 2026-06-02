from .counselor import CAMI
from .env import Env

def __getattr__(name):
    if name != "Client":
        raise AttributeError(name)

    try:
        from .client import Client
    except Exception as exc:
        raise ImportError(
            "Client requires the batch-simulation dependencies. "
            "Install them with: uv pip install torch torchvision transformers"
        ) from exc

    return Client


__all__ = ["CAMI", "Env", "Client"]

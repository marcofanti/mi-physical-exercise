import os
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()

_PROVIDER = os.getenv("LLM_PROVIDER", "openai").lower()


def build_client(provider: str | None = None) -> OpenAI:
    provider = (provider or _PROVIDER).lower()
    timeout = float(os.getenv("LLM_TIMEOUT_SECONDS", "20"))
    client_options = {"timeout": timeout, "max_retries": 0}
    if provider == "ollama":
        base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434").rstrip("/")
        if not base_url.endswith("/v1"):
            base_url += "/v1"
        return OpenAI(api_key="ollama", base_url=base_url, **client_options)
    if provider == "gemini":
        return OpenAI(
            api_key=os.getenv("GEMINI_API_KEY"),
            base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
            **client_options,
        )
    return OpenAI(
        api_key=os.getenv("OPENAI_API_KEY") or "missing-openai-api-key",
        base_url=os.getenv("OPENAI_BASE_URL"),
        **client_options,
    )


def default_model(provider: str | None = None) -> str:
    provider = (provider or _PROVIDER).lower()
    if provider == "ollama":
        return os.getenv("OLLAMA_MODEL", "llama3.2")
    if provider == "gemini":
        return os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
    return os.getenv("OPENAI_MODEL", "gpt-4o-2024-08-06")


client = build_client()
DEFAULT_MODEL = default_model()

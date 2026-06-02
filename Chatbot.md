# Exercise Chatbot Runbook

This project has two Streamlit chatbot apps for motivational interviewing around
physical exercise:

- `exercise_app.py`: local Ollama-backed chatbot.
- `openai_exercise_app.py`: OpenAI-backed chatbot for comparison.

Both apps use `V8-Decision Tree.md` as the visible and functional
exercise-barrier map.

## 1. Install `uv`

If `uv` is not installed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Verify:

```bash
uv --version
```

## 2. Sync Dependencies

From the project root:

```bash
uv sync
```

This installs the UI dependencies from `pyproject.toml`.

Batch simulation dependencies are optional and not needed for the chatbots. If
you need `generate.py`, install the batch extra:

```bash
uv sync --extra batch
```

## 3. Configure `.env`

Copy the example file if needed:

```bash
cp .env.example .env
```

### Ollama Chatbot

For the local Ollama chatbot, make sure Ollama is running and the model is
available:

```bash
ollama serve
ollama pull gemma4:latest
```

Use this `.env` setup:

```env
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=gemma4:latest
```

Optional: use a smaller model for faster exercise-chatbot responses:

```env
OLLAMA_FAST_MODEL=llama3.2
```

### OpenAI Chatbot

Use this `.env` setup:

```env
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o
```

Create an API key here:

```text
https://platform.openai.com/api-keys
```

If the OpenAI chatbot returns `429 insufficient_quota`, the key is valid but the
account needs billing or available quota:

```text
https://platform.openai.com/settings/organization/billing
```

## 4. Run the Ollama Exercise Chatbot

```bash
uv run streamlit run exercise_app.py --server.headless true --server.port 8503
```

Open:

```text
http://localhost:8503
```

## 5. Run the OpenAI Exercise Chatbot

```bash
uv run streamlit run openai_exercise_app.py --server.headless true --server.port 8504
```

Open:

```text
http://localhost:8504
```

## 6. Stop a Running Server

Press `Ctrl-C` in the terminal where the Streamlit server is running.

If a port is stuck, find and stop the listener:

```bash
lsof -nP -iTCP:8503 -sTCP:LISTEN
kill <PID>
```

Use `8504` instead of `8503` for the OpenAI chatbot.

## 7. Notes

- The Ollama app defaults to provider `ollama` even if `LLM_PROVIDER` is set to
  something else.
- The OpenAI app forces provider `openai`.
- The OpenAI app will load without a key, but it cannot generate responses until
  `OPENAI_API_KEY` is set.
- Both apps use one model call per user turn for speed.


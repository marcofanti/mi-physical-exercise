# CAMI – Developer Notes

## What this project is

CAMI is a research implementation of a Motivational Interviewing (MI) counselor agent.
Published at ACL 2025: [CAMI: A Counselor Agent Supporting Motivational Interviewing through State Inference and Topic Exploration](https://aclanthology.org/2025.acl-long.1024/).

The agent uses the **STAR framework**:
- **S**tate Inference — infers the client's readiness stage (Precontemplation / Contemplation / Preparation) from the TTM model
- **T**opic Exploration — navigates a topic graph (Health → Diseases → COPD, etc.) to find what motivates the client
- **A**ction / Strategy Selection — picks MI strategies (Reflect, Open Question, Affirm, Reframe, etc.)
- **R**esponse Generation & Ranking — generates 3 candidate responses, ranks them, then self-refines

The original code ran only as a **batch simulation**: both counselor and client are LLMs, iterated over `annotations/profiles.jsonl` and saved to text files.

---

## What was changed from the original repo

### 1. LLM provider abstraction (`agents/llm.py`)

The original code hardcoded `OpenAI(api_key=..., base_url=...)` in both `agents/counselor.py` and `agents/client.py`, and the model was a CLI-only `--model` argument with no default from the environment.

**New file: `agents/llm.py`**

Reads `LLM_PROVIDER` from `.env` and builds the appropriate OpenAI-compatible client:

```python
from agents.llm import client, DEFAULT_MODEL
```

Exports two things used by the rest of the code:
- `client` — an `openai.OpenAI` instance pointed at the right endpoint
- `DEFAULT_MODEL` — the model name resolved from env vars

Provider routing:

| `LLM_PROVIDER` | endpoint | auth env var | model env var |
|---|---|---|---|
| `openai` (default) | `OPENAI_BASE_URL` or default | `OPENAI_API_KEY` | `OPENAI_MODEL` |
| `ollama` | `OLLAMA_BASE_URL/v1` | hardcoded `"ollama"` | `OLLAMA_MODEL` |
| `gemini` | Google's OpenAI-compat endpoint | `GEMINI_API_KEY` | `GEMINI_MODEL` |

Gemini uses the OpenAI-compatible endpoint at `https://generativelanguage.googleapis.com/v1beta/openai/` so no SDK change is needed.

### 2. `agents/counselor.py` and `agents/client.py`

Both files previously duplicated the same OpenAI setup block. That block was removed and replaced with:

```python
from .llm import client as openai_client, DEFAULT_MODEL
```

All three helper functions (`get_chatbot_response`, `get_precise_response`, `get_json_response`) now default to `model=DEFAULT_MODEL` instead of the hardcoded `"gpt-4o-2024-08-06"`.

### 3. `generate.py`

- Added `from dotenv import load_dotenv; load_dotenv()` at the top so `.env` is loaded before anything else
- `--model` CLI argument is now optional (default `None`); if omitted, falls back to `DEFAULT_MODEL` from `agents/llm.py`

### 4. `agents/__init__.py`

Made the `Client` import conditional so the Streamlit app works without `torch`/`transformers` installed:

```python
from .counselor import CAMI
from .env import Env
try:
    from .client import Client
except ImportError:
    Client = None  # torch not installed; Client unavailable
```

`generate.py` still requires torch (it uses Client). The Streamlit UI does not.

### 5. `.env.example`

Created as a template showing all three provider configurations. Copy to `.env` and fill in credentials.

### 6. `app.py` — Streamlit interactive UI

New file. Lets a human play the **client** role while CAMI acts as the AI counselor. The original `generate.py` simulation loop (both sides are LLMs) is not used here — only the `CAMI` counselor agent is instantiated.

---

## File layout

```
CAMI/
├── agents/
│   ├── __init__.py        # CAMI, Env (Client conditional on torch)
│   ├── llm.py             # NEW: provider factory, client + DEFAULT_MODEL
│   ├── counselor.py       # CAMI agent — all LLM calls go through llm.py
│   ├── client.py          # Simulated client agent (requires torch)
│   └── env.py             # Simulation loop (batch mode)
├── annotations/
│   └── profiles.jsonl     # 38 client profiles (topic, behavior, personas, …)
├── wikipedias/            # Wikipedia passages for retrieval (used by Client)
├── figures/               # Paper diagrams
├── app.py                 # NEW: Streamlit interactive UI
├── generate.py            # Original batch simulation entry point
├── .env                   # Local secrets — never commit
├── .env.example           # Template for .env
├── AGENTS.md              # This file
└── README.md              # Original paper README
```

---

## Environment setup

### 1. Install uv (if not already installed)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Verify: `uv --version` (tested with 0.9.8).

### 2. Create and activate the virtual environment

```bash
# From the project root
uv venv                        # creates .venv/ using your system Python
source .venv/bin/activate      # macOS / Linux
# .venv\Scripts\activate       # Windows
```

To use a specific Python version:
```bash
uv venv --python 3.12
```

### 3. Install dependencies

```bash
uv pip install -r requirements.txt
```

`requirements.txt` installs the core packages + Streamlit UI deps.
The `torch` / `transformers` lines are commented out by default — uncomment them
if you also want to run the batch simulation (`generate.py`):

```bash
# Uncomment torch lines in requirements.txt first, then:
uv pip install -r requirements.txt
```

Or install them directly without editing the file:
```bash
uv pip install torch transformers
```

### Configure `.env`

Copy `.env.example` to `.env` and fill in the relevant section for your provider.

**Ollama (current local setup):**
```env
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=gemma4:latest
```

**OpenAI:**
```env
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o
```

**Gemini:**
```env
LLM_PROVIDER=gemini
GEMINI_API_KEY=AIza...
GEMINI_MODEL=gemini-2.5-flash
```

> Note: the inline comment on `OLLAMA_MODEL=gemma4:latest  # Or your preferred model`
> is parsed correctly by `python-dotenv >= 1.0`. If you see the comment included in the
> model name, upgrade python-dotenv or remove the inline comment.

---

## Running the Streamlit UI

```bash
streamlit run app.py
```

**What the UI does:**

- **Sidebar — Session Setup**: pick one of 8 unique topic presets from `profiles.jsonl`
  (reducing drug use, smoking cessation, reducing alcohol, more activity, etc.) or enter
  a custom goal + behavior. Model field is pre-filled from `.env`.
  Click **▶ Start / Reset Session** to initialize a fresh CAMI instance.

- **Sidebar — CAMI Internal State** (updates after every turn):
  - 🔴/🟡/🟢 Client Stage (Precontemplation / Contemplation / Preparation)
  - Current Topic being explored + the topic navigation path
  - Exploration Move: Step Into ⬇️ / Switch ↔️ / Step Out ⬆️ / Stay 📍
  - Strategy Used + list of candidate strategies considered
  - Expandable panels: strategy selection reasoning, topic exploration reasoning

- **Main area**: chat interface. You type as the client; CAMI responds as the counselor.
  A spinner shows while CAMI processes (it makes 5–8 LLM calls per turn).

**Speed note**: each CAMI turn involves state inference + topic exploration + strategy
selection + 3 candidate response generations + response ranking + up to 3 self-refinement
rounds. With a local Ollama model this may take 30–60 s per turn depending on hardware.

---

## Running the batch simulation (original mode)

First make sure `torch` and `transformers` are installed (see Environment setup above), then:

```bash
python generate.py \
    --retriever_path BAAI/bge-reranker-v2-m3 \
    --profile_path ./annotations/profiles.jsonl \
    --output_dir Output/ \
    --round 5 \
    --max_turns 25
# --model is optional; falls back to DEFAULT_MODEL from .env
```

The retriever model (`bge-reranker-v2-m3`) is downloaded automatically from HuggingFace
on first run.

---

## How CAMI's reply is structured

`CAMI.reply()` returns a single string with metadata prepended in brackets:

```
[Inferred State: Precontemplation || Strategy Selection: <reasoning> || Strategies: ['Open Question', 'Support'] || Final Strategy: Open Question || Topic: Health || Exploration Action: Switch || Exploration: <reasoning>] Counselor: <response text>
```

The Streamlit app parses this with `parse_reply()` in `app.py` by splitting on `"] Counselor: "`. The metadata dict feeds the sidebar state panel; only the clean counselor text goes into the chat.

In `generate.py` / `env.py`, the metadata prefix is stripped via `clean_utterance()` (a recursive regex that removes all `[...]` blocks) before the response is fed back into the conversation context.

---

## Topic graph

The topic graph has three levels:

```
Superclass (5):  Health, Economy, Interpersonal Relationships, Law, Education
Coarse (14):     Diseases, Fitness, Mental Disorders, Employment, Personal Finance, …
Fine (59):       COPD, Depression, Diabetes, Debt, Arrest, …
```

All topic labels correspond to Wikipedia article titles. The `wikipedias/` directory
contains the passages used for retrieval-based topic perception in the Client agent.

Navigation operations used during Precontemplation:
- **Step Into** — client shows interest → drill into a sub-topic
- **Switch** — client interested in parent but not this topic → sibling topic
- **Step Out** — client disengaged → back up to parent level

---

## Known limitations / watch-outs

- `get_json_response` in `counselor.py` uses `ResponseFormatJSONObject` from the OpenAI
  types. Ollama and Gemini support `{"type": "json_object"}` for most models but not all
  — if JSON extraction fails, CAMI falls back to `random.choice`.

- The `Client` agent is not used in the Streamlit UI. Its retriever (BGE-ReRanker) and
  Dijkstra-based topic distance logic are only active in the batch simulation.

- CAMI's `self.conversation` starts with two hardcoded lines (`"Counselor: Hello..."` /
  `"Client: I am good..."`). In the interactive UI these are just initial context — the
  user's actual first message is appended on top and used as `last_utterance`.

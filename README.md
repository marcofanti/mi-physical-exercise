# MI Physical Exercise Chatbot

This project adapts the CAMI motivational interviewing counselor agent into an
interactive chatbot for physical exercise. The goal is to help a human user
explore barriers to exercise, identify what is getting in the way, and move
toward a small, self-directed next step.

The implementation is based on the ACL 2025 CAMI project:
[CAMI: A Counselor Agent Supporting Motivational Interviewing through State
Inference and Topic Exploration](https://aclanthology.org/2025.acl-long.1024/).

## What This Project Does

The original CAMI repository focused on batch simulation: both the counselor and
client were LLM agents, and conversations were generated from profile data.

This fork adds human-facing chatbot interfaces:

- `exercise_app.py`: an Ollama-backed Streamlit chatbot for local use.
- `openai_exercise_app.py`: an OpenAI-backed Streamlit chatbot for comparison.
- `app.py`: a general CAMI Streamlit UI for interactive counseling sessions.

The exercise chatbot uses `V8-Decision Tree.md` as both:

- a visible exercise-barrier map in the UI, and
- the functional classification tree for each user turn.

## CAMI Background

CAMI uses the STAR framework:

- **State Inference**: infer readiness stage, usually
  `Precontemplation`, `Contemplation`, or `Preparation`.
- **Topic Exploration**: identify motivational topics that may evoke change
  talk.
- **Action / Strategy Selection**: choose a motivational interviewing strategy
  such as reflection, open question, affirmation, support, or reframing.
- **Response Generation & Ranking**: generate counselor responses aligned with
  the inferred state, topic, and strategy.

For the exercise chatbot, a faster one-call mode combines state inference,
barrier classification, strategy selection, and response generation into one
structured LLM request.

## Exercise Barrier Tree

The V8 exercise decision tree has three major branches:

- Sense of Personal Control over Exercise
- Sense of Capability in Fitness
- Relationships with Others in Fitness

The full parsed tree is in:

```text
V8-Decision Tree.md
```

The source deck is:

```text
V8-Decision Tree.pptx
```

## Project Layout

```text
CAMI/
├── agents/
│   ├── llm.py                 # LLM provider factory
│   ├── counselor.py           # CAMI counselor agent
│   ├── client.py              # simulated client agent; batch mode only
│   └── env.py                 # original batch simulation loop
├── annotations/
│   └── profiles.jsonl
├── wikipedias/
├── app.py                     # general CAMI Streamlit UI
├── exercise_app.py            # local Ollama exercise chatbot
├── openai_exercise_app.py     # OpenAI exercise chatbot
├── Chatbot.md                 # chatbot setup and runbook
├── V8-Decision Tree.md        # parsed exercise barrier tree
├── generate.py                # original batch simulation entry point
├── pyproject.toml             # uv project config
└── uv.lock
```

## Setup

Install `uv` if needed:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Sync the project:

```bash
uv sync
```

Batch simulation dependencies are optional and not needed for the chatbots. If
you need `generate.py`, install the batch extra:

```bash
uv sync --extra batch
```

## Environment Configuration

Copy the example environment file:

```bash
cp .env.example .env
```

### Ollama

Use this for local chatbot testing:

```env
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=gemma4:latest
```

Optional faster model override for `exercise_app.py`:

```env
OLLAMA_FAST_MODEL=llama3.2
```

Make sure Ollama is running and the model is available:

```bash
ollama serve
ollama pull gemma4:latest
```

### OpenAI

Use this for `openai_exercise_app.py`:

```env
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4o
```

Create an API key:

```text
https://platform.openai.com/api-keys
```

If the app returns `429 insufficient_quota`, the key is valid but the account
needs billing or available quota:

```text
https://platform.openai.com/settings/organization/billing
```

### Gemini

The shared LLM layer also supports Gemini through Google's OpenAI-compatible
endpoint:

```env
LLM_PROVIDER=gemini
GEMINI_API_KEY=AIza...
GEMINI_MODEL=gemini-2.5-flash
```

## Run the Exercise Chatbots

Ollama-backed exercise chatbot:

```bash
uv run streamlit run exercise_app.py --server.headless true --server.port 8503
```

Open:

```text
http://localhost:8503
```

OpenAI-backed exercise chatbot:

```bash
uv run streamlit run openai_exercise_app.py --server.headless true --server.port 8504
```

Open:

```text
http://localhost:8504
```

For more detailed chatbot setup notes, see:

```text
Chatbot.md
```

## Run the General CAMI UI

```bash
uv run streamlit run app.py
```

The general UI lets a human play the client role while CAMI acts as the
counselor. It can run in fast mode or the fuller CAMI pipeline.

## Run Batch Simulation

Batch simulation uses the original simulated `Client` agent and requires the
optional batch dependencies:

```bash
uv sync --extra batch
```

Then run:

```bash
uv run python generate.py \
    --retriever_path BAAI/bge-reranker-v2-m3 \
    --profile_path ./annotations/profiles.jsonl \
    --output_dir Output/ \
    --round 5 \
    --max_turns 25
```

The retriever model is downloaded from Hugging Face on first use.

## Notes

- `agents/llm.py` centralizes provider selection for Ollama, OpenAI, and Gemini.
- `agents.Client` is lazy-loaded so the Streamlit UIs do not require
  `torch`, `torchvision`, or `transformers`.
- `exercise_app.py` defaults to Ollama even if `LLM_PROVIDER` is set to another
  provider.
- `openai_exercise_app.py` forces the OpenAI provider.
- The exercise chatbot uses one model call per user turn for speed.

## Citation

If you use the underlying CAMI method, cite the original paper:

```bibtex
@inproceedings{yang-etal-2025-cami,
    title = "{CAMI}: A Counselor Agent Supporting Motivational Interviewing through State Inference and Topic Exploration",
    author = "Yang, Yizhe  and
      Achananuparp, Palakorn  and
      Huang, Heyan  and
      Jiang, Jing  and
      Kit, Phey Ling  and
      Lim, Nicholas Gabriel  and
      Ern, Cameron Tan Shi  and
      Lim, Ee-Peng",
    editor = "Che, Wanxiang  and
      Nabende, Joyce  and
      Shutova, Ekaterina  and
      Pilehvar, Mohammad Taher",
    booktitle = "Proceedings of the 63rd Annual Meeting of the Association for Computational Linguistics (Volume 1: Long Papers)",
    month = jul,
    year = "2025",
    address = "Vienna, Austria",
    publisher = "Association for Computational Linguistics",
    url = "https://aclanthology.org/2025.acl-long.1024/",
    pages = "21037--21081",
    ISBN = "979-8-89176-251-0",
}
```


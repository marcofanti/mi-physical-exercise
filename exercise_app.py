import json
import logging
import os
import re
from pathlib import Path

import streamlit as st
from dotenv import load_dotenv
from openai import APIStatusError

from agents.llm import build_client, default_model


load_dotenv()

logging.basicConfig(
    level=logging.WARNING,
    format="%(asctime)s [%(name)s] %(levelname)s  %(message)s",
    datefmt="%H:%M:%S",
)
_log = logging.getLogger("cami.exercise_app")


TREE_PATH = Path(__file__).parent / "V8-Decision Tree.md"
EXERCISE_PROVIDER = os.getenv("EXERCISE_LLM_PROVIDER", "ollama").lower()
EXERCISE_CLIENT = build_client(EXERCISE_PROVIDER)
EXERCISE_DEFAULT_MODEL = (
    os.getenv("OLLAMA_FAST_MODEL") if EXERCISE_PROVIDER == "ollama" else None
) or default_model(EXERCISE_PROVIDER)

STAGES = {
    "Precontemplation": "Not yet seeing exercise change as important.",
    "Contemplation": "Interested or ambivalent, but not ready for a concrete plan.",
    "Preparation": "Ready to try a specific next step.",
}

STRATEGIES = [
    "Reflect",
    "Open Question",
    "Affirm",
    "Emphasize Control",
    "Reframe",
    "Support",
    "Advise with Permission",
]

FALLBACK_KEYWORDS = {
    "Academic Overload": ["school", "class", "homework", "exam", "study", "assignment"],
    "Irregular Routine": ["routine", "schedule changes", "inconsistent", "random", "unpredictable"],
    "Long Commute": ["commute", "drive", "bus", "train", "travel"],
    "Tiny Living Space": ["small apartment", "tiny", "no space", "room", "dorm"],
    "No Equipment": ["equipment", "gym", "weights", "machine", "treadmill"],
    "Outdoor Access Only": ["outside", "outdoor", "weather", "rain", "cold", "hot"],
    "Lack of Alternative Moves": ["alternative", "modify", "modification", "can't do", "hurts"],
    "Lack of Intensity adjustment": ["too hard", "too intense", "intensity", "overdo"],
    "Lack of Pace & Rest Management": ["pace", "rest", "break", "burn out", "exhausted"],
    "Fatigue": ["tired", "fatigue", "exhausted", "low energy", "drained"],
    "Slow Recovery": ["sore", "recover", "recovery", "pain after", "days after"],
    "Poor Conditioning": ["out of shape", "winded", "conditioning", "unfit", "stamina"],
    "Lack Exercise Experience": ["never exercised", "beginner", "new to exercise", "experience"],
    "Unable to Plan": ["plan", "where to start", "don't know what", "routine"],
    "Lack fitness knowledge and skill": ["knowledge", "skill", "form", "technique", "how to"],
    "Repeated Failure": ["failed", "quit", "tried before", "never sticks", "give up"],
    "Lack of Visible Progress": ["progress", "results", "nothing changes", "not working"],
    "Lack Connections to the community": ["community", "belong", "group", "class"],
    "No Friends to Go With": ["friend", "alone", "partner", "go with"],
    "Fear of Being Judged": ["judged", "embarrassed", "people watching", "self-conscious"],
    "Interpersonal Recognition & Inclusion": ["included", "recognized", "fit in", "left out"],
    "Lack Shared Goals & Collaboration": ["same goals", "collaborate", "together", "accountability"],
    "Lack Encouragement & Constructive Feedback": ["encouragement", "feedback", "support", "criticized"],
    "Lack Reciprocal monitoring": ["checking in", "monitor", "accountability", "remind"],
}


def parse_markdown_tree(path: Path) -> tuple[str, dict[str, list[str]], dict[str, str | None]]:
    root = "Root"
    children: dict[str, list[str]] = {}
    parents: dict[str, str | None] = {root: None}
    stack: list[tuple[int, str]] = []

    for line in path.read_text().splitlines():
        match = re.match(r"^( *)- (.+?)\s*$", line)
        if not match:
            continue

        indent = len(match.group(1))
        label = match.group(2).strip()
        level = indent // 2

        while stack and stack[-1][0] >= level:
            stack.pop()

        parent = stack[-1][1] if stack else None
        parents[label] = parent
        children.setdefault(label, [])
        if parent:
            children.setdefault(parent, []).append(label)
        elif label != root:
            children.setdefault(root, []).append(label)

        stack.append((level, label))

    return root, children, parents


ROOT, TREE, PARENTS = parse_markdown_tree(TREE_PATH)
ALL_NODES = list(TREE.keys())
LEAF_NODES = [node for node, children in TREE.items() if not children and node != ROOT]


def path_to_node(node: str) -> list[str]:
    path = []
    current: str | None = node
    while current:
        path.append(current)
        current = PARENTS.get(current)
    return list(reversed(path))


NODE_PATHS = {node: path_to_node(node) for node in ALL_NODES}
LEAF_PATH_TEXT = "\n".join(
    f"- {' > '.join(NODE_PATHS[node])}" for node in LEAF_NODES
)


def strip_json_fences(text: str) -> str:
    cleaned = text.strip()
    cleaned = re.sub(r"^```(?:json)?\s*", "", cleaned)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    return cleaned.strip()


def normalize_path(raw_path: object, user_text: str) -> list[str]:
    if isinstance(raw_path, str):
        pieces = [piece.strip() for piece in re.split(r">|/|,", raw_path) if piece.strip()]
    elif isinstance(raw_path, list):
        pieces = [str(piece).strip() for piece in raw_path if str(piece).strip()]
    else:
        pieces = []

    exact = [piece for piece in pieces if piece in ALL_NODES]
    if exact:
        deepest = exact[-1]
        return NODE_PATHS.get(deepest, [ROOT])

    return fallback_classification(user_text)


def fallback_classification(user_text: str) -> list[str]:
    lowered = user_text.lower()
    best_leaf = "Unable to Plan"
    best_score = -1

    for leaf in LEAF_NODES:
        terms = [leaf.lower(), *FALLBACK_KEYWORDS.get(leaf, [])]
        score = sum(1 for term in terms if term and term in lowered)
        if score > best_score:
            best_leaf = leaf
            best_score = score

    return NODE_PATHS[best_leaf]


def sanitize_stage(stage: object) -> str:
    value = str(stage or "").strip()
    return value if value in STAGES else "Contemplation"


def sanitize_strategy(strategy: object) -> str:
    value = str(strategy or "").strip()
    return value if value in STRATEGIES else "Reflect"


def recent_chat_for_prompt(chat: list[dict], limit: int = 6) -> str:
    rows = []
    for message in chat[-limit:]:
        speaker = "Counselor" if message["role"] == "assistant" else "Client"
        rows.append(f"{speaker}: {message['content']}")
    return "\n".join(rows)


def infer_and_respond(user_text: str, model: str, chat: list[dict]) -> dict:
    if EXERCISE_PROVIDER == "openai" and not os.getenv("OPENAI_API_KEY"):
        barrier_path = fallback_classification(user_text)
        return {
            "stage": "Contemplation",
            "barrier_path": barrier_path,
            "strategy": "Open Question",
            "rationale": "OpenAI provider selected, but OPENAI_API_KEY is not set.",
            "counselor_response": "OpenAI is not configured. Set OPENAI_API_KEY in .env, then restart this app.",
            "confidence": None,
            "error": "Missing OPENAI_API_KEY",
        }

    system_prompt = f"""You are a Motivational Interviewing counselor for physical exercise.
Use the V8 exercise-barrier decision tree as the functional map of the conversation.

Decision-tree leaf paths:
{LEAF_PATH_TEXT}

In one pass:
1. infer the client's readiness stage: one of {list(STAGES)}
2. classify the client's main barrier to one exact path from the tree
3. choose one MI strategy from {STRATEGIES}
4. write one counselor response under 80 words

Do not mention motivational interviewing, stages, strategies, or the tree to the client.
Avoid giving a plan unless the client sounds ready or you ask permission first.
Return only JSON with keys:
stage, barrier_path, strategy, rationale, counselor_response, confidence
"""
    user_prompt = f"""Recent conversation:
{recent_chat_for_prompt(chat)}

Latest client message:
{user_text}
"""
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ]

    try:
        response = EXERCISE_CLIENT.chat.completions.create(
            model=model,
            messages=messages,
            temperature=0.2,
            top_p=0.5,
            max_tokens=650,
            response_format={"type": "json_object"},
        )
        content = response.choices[0].message.content or "{}"
        parsed = json.loads(strip_json_fences(content))
    except Exception as exc:
        _log.warning("Falling back after model/JSON error: %s", exc)
        parsed = {}
        error_message = str(exc)
        if isinstance(exc, APIStatusError):
            error_message = f"OpenAI API error {exc.status_code}: {exc.response.text}"
    else:
        error_message = ""

    barrier_path = normalize_path(parsed.get("barrier_path"), user_text)
    stage = sanitize_stage(parsed.get("stage"))
    strategy = sanitize_strategy(parsed.get("strategy"))
    counselor_response = str(parsed.get("counselor_response") or "").strip()
    if not counselor_response:
        if EXERCISE_PROVIDER == "openai" and error_message:
            counselor_response = f"OpenAI request failed: {error_message}"
        else:
            leaf = barrier_path[-1] if barrier_path else "exercise"
            counselor_response = (
                f"It sounds like {leaf.lower()} is getting in the way. "
                "What feels most workable to change, even a little, this week?"
            )

    return {
        "stage": stage,
        "barrier_path": barrier_path,
        "strategy": strategy,
        "rationale": str(parsed.get("rationale") or "Fallback or concise model classification.").strip(),
        "counselor_response": counselor_response,
        "confidence": parsed.get("confidence", None),
        "error": error_message,
    }


def render_tree(node: str, selected_path: list[str], depth: int = 0) -> None:
    selected = node in selected_path
    label = f"**{node}**" if selected else node
    if depth == 0:
        st.markdown(label)
    else:
        st.markdown(f"{'&nbsp;' * depth * 4}- {label}", unsafe_allow_html=True)

    for child in TREE.get(node, []):
        render_tree(child, selected_path, depth + 1)


def reset_session(model: str) -> None:
    st.session_state.exercise_chat = [
        {
            "role": "assistant",
            "content": "Hi. What has exercise been like for you lately?",
        }
    ]
    st.session_state.exercise_model = model
    st.session_state.exercise_provider = EXERCISE_PROVIDER
    st.session_state.exercise_meta = {
        "stage": "Contemplation",
        "barrier_path": [ROOT],
        "strategy": "Open Question",
        "rationale": "Session initialized.",
        "confidence": None,
    }
    st.session_state.exercise_turn = 0


st.set_page_config(
    page_title="Exercise MI Chatbot",
    page_icon="",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    """
    <style>
    .block-container { padding-top: 1.5rem; }
    [data-testid="stMetricValue"] { font-size: 1.05rem; }
    .stChatMessage { border-radius: 8px; }
    </style>
    """,
    unsafe_allow_html=True,
)

for key, default in {
    "exercise_chat": [],
    "exercise_model": EXERCISE_DEFAULT_MODEL,
    "exercise_provider": EXERCISE_PROVIDER,
    "exercise_meta": {
        "stage": "Contemplation",
        "barrier_path": [ROOT],
        "strategy": "Open Question",
        "rationale": "Session initialized.",
        "confidence": None,
    },
    "exercise_turn": 0,
}.items():
    if key not in st.session_state:
        st.session_state[key] = default

if not st.session_state.exercise_chat:
    reset_session(st.session_state.exercise_model)


with st.sidebar:
    st.title("Exercise Barrier Map")
    st.caption("V8 decision tree used for classification and response focus.")

    st.caption(f"Provider: `{EXERCISE_PROVIDER}`")
    if EXERCISE_PROVIDER == "openai" and not os.getenv("OPENAI_API_KEY"):
        st.warning("Set OPENAI_API_KEY before testing OpenAI responses.")
    model_input = st.text_input("Model", value=st.session_state.exercise_model)
    if st.button("Start / Reset", type="primary", use_container_width=True):
        reset_session(model_input.strip() or EXERCISE_DEFAULT_MODEL)
        st.rerun()

    meta = st.session_state.exercise_meta
    selected_path = meta.get("barrier_path", [ROOT])

    st.divider()
    st.metric("Readiness Stage", meta.get("stage", "Contemplation"))
    st.caption(STAGES.get(meta.get("stage"), ""))
    st.metric("MI Strategy", meta.get("strategy", "Open Question"))
    st.metric("Turns", st.session_state.exercise_turn)

    confidence = meta.get("confidence")
    if confidence is not None:
        st.caption(f"Classification confidence: {confidence}")

    st.divider()
    st.subheader("Current Path")
    st.write(" > ".join(selected_path))

    st.divider()
    st.subheader("Decision Tree")
    render_tree(ROOT, selected_path)

    with st.expander("Why this node?"):
        st.write(meta.get("rationale", "No rationale yet."))


st.title("Motivational Interview Chatbot for Exercise")
st.caption(
    f"Fast mode: one `{EXERCISE_PROVIDER}` model call per turn using `{st.session_state.exercise_model}`."
)

left, right = st.columns([0.68, 0.32], gap="large")

with left:
    for message in st.session_state.exercise_chat:
        with st.chat_message(message["role"]):
            st.write(message["content"])

    user_input = st.chat_input("Tell the counselor what makes exercise hard right now...")

with right:
    st.subheader("Session Focus")
    current_path = st.session_state.exercise_meta.get("barrier_path", [ROOT])
    st.write(current_path[-1])
    st.caption("The assistant uses this barrier to shape the next response.")

    st.subheader("Fast Mode")
    st.markdown(
        "- One LLM call per client turn\n"
        "- Last six chat messages only\n"
        "- JSON classification and response in the same prompt\n"
        "- Short response cap for local Ollama latency"
    )


if user_input:
    st.session_state.exercise_chat.append({"role": "user", "content": user_input})

    with st.spinner("Generating counselor response..."):
        result = infer_and_respond(
            user_text=user_input,
            model=st.session_state.exercise_model,
            chat=st.session_state.exercise_chat,
        )

    st.session_state.exercise_meta = result
    st.session_state.exercise_turn += 1
    st.session_state.exercise_chat.append(
        {"role": "assistant", "content": result["counselor_response"]}
    )
    st.rerun()

import logging
import streamlit as st
import json
import re
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(
    level=logging.WARNING,
    format="%(asctime)s [%(name)s] %(levelname)s  %(message)s",
    datefmt="%H:%M:%S",
)
# Show CAMI pipeline steps without flooding terminal with HTTP internals
logging.getLogger("cami").setLevel(logging.DEBUG)
_log = logging.getLogger("cami.app")

from agents.llm import DEFAULT_MODEL
from agents.counselor import CAMI


# ── Constants ────────────────────────────────────────────────────────────────

PROFILES_PATH = Path(__file__).parent / "annotations" / "profiles.jsonl"

STAGE_INFO = {
    "Precontemplation": ("🔴", "Does not see the behavior as a problem"),
    "Contemplation":    ("🟡", "Aware of the problem, ambivalent about change"),
    "Preparation":      ("🟢", "Ready to take action toward change"),
}

EXPLORATION_ICONS = {
    "Step Into": "⬇️",
    "Switch":    "↔️",
    "Step Out":  "⬆️",
    "Stay":      "📍",
}


# ── Pure helpers ─────────────────────────────────────────────────────────────

def load_profiles() -> list[dict]:
    profiles = []
    if PROFILES_PATH.exists():
        with open(PROFILES_PATH) as f:
            for line in f:
                p = json.loads(line)
                profiles.append({"topic": p["topic"], "behavior": p["Behavior"]})
    return profiles


def parse_reply(raw: str) -> tuple[dict, str]:
    """
    Split CAMI's annotated reply into a metadata dict and clean counselor text.
    Reply format: [Key: val || Key: val || ...] Counselor: <text>
    """
    if "] Counselor: " in raw:
        bracket_part, _, after = raw.partition("] Counselor: ")
        meta_str = bracket_part.lstrip("[")
        response = "Counselor: " + after
    elif raw.startswith("["):
        idx = raw.find("]")
        meta_str = raw[1:idx]
        response = raw[idx + 1:].strip()
    else:
        return {}, raw

    meta: dict = {}
    for part in meta_str.split("||"):
        key, _, val = part.strip().partition(":")
        meta[key.strip()] = val.strip()

    return meta, response


def strip_speaker_prefix(text: str) -> str:
    return re.sub(r"^(Counselor|Client):\s*", "", text)


# ── Session helpers ───────────────────────────────────────────────────────────

def start_session(goal: str, behavior: str, model: str, fast_mode: bool) -> None:
    st.session_state.counselor = CAMI(
        goal=goal,
        behavior=behavior,
        model=model,
        fast_mode=fast_mode,
        enable_refinement=not fast_mode,
    )
    st.session_state.goal = goal
    st.session_state.behavior = behavior
    st.session_state.model = model
    st.session_state.fast_mode = fast_mode
    st.session_state.chat = [
        {"role": "assistant", "content": "Counselor: Hello. How are you?"}
    ]
    st.session_state.current_meta = {}
    st.session_state.turn = 0
    st.session_state.session_active = True


# ── App entry point ───────────────────────────────────────────────────────────

st.set_page_config(
    page_title="CAMI – Motivational Interviewing",
    page_icon="🧠",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Session state defaults ───────────────────────────────────────────────────
for key, default in {
    "counselor": None,
    "chat": [],
    "current_meta": {},
    "session_active": False,
    "goal": "",
    "behavior": "",
    "model": DEFAULT_MODEL,
    "fast_mode": True,
    "turn": 0,
}.items():
    if key not in st.session_state:
        st.session_state[key] = default


# ── Sidebar ──────────────────────────────────────────────────────────────────
with st.sidebar:
    st.title("🧠 CAMI")
    st.caption("Motivational Interviewing Counselor Agent")
    st.divider()

    # ── New session form ──────────────────────────────────────────────────────
    st.subheader("New Session")

    profiles = load_profiles()
    unique = list({(p["topic"], p["behavior"]): p for p in profiles}.values())
    options = ["✏️  Custom…"] + [
        f"{p['topic']}  ({p['behavior']})" for p in unique
    ]
    choice = st.selectbox(
        "Load a preset topic",
        range(len(options)),
        format_func=lambda i: options[i],
        key="profile_choice",
    )

    if choice == 0 or not unique:
        pre_goal = st.session_state.goal
        pre_behavior = st.session_state.behavior
    else:
        pre_goal = unique[choice - 1]["topic"]
        pre_behavior = unique[choice - 1]["behavior"]

    goal_input = st.text_input(
        "Counseling goal",
        value=pre_goal,
        placeholder="e.g. smoking cessation",
    )
    behavior_input = st.text_input(
        "Client behavior",
        value=pre_behavior,
        placeholder="e.g. smoking",
    )
    model_input = st.text_input("Model", value=st.session_state.model)
    fast_mode = st.toggle(
        "Fast mode",
        value=st.session_state.fast_mode,
        help="Use one LLM call per counselor turn instead of the full CAMI ranking/refinement pipeline.",
    )

    can_start = bool(goal_input.strip() and behavior_input.strip())
    if st.button(
        "▶ Start / Reset Session",
        disabled=not can_start,
        type="primary",
        use_container_width=True,
    ):
        start_session(goal_input.strip(), behavior_input.strip(), model_input.strip(), fast_mode)
        st.rerun()

    # ── CAMI internal state panel ─────────────────────────────────────────────
    if st.session_state.session_active:
        st.divider()
        st.subheader("CAMI Internal State")

        meta = st.session_state.current_meta

        if not meta:
            st.caption("Waiting for first exchange…")
        else:
            # ── Client stage ──────────────────────────────────────────────────
            stage = meta.get("Inferred State", "—")
            icon, desc = STAGE_INFO.get(stage, ("⚪", ""))
            st.metric("Client Stage", f"{icon}  {stage}")
            st.caption(desc)

            st.divider()

            # ── Topic ─────────────────────────────────────────────────────────
            topic = meta.get("Topic", "—")
            st.metric("Current Topic", topic)

            counselor = st.session_state.counselor
            if counselor and counselor.topic_stack:
                st.caption("**Path:** " + " → ".join(counselor.topic_stack))

            exp_action = meta.get("Exploration Action", "—")
            exp_icon = EXPLORATION_ICONS.get(exp_action, "")
            st.metric("Exploration Move", f"{exp_icon}  {exp_action}")

            st.divider()

            # ── Strategy ──────────────────────────────────────────────────────
            final_strat = meta.get("Final Strategy", "—")
            st.metric("Strategy Used", final_strat)

            strategies_raw = meta.get("Strategies", "")
            if strategies_raw:
                # Attempt to render as a neat list, fall back to raw text
                try:
                    strats = re.findall(r"'([^']+)'", strategies_raw)
                    if strats:
                        for s in strats:
                            st.markdown(f"- `{s}`")
                    else:
                        st.caption(strategies_raw)
                except Exception:
                    st.caption(strategies_raw)

            st.divider()

            # ── Reasoning expanders ───────────────────────────────────────────
            with st.expander("Strategy selection reasoning"):
                st.write(meta.get("Strategy Selection", "—"))

            with st.expander("Topic exploration reasoning"):
                st.write(meta.get("Exploration", "—"))

        st.divider()
        st.caption(f"Turn **{st.session_state.turn}**")
        st.caption(f"Mode **{'Fast' if st.session_state.fast_mode else 'Full'}**")


# ── Main chat area ────────────────────────────────────────────────────────────
st.title("Motivational Interviewing Session")

if not st.session_state.session_active:
    st.info(
        "👈 Select a topic preset or enter a custom goal/behavior in the sidebar, "
        "then click **▶ Start / Reset Session** to begin."
    )

    # Show available topic presets as a quick-reference table
    if profiles:
        st.subheader("Available preset topics")
        seen = set()
        rows = []
        for p in profiles:
            key = (p["topic"], p["behavior"])
            if key not in seen:
                seen.add(key)
                rows.append(p)
        st.dataframe(
            rows,
            column_config={
                "topic": st.column_config.TextColumn("Counseling Goal"),
                "behavior": st.column_config.TextColumn("Client Behavior"),
            },
            hide_index=True,
            use_container_width=True,
        )
    st.stop()

# Session header
st.caption(
    f"🎯 **Goal:** {st.session_state.goal}  ·  "
    f"⚠️ **Behavior:** {st.session_state.behavior}  ·  "
    f"🤖 **Model:** `{st.session_state.model}`"
)
st.info(
    "You are playing the **client** role. Respond naturally to the counselor. "
    "CAMI will guide the conversation using Motivational Interviewing.",
    icon="ℹ️",
)

# Render chat history
for msg in st.session_state.chat:
    role = "assistant" if msg["role"] == "assistant" else "user"
    with st.chat_message(role):
        st.write(strip_speaker_prefix(msg["content"]))

# User input
user_input = st.chat_input("Your response as client…")

if user_input:
    client_text = f"Client: {user_input}"
    st.session_state.chat.append({"role": "user", "content": client_text})

    with st.spinner("CAMI is thinking…"):
        st.session_state.counselor.receive(client_text)
        raw = st.session_state.counselor.reply()

    _log.debug("═" * 60)
    _log.debug("RAW from reply() (full):\n%s", raw)
    meta, counselor_text = parse_reply(raw)
    _log.debug("PARSED counselor_text: %r", counselor_text)
    _log.debug("PARSED meta keys: %s", list(meta.keys()))
    _log.debug("DISPLAY text (after strip_prefix): %r", strip_speaker_prefix(counselor_text))
    _log.debug("═" * 60)
    st.session_state.current_meta = meta
    st.session_state.turn += 1
    st.session_state.chat.append({"role": "assistant", "content": counselor_text})

    st.rerun()

"""
Run this before launching the Streamlit app to verify the full CAMI pipeline.

    python test_cami.py

Tests (in order, each depends on the previous passing):
  1. LLM connectivity     — one raw API call
  2. infer_state          — state inference prompt
  3. initialize_topic     — JSON topic distribution
  4. select_strategy      — strategy selection + fallback
  5. generate             — candidate response generation
  6. full reply()         — one complete counselor turn end-to-end
"""

import sys
import traceback
from dotenv import load_dotenv

load_dotenv()

from agents.llm import client, DEFAULT_MODEL
from agents.counselor import CAMI

GOAL = "smoking cessation"
BEHAVIOR = "smoking"
FIRST_CLIENT_MSG = "Client: I'm fine honestly, smoking helps me relax after work."

PASS = "  PASS"
FAIL = "  FAIL"


def section(title: str):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print('='*60)


def run(label: str, fn):
    try:
        result = fn()
        print(f"{PASS}  {label}")
        return result
    except Exception:
        print(f"{FAIL}  {label}")
        traceback.print_exc()
        sys.exit(1)


# ── 1. Raw API connectivity ──────────────────────────────────────────────────
section("1. LLM connectivity")

def test_connectivity():
    resp = client.chat.completions.create(
        model=DEFAULT_MODEL,
        messages=[{"role": "user", "content": "Say exactly: hello"}],
        max_tokens=50,
    )
    content = resp.choices[0].message.content or ""
    assert content.strip(), \
        f"empty response (finish_reason={resp.choices[0].finish_reason!r})"
    print(f"       model={DEFAULT_MODEL!r}  response={content.strip()!r}")
    return content

run("raw API call", test_connectivity)


# ── 2. infer_state ───────────────────────────────────────────────────────────
section("2. infer_state")

counselor = CAMI(goal=GOAL, behavior=BEHAVIOR, model=DEFAULT_MODEL)
counselor.receive(FIRST_CLIENT_MSG)
counselor.conversation.append(FIRST_CLIENT_MSG)

def test_infer_state():
    state = counselor.infer_state()
    assert state in ("Precontemplation", "Contemplation", "Preparation"), \
        f"unexpected state: {state!r}"
    print(f"       state={state!r}")
    return state

state = run("infer_state()", test_infer_state)


# ── 3. initialize_topic ──────────────────────────────────────────────────────
section("3. initialize_topic (JSON parsing)")

VALID_TOPICS = {"Health", "Economy", "Interpersonal Relationships", "Law", "Education"}

def test_initialize_topic():
    analysis, action, topic = counselor.initialize_topic()
    assert topic in VALID_TOPICS, f"unknown topic: {topic!r}"
    print(f"       action={action!r}  topic={topic!r}")
    print(f"       analysis[:80]={analysis[:80]!r}")
    return topic

topic = run("initialize_topic()", test_initialize_topic)


# ── 4. select_strategy ───────────────────────────────────────────────────────
section("4. select_strategy (+ empty-list fallback)")

ALL_STRATEGIES = set(counselor.strategy2description.keys())

def test_select_strategy():
    analysis, strategies = counselor.select_strategy(state)
    assert len(strategies) >= 1, "strategies list is empty after fallback"
    for s in strategies:
        assert s in ALL_STRATEGIES, f"unknown strategy: {s!r}"
    print(f"       strategies={strategies}")
    return strategies

strategies = run("select_strategy()", test_select_strategy)


# ── 5. generate ──────────────────────────────────────────────────────────────
section("5. generate (candidate responses)")

def test_generate():
    response, final_strategy = counselor.generate(
        FIRST_CLIENT_MSG, topic, state, strategies
    )
    assert response.startswith("Counselor:"), \
        f"response missing 'Counselor:' prefix: {response[:60]!r}"
    assert final_strategy, "final_strategy is empty"
    print(f"       final_strategy={final_strategy!r}")
    print(f"       response[:80]={response[:80]!r}")
    return response

run("generate()", test_generate)


# ── 6. Full reply() ──────────────────────────────────────────────────────────
section("6. Full reply() — end-to-end turn")

counselor2 = CAMI(goal=GOAL, behavior=BEHAVIOR, model=DEFAULT_MODEL)
counselor2.receive(FIRST_CLIENT_MSG)

def test_full_reply():
    raw = counselor2.reply()
    assert "] Counselor:" in raw, \
        f"metadata prefix missing from reply: {raw[:120]!r}"
    # Parse it the same way app.py does
    import re
    bracket_part, _, after = raw.partition("] Counselor: ")
    meta_str = bracket_part.lstrip("[")
    meta = {}
    for part in meta_str.split("||"):
        key, _, val = part.strip().partition(":")
        meta[key.strip()] = val.strip()

    required_keys = {"Inferred State", "Topic", "Final Strategy", "Exploration Action"}
    missing = required_keys - meta.keys()
    assert not missing, f"missing metadata keys: {missing}"

    stage = meta["Inferred State"]
    assert stage in ("Precontemplation", "Contemplation", "Preparation"), \
        f"bad stage: {stage!r}"

    # Ensure response is not LLM preamble garbage
    GARBAGE_PREFIXES = ("here's", "here is", "i've", "i have", "certainly", "sure,", "of course")
    assert not after.lower().startswith(GARBAGE_PREFIXES), \
        f"response looks like LLM preamble, not counselor text: {after[:120]!r}"

    print(f"       stage={stage!r}")
    print(f"       topic={meta.get('Topic')!r}")
    print(f"       strategy={meta.get('Final Strategy')!r}")
    print(f"       exploration={meta.get('Exploration Action')!r}")
    print(f"       response[:80]={after[:80]!r}")

run("reply()", test_full_reply)


# ── Done ─────────────────────────────────────────────────────────────────────
print(f"\n{'='*60}")
print("  All tests passed — safe to run: streamlit run app.py")
print('='*60)

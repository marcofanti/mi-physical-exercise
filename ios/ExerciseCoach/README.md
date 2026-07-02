# ExerciseCoach — iOS Port of the CAMI MI Exercise Chatbot

A native iPhone app that ports the Streamlit motivational-interviewing (MI)
exercise chatbot (`../../exercise_app.py`) to iOS, running the counselor
entirely **on-device** with Apple's Foundation Models framework. No server, no
API key, no data leaving the phone.

- [Design](#design)
- [Build](#build)
- [Run](#run)

---

## Design

### Goal and constraints

The Python app makes **one structured LLM call per user turn**: infer the
client's readiness stage (TTM: Precontemplation / Contemplation /
Preparation) → classify their main barrier against the V8 exercise-barrier
decision tree → pick one MI strategy → write a <80-word counselor reply — all
in a single JSON response (`infer_and_respond`, `exercise_app.py:185-273`).

ExerciseCoach reproduces that exact contract natively, with four constraints
from the product decision behind this app:

1. **On-device only** — the counselor runs on Apple's Foundation Models
   framework (iOS 26). No network call, no API key, no server.
2. **Verifiable parity** — every constant, prompt, and fallback behavior is
   ported from the Python source and checked against it with unit tests
   (not "similar," but byte-for-byte where it matters).
3. **Mobile-native features** — session history, a compact MI state panel,
   full voice conversation, optional HealthKit grounding, and local
   check-in notifications — none of which exist in the Streamlit app.
4. **No backend** — everything (model, speech, health data, storage) stays
   on the phone; this drives the TestFlight privacy story ("Data Not
   Collected").

### Module layout

```
ExerciseCoach/
├── App/
│   ├── ExerciseCoachApp.swift   @main, SwiftData ModelContainer
│   ├── RootView.swift           disclaimer gate → availability gate → ChatView
│   └── AppDelegate.swift        UNUserNotificationCenterDelegate, check-in routing
├── Models/
│   ├── MITypes.swift            Stage, Strategy enums; TranscriptMessage; TurnResult
│   ├── DecisionTree.swift       static V8 tree, leaf paths, LEAF_PATH_TEXT
│   ├── CounselorTurn.swift      @Generable guided-generation schema
│   └── Persistence/             SwiftData @Models: ChatSession, ChatMessage,
│                                 TurnMetadata, CommittedStep
├── Services/
│   ├── CounselorEngine.swift    Foundation Models session, sanitization, fallback
│   ├── PromptBuilder.swift      ported system/user prompts
│   ├── FallbackClassifier.swift ported keyword classifier
│   ├── SpeechInput.swift        on-device STT (SpeechAnalyzer/SpeechTranscriber)
│   ├── SpeechOutput.swift       TTS (AVSpeechSynthesizer)
│   ├── VoiceConversationController.swift  hands-free state machine
│   ├── HealthContextProvider.swift  HealthKit → one prompt line
│   └── NotificationScheduler.swift  local check-in notifications
├── ViewModels/
│   └── ChatViewModel.swift      turn orchestration + SwiftData writes
└── Views/
    ├── ChatView.swift           chat, input bar, mic button, commit affordance
    ├── MIStateChipsView.swift / MIDetailSheet.swift / DecisionTreeView.swift
    ├── SessionListView.swift    history browser
    ├── CommitStepSheet.swift    next-step commitment + reminder time
    ├── VoiceModeOverlay.swift   hands-free state banner
    ├── ModelUnavailableView.swift / DisclaimerView.swift
    └── MessageBubbleView.swift
```

### Anatomy of one turn

1. `ChatView` sends the user's text to `ChatViewModel.send(_:)`.
2. `ChatViewModel` appends the message, persists it, and calls
   `CounselorEngine.respond(userText:chat:healthContext:)`.
3. `CounselorEngine` builds a prompt via `PromptBuilder` from the **last 6
   messages** (`recentChat(limit: 6)`, ported from
   `recent_chat_for_prompt`), runs it through a `LanguageModelSession`
   constrained to the `CounselorTurn` `@Generable` schema, and sanitizes the
   result (unknown stage → Contemplation, unknown strategy → Reflect, empty
   reply → templated fallback — all ported from
   `sanitize_stage`/`sanitize_strategy`/the templated-response block).
4. On any model failure (guardrail refusal, context overflow, generation
   error), `CounselorEngine` falls back to `FallbackClassifier` — a literal
   port of `FALLBACK_KEYWORDS` and its scoring loop — so the user never sees
   a raw error.
5. `ChatViewModel` stores the turn's `TurnResult` as `TurnMetadata` in
   SwiftData and appends the counselor reply to the transcript.

### Key design decisions

- **Stateless per turn.** Each turn opens a *fresh* `LanguageModelSession`
  whose instructions embed the full decision tree; only the last 6 messages
  go into the prompt. This mirrors the Python app's context management and
  keeps every request far under the on-device context window. The next
  turn's session is `prewarm()`ed immediately after each reply to hide
  session-startup latency.
- **Guided generation over JSON repair.** `CounselorTurn` uses
  `@Guide(.anyOf(...))` to constrain `stage`, `strategy`, and `barrierLeaf`
  to valid values by construction. This replaces Python's `normalize_path`
  string-repair logic entirely — the model literally cannot emit an invalid
  tree node.
- **Fallback is not an edge case, it's a designed path.** The keyword
  classifier and templated replies are first-class, tested code paths, not
  an afterthought — they're what runs on guardrail refusals, context
  overflow, and any other generation failure.
- **Manual commitment detection.** When a turn's stage is `Preparation`, the
  UI shows a "Commit to a next step" affordance rather than trying to
  extract a commitment from the model's text. This was a deliberate
  simplicity/reliability tradeoff (see `ios/ExerciseCoach` plan notes) —
  LLM-based extraction is a noted future option, not built.
- **Privacy by construction.** No networking code exists in the app. Speech
  recognition is on-device (`requiresOnDeviceRecognition` /
  `SpeechAnalyzer` locally-installed assets), HealthKit access is read-only,
  and SwiftData persists locally with no CloudKit sync configured.

### Relation to the Python app

| Python (`exercise_app.py`) | Swift |
|---|---|
| `STAGES` / `STRATEGIES` | `MITypes.swift` |
| `parse_markdown_tree` + `V8-Decision Tree.md` | `DecisionTree.swift` (static) |
| `FALLBACK_KEYWORDS` + `fallback_classification` | `FallbackClassifier.swift` |
| system/user prompts | `PromptBuilder.swift` |
| `infer_and_respond` | `CounselorEngine.swift` |
| `st.session_state` | `ChatViewModel` + SwiftData |
| sidebar tree/metrics | `MIStateChipsView` + `MIDetailSheet` |

The one-call-per-turn contract and all fallback behavior are ported verbatim;
deviations (leaf-name generation instead of free-form path strings, dropped
"Return only JSON" instruction since Foundation Models enforces the schema
itself) are documented in code comments where they occur.

---

## Build

### Requirements

| What | Version |
|---|---|
| Xcode | 26+ (iOS 26 SDK) |
| macOS | 26 (Tahoe), with Apple Intelligence enabled, to run Foundation Models in the simulator |
| Tooling | [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen` |

Check your toolchain:

```bash
xcodebuild -version   # expect Xcode 26.x
sw_vers               # expect macOS 26.x
```

### Generate the Xcode project

The `.xcodeproj` is generated from `project.yml` — **never edit the
`.xcodeproj` by hand**; edit `project.yml` and regenerate:

```bash
cd ios/ExerciseCoach
xcodegen generate
open ExerciseCoach.xcodeproj
```

### Command-line build

```bash
xcodebuild build -project ExerciseCoach.xcodeproj -scheme ExerciseCoach \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Command-line test

```bash
xcodebuild test -project ExerciseCoach.xcodeproj -scheme ExerciseCoach \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

25 tests across four suites verify Python parity:

- `DecisionTreeTests` — leaf count/labels, `LEAF_PATH_TEXT` byte-for-byte
  against a pinned copy of the Python output.
- `FallbackClassifierTests` — probe sentences with expected paths generated
  by running the actual `fallback_classification` from `exercise_app.py`
  (including its tie-break behavior).
- `PromptBuilderTests` — system/user prompt strings match the Python
  f-string output exactly.
- `CounselorEngineParityTests` — sanitizer defaults and templated fallback
  responses.

If you change the decision tree, prompts, or keyword map in
`exercise_app.py`, regenerate the pinned expectations by running the
relevant Python function directly (see comments at the top of each test
file) and update the Swift test literals to match.

### If the build fails

- **"iOS 26.x is not installed"** — download the matching simulator runtime:
  `xcodebuild -downloadPlatform iOS`, or Xcode → Settings → Components.
- **XcodeGen not found** — `brew install xcodegen`.
- **Concurrency/Sendable errors touching `HealthKit`/`AVFoundation` types** —
  these frameworks aren't fully concurrency-audited; see the
  `@preconcurrency import AVFoundation` pattern in `SpeechInput.swift` for
  the fix, or pass plain `Sendable` values (not model/framework objects)
  across `async` boundaries, as done in `NotificationScheduler`.

---

## Run

### In the simulator

1. `xcodegen generate && open ExerciseCoach.xcodeproj`.
2. Pick any iOS 26 simulator (e.g. iPhone 17 Pro) as the run destination and
   press ⌘R.
3. **Foundation Models availability**: the simulator inherits Apple
   Intelligence state from the host Mac. If macOS Settings → Apple
   Intelligence & Siri is off, the app shows `ModelUnavailableView` instead
   of the chat — enable it there, then relaunch.
4. HealthKit and the microphone work in the simulator with reduced
   fidelity (HealthKit needs manually added samples via the Health app;
   microphone input needs host-mic passthrough). For a realistic test of
   voice and health grounding, use a physical device.

### On a physical iPhone

Requirements: **iPhone 15 Pro or later**, iOS 26, Apple Intelligence enabled
in Settings → Apple Intelligence & Siri.

1. Connect the device, select it as the run destination in Xcode.
2. Set your Apple Developer team on both targets (Signing & Capabilities;
   automatic signing works for a personal team). Bundle id:
   `com.mfanti.exercisecoach`.
3. Press ⌘R. On first launch you'll see the **disclaimer** ("student
   research prototype, not medical advice"), then the chat.
4. Permission prompts appear the first time each feature is used, not at
   launch:
   - **Microphone / Speech Recognition** — first tap of the mic button.
   - **HealthKit** — first session start (steps/workouts, read-only).
   - **Notifications** — first "Commit to a next step" confirmation.

### What to try

A minimal script exercising every subsystem:

1. *"My class schedule is insane lately."* → chip row should show the
   **Schedule Constraints** barrier; reply stays under 80 words with no MI
   jargon.
2. *"I don't see the point, I feel fine."* → **Precontemplation**; no plan
   or next step should be pushed.
3. *"I could try a 10-minute walk after dinner tomorrow."* → **Preparation**
   → "Commit to a next step" affordance appears → confirm → a local
   notification is scheduled for the chosen time.
4. Tap the mic, speak a turn hands-free — the app should listen, transcribe
   live, respond, and speak the reply automatically, then resume listening.
   Tap the mic again while it's speaking to interrupt.
5. Turn on Airplane Mode and repeat step 1 — everything should still work,
   proving the whole pipeline is on-device.
6. Force-quit and relaunch — the conversation should reappear via
   **History** (SwiftData persistence).

### TestFlight

1. Product → Archive → Distribute App → TestFlight (automatic signing,
   same team as above).
2. App Privacy in App Store Connect: **Data Not Collected** — model,
   speech, health data, and storage are all on-device.
3. "What to Test" notes for testers: requires iPhone 15 Pro+, iOS 26, Apple
   Intelligence enabled; include the script above.

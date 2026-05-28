# AGENTS.md

This file defines the working rules for any AI agent or engineer editing this repository.

The repository is now a `local-first macOS app` for portfolio/open-source use. Do not reintroduce SaaS assumptions unless the repository owner explicitly asks for that architecture again.

---

## 1. Product Direction

### Core mission

Build a native Apple-platform meeting recorder that:
- records locally
- stores history locally
- uses the user’s own `OpenAI API key`
- processes transcripts and summaries directly from the app

### Permanent rules

1. No login flow.
2. No backend dependency.
3. No Supabase or remote persistence.
4. The OpenAI API key belongs to the user and is stored only in the macOS `Keychain`.
5. Recording reliability and recovery matter more than adding new features.

### Priority order

When there is a tradeoff, prefer:
1. correctness
2. recoverability
3. performance
4. UX clarity
5. feature breadth
6. visual polish

---

## 2. Repository Context

### Current structure

- `MeetingNotes/`
  - native macOS application
- `MeetingNotes.xcodeproj/`
  - Xcode project

### Current platform scope

- shipping now: `macOS`
- future-compatible direction: `iOS` and `watchOS`
- default AI flow: `post-meeting`

### Source of truth

- `SwiftData` is the local source of truth for history
- local recording files in `Application Support` are the source of truth for reprocessing
- no cloud copy is assumed

---

## 3. Engineering Workflow Rules

### Before changing code

Always identify whether the change affects:
- audio capture
- processing quality
- persistence
- reprocessing
- UX around permissions or API key setup

### Preferred development style

- Keep changes incremental.
- Avoid broad rewrites unless necessary for correctness.
- Preserve working behavior before expanding scope.
- Prefer explicit state transitions over hidden implicit logic.

### Validation expectation

For non-trivial changes, validate as many of these as possible:
- app build
- app launch
- API key configuration flow
- capture start/stop
- transcript generation
- summary generation
- history persistence
- delete/reprocess behavior

### Documentation expectation

When architecture, setup, or user flow changes:
- update `README.md`
- keep this `AGENTS.md` aligned

---

## 4. Architecture Rules

### Separation of concerns

Keep these boundaries clean:
- `Views`
  - UI only
- `AppShell`
  - orchestration and lifecycle
- `AudioCapture`
  - recording implementation
- `Networking`
  - direct OpenAI transport
- `Persistence`
  - local storage mechanics
- `Models`
  - stable app state
- `Security`
  - Keychain-only secrets handling

### Local-first rule

Do not introduce:
- remote auth
- remote sync
- cloud storage
- server-required processing

unless the repository owner explicitly changes the product direction.

### Meeting lifecycle

Any feature touching processing must preserve a clear lifecycle:
1. capture starts
2. local audio is persisted
3. audio is prepared
4. audio is chunked
5. chunks are transcribed
6. transcript is consolidated
7. summary is generated
8. meeting becomes reviewable

---

## 5. Apple Platform Best Practices

### General

- Prefer native frameworks.
- Respect macOS/iOS/watchOS idioms instead of forcing a shared UI shape.
- Keep CPU, memory, and battery use reasonable.
- Minimize main-thread work for file IO, networking, and audio processing.

### macOS

- Prefer `SwiftUI` for most UI.
- Use `AppKit` only when menu bar, windowing, or lifecycle behavior needs it.
- Menu bar surfaces should feel fast and never depend on external services.
- Floating widgets should stay compact, stable, and easy to understand.

### iOS

- If added later, do not copy the macOS UX directly.
- Design for interruptions, backgrounding limits, and simpler flows.

### watchOS

- If added later, keep it narrowly scoped:
  - start/stop
  - status
  - short summary output
- Do not treat watchOS as a full transcript-review surface.

---

## 6. Audio and Processing Rules

### Recording

- Long sessions are a normal use case.
- Never assume audio files stay small.
- Preserve reliable input-level behavior while optimizing formats.
- If system audio fails, degrade clearly to microphone-only.

### Chunking

- Long audio must remain chunkable by design.
- Chunk metadata should remain explicit:
  - source
  - sequence index
  - duration
  - file size
  - transcription state
  - processing error

### Transcript quality

- Treat transcript cleanup as product logic, not cosmetic polish.
- Remove prompt leakage and repeated chunk artifacts.
- Never discard a valid transcript only because summarization failed.

### Summary quality

- Preserve structured output.
- Keep the result useful for real work:
  - title
  - summary
  - notes
  - topics
  - key points
  - decisions
  - action items
  - questions
  - blockers
  - follow-ups

---

## 7. Security and Secrets

- The user’s OpenAI API key must be stored only in `Keychain`.
- Do not store the key in:
  - repo files
  - `.env` for the desktop app
  - `UserDefaults`
  - `SwiftData`
  - plaintext files
- Never commit secrets to this repository.

---

## 8. UX Rules

- If no API key is configured, make that state explicit and actionable.
- Do not block app launch just because the key is missing.
- The user must be able to:
  - configure the key
  - start recording when ready
  - review and edit notes
  - delete meetings permanently
  - reprocess from local files when available

Keep copy concise and practical. Avoid product language that implies cloud sync or account-based features.

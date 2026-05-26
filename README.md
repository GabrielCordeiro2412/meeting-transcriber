# Meeting Notes

Native macOS SwiftUI app for recording meeting audio, sending the final recording to a backend, and storing structured meeting notes.

## Architecture

- `MeetingNotes/`: macOS client built with SwiftUI and SwiftData.
- `backend/`: Node.js API that handles auth, storage, transcription, and summarization.
- The desktop client never stores or sends an OpenAI API key directly.
- `OPENAI_API_KEY` is used only by the backend.

## Requirements

- macOS with Xcode 26+
- Node.js 20+
- A Supabase project for auth, database, and storage
- One server-side OpenAI API key configured in the backend environment

## Configure the backend

1. Copy `backend/.env.example` to `backend/.env`.
2. Fill in:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `OPENAI_API_KEY`
3. Install backend dependencies:

```sh
cd backend
npm install
```

4. Apply the SQL migration in `backend/supabase/migrations/0001_meeting_notes.sql` to your Supabase project.

## Run locally

1. Build the macOS app:

```sh
xcodebuild -project MeetingNotes.xcodeproj -scheme MeetingNotes -configuration Debug -derivedDataPath .derivedData CODE_SIGNING_ALLOWED=NO build
```

2. Start the backend:

```sh
cd backend
npm start
```

3. Open the app:

```sh
open -n .derivedData/Build/Products/Debug/MeetingNotes.app
```

You can also use `Open Meeting Notes.command`. If `backend/.env` is present, it tries to start the backend automatically before launching the app.

## Current behavior

- Records microphone audio with `AVAudioEngine`.
- Attempts to capture app or system audio with `ScreenCaptureKit`.
- Falls back to microphone-only capture when system audio is unavailable.
- Uploads final audio to the backend after the recording stops.
- Uses Supabase magic-link auth.
- Processes transcript and summary on the backend.
- Caches meeting history locally with SwiftData and syncs remote sessions into the local store.

## Current limitations

- No billing flow yet.
- No realtime transcript.
- No background job queue yet; processing still runs in the request cycle.
- App audio and microphone audio are uploaded as separate source files and merged at transcript level.
- There is no refresh-token renewal flow yet; expired sessions require a new sign-in.

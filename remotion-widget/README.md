# Remotion Widget Video

This folder contains a small [Remotion](https://www.remotion.dev/) project that renders an animated demo video of the macOS floating widget used in this repo.

The styling is a faithful approximation of the current SwiftUI widget (`MeetingNotes/Views/FloatingWidgetView.swift`):
- Pill shape
- Translucent gradient fill + inner shine
- Cyan/blue glow blobs
- Circular control buttons
- Fake animated waveform bars (synthetic, no audio required)

## Prereqs

- Node.js 20+ (works with Node 24 in this workspace)

## Install

```bash
cd remotion-widget
npm install
```

## Render

Render a still preview frame:

```bash
npm run remotion:still
```

Render the full MP4:

```bash
npm run remotion:render
```

Outputs are written to:
- `remotion-widget/out/widget.png`
- `remotion-widget/out/widget.mp4`


import React, {useMemo} from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {WidgetShell} from './components/WidgetShell';
import {Waveform} from './components/Waveform';
import {IconButton} from './components/IconButton';
import {TimerPill} from './components/TimerPill';
import {Background} from './components/Background';
import {HistoryScreen} from './components/HistoryScreen';

type Props = {
  theme: 'meeting-notes-widget';
};

export const WidgetRecordingDemo: React.FC<Props> = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const appear = spring({
    fps,
    frame,
    config: {damping: 18, stiffness: 140, mass: 0.8},
    durationInFrames: 35,
  });

  const phase = useMemo(() => {
    if (frame < 75) return 'idle' as const;
    if (frame < 185) return 'recording' as const;
    if (frame < 235) return 'transcribing' as const;
    if (frame < 280) return 'summarizing' as const;
    return 'history' as const;
  }, [frame]);

  const widgetScale = interpolate(appear, [0, 1], [0.92, 1]);
  const widgetEntryY = interpolate(appear, [0, 1], [18, 0]);
  const widgetOpacity = interpolate(appear, [0, 1], [0, 1]);

  const showWidget = frame < 296;
  const showTimer = phase === 'recording';
  const showPause = phase === 'recording';
  const showFinish = phase !== 'history';

  const elapsedSeconds = Math.max(0, (Math.min(frame, 185) - 75) / fps);
  const recordExpand = spring({
    fps,
    frame: frame - 72,
    config: {damping: 22, stiffness: 150, mass: 0.82},
    durationInFrames: 22,
  });
  const recordContract = spring({
    fps,
    frame: frame - 184,
    config: {damping: 22, stiffness: 140, mass: 0.9},
    durationInFrames: 20,
  });
  const widthStart = 560;
  const widthRecorded = 714;
  const widgetWidth = frame < 185
    ? interpolate(recordExpand, [0, 1], [widthStart, widthRecorded])
    : interpolate(recordContract, [0, 1], [widthRecorded, widthStart]);
  const processingLabel = phase === 'transcribing' ? 'Transcribing...' : 'Summarizing...';
  const finishPress = spring({
    fps,
    frame: frame - 182,
    config: {damping: 10, stiffness: 180, mass: 0.6},
    durationInFrames: 18,
  });
  const widgetExit = interpolate(frame, [270, 292], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const widgetDropY = interpolate(frame, [268, 292], [0, 560], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const widgetY = widgetEntryY + widgetDropY;

  return (
    <Background>
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {showWidget ? (
          <div
            style={{
              transform: `translateY(${widgetY}px) scale(${widgetScale})`,
              opacity: widgetOpacity * widgetExit,
            }}
          >
            <WidgetShell active={phase === 'recording'} width={widgetWidth}>
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 16,
                  paddingLeft: 28,
                  paddingRight: 18,
                  paddingTop: 14,
                  paddingBottom: 14,
                  height: '100%',
                }}
              >
                <div style={{display: 'flex', alignItems: 'center', gap: 12}}>
                  <Waveform active={phase === 'recording'} />
                  <div style={{width: 96, display: 'flex', justifyContent: 'flex-start'}}>
                    {showTimer ? (
                      <TimerPill seconds={elapsedSeconds} />
                    ) : phase === 'transcribing' || phase === 'summarizing' ? (
                      <StatusPill label={processingLabel} />
                    ) : null}
                  </div>
                </div>

                <div style={{flex: 1}} />

                <div style={{display: 'flex', alignItems: 'center', gap: 10}}>
                  {showPause ? <IconButton kind="pause" tint="red" /> : <IconButton kind="mic" tint="cyan" />}
                  {phase === 'recording' ? <IconButton kind="x" tint="red" subtle /> : null}
                  {showFinish ? (
                    <div
                      style={{
                        transform:
                          phase === 'transcribing' || phase === 'summarizing'
                            ? `scale(${interpolate(finishPress, [0, 1], [1, 0.95])})`
                            : 'scale(1)',
                      }}
                    >
                      <IconButton
                        kind="finish"
                        tint="green"
                        subtle={phase !== 'recording'}
                      />
                    </div>
                  ) : null}
                </div>
              </div>
            </WidgetShell>
          </div>
        ) : null}

        {frame >= 292 ? <HistoryScreen fromFrame={292} /> : null}
      </div>
    </Background>
  );
};

const StatusPill: React.FC<{label: string}> = ({label}) => (
  <div
    style={{
      color: 'rgba(255,255,255,0.82)',
      fontSize: 13,
      fontWeight: 700,
      padding: '8px 12px',
      borderRadius: 999,
      background: 'rgba(255,255,255,0.08)',
      border: '1px solid rgba(255,255,255,0.10)',
      whiteSpace: 'nowrap',
    }}
  >
    {label}
  </div>
);

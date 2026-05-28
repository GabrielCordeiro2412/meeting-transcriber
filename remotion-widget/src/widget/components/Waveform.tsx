import React, {useMemo} from 'react';
import {interpolate, useCurrentFrame, useVideoConfig} from 'remotion';

type Props = {
  active: boolean;
};

type Bar = {h: number; phase: number};

const clamp = (v: number, min: number, max: number) => Math.min(max, Math.max(min, v));

export const Waveform: React.FC<Props> = ({active}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const bars = useMemo<Bar[]>(() => {
    const n = 18;
    const out: Bar[] = [];
    for (let i = 0; i < n; i++) {
      // Deterministic pseudo randomness.
      const seed = Math.sin(i * 12.9898) * 43758.5453;
      const frac = seed - Math.floor(seed);
      out.push({h: 0.35 + frac * 0.65, phase: frac * Math.PI * 2});
    }
    return out;
  }, []);

  const t = frame / fps;
  const baseAmp = active ? 1 : 0.18;
  const containerOpacity = active ? 1 : 0.85;

  return (
    <div
      style={{
        width: 210,
        height: 52,
        borderRadius: 18,
        display: 'flex',
        alignItems: 'center',
        gap: 6,
        paddingLeft: 14,
        paddingRight: 14,
        background: 'transparent',
        opacity: containerOpacity,
      }}
    >
      {bars.map((bar, i) => {
        const wave = Math.sin(t * 7.2 + bar.phase + i * 0.18);
        const raw = (wave * 0.5 + 0.5) * bar.h;
        const amp = clamp(raw * baseAmp, 0.08, 1);
        const height = interpolate(amp, [0, 1], [10, 44]);

        const glow = interpolate(amp, [0, 1], [0.1, 0.55]);

        return (
          <div
            key={i}
            style={{
              width: 6,
              height,
              borderRadius: 6,
              background: 'linear-gradient(180deg, rgba(130,210,255,1), rgba(80,160,255,1))',
              boxShadow: `0 0 14px rgba(90, 185, 255, ${glow})`,
            }}
          />
        );
      })}
    </div>
  );
};


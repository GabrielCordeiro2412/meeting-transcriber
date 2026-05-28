import React from 'react';
import {interpolate, useCurrentFrame} from 'remotion';

type Kind = 'mic' | 'pause' | 'x' | 'finish';

type Props = {
  kind: Kind;
  tint: 'cyan' | 'green' | 'red';
  subtle?: boolean;
};

const tintMap: Record<Props['tint'], {bg: string; glow: string}> = {
  cyan: {bg: 'rgba(55, 210, 255, 0.95)', glow: 'rgba(55, 210, 255, 0.30)'},
  green: {bg: 'rgba(55, 190, 120, 0.88)', glow: 'rgba(55, 190, 120, 0.28)'},
  red: {bg: 'rgba(245, 75, 75, 0.88)', glow: 'rgba(245, 75, 75, 0.28)'},
};

const iconFor = (kind: Kind) => {
  // Use simple SVGs to avoid font rendering differences.
  switch (kind) {
    case 'mic':
      return (
        <path
          d="M12 14.5c2.2 0 4-1.8 4-4V6.5c0-2.2-1.8-4-4-4s-4 1.8-4 4v4c0 2.2 1.8 4 4 4Zm6-4a1 1 0 1 1 2 0c0 3.7-2.8 6.8-6.5 7.2V20h2a1 1 0 1 1 0 2h-7a1 1 0 1 1 0-2h2v-2.3C6.8 17.3 4 14.2 4 10.5a1 1 0 1 1 2 0c0 3.3 2.7 6 6 6s6-2.7 6-6Z"
          fill="white"
          fillRule="evenodd"
        />
      );
    case 'pause':
      return (
        <path
          d="M7 5.5A1.5 1.5 0 0 1 8.5 4h1A1.5 1.5 0 0 1 11 5.5v13A1.5 1.5 0 0 1 9.5 20h-1A1.5 1.5 0 0 1 7 18.5v-13Zm6 0A1.5 1.5 0 0 1 14.5 4h1A1.5 1.5 0 0 1 17 5.5v13A1.5 1.5 0 0 1 15.5 20h-1A1.5 1.5 0 0 1 13 18.5v-13Z"
          fill="white"
        />
      );
    case 'x':
      return (
        <path
          d="M6.3 6.3a1 1 0 0 1 1.4 0L12 10.6l4.3-4.3a1 1 0 1 1 1.4 1.4L13.4 12l4.3 4.3a1 1 0 0 1-1.4 1.4L12 13.4l-4.3 4.3a1 1 0 0 1-1.4-1.4l4.3-4.3-4.3-4.3a1 1 0 0 1 0-1.4Z"
          fill="white"
          fillRule="evenodd"
        />
      );
    case 'finish':
      return (
        <path
          d="M4 6.5A2.5 2.5 0 0 1 6.5 4h11A2.5 2.5 0 0 1 20 6.5v11A2.5 2.5 0 0 1 17.5 20h-11A2.5 2.5 0 0 1 4 17.5v-11Zm10.2 4.0a1 1 0 0 1 1.5 1.3l-4.1 4.8a1 1 0 0 1-1.5.0l-1.9-2.2a1 1 0 1 1 1.5-1.3l1.1 1.3 3.4-3.9Z"
          fill="white"
          fillRule="evenodd"
        />
      );
  }
};

export const IconButton: React.FC<Props> = ({kind, tint, subtle}) => {
  const frame = useCurrentFrame();
  const pulse = interpolate(frame % 30, [0, 15, 30], [1, 1.03, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const {bg, glow} = tintMap[tint];
  const opacity = subtle ? 0.86 : 1;

  return (
    <div
      style={{
        width: 44,
        height: 44,
        borderRadius: 999,
        background: bg,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        boxShadow: `0 10px 25px ${glow}`,
        transform: `scale(${subtle ? 1 : pulse})`,
        opacity,
      }}
    >
      <svg width={22} height={22} viewBox="0 0 24 24" aria-hidden="true">
        {iconFor(kind)}
      </svg>
    </div>
  );
};


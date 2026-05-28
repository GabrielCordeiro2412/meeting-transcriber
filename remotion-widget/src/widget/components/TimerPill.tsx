import React from 'react';

const format = (seconds: number) => {
  const total = Math.floor(seconds);
  const mm = Math.floor(total / 60);
  const ss = total % 60;
  return `${String(mm).padStart(2, '0')}:${String(ss).padStart(2, '0')}`;
};

export const TimerPill: React.FC<{seconds: number}> = ({seconds}) => {
  return (
    <div
      style={{
        paddingLeft: 14,
        paddingRight: 14,
        paddingTop: 8,
        paddingBottom: 8,
        borderRadius: 999,
        background: 'rgba(20, 26, 33, 0.32)',
        border: '1px solid rgba(255,255,255,0.14)',
        color: 'rgba(255,255,255,0.92)',
        fontWeight: 800,
        fontSize: 18,
        letterSpacing: 0.2,
        fontVariantNumeric: 'tabular-nums',
      }}
    >
      {format(seconds)}
    </div>
  );
};


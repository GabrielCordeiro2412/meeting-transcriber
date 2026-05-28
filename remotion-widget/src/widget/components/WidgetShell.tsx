import React from 'react';

type Props = React.PropsWithChildren<{
  active: boolean;
  width: number;
}>;

export const WidgetShell: React.FC<Props> = ({active, width, children}) => {
  const radius = 54;

  // Approximates FloatingWidgetView.swift:
  // - HUDWindow blur (video can't blur background reliably) => emulate via translucent gradient + inner shine
  // - cyan/blue glow blobs
  const borderOpacity = active ? 0.22 : 0.12;

  return (
    <div
      style={{
        width,
        height: 140,
        borderRadius: radius,
        position: 'relative',
        overflow: 'hidden',
        border: `1px solid rgba(255,255,255,${borderOpacity})`,
        boxShadow: '0 18px 55px rgba(0,0,0,0.42)',
      }}
    >
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background:
            'linear-gradient(135deg, rgba(23,33,46,0.64), rgba(26,46,61,0.58), rgba(33,61,74,0.52))',
          filter: 'saturate(1.08)',
        }}
      />

      <div
        style={{
          position: 'absolute',
          width: 180,
          height: 180,
          left: -34,
          top: -60,
          background: 'rgba(0, 255, 255, 0.14)',
          borderRadius: 999,
          filter: 'blur(26px)',
        }}
      />
      <div
        style={{
          position: 'absolute',
          width: 150,
          height: 150,
          right: 42,
          bottom: 42,
          background: 'rgba(60, 120, 255, 0.12)',
          borderRadius: 999,
          filter: 'blur(28px)',
        }}
      />

      <div
        style={{
          position: 'absolute',
          inset: 10,
          borderRadius: radius - 10,
          background:
            'linear-gradient(135deg, rgba(255,255,255,0.12), rgba(255,255,255,0))',
          filter: 'blur(14px)',
          opacity: 1,
        }}
      />

      <div style={{position: 'relative', height: '100%'}}>{children}</div>
    </div>
  );
};

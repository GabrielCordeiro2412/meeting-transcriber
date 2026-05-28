import React from 'react';

export const Background: React.FC<React.PropsWithChildren> = ({children}) => {
  return (
    <div
      style={{
        width: '100%',
        height: '100%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background:
          'radial-gradient(900px 600px at 30% 30%, rgba(80,140,255,0.55), rgba(0,0,0,0) 70%), radial-gradient(900px 600px at 70% 70%, rgba(80,255,220,0.22), rgba(0,0,0,0) 70%), linear-gradient(135deg, #0b1220, #05080f)',
        fontFamily:
          '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif',
      }}
    >
      {children}
    </div>
  );
};


import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';

export const HistoryScreen: React.FC<{fromFrame: number}> = ({fromFrame}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const localFrame = Math.max(0, frame - fromFrame);

  const shellIn = spring({
    fps,
    frame: localFrame,
    config: {damping: 20, stiffness: 110, mass: 0.95},
    durationInFrames: 34,
  });

  const listIn = spring({
    fps,
    frame: localFrame - 8,
    config: {damping: 18, stiffness: 120},
    durationInFrames: 28,
  });

  const detailIn = spring({
    fps,
    frame: localFrame - 14,
    config: {damping: 18, stiffness: 118},
    durationInFrames: 30,
  });

  return (
    <div
      style={{
        width: 1640,
        height: 960,
        borderRadius: 38,
        overflow: 'hidden',
        border: '1px solid rgba(255,255,255,0.12)',
        background: '#1f2126',
        boxShadow: '0 36px 84px rgba(0,0,0,0.48)',
        opacity: shellIn,
        transform: `translateY(${interpolate(shellIn, [0, 1], [-120, 0])}px) scale(${interpolate(shellIn, [0, 1], [0.985, 1])})`,
      }}
    >
      <TopBar />

      <div style={{display: 'grid', gridTemplateColumns: '260px 1fr', height: 'calc(100% - 62px)'}}>
        <Sidebar listIn={listIn} />
        <Detail detailIn={detailIn} />
      </div>
    </div>
  );
};

const TopBar: React.FC = () => {
  return (
    <div
      style={{
        height: 62,
        background: '#242732',
        borderBottom: '1px solid rgba(255,255,255,0.06)',
        display: 'flex',
        alignItems: 'center',
        paddingLeft: 18,
        paddingRight: 18,
      }}
    >
      <div style={{display: 'flex', alignItems: 'center', gap: 10, marginRight: 20}}>
        <TrafficLight color="#ff6058" />
        <TrafficLight color="#ffbd2f" />
        <TrafficLight color="#28c840" />
      </div>

      <div style={{color: 'rgba(255,255,255,0.94)', fontSize: 22, fontWeight: 800, marginRight: 20}}>
        Testes iniciais do...
      </div>

      <div style={{display: 'flex', alignItems: 'center', gap: 10}}>
        <ToolbarBubble icon="↻" />
        <ToolbarBubble icon="◫" />
      </div>

      <div
        style={{
          width: 1,
          alignSelf: 'stretch',
          background: 'rgba(255,255,255,0.08)',
          marginLeft: 16,
          marginRight: 16,
        }}
      />

      <ToolbarBubble icon="↗" />
    </div>
  );
};

const Sidebar: React.FC<{listIn: number}> = ({listIn}) => {
  return (
    <div
      style={{
        background: '#202020',
        borderRight: '1px solid rgba(255,255,255,0.06)',
        padding: 14,
        opacity: listIn,
        transform: `translateX(${interpolate(listIn, [0, 1], [-18, 0])}px)`,
      }}
    >
      {[
        'Discussion on...',
        'Testes iniciais...',
        'Planejamento...',
        'Discussao sob...',
        'Reuniao sobre...',
        'Treinamento s...',
        'Meeting 26 Ma...',
        'Meeting 26 Ma...',
      ].map((title, index) => (
        <SidebarRow
          key={title + index}
          title={title}
          active={index === 1}
          warning={index > 5}
        />
      ))}
    </div>
  );
};

const Detail: React.FC<{detailIn: number}> = ({detailIn}) => {
  return (
    <div
      style={{
        background: '#1f1f1f',
        overflow: 'hidden',
        opacity: detailIn,
        transform: `translateY(${interpolate(detailIn, [0, 1], [18, 0])}px)`,
      }}
    >
      <div
        style={{
          height: '100%',
          overflow: 'hidden',
          paddingLeft: 44,
          paddingRight: 52,
          paddingTop: 42,
          paddingBottom: 42,
        }}
      >
        <div style={{color: '#e7e7e7', fontSize: 64, lineHeight: 1.08, fontWeight: 800, marginBottom: 18, maxWidth: 1080}}>
          Testes iniciais do sistema de transcricao de audio com OpenAI APIKey
        </div>

        <div style={{display: 'flex', alignItems: 'center', gap: 24, marginBottom: 40, color: 'rgba(255,255,255,0.62)', fontSize: 17}}>
          <MetaDot label="Completed" />
          <MetaDot label="Microphone + app audio" />
          <MetaDot label="0m 37s" />
        </div>

        <div style={{display: 'grid', rowGap: 34, maxWidth: 1100}}>
          <DetailSection
            title="Summary"
            icon="☰"
            body="O encontro discutiu os testes iniciais do sistema de transcricao de audio que suporta exclusivamente a OpenAI APIKey como metodo de autenticacao. O projeto e destinado para uso individual, onde os usuarios configuram sua propria chave da OpenAI para poder utilizar o sistema localmente. Dessa forma, decidiu-se que nao havera suporte para outras APIKeys para manter a simplicidade. Foram estabelecidas acoes para testar as funcionalidades e validar o armazenamento da APIKey."
          />

          <DetailListSection
            title="Detailed Notes"
            icon="▣"
            items={[
              'O foco principal do projeto e a transcricao de audio utilizando a OpenAI API.',
              'A unica chave suportada sera a OpenAI APIKey para nao complicar o sistema.',
              'O projeto serve para ser utilizado em maquinas locais, permitindo que os usuarios configurem suas proprias chaves.',
              'Nos testes iniciais, foi destacado que basta o usuario possuir uma OpenAI APIKey para configurar e baixar o sistema.',
              'Nao havera suporte para outras APIs porque isso poderia dificultar a implementacao e o uso.',
              'A ideia e que o projeto funcione como um portfolio que as pessoas podem utilizar facilmente.',
            ]}
          />

          <DetailListSection
            title="Topics"
            icon="⌁"
            items={[
              'Sistema de transcricao de audio',
              'OpenAI APIKey',
              'Projeto para portfolio',
              'Configuracao local do sistema',
            ]}
          />

          <DetailListSection
            title="Key Points"
            icon="☷"
            items={[
              'O sistema de transcricao de audio esta sendo desenvolvido para uso pessoal em maquinas dos usuarios.',
              'Sera suportada somente a OpenAI APIKey, sem suporte a outras chaves ou provedores.',
              'O projeto tem carater mais de portfolio para facilitar o uso individual.',
              'Usuarios precisam ter uma chave da OpenAI para configurar e usar o sistema.',
            ]}
          />
        </div>
      </div>
    </div>
  );
};

const DetailSection: React.FC<{title: string; icon: string; body: string}> = ({title, icon, body}) => (
  <div>
    <SectionLabel title={title} icon={icon} />
    <div style={{color: '#e0e0e0', fontSize: 20, lineHeight: 1.42, maxWidth: 1060}}>{body}</div>
  </div>
);

const DetailListSection: React.FC<{title: string; icon: string; items: string[]}> = ({title, icon, items}) => (
  <div>
    <SectionLabel title={title} icon={icon} />
    <div>
      {items.map((item) => (
        <div key={item} style={{display: 'flex', alignItems: 'flex-start', gap: 16, color: '#e0e0e0', fontSize: 20, lineHeight: 1.38, marginBottom: 14}}>
          <div style={{width: 14, height: 14, borderRadius: 999, background: '#f1f1f1', marginTop: 8, flexShrink: 0}} />
          <div>{item}</div>
        </div>
      ))}
    </div>
  </div>
);

const SectionLabel: React.FC<{title: string; icon: string}> = ({title, icon}) => (
  <div style={{display: 'flex', alignItems: 'center', gap: 14, color: '#f2f2f2', fontSize: 22, fontWeight: 800, marginBottom: 16}}>
    <div style={{width: 24, textAlign: 'center', color: 'rgba(255,255,255,0.88)'}}>{icon}</div>
    <div>{title}</div>
  </div>
);

const SidebarRow: React.FC<{title: string; active?: boolean; warning?: boolean}> = ({title, active, warning}) => (
  <div
    style={{
      padding: '12px 14px',
      borderRadius: 22,
      background: active ? '#2f6df6' : 'transparent',
      color: active ? '#ffffff' : '#f2f2f2',
      marginBottom: 8,
    }}
  >
    <div style={{fontSize: 18, fontWeight: 800, marginBottom: 8, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis'}}>
      {title}
    </div>
    <div style={{display: 'flex', alignItems: 'center', gap: 12, color: active ? 'rgba(255,255,255,0.82)' : 'rgba(255,255,255,0.52)', fontSize: 13, fontWeight: 700}}>
      <span>{warning ? '⚠' : '◉'}</span>
      <span>C...</span>
      <span>28 May 2...</span>
    </div>
  </div>
);

const ToolbarBubble: React.FC<{icon: string}> = ({icon}) => (
  <div
    style={{
      width: 54,
      height: 54,
      borderRadius: 27,
      background: 'rgba(255,255,255,0.03)',
      border: '1px solid rgba(255,255,255,0.12)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      color: 'rgba(255,255,255,0.9)',
      fontSize: 28,
      fontWeight: 700,
    }}
  >
    {icon}
  </div>
);

const TrafficLight: React.FC<{color: string}> = ({color}) => (
  <div
    style={{
      width: 18,
      height: 18,
      borderRadius: 9,
      background: color,
    }}
  />
);

const MetaDot: React.FC<{label: string}> = ({label}) => (
  <div style={{display: 'flex', alignItems: 'center', gap: 10}}>
    <div style={{width: 16, height: 16, borderRadius: 999, border: '2px solid rgba(255,255,255,0.56)'}} />
    <div>{label}</div>
  </div>
);


import {Composition} from 'remotion';
import {WidgetRecordingDemo} from './widget/WidgetRecordingDemo';

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="WidgetRecordingDemo"
        component={WidgetRecordingDemo}
        durationInFrames={390}
        fps={30}
        width={1920}
        height={1080}
        defaultProps={{
          theme: 'meeting-notes-widget',
        }}
      />
    </>
  );
};

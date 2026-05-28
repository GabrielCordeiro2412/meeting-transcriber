const path = require('path');
const {bundle} = require('@remotion/bundler');
const {renderMedia, selectComposition} = require('@remotion/renderer');

const entry = path.join(__dirname, '..', 'src', 'entry.tsx');

async function main() {
  const outDir = path.join(__dirname, '..', 'out');
  const outPath = path.join(outDir, 'widget.mp4');

  const bundleLocation = await bundle({
    entryPoint: entry,
    webpackOverride: (current) => current,
  });

  const composition = await selectComposition({
    serveUrl: bundleLocation,
    id: 'WidgetRecordingDemo',
    inputProps: {theme: 'meeting-notes-widget'},
  });

  await renderMedia({
    codec: 'h264',
    composition,
    serveUrl: bundleLocation,
    outputLocation: outPath,
    inputProps: {theme: 'meeting-notes-widget'},
    crf: 18,
    pixelFormat: 'yuv420p',
  });

  // eslint-disable-next-line no-console
  console.log(`Rendered: ${outPath}`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});

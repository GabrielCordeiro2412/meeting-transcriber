const path = require('path');
const {bundle} = require('@remotion/bundler');
const {renderStill, selectComposition} = require('@remotion/renderer');

const entry = path.join(__dirname, '..', 'src', 'entry.tsx');

async function main() {
  const outDir = path.join(__dirname, '..', 'out');
  const outPath = path.join(outDir, 'widget.png');

  const bundleLocation = await bundle({
    entryPoint: entry,
    webpackOverride: (current) => current,
  });

  const composition = await selectComposition({
    serveUrl: bundleLocation,
    id: 'WidgetRecordingDemo',
    inputProps: {theme: 'meeting-notes-widget'},
  });

  await renderStill({
    composition,
    serveUrl: bundleLocation,
    output: outPath,
    inputProps: {theme: 'meeting-notes-widget'},
    frame: 90,
  });

  // eslint-disable-next-line no-console
  console.log(`Rendered still: ${outPath}`);
}

main().catch((err) => {
  // eslint-disable-next-line no-console
  console.error(err);
  process.exit(1);
});

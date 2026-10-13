import { build } from 'esbuild';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { Script } from 'node:vm';

await mkdir('dist', { recursive: true });
const notices = await readFile('THIRD_PARTY_NOTICES.md', 'utf8');
const worker = await build({
  entryPoints: ['src/cosmic/physics/worker.ts'], bundle: true, minify: true,
  format: 'iife', target: 'es2022', write: false, outfile: 'worker.js',
});
const workerSource = worker.outputFiles[0].text;
new Script(workerSource, { filename: 'physics-worker.js' });
for (const app of [
  { entry: 'src/cosmic/main.ts', html: 'index.html', output: 'dist/index.html', worker: true },
  { entry: 'src/main.js', html: 'blackhole.html', output: 'dist/blackhole.html', worker: false },
]) {
  const result = await build({
    entryPoints: [app.entry], bundle: true, minify: true,
    format: 'iife', target: 'es2022', write: false,
    loader: { '.glsl': 'text' }, outfile: 'app.js',
    define: app.worker ? { 'import.meta.url': 'location.href' } : {},
  });
  let js = result.outputFiles.find(f => f.path.endsWith('.js')).text;
  const css = result.outputFiles.find(f => f.path.endsWith('.css')).text;
  if (app.worker) js = `window.__COSMIC_WORKER_SOURCE__=${JSON.stringify(workerSource)};\n${js}`;
  let html = await readFile(app.html, 'utf8');
  html = html.replace('</head>', () => `<style>${css}</style>\n</head>`)
    .replace(`<script type="module" src="/${app.entry}"></script>`, () => `<script>${js.replaceAll('</script', '<\\/script')}</script>`);
  html = html.replace('</html>', () => `<!--\n${notices}\n-->\n</html>`);
  const embeddedScript = html.match(/<script>([\s\S]*?)<\/script>/)?.[1];
  if (!embeddedScript) throw new Error(`Standalone script was not embedded: ${app.output}`);
  new Script(embeddedScript, { filename: app.output });
  await writeFile(app.output, html);
  console.log(`Built ${app.output} (${(Buffer.byteLength(html) / 1024).toFixed(0)} KiB), with no external assets${app.worker ? ' and embedded physics Worker' : ''}.`);
}

import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const args = new Map();
for (let index = 2; index < process.argv.length; index += 1) {
  const arg = process.argv[index];
  if (arg.startsWith('--')) {
    const key = arg.slice(2);
    const next = process.argv[index + 1];
    if (next && !next.startsWith('--')) {
      args.set(key, next);
      index += 1;
    } else {
      args.set(key, 'true');
    }
  }
}

const url = args.get('url') ?? process.env.SMOKE_URL ?? 'https://fiestaaa.app';
const timeoutMs = Number(args.get('timeout-ms') ?? process.env.SMOKE_TIMEOUT_MS ?? 30000);
const locale = args.get('locale') ?? process.env.SMOKE_LOCALE ?? 'fr-FR';

const browser = await chromium.launch();
const page = await browser.newPage({
  viewport: { width: 1366, height: 900 },
  deviceScaleFactor: 1,
  locale,
});

const failures = [];
const ignoredConsoleErrors = [
  /Failed to load resource: the server responded with a status of 401/,
];

page.on('console', (message) => {
  const text = message.text();
  if (
    message.type() === 'error' &&
    !ignoredConsoleErrors.some((pattern) => pattern.test(text))
  ) {
    failures.push(`console error: ${text}`);
  }
});

page.on('pageerror', (error) => {
  failures.push(`page error: ${error.message}`);
});

page.on('requestfailed', (request) => {
  const failure = request.failure();
  failures.push(`request failed: ${request.url()} (${failure?.errorText ?? 'unknown'})`);
});

try {
  const response = await page.goto(url, {
    waitUntil: 'domcontentloaded',
    timeout: timeoutMs,
  });

  if (!response || !response.ok()) {
    throw new Error(`navigation failed with status ${response?.status() ?? 'no response'}`);
  }

  await page.waitForLoadState('networkidle', { timeout: timeoutMs }).catch(() => {});

  await page.waitForFunction(
    () => {
      const host = document.querySelector('flt-glass-pane, flutter-view');
      const canvases = Array.from(document.querySelectorAll('canvas'));
      return Boolean(host) || canvases.some((canvas) => canvas.width > 0 && canvas.height > 0);
    },
    { timeout: timeoutMs },
  );

  const screenshot = await page.screenshot({ fullPage: false });
  const png = PNG.sync.read(screenshot);
  let sampled = 0;
  let nonBlank = 0;
  const step = 8;

  for (let y = 0; y < png.height; y += step) {
    for (let x = 0; x < png.width; x += step) {
      const offset = (png.width * y + x) << 2;
      const r = png.data[offset];
      const g = png.data[offset + 1];
      const b = png.data[offset + 2];
      const a = png.data[offset + 3];
      sampled += 1;
      if (a > 16 && (r < 245 || g < 245 || b < 245)) {
        nonBlank += 1;
      }
    }
  }

  const nonBlankRatio = nonBlank / sampled;
  if (nonBlankRatio < 0.01) {
    throw new Error(`page appears blank (${(nonBlankRatio * 100).toFixed(2)}% non-blank pixels)`);
  }

  if (failures.length > 0) {
    throw new Error(failures.join('\n'));
  }

  console.log(`Smoke check passed for ${url}`);
} catch (error) {
  console.error(`Smoke check failed for ${url}`);
  if (failures.length > 0) {
    console.error(failures.join('\n'));
  }
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
} finally {
  await browser.close();
}

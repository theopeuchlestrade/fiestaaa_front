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
const viewportArg = args.get('viewport') ?? process.env.SMOKE_VIEWPORT ?? 'all';
const expectedCspOrigin =
  args.get('expect-csp-origin') ?? process.env.SMOKE_EXPECT_CSP_ORIGIN;

const viewports = [
  {
    name: 'desktop',
    viewport: { width: 1366, height: 900 },
    deviceScaleFactor: 1,
  },
  {
    name: 'mobile',
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    isMobile: true,
    hasTouch: true,
  },
];

const selectedViewports = viewportArg === 'all'
  ? viewports
  : viewports.filter((candidate) => candidate.name === viewportArg);

if (selectedViewports.length === 0) {
  console.error(`Unknown viewport "${viewportArg}". Use desktop, mobile, or all.`);
  process.exit(1);
}

const ignoredConsoleErrors = [
  /Failed to load resource: the server responded with a status of 401/,
];

function collectPageFailures(page, failures) {
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
}

async function waitForFlutter(page) {
  await page.waitForFunction(
    () => {
      const host = document.querySelector('flt-glass-pane, flutter-view');
      const canvases = Array.from(document.querySelectorAll('canvas'));
      return Boolean(host) || canvases.some((canvas) => canvas.width > 0 && canvas.height > 0);
    },
    undefined,
    { timeout: timeoutMs },
  );
}

async function assertNonBlank(page, viewportName) {
  const deadline = Date.now() + timeoutMs;
  let nonBlankRatio = 0;
  do {
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

    nonBlankRatio = nonBlank / sampled;
    if (nonBlankRatio >= 0.01) return;
    // Flutter can attach its host before painting the first frame.
    await page.waitForTimeout(100);
  } while (Date.now() < deadline);
  throw new Error(
    `${viewportName} page appears blank (${(nonBlankRatio * 100).toFixed(2)}% non-blank pixels)`,
  );
}

async function smokeViewport(browser, targetViewport) {
  const failures = [];
  const page = await browser.newPage({
    viewport: targetViewport.viewport,
    deviceScaleFactor: targetViewport.deviceScaleFactor,
    isMobile: targetViewport.isMobile ?? false,
    hasTouch: targetViewport.hasTouch ?? false,
    locale,
  });
  collectPageFailures(page, failures);

  try {
    const response = await page.goto(url, {
      waitUntil: 'domcontentloaded',
      timeout: timeoutMs,
    });

    if (!response || !response.ok()) {
      throw new Error(`navigation failed with status ${response?.status() ?? 'no response'}`);
    }
    if (expectedCspOrigin) {
      const csp = response.headers()['content-security-policy'] ?? '';
      if (!csp.includes(expectedCspOrigin)) {
        throw new Error(
          `Content-Security-Policy does not contain ${expectedCspOrigin}`,
        );
      }
    }

    await page.waitForLoadState('networkidle', { timeout: timeoutMs }).catch(() => {});
    await waitForFlutter(page);
    await assertNonBlank(page, targetViewport.name);

    if (failures.length > 0) {
      throw new Error(failures.join('\n'));
    }
  } finally {
    await page.close();
  }

}

const browser = await chromium.launch();
const failures = [];

try {
  for (const targetViewport of selectedViewports) {
    try {
      await smokeViewport(browser, targetViewport);
      console.log(`Smoke check passed for ${url} (${targetViewport.name})`);
    } catch (error) {
      failures.push(
        `${targetViewport.name}: ${error instanceof Error ? error.message : String(error)}`,
      );
    }
  }

} finally {
  await browser.close();
}

if (failures.length > 0) {
  console.error(`Smoke check failed for ${url}`);
  console.error(failures.join('\n'));
  process.exitCode = 1;
}

// Renders composition.html frame by frame and encodes the landing-page video.
//
//   node render.mjs --lang bg                 # MP4 + WebM + poster
//   node render.mjs --lang en --stills 2,7.5  # PNG stills for review
//
// Options: --comp story (the "dark to clear" cut), --fps 60, --out <dir>,
// --poster <seconds>, --chrome <executable>.
import { spawn } from "node:child_process";
import { mkdirSync, existsSync, readdirSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { chromium } from "playwright";

const here = dirname(fileURLToPath(import.meta.url));
const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, arg, i, all) => {
  if (arg.startsWith("--")) pairs.push([arg.slice(2), all[i + 1]?.startsWith("--") ? true : all[i + 1] ?? true]);
  return pairs;
}, []));

const lang = args.lang === "en" ? "en" : "bg";
const comp = args.comp === "story" ? "story" : "composition";
const name = comp === "story" ? `mesto-explainer-story-${lang}` : `mesto-explainer-${lang}`;
// The story cut opens in the dark, so its poster must be the first frame or
// the page flashes a lit frame before playback starts.
const posterAt = Number(args.poster ?? (comp === "story" ? 0 : 22.5));
const fps = Number(args.fps || 60);
const outDir = resolve(args.out || join(here, "../../app/assets/videos"));

mkdirSync(outDir, { recursive: true });

function chromeExecutable() {
  if (args.chrome) return args.chrome;
  const bundled = chromium.executablePath();
  if (existsSync(bundled)) return bundled;
  // Fall back to any Chromium already downloaded by another Playwright version.
  const cache = join(homedir(), "Library/Caches/ms-playwright");
  const builds = existsSync(cache) ? readdirSync(cache).filter((d) => /^chromium-\d+$/.test(d)).sort().reverse() : [];
  for (const build of builds) {
    const candidate = join(cache, build, "chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing");
    if (existsSync(candidate)) return candidate;
  }
  throw new Error("No Chromium found. Run `npx playwright install chromium` or pass --chrome.");
}

function ffmpeg(ffArgs) {
  const proc = spawn("ffmpeg", ["-hide_banner", "-loglevel", "error", "-y", ...ffArgs], { stdio: ["pipe", "inherit", "inherit"] });
  const done = new Promise((ok, fail) => proc.on("close", (code) => (code === 0 ? ok() : fail(new Error(`ffmpeg exited ${code}`)))));
  return { proc, done };
}

const browser = await chromium.launch({ executablePath: chromeExecutable(), args: ["--force-color-profile=srgb", "--hide-scrollbars"] });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
page.on("pageerror", (error) => { console.error(error); process.exitCode = 1; });
const url = `${pathToFileURL(join(here, `${comp}.html`)).href}?render&lang=${lang}`;
await page.goto(url, { waitUntil: "networkidle" });
await page.evaluate(() => window.__ready);
const duration = await page.evaluate(() => window.__duration);
const stage = page.locator("#stage");

async function frameAt(t) {
  await page.evaluate((time) => window.__seek(time), t);
  return stage.screenshot({ type: "png", animations: "disabled", caret: "initial", scale: "css" });
}

if (args.stills) {
  const times = String(args.stills).split(",").map(Number);
  for (const t of times) {
    const file = join(outDir, `still-${name}-${t.toFixed(2)}.png`);
    await page.evaluate((time) => window.__seek(time), t);
    await stage.screenshot({ path: file, scale: "css" });
    console.log(file);
  }
  await browser.close();
  process.exit();
}

const base = join(outDir, name);
// Lossless intermediate first, so both delivery encodes come from identical pixels.
const tmpDir = join(here, "../../tmp");
mkdirSync(tmpDir, { recursive: true });
const master = join(tmpDir, `${name}.master.mkv`);
const { proc, done } = ffmpeg(["-f", "image2pipe", "-framerate", String(fps), "-c:v", "png", "-i", "-", "-c:v", "ffv1", "-pix_fmt", "yuv444p", master]);
const total = Math.round(duration * fps);
const started = Date.now();
for (let i = 0; i < total; i++) {
  const png = await frameAt(i / fps);
  if (!proc.stdin.write(png)) await new Promise((ok) => proc.stdin.once("drain", ok));
  if (i % fps === 0) process.stdout.write(`\r${lang}: ${Math.round((i / total) * 100)}% (${((Date.now() - started) / 1000).toFixed(0)}s)`);
}
proc.stdin.end();
await done;
process.stdout.write(`\r${lang}: 100% frames captured\n`);

await browser.close();

await ffmpeg(["-i", master, "-c:v", "libx264", "-profile:v", "high", "-preset", "slow", "-crf", "21", "-pix_fmt", "yuv420p", "-movflags", "+faststart", "-an", `${base}.mp4`]).done;
await ffmpeg(["-i", master, "-c:v", "libvpx-vp9", "-crf", "34", "-b:v", "0", "-row-mt", "1", "-deadline", "good", "-cpu-used", "2", "-pix_fmt", "yuv420p", "-an", `${base}.webm`]).done;
const posterPath = `${base}-poster.jpg`;
await ffmpeg(["-ss", String(posterAt), "-i", master, "-frames:v", "1", "-vf", "scale=1600:-1", "-q:v", "3", posterPath]).done;
console.log(`${base}.mp4\n${base}.webm\n${posterPath}\nmaster kept at ${master}`);

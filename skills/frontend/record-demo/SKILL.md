---
name: record-demo
description: Record a demo video of a web app as an MP4 with a Playwright script. Use when the user asks for a demo, screen recording or walkthrough video of a web app, in place of the Claude in Chrome GIF recorder.
---

# Record a demo video

Drive the app with a Playwright script using `recordVideo`, then encode the result as an MP4.
The Claude in Chrome GIF recorder grabs one frame per action, caps at 50 and stamps action labels, so its result plays like a slideshow; a Playwright video plays like a real screen recording.

## Steps

1. **Set up the script outside the repo.**
   Write it in a scratch directory, and load Playwright from the project's `node_modules` with `createRequire`, so the repo gains no files and no dependencies:

   ```js
   import { createRequire } from 'node:module';
   const require = createRequire('/path/to/project/package.json');
   const { chromium } = require('playwright'); // or '@playwright/test', whichever the project has
   ```

2. **Launch the browser.**
   Date and time inputs take their format from the browser's UI language, not the context `locale`, and Playwright's bundled Chromium ignores it.
   When the demo shows dates or times in a local format, launch the system Chrome or Chromium through `executablePath` with `--lang=<locale>` and the `LANGUAGE` env var:

   ```js
   const browser = await chromium.launch({
     executablePath: '/usr/bin/chromium',
     args: ['--lang=nl-BE'],
     env: { ...process.env, LANGUAGE: 'nl_BE' },
   });
   const size = { width: 1280, height: 720 };
   const context = await browser.newContext({ viewport: size, locale: 'nl-BE', recordVideo: { dir: videoDir, size } });
   ```

3. **Make the page camera-ready with `context.addInitScript`.**
   Playwright videos show no mouse, so inject a cursor that follows `mousemove` and pulses on `mousedown`.
   In the same script, turn off spellcheck squiggles and hide dev overlays such as framework dev toolbars (`astro-dev-toolbar`, `nextjs-portal`, `vite-error-overlay`, the Nuxt devtools):

   ```js
   await context.addInitScript(() => {
     addEventListener('DOMContentLoaded', () => {
       document.documentElement.setAttribute('spellcheck', 'false');
       const style = document.createElement('style');
       style.textContent = 'astro-dev-toolbar, nextjs-portal, vite-error-overlay { display: none !important; }';
       document.head.append(style);
       const cursor = document.createElement('div');
       cursor.style.cssText = 'position:fixed;left:-40px;top:-40px;width:22px;height:22px;margin:-11px 0 0 -11px;border-radius:50%;background:rgba(255,80,80,.45);border:2px solid #fff;box-shadow:0 0 6px rgba(0,0,0,.4);pointer-events:none;z-index:2147483647;transition:transform .12s';
       document.body.append(cursor);
       addEventListener('mousemove', (e) => { cursor.style.left = `${e.clientX}px`; cursor.style.top = `${e.clientY}px`; }, true);
       addEventListener('mousedown', () => { cursor.style.transform = 'scale(.6)'; }, true);
       addEventListener('mouseup', () => { cursor.style.transform = ''; }, true);
     });
   });
   ```

4. **Act like a person the viewer can follow.**
   Glide to each target with `page.mouse.move(x, y, { steps })` and click with `page.mouse.down()` / `page.mouse.up()`, so the cursor travels and pulses where the click lands.
   Type with a per-key delay (`locator.pressSequentially(text, { delay: 80 })`).
   Scroll only when the target is out of view (`locator.scrollIntoViewIfNeeded()` before reading its `boundingBox()`), so sticky bars don't make the page jump.
   Pause briefly after each result appears, so the viewer sees it before the next action.

   ```js
   async function clickLike(locator) {
     await locator.scrollIntoViewIfNeeded();
     const box = await locator.boundingBox();
     await page.mouse.move(box.x + box.width / 2, box.y + box.height / 2, { steps: 25 });
     await page.mouse.down();
     await page.mouse.up();
   }
   ```

5. **Note when the page is ready.**
   The video starts when the page opens, blank frames and loading included.
   Record the elapsed time once the first screen has settled, then close the context so the video file is written, and take its path from `page.video().path()`.

6. **Trim and encode.**
   Cut the video to start at the ready time, and encode it as H.264 MP4 with `yuv420p` and `+faststart`, so it plays everywhere and streams before it has fully downloaded:

   ```bash
   ffmpeg -y -ss <ready-seconds> -i raw.webm -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart demo.mp4
   ```

7. **Check a contact sheet before handing it over.**
   Tile frames from across the whole video into one image, choosing the `fps` so the tiles span its full length, and read the image:

   ```bash
   ffmpeg -y -i demo.mp4 -vf "fps=1/2,scale=480:-1,tile=4x4" -frames:v 1 sheet.png
   ```

   The demo is done when the sheet shows no blank or loading frames at the start, no dev overlay, no spellcheck squiggles, the cursor on every interaction, and each step of the flow in order.
   Fix the script and re-record until it does, then give the user the MP4's full path.

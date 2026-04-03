# Factory Landing Page

## Project Summary

A single-page static website for the Factory project, hosted on GitHub Pages at
`whalbawi.github.io/factory`. The page provides discovery and frictionless installation
for Factory's 10 Claude Code skills.

## Architecture

**Tech stack:** HTML, CSS, vanilla JavaScript. No frameworks, no build step.

**Files:**

| File | Purpose |
|------|---------|
| `site/index.html` | The entire landing page (HTML + inline CSS + inline JS) |
| `site/.nojekyll` | Disables Jekyll on GitHub Pages |
| `.claude-plugin/plugin.json` | Claude Code plugin manifest |
| `marketplace.json` | Custom marketplace index (repo root) |

**Hosting:** GitHub Pages, serving from the `site/` directory on the `main` branch.

## Technical Standards

### HTML

- Single file. No partials, no includes, no templates.
- All CSS in one `<style>` block in `<head>`.
- All JS in one `<script>` block before `</body>`.
- Semantic HTML5 elements: `<header>`, `<main>`, `<section>`, `<footer>`, `<nav>`.
- `lang="en"` on `<html>`.
- Viewport meta tag for mobile.
- OpenGraph meta tags for social sharing.

### CSS

- All styles use CSS custom properties for theming.
- Theme is controlled by `data-theme` attribute on `<html>`.
- Dark mode is the default (`data-theme="dark"`).
- System font stack -- no external fonts.
- Mobile-first responsive design. Breakpoint at 768px for desktop layout.
- No CSS frameworks, no resets beyond minimal normalization.

### JavaScript

- Vanilla JS only. No libraries, no transpilation.
- Two features only: theme toggle and copy-to-clipboard buttons.
- Theme preference stored in `localStorage` under key `theme`.
- Copy buttons use `navigator.clipboard.writeText`.

### Performance

- Total page weight under 15 KB uncompressed.
- Zero external requests (no fonts, no analytics, no CDN resources).
- No images unless absolutely necessary (prefer CSS/SVG for decoration).

### JSON Files

- `plugin.json`: Must list all 10 skills with correct paths.
- `marketplace.json`: Must reference `plugin.json` with correct path.
- Both must be valid JSON (test with `python3 -m json.tool`).

## Quality Checklist

Before merging, verify:

- [ ] `python3 -m json.tool .claude-plugin/plugin.json` succeeds
- [ ] `python3 -m json.tool marketplace.json` succeeds
- [ ] Opening `site/index.html` in a browser works without a server
- [ ] Dark mode is shown by default
- [ ] Toggle switches to light mode and back
- [ ] Refreshing after toggling preserves the choice
- [ ] Install commands are visible without scrolling on 1080p
- [ ] Page is readable on a 320px-wide viewport
- [ ] Copy buttons work on all code blocks
- [ ] No console errors in browser DevTools
- [ ] View Source shows no external resource URLs

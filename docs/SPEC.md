# Spec: Factory Landing Page & Plugin Marketplace Packaging

Turn Factory from a repo-clone install into a two-command install with a public landing
page for discovery. Two deliverables: a single-file landing page hosted on GitHub Pages,
and a Claude Code plugin manifest for marketplace distribution.

## Problem

Factory has no web presence. Users must know the GitHub URL, clone the repo, and run an
installer script. There is no way to discover Factory through search or social sharing,
and the install friction is too high for casual adoption.

## Solution

1. **Landing page** at `whalbawi.github.io/factory` — a single `index.html` with inline
   CSS and JS. Dark by default. Shows the install commands above the fold. No framework,
   no build step.

2. **Plugin manifest** at `.claude-plugin/plugin.json` — packages all 10 Factory skills
   as a Claude Code plugin installable from a custom GitHub-hosted marketplace.

## Deliverables

| File | Location | Purpose |
|------|----------|---------|
| `index.html` | `site/index.html` | Landing page (GitHub Pages root) |
| `plugin.json` | `.claude-plugin/plugin.json` | Plugin manifest |
| `marketplace.json` | `.claude-plugin/marketplace.json` | Custom marketplace index |

## Landing Page

### Requirements

- Single `index.html` file. All CSS inline in a `<style>` tag. All JS inline in a
  `<script>` tag.
- No external dependencies. No fonts loaded from CDNs. Use system font stack.
- Dark mode by default. Light/dark toggle in the top-right corner. Preference saved to
  `localStorage`.
- Responsive: works on desktop (1200px+) and mobile (320px+).
- Above the fold on desktop: headline, one-sentence pitch, install commands, GitHub link.
- Page weight under 15 KB uncompressed.

### Information Architecture

The page has exactly four sections, in order:

1. **Hero** (above the fold)
   - Headline: "Factory"
   - Subheadline: "Idea to production in one pipeline."
   - Install block: the two plugin commands in a copyable code block
   - "View on GitHub" link to `https://github.com/whalbawi/factory`

2. **Pipeline** (one-line visual)
   - The 10 skills shown as a horizontal flow:
     `/ideation` -> `/spec` -> `/prototype` -> `/setup` -> `/build` -> `/retro` ->
     `/qa` -> `/security` -> `/deploy`
   - Plus `/genesis` shown as the orchestrator above the flow
   - On mobile: wraps to multiple lines

3. **Install** (expanded)
   - Two install methods:
     - **Plugin** (preferred): the two `/plugin` commands
     - **Manual**: `git clone` + `./install.sh` (existing flow)
   - Each method in its own code block with a copy button

4. **Footer**
   - "Built with Claude Code" text
   - Link to GitHub repo
   - Link to Factory's LICENSE

### HTML Structure

```html
<!DOCTYPE html>
<html lang="en" data-theme="dark">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Factory — Idea to Production</title>
  <meta name="description"
        content="A pipeline of Claude Code skills that takes software products from idea
                 to production.">
  <meta property="og:title" content="Factory">
  <meta property="og:description"
        content="Idea to production in one pipeline. 10 Claude Code skills for the full
                 development lifecycle.">
  <meta property="og:url" content="https://whalbawi.github.io/factory">
  <meta property="og:type" content="website">
  <style>/* all CSS here */</style>
</head>
<body>
  <header>
    <nav>
      <span class="logo">Factory</span>
      <button id="theme-toggle" aria-label="Toggle dark/light mode">...</button>
    </nav>
  </header>

  <main>
    <section id="hero">
      <h1>Factory</h1>
      <p class="pitch">Idea to production in one pipeline.</p>
      <div class="install-quick">
        <pre><code>/plugin marketplace add whalbawi/factory
/plugin install factory@factory-marketplace</code></pre>
      </div>
      <a href="https://github.com/whalbawi/factory" class="gh-link">View on GitHub</a>
    </section>

    <section id="pipeline">
      <div class="pipeline-flow">
        <!-- 10 skill nodes connected by arrows -->
      </div>
    </section>

    <section id="install">
      <h2>Install</h2>
      <div class="method">
        <h3>Plugin (recommended)</h3>
        <pre><code>/plugin marketplace add whalbawi/factory
/plugin install factory@factory-marketplace</code></pre>
      </div>
      <div class="method">
        <h3>Manual</h3>
        <pre><code>git clone https://github.com/whalbawi/factory.git
cd factory && ./install.sh</code></pre>
      </div>
    </section>
  </main>

  <footer>
    <p>Built with <a href="https://claude.com/claude-code">Claude Code</a></p>
    <p>
      <a href="https://github.com/whalbawi/factory">GitHub</a> ·
      <a href="https://github.com/whalbawi/factory/blob/main/LICENSE">License</a>
    </p>
  </footer>

  <script>/* theme toggle JS here */</script>
</body>
</html>
```

### Design Tokens

Use CSS custom properties on `[data-theme]` for theming:

```css
[data-theme="dark"] {
  --bg: #0d1117;
  --bg-secondary: #161b22;
  --text: #e6edf3;
  --text-muted: #8b949e;
  --accent: #58a6ff;
  --border: #30363d;
  --code-bg: #0d1117;
}

[data-theme="light"] {
  --bg: #ffffff;
  --bg-secondary: #f6f8fa;
  --text: #1f2328;
  --text-muted: #656d76;
  --accent: #0969da;
  --border: #d0d7de;
  --code-bg: #f6f8fa;
}
```

System font stack:

```css
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans",
               Helvetica, Arial, sans-serif;
}

code, pre {
  font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas,
               "Liberation Mono", monospace;
}
```

### Theme Toggle

```javascript
const toggle = document.getElementById('theme-toggle');
const html = document.documentElement;

// Restore saved preference, default to dark
const saved = localStorage.getItem('theme');
if (saved) html.setAttribute('data-theme', saved);

toggle.addEventListener('click', () => {
  const next = html.getAttribute('data-theme') === 'dark' ? 'light' : 'dark';
  html.setAttribute('data-theme', next);
  localStorage.setItem('theme', next);
});
```

### Copy Button

Each `<pre>` block gets a copy button. On click, copy the `<code>` text content to the
clipboard and show a brief "Copied!" confirmation.

```javascript
document.querySelectorAll('pre').forEach(pre => {
  const btn = document.createElement('button');
  btn.className = 'copy-btn';
  btn.textContent = 'Copy';
  btn.addEventListener('click', () => {
    navigator.clipboard.writeText(pre.querySelector('code').textContent);
    btn.textContent = 'Copied!';
    setTimeout(() => btn.textContent = 'Copy', 1500);
  });
  pre.style.position = 'relative';
  pre.appendChild(btn);
});
```

## Plugin Manifest

### `.claude-plugin/plugin.json`

The plugin manifest. The `skills` field points to the directory containing
skill subdirectories. Claude Code auto-discovers `SKILL.md` files within
each subdirectory. Skills are namespaced by plugin name — users invoke
them as `/ideation`, `/spec`, etc.

```json
{
  "name": "factory",
  "version": "0.1.0",
  "description": "A pipeline of Claude Code skills that takes software products from idea to production.",
  "author": {
    "name": "whalbawi"
  },
  "homepage": "https://whalbawi.github.io/factory",
  "repository": "https://github.com/whalbawi/factory",
  "license": "MIT",
  "skills": "./skills/"
}
```

### `.claude-plugin/marketplace.json`

The custom marketplace index. This file must be at
`.claude-plugin/marketplace.json` in the repo root. When a user runs
`/plugin marketplace add whalbawi/factory`, Claude Code clones the repo
and reads this file.

The marketplace `name` field is used in install commands:
`/plugin install factory@factory-marketplace`.

```json
{
  "name": "factory-marketplace",
  "owner": {
    "name": "whalbawi"
  },
  "plugins": [
    {
      "name": "factory",
      "source": "./",
      "description": "Idea to production in one pipeline. 10 Claude Code skills for the full development lifecycle.",
      "version": "0.1.0"
    }
  ]
}
```

## GitHub Pages Configuration

GitHub Pages must serve from a specific directory. Since Factory's repo root contains
project files, the landing page lives in `site/` and GitHub Pages is configured to serve
from that directory.

### Setup Steps

1. Go to repo Settings > Pages.
2. Set Source to "Deploy from a branch".
3. Set Branch to `main`, folder to `/site`.
4. Save. The page will be available at `https://whalbawi.github.io/factory`.

No `CNAME` file needed. No Jekyll — add an empty `.nojekyll` file in `site/` to disable
Jekyll processing.

### Files in `site/`

| File | Purpose |
|------|---------|
| `index.html` | The landing page |
| `.nojekyll` | Disables Jekyll processing on GitHub Pages |

## Acceptance Criteria

### Landing Page

- [ ] `site/index.html` exists and is a single self-contained HTML file
- [ ] Page loads at `whalbawi.github.io/factory` after GitHub Pages is enabled
- [ ] Dark mode is the default
- [ ] Light/dark toggle works and persists across page reloads
- [ ] Install commands are visible above the fold on a 1080p desktop display
- [ ] Page renders correctly on mobile (320px viewport)
- [ ] All code blocks have a working copy button
- [ ] No external resource requests (fonts, scripts, stylesheets)
- [ ] Page weight is under 15 KB
- [ ] OpenGraph meta tags are present for social sharing
- [ ] Pipeline visualization shows all 10 skills

### Plugin Manifest

- [ ] `.claude-plugin/plugin.json` exists with valid JSON
- [ ] All 10 skills are listed in the manifest
- [ ] Skill paths in the manifest match actual file locations in the repo
- [ ] `.claude-plugin/marketplace.json` exists with valid JSON
- [ ] `/plugin marketplace add whalbawi/factory` succeeds
- [ ] `/plugin install factory@factory-marketplace` installs all 10 skills

## Architect Review

### Decisions Made

1. **Single HTML file, no build step.** The page is simple enough that a build step adds
   complexity without benefit. Inline CSS/JS keeps deployment trivial.

2. **`site/` directory for GitHub Pages.** GitHub Pages can serve from `/` (root) or
   `/docs`. Using `site/` keeps landing page files separate from Factory's own files.
   This requires selecting "Deploy from a branch" with the `/site` folder in GitHub Pages
   settings.

3. **System fonts only.** No web font loading means zero external requests and faster
   paint. The system font stack looks good on all platforms.

4. **Dark default.** Target audience is developers using Claude Code in a terminal. Dark
   mode is the expected default. Light mode is available via toggle.

5. **Plugin manifest structure.** The `.claude-plugin/plugin.json` format is speculative
   -- Claude Code's plugin system may not exist yet or may use a different schema. The
   manifest is designed to be plausible and easy to adapt once the actual schema is known.

6. **Custom marketplace vs. official.** The spec calls for a self-hosted marketplace via
   `marketplace.json` in the repo. This avoids any dependency on Anthropic's official
   marketplace timeline. If/when an official marketplace launches, Factory can be
   submitted there too.

### Open Questions

1. **Plugin system schema validated.** The `plugin.json` and `marketplace.json` schemas
   have been verified against Claude Code's plugin documentation. The `skills` field
   points to a directory (not individual files), skills are namespaced by plugin name
   (e.g., `/ideation`), and `marketplace.json` lives at
   `.claude-plugin/marketplace.json`. Install requires the marketplace name:
   `/plugin install factory@factory-marketplace`.

2. **GitHub Pages base path.** When GitHub Pages serves from a project repo (not
   `username.github.io`), assets are served under `/genesis/`. The single-file design
   avoids this issue entirely since there are no relative asset paths to break. But if
   images or other assets are added later, paths must be root-relative or use `<base>`.

3. **`/site` vs `/docs` for GitHub Pages.** GitHub Pages natively supports `/docs` as a
   source folder. Using `/site` requires the newer "custom folder" option in Pages
   settings. If this causes issues, renaming to `/docs` is a fallback. `/site` was chosen
   because it is more descriptive and does not imply documentation.

4. **Version bumping.** The `plugin.json` has a `version` field set to `0.1.0`. There is
   no automated version bump process. For now, version is updated manually. A future
   improvement could read version from a single source of truth.

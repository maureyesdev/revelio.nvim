# revelio.nvim

> *"Revelio!"* — reveal what's hiding behind your Markdown syntax.

A live Markdown preview for Neovim, rendered in a real browser. GitHub-flavored
rendering (tables, task lists, strikethrough), syntax-highlighted code fences,
cursor-follow scroll sync, light/dark theming, and self-contained HTML export
— synced to your buffer as you type.

Pure Lua plugin. Zero install dependencies — your browser is the rendering
engine, loading markdown-it, highlight.js, and github-markdown-css from a CDN.

---

## Requirements

- Neovim ≥ 0.10
- A web browser — Chrome, Chromium, Edge, or Brave for the default chromeless
  app-mode preview window (`browser_mode = "app"`); any browser works with
  `browser_mode = "tab"`
- Network access to load markdown-it/highlight.js/github-markdown-css from a
  CDN (no offline/local caching mode in this version)

---

## Installation

### lazy.nvim

```lua
{
  "maureyesdev/revelio.nvim",
  ft = { "markdown", "markdown.mdx" },
  opts = {},   -- use defaults, or pass your own config table
}
```

### packer.nvim

```lua
use {
  "maureyesdev/revelio.nvim",
  config = function()
    require("revelio").setup()
  end,
}
```

---

## Usage

| Command          | Keymap       | Description                              |
| ---------------- | ------------ | ----------------------------------------- |
| `:RevelioPreview` | `<leader>vp` | Open a live Markdown preview             |
| `:RevelioClose`   | `<leader>vc` | Close the preview                        |
| `:RevelioToggle`  | `<leader>vt` | Toggle the preview                       |
| `:RevelioExport`  | `<leader>ve` | Export the current document as one HTML file |
| `:RevelioInfo`    |              | Print current config                     |

---

## Configuration

All options are optional — `setup({})` or `setup()` uses the defaults shown below.

```lua
require("revelio").setup({
  -- Local preview server
  host = "127.0.0.1",
  port = 0,                    -- 0 = OS-assigned free port

  -- Where the preview opens
  auto_open_browser = true,
  browser_mode = "app",        -- "app" (chromeless Chromium-family window) | "tab"
  browser_cmd = nil,           -- nil = system default (open / xdg-open / wslview)
                                -- set to bypass browser_mode entirely

  -- Theming
  theme = "auto",               -- "auto" (follow &background) | "light" | "dark"

  -- Sync
  debounce_ms = 250,
  follow_cursor = true,         -- preview scrolls to track the cursor position

  -- Sources
  filetypes = { "markdown", "markdown.mdx" },

  -- ```mermaid fenced blocks: "plain" renders them as highlighted code |
  -- "render" renders them as real diagrams via mermaid.js (fetched from CDN
  -- only when this is set).
  mermaid_fences = "plain",

  -- CDN sources for the client-side rendering stack
  cdn = {
    markdown_it          = "https://cdn.jsdelivr.net/npm/markdown-it@14/dist/markdown-it.min.js",
    task_lists           = "https://cdn.jsdelivr.net/npm/markdown-it-task-lists@2/dist/markdown-it-task-lists.min.js",
    highlight_js         = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/highlight.min.js",
    highlight_css_light  = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/github.min.css",
    highlight_css_dark   = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/github-dark.min.css",
    github_markdown_css  = "https://cdn.jsdelivr.net/npm/github-markdown-css@5/github-markdown.css",
    mermaid_js           = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js",
  },

  -- Export
  export = {
    dir = nil,                 -- nil = browser download; path = server-side save
  },

  -- Keymaps
  default_keymaps = true,
  keymaps = {
    preview = "<leader>vp",
    close   = "<leader>vc",
    toggle  = "<leader>vt",
    export  = "<leader>ve",
  },
})
```

### Preview window mode

`browser_mode = "app"` (the default) opens the preview in a chromeless,
toolbarless window using a Chromium-family browser's `--app=` flag — a single
dedicated window instead of a tab in your regular browsing session, while
still being the same live, interactive page. revelio looks for Google Chrome,
Chromium, Microsoft Edge, or Brave Browser, in that order. If none is found,
it falls back to `browser_mode = "tab"` with a one-time warning.

`browser_mode = "tab"` opens the preview URL in your system's default
browser, in a normal tab.

App-mode windows run in their own dedicated browser profile (separate from
your regular Chrome/Edge/Brave profile — no shared cookies, extensions, or
logins), so revelio can close the window on `:RevelioClose`/`:RevelioToggle`
instead of leaving it open with a dead page. Reopening the preview after the
window was closed (by you, or by revelio) always spawns a fresh one.

### Theme

`theme = "auto"` (the default) follows `&background` — `:set background=light`
or `:set background=dark` restyles an already-open preview live, no need to
reopen it. Set `theme = "light"` or `theme = "dark"` to pin it explicitly.

### Scroll sync

With `follow_cursor = true` (the default), moving the cursor in the Markdown
buffer scrolls the preview to the nearest rendered block, debounced by
`debounce_ms`.

### Mermaid diagrams

By default (`mermaid_fences = "plain"`), fenced ` ```mermaid ` blocks render
as plain highlighted code — revelio stays pure-Markdown, and
[mermish.nvim](https://github.com/maureyesdev/mermish.nvim) owns dedicated
mermaid diagram preview.

Set `mermaid_fences = "render"` to render them as real diagrams instead,
matching how GitHub renders embedded mermaid in READMEs. mermaid.js is
fetched from CDN only when this is set. Diagrams re-render on every live-sync
update and on theme changes (mermaid bakes its theme into the SVG itself, so
a light/dark switch re-renders rather than just restyling).

### Export

`:RevelioExport` (or `<leader>ve`) assembles a single, self-contained HTML
file — every stylesheet currently in effect (base styling, github-markdown-css,
the active highlight.js theme) is fetched and inlined, so the result looks
right when opened standalone with no network access and no CDN scripts.

- `export.dir = nil` (default): triggers a browser download named
  `<buffer-basename>.html`.
- `export.dir = "/some/path"`: the browser POSTs the assembled HTML back to
  revelio's local server, which saves it as
  `<buffer-basename>-<timestamp>.html` in that directory.

---

## Status

Built in phases; all shipped:

- [x] **Phase 0** — scaffold, config, health, command stubs
- [x] **Phase 1** — HTTP server + chromeless browser window
- [x] **Phase 2** — core Markdown rendering (markdown-it, GFM tables/strikethrough, task lists)
- [x] **Phase 3** — live sync (debounced, via SSE)
- [x] **Phase 4** — syntax highlighting for fenced code blocks (highlight.js)
- [x] **Phase 5** — cursor-follow scroll sync
- [x] **Phase 6** — theme (auto/light/dark)
- [x] **Phase 7** — self-contained HTML export
- [x] **Phase 8** — health check, docs, polish
- [x] **Phase 9** — mermaid diagram rendering (`mermaid_fences = "render"`)

---

## Health check

```vim
:checkhealth revelio
```

Reports Neovim version, Chromium-family browser detection, `mermaid_fences`
sanity, export directory status, and a config summary.

## Development

```bash
make test-setup   # install plenary.nvim to /tmp
make test         # run all unit tests
make lint         # check formatting with stylua
```

## License

MIT

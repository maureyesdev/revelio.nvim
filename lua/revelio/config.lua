local M = {}

---@class revelio.CdnConfig
---@field markdown_it string CDN URL for markdown-it
---@field task_lists string CDN URL for the markdown-it-task-lists plugin
---@field highlight_js string CDN URL for highlight.js
---@field highlight_css_light string CDN URL for highlight.js's light theme CSS
---@field highlight_css_dark string CDN URL for highlight.js's dark theme CSS
---@field github_markdown_css string CDN URL for github-markdown-css

---@class revelio.ExportConfig
---@field dir string|nil Directory to save exports server-side; nil = browser download (default: nil)

---@class revelio.Keymaps
---@field preview string Keymap to open the preview (default: "<leader>vp")
---@field close string Keymap to close the preview (default: "<leader>vc")
---@field toggle string Keymap to toggle the preview (default: "<leader>vt")
---@field export string Keymap to export the current document (default: "<leader>ve")

---@class revelio.Config
---@field host string Host the local preview server binds to (default: "127.0.0.1")
---@field port integer Port the local preview server binds to; 0 = OS-assigned free port (default: 0)
---@field auto_open_browser boolean Whether to open the system browser automatically on preview (default: true)
---@field browser_mode string "app" (chromeless Chromium-family window via --app=, falls back to "tab" if none found) | "tab" (default: "app")
---@field browser_cmd string|nil Command used to open the browser; nil = system default (open/xdg-open/wslview). Set this to bypass browser_mode entirely (default: nil)
---@field theme string Preview theme: "auto" (follow &background), "light", "dark" (default: "auto")
---@field debounce_ms integer Milliseconds to wait after the last keystroke before re-rendering (default: 250)
---@field follow_cursor boolean Preview scrolls to track the cursor position (default: true)
---@field filetypes string[] Filetypes revelio will preview (default: { "markdown", "markdown.mdx" })
---@field mermaid_fences string How ```mermaid fenced blocks are rendered: "plain" (highlighted code, default) | "render" (reserved for a future release — falls back to "plain" with a warning)
---@field cdn revelio.CdnConfig
---@field export revelio.ExportConfig
---@field default_keymaps boolean Whether to register the built-in keymaps on setup() (default: true)
---@field keymaps revelio.Keymaps

---@type revelio.Config
local DEFAULTS = {
  host = "127.0.0.1",
  port = 0,

  auto_open_browser = true,
  browser_mode = "app",
  browser_cmd = nil,

  theme = "auto",

  debounce_ms = 250,
  follow_cursor = true,

  filetypes = { "markdown", "markdown.mdx" },

  mermaid_fences = "plain",

  cdn = {
    markdown_it = "https://cdn.jsdelivr.net/npm/markdown-it@14/dist/markdown-it.min.js",
    task_lists = "https://cdn.jsdelivr.net/npm/markdown-it-task-lists@2/dist/markdown-it-task-lists.min.js",
    highlight_js = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/highlight.min.js",
    highlight_css_light = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/github.min.css",
    highlight_css_dark = "https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.11.1/build/styles/github-dark.min.css",
    github_markdown_css = "https://cdn.jsdelivr.net/npm/github-markdown-css@5/github-markdown.css",
  },

  export = {
    dir = nil,
  },

  default_keymaps = true,
  keymaps = {
    preview = "<leader>vp",
    close = "<leader>vc",
    toggle = "<leader>vt",
    export = "<leader>ve",
  },
}

---@type revelio.Config
local _cfg = vim.deepcopy(DEFAULTS)

---Merge user options over the defaults and store the result.
---@param opts revelio.Config|nil
function M.setup(opts)
  _cfg = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULTS), opts or {})

  if _cfg.mermaid_fences ~= "plain" and _cfg.mermaid_fences ~= "render" then
    vim.notify(
      ('revelio: unknown mermaid_fences %q — falling back to "plain"'):format(_cfg.mermaid_fences),
      vim.log.levels.WARN
    )
    _cfg.mermaid_fences = "plain"
  elseif _cfg.mermaid_fences == "render" then
    vim.notify(
      'revelio: mermaid_fences = "render" is not implemented yet — falling back to "plain"',
      vim.log.levels.WARN
    )
    _cfg.mermaid_fences = "plain"
  end
end

---Return the active configuration.
---@return revelio.Config
function M.get()
  return _cfg
end

---A fresh copy of the built-in defaults.
---@return revelio.Config
function M.defaults()
  return vim.deepcopy(DEFAULTS)
end

return M

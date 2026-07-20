-- :checkhealth revelio
local M = {}

local function browser_opener()
  if vim.fn.has("mac") == 1 then
    return "open"
  elseif vim.fn.has("wsl") == 1 then
    return vim.fn.executable("wslview") == 1 and "wslview" or "explorer.exe"
  else
    return "xdg-open"
  end
end

function M.check()
  local h = vim.health

  h.start("revelio.nvim")

  -- Neovim version (>= 0.10 required)
  local ver = vim.version()
  if ver.major > 0 or ver.minor >= 10 then
    h.ok(("Neovim %d.%d.%d (>= 0.10 required)"):format(ver.major, ver.minor, ver.patch))
  else
    h.error(("Neovim %d.%d.%d detected — revelio requires >= 0.10"):format(ver.major, ver.minor, ver.patch))
  end

  local cfg = require("revelio.config").get()
  local browser = require("revelio.browser")

  -- Browser mode / opener
  if cfg.browser_cmd then
    if vim.fn.executable(cfg.browser_cmd) == 1 then
      h.ok(("browser_cmd found: %s"):format(cfg.browser_cmd))
    else
      h.warn(
        ("browser_cmd %q not found on PATH"):format(cfg.browser_cmd),
        "Fix browser_cmd in setup(), or open the preview URL manually with auto_open_browser = false"
      )
    end
  elseif cfg.browser_mode == "app" then
    local app_cmd = browser.detect_app_browser()
    if app_cmd then
      h.ok(("browser_mode = \"app\" — will open via: %s"):format(app_cmd))
    else
      h.warn(
        'browser_mode = "app" but no Chromium-family browser found (Chrome/Chromium/Edge/Brave)',
        'Install one, or set browser_mode = "tab" to use the system default browser'
      )
    end
  else
    local opener = browser_opener()
    if vim.fn.executable(opener) == 1 then
      h.ok(("browser opener found: %s"):format(opener))
    else
      h.warn(
        ("browser opener %q not found on PATH"):format(opener),
        "Set browser_cmd in setup(), or open the preview URL manually with auto_open_browser = false"
      )
    end
  end

  -- mermaid_fences is validated at setup() time (falls back to "plain" with
  -- a warning on any other unrecognized value), so by the time checkhealth
  -- runs it's always "plain" or "render".
  if cfg.mermaid_fences == "render" then
    h.ok('mermaid_fences = "render" — ```mermaid blocks render as real diagrams (fetches mermaid.js from CDN)')
  elseif cfg.mermaid_fences == "plain" then
    h.ok('mermaid_fences = "plain" — ```mermaid blocks render as plain highlighted code')
  else
    h.warn(("mermaid_fences = %q is unexpected — expected \"plain\" or \"render\""):format(cfg.mermaid_fences))
  end

  -- Export directory, if configured
  if cfg.export.dir then
    local dir = vim.fn.expand(cfg.export.dir)
    if vim.fn.isdirectory(dir) == 1 or vim.fn.filewritable(vim.fn.fnamemodify(dir, ":h")) == 2 then
      h.ok(("export.dir configured: %s"):format(dir))
    else
      h.warn(("export.dir %s does not exist yet — it will be created on first export"):format(dir))
    end
  else
    h.info("export.dir not set — :RevelioExport triggers a browser download instead of a server-side save")
  end

  -- Config summary
  h.info(("host: %s"):format(cfg.host))
  h.info(("port: %s"):format(cfg.port == 0 and "0 (OS-assigned)" or tostring(cfg.port)))
  h.info(("theme: %s"):format(cfg.theme))
  h.info(("follow_cursor: %s"):format(tostring(cfg.follow_cursor)))
  h.info(("filetypes: %s"):format(table.concat(cfg.filetypes, ", ")))
end

return M

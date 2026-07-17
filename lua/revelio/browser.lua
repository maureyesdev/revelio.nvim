-- Cross-platform "open URL in the browser" opener. Supports a chromeless
-- app-mode window (browser_mode = "app", the default) via a Chromium-family
-- browser's --app= flag, falling back to a normal browser tab when none is
-- found or when browser_mode = "tab".
--
-- App-mode windows are launched by executing the browser binary directly
-- (not the "open" wrapper) with a dedicated --user-data-dir. That keeps the
-- window out of the user's default Chrome profile/singleton, so revelio gets
-- back a real, independently killable job — required for M.close_app_window
-- to actually close the window instead of just orphaning it when the local
-- preview server stops.
local M = {}

local MAC_APP_MODE_APPS = { "Google Chrome", "Chromium", "Microsoft Edge", "Brave Browser" }
local LINUX_APP_MODE_BINS = {
  "google-chrome-stable",
  "google-chrome",
  "chromium",
  "chromium-browser",
  "microsoft-edge-stable",
  "microsoft-edge",
  "brave-browser",
}

local warned_no_app_browser = false

local function detect_opener(cfg)
  if cfg and cfg.browser_cmd then
    return cfg.browser_cmd
  end
  if vim.fn.has("mac") == 1 then
    return "open"
  elseif vim.fn.has("wsl") == 1 then
    return vim.fn.executable("wslview") == 1 and "wslview" or "explorer.exe"
  else
    return "xdg-open"
  end
end

local function mac_app_bundle_path(name)
  local sys_path = "/Applications/" .. name .. ".app"
  if vim.fn.isdirectory(sys_path) == 1 then
    return sys_path
  end
  local user_path = vim.fn.expand("~/Applications/" .. name .. ".app")
  if vim.fn.isdirectory(user_path) == 1 then
    return user_path
  end
  return nil
end

--- Find an installed Chromium-family browser usable in app mode.
--- @return string|nil exe Path (mac) or binary name (Linux) to jobstart directly
local function detect_app_browser()
  if vim.fn.has("mac") == 1 then
    for _, name in ipairs(MAC_APP_MODE_APPS) do
      local app_path = mac_app_bundle_path(name)
      if app_path then
        local exe = app_path .. "/Contents/MacOS/" .. name
        if vim.fn.executable(exe) == 1 then
          return exe
        end
      end
    end
  elseif vim.fn.has("wsl") ~= 1 then
    for _, bin in ipairs(LINUX_APP_MODE_BINS) do
      if vim.fn.executable(bin) == 1 then
        return bin
      end
    end
  end
  return nil
end

--- Try to open the URL as a chromeless app-mode window, in its own isolated
--- browser profile so it can be closed independently of the user's default
--- browser session.
--- @param url string
--- @return boolean ok
--- @return table|nil handle { job = integer, pid = integer|nil }
local function open_app_mode(url)
  local exe = detect_app_browser()
  if not exe then
    return false, nil
  end

  local profile_dir = vim.fn.stdpath("cache") .. "/revelio/chrome-profile"
  pcall(vim.fn.mkdir, profile_dir, "p")

  local cmd = {
    exe,
    "--app=" .. url,
    "--new-window",
    "--user-data-dir=" .. profile_dir,
    "--no-first-run",
    "--no-default-browser-check",
  }

  local job = vim.fn.jobstart(cmd, { detach = true })
  if job <= 0 then
    return false, nil
  end

  local pid_ok, pid = pcall(vim.fn.jobpid, job)
  return true, { job = job, pid = pid_ok and pid or nil }
end

--- Open a URL in the system's default browser (tab mode).
--- @param url string
--- @param cfg table|nil revelio config (consulted for browser_cmd override)
--- @return boolean ok
--- @return string|nil err
local function open_tab(url, cfg)
  local opener = detect_opener(cfg)
  if vim.fn.executable(opener) ~= 1 then
    return false, ("browser opener %q not found on PATH"):format(opener)
  end

  local job = vim.fn.jobstart({ opener, url }, { detach = true })
  if job <= 0 then
    return false, "failed to start browser opener job"
  end
  return true
end

--- Detect an installed Chromium-family browser usable for browser_mode =
--- "app". Exposed for :checkhealth.
--- @return string|nil exe
function M.detect_app_browser()
  return detect_app_browser()
end

--- Best-effort close of a window handle previously returned by M.open() (the
--- third return value, app-mode only). Safe no-op for nil/tab-mode handles.
--- @param handle table|nil { job = integer }
function M.close_app_window(handle)
  if not handle or not handle.job then
    return
  end
  pcall(vim.fn.jobstop, handle.job)
end

--- Open a URL, honoring cfg.browser_mode ("app" (default) | "tab") and the
--- cfg.browser_cmd escape hatch, which bypasses browser_mode entirely and is
--- used verbatim as the tab-mode opener.
--- @param url string
--- @param cfg table|nil revelio config
--- @return boolean ok
--- @return string|nil err
--- @return table|nil handle App-mode window handle to pass to M.close_app_window; nil for tab mode
function M.open(url, cfg)
  if cfg and cfg.browser_cmd then
    local ok, err = open_tab(url, cfg)
    return ok, err, nil
  end

  if cfg and cfg.browser_mode == "app" then
    local ok, handle = open_app_mode(url)
    if ok then
      return true, nil, handle
    end
    if not warned_no_app_browser then
      warned_no_app_browser = true
      vim.notify(
        'revelio: no Chromium-family browser found for browser_mode = "app" — falling back to tab mode',
        vim.log.levels.WARN
      )
    end
  end

  local ok, err = open_tab(url, cfg)
  return ok, err, nil
end

return M

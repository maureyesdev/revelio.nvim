# revelio.nvim

> *"Revelio!"* — reveal what's hiding in your variables.

A Neovim port of [turbo-console-log](https://github.com/Chakroun-Anas/turbo-console-log). Place your cursor on any variable and insert a structured debug log statement below it with a single keymap. Bulk-delete, comment, uncomment, or correct every log the plugin has ever written — all in one shot.

Supports **JavaScript · TypeScript · JSX · TSX · Python · Lua · Go**.

---

## Requirements

- Neovim ≥ 0.9
- Tree-sitter parsers for your languages (optional — falls back to `<cword>` if missing)

---

## Installation

### lazy.nvim

```lua
{
  "maureyesdev/revelio.nvim",
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

### Manual / no plugin manager

Clone the repo into your `runtimepath` and call `setup()` somewhere in your config:

```bash
git clone https://github.com/maureyesdev/revelio.nvim \
  ~/.local/share/nvim/site/pack/plugins/start/revelio.nvim
```

```lua
require("revelio").setup()
```

---

## Quick start

1. Open a JS/TS/Python/Lua/Go file.
2. Place the cursor on a variable.
3. Press `<leader>rl` — a log statement appears on the line below.

```javascript
// before
const userId = req.params.id

// after  (<leader>rl on `userId`)
const userId = req.params.id
console.log("🚀 ~ auth.js ~ getUser ~ userId:", userId);
```

---

## Keymaps

All keymaps are global (work in any buffer).

| Keymap | Command | Action |
|--------|---------|--------|
| `<leader>rl` | `:RevelioLog` | Insert log for variable under cursor |
| `<leader>rd` | `:RevelioDelete` | Delete **all** revelio logs in buffer |
| `<leader>rc` | `:RevelioComment` | Comment **all** revelio logs in buffer |
| `<leader>ru` | `:RevelioUncomment` | Uncomment **all** revelio logs in buffer |
| `<leader>rx` | `:RevelioCorrect` | Correct filename/line metadata in all logs |

Visual mode is also supported for `<leader>rl` — select a multi-word expression and the full selection is used as the log target.

---

## Commands

| Command | Description |
|---------|-------------|
| `:RevelioLog` | Insert log for the variable under cursor |
| `:RevelioDelete` | Remove every revelio-generated log in the buffer |
| `:RevelioComment` | Comment out every revelio log (preserves indentation) |
| `:RevelioUncomment` | Uncomment every commented revelio log |
| `:RevelioCorrect` | Fix stale `filename:line` metadata after lines have moved |

---

## Configuration

Call `setup()` with any overrides. Unspecified keys keep their defaults.

```lua
require("revelio").setup({
  -- String prepended to every log message — used to identify revelio logs
  prefix = "🚀",

  -- Separator between message parts
  delimiter = "~",

  -- Quote style for the message string: '"' | "'" | '`'
  quote = '"',

  -- Include the filename in the log message
  include_filename = true,

  -- Include the line number in the log message
  include_line_number = false,

  -- Include the enclosing function name (requires tree-sitter)
  include_function = true,

  -- Include the enclosing class name (requires tree-sitter)
  include_class = false,

  -- Per-language log function overrides
  log_functions = {
    javascript      = { fn = "console.log", semicolon = true },
    typescript      = { fn = "console.log", semicolon = true },
    javascriptreact = { fn = "console.log", semicolon = true },
    typescriptreact = { fn = "console.log", semicolon = true },
    python          = { fn = "print",       semicolon = false },
    lua             = { fn = "print",       semicolon = false },
    go              = { fn = "fmt.Println", semicolon = false },
  },

  -- Default keymap bindings (set default_keymaps = false to disable)
  keymaps = {
    log       = "<leader>rl",
    delete    = "<leader>rd",
    comment   = "<leader>rc",
    uncomment = "<leader>ru",
    correct   = "<leader>rx",
  },

  default_keymaps = true,
})
```

### Disable default keymaps and bind your own

```lua
require("revelio").setup({ default_keymaps = false })

local r = require("revelio")
vim.keymap.set("n", "<leader>cl", r.log,       { desc = "Revelio: log" })
vim.keymap.set("v", "<leader>cl", r.log,       { desc = "Revelio: log selection" })
vim.keymap.set("n", "<leader>cd", r.delete,    { desc = "Revelio: delete all" })
vim.keymap.set("n", "<leader>cc", r.comment,   { desc = "Revelio: comment all" })
vim.keymap.set("n", "<leader>cu", r.uncomment, { desc = "Revelio: uncomment all" })
vim.keymap.set("n", "<leader>cx", r.correct,   { desc = "Revelio: correct all" })
```

### Add a custom language

```lua
require("revelio").setup({
  log_functions = {
    ruby = { fn = "p", semicolon = false },
  },
})
```

---

## How it works

**Inserting a log** (`<leader>rl`)

1. Detects the variable under cursor via tree-sitter or `<cword>`.
2. Walks up the syntax tree to find the enclosing function (and class, if enabled).
3. Scans forward from the cursor line until open brackets are balanced — handles multi-line function calls and destructuring.
4. Inserts the formatted log statement on the next balanced line, preserving indentation.

**Log format**

```
<fn>("<prefix> <delimiter> <filename> <delimiter> [class] <delimiter> [function] <delimiter> <var>:", <var>)[;]
```

Example with all options on:

```javascript
console.log("🚀 ~ app.js:42 ~ UserService ~ getById ~ userId:", userId);
```

**Manager operations** (`delete` / `comment` / `uncomment` / `correct`)

All manager commands scan the entire buffer for lines containing the configured `prefix` string. They work on both active and commented revelio lines. `correct` updates stale `filename:line` fragments when lines have shifted after edits.

---

## Health check

```vim
:checkhealth revelio
```

Reports Neovim version, tree-sitter availability, and which language parsers are installed.

---

## Tree-sitter parsers

Install parsers with [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter):

```vim
:TSInstall javascript typescript tsx python lua go
```

Without a parser, revelio falls back to `<cword>` for variable detection and omits function/class context from the log message.

---

## License

MIT

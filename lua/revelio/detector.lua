local M = {}

-- Node types that represent function definitions per language
local FUNCTION_TYPES = {
  javascript      = { "function_declaration", "method_definition", "arrow_function", "function_expression" },
  typescript      = { "function_declaration", "method_definition", "arrow_function", "function_expression" },
  javascriptreact = { "function_declaration", "method_definition", "arrow_function", "function_expression" },
  typescriptreact = { "function_declaration", "method_definition", "arrow_function", "function_expression" },
  python          = { "function_definition" },
  lua             = { "function_declaration", "local_function" },
  go              = { "function_declaration", "method_declaration" },
}

-- Node types that represent class definitions per language
local CLASS_TYPES = {
  javascript      = { "class_declaration" },
  typescript      = { "class_declaration" },
  javascriptreact = { "class_declaration" },
  typescriptreact = { "class_declaration" },
  python          = { "class_definition" },
  lua             = {},
  go              = { "type_declaration" },
}

local function set_from(list)
  local s = {}
  for _, v in ipairs(list) do
    s[v] = true
  end
  return s
end

local function walk_up_for(bufnr, lnum, target_types)
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr)
  if not ok or not parser then
    return nil
  end

  local tree = parser:parse()[1]
  if not tree then
    return nil
  end

  local root = tree:root()
  -- lnum is 1-indexed; tree-sitter uses 0-indexed rows
  local node = root:named_descendant_for_range(lnum - 1, 0, lnum - 1, 0)
  if not node then
    return nil
  end

  local type_set = set_from(target_types)

  while node do
    if type_set[node:type()] then
      -- node:field(name) returns a list of nodes with that field name (Neovim 0.11+)
      local name_nodes = node:field("name")
      if name_nodes and #name_nodes > 0 then
        return vim.treesitter.get_node_text(name_nodes[1], bufnr)
      end
      -- Go type_declaration: walk into type_spec children for the name
      if node:type() == "type_declaration" then
        local specs = node:field("types")
        if specs then
          for _, spec in ipairs(specs) do
            local names = spec:field("name")
            if names and #names > 0 then
              return vim.treesitter.get_node_text(names[1], bufnr)
            end
          end
        end
      end
    end
    node = node:parent()
  end

  return nil
end

--- Returns the variable name under cursor or from visual selection.
--- @param mode string current vim mode
--- @return string|nil
function M.get_variable(mode)
  if mode == "v" or mode == "V" or mode == "\22" then
    -- Get visual selection
    local ok, region = pcall(vim.fn.getregion, vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
    if ok and region and #region > 0 then
      local text = table.concat(region, "\n"):gsub("^%s+", ""):gsub("%s+$", "")
      if text ~= "" then
        return text
      end
    end
  end

  local word = vim.fn.expand("<cword>")
  if word == "" then
    return nil
  end
  return word
end

--- Returns the enclosing function name at lnum in bufnr, or nil.
--- @param bufnr integer
--- @param lnum integer 1-indexed
--- @return string|nil
function M.get_enclosing_function(bufnr, lnum)
  local ft = vim.bo[bufnr].filetype
  local types = FUNCTION_TYPES[ft]
  if not types or #types == 0 then
    return nil
  end
  return walk_up_for(bufnr, lnum, types)
end

--- Returns the enclosing class name at lnum in bufnr, or nil.
--- @param bufnr integer
--- @param lnum integer 1-indexed
--- @return string|nil
function M.get_enclosing_class(bufnr, lnum)
  local ft = vim.bo[bufnr].filetype
  local types = CLASS_TYPES[ft]
  if not types or #types == 0 then
    return nil
  end
  return walk_up_for(bufnr, lnum, types)
end

return M

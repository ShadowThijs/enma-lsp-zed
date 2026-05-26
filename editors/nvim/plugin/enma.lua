-- Enma language plugin for Neovim
-- Works standalone, with lazy.nvim, and with LazyVim

-- Filetype detection
vim.filetype.add({ extension = { em = "enma" } })

-- Register tree-sitter parser via Neovim core API (works on all nvim >= 0.9)
local parser_ext = vim.fn.has("win32") == 1 and "dll"
  or (vim.fn.has("mac") == 1 and "dylib" or "so")
local parser_path = vim.fn.stdpath("data") .. "/site/parser/enma." .. parser_ext

if vim.fn.filereadable(parser_path) == 1 then
  pcall(vim.treesitter.language.add, "enma", { path = parser_path })
end

-- LSP auto-start: look for enma-lsp on PATH or in ~/.local/bin
local function find_lsp()
  if vim.fn.executable("enma-lsp") == 1 then
    return "enma-lsp"
  end
  local alt = vim.fn.expand("~/.local/bin/enma-lsp")
  if vim.fn.executable(alt) == 1 then
    return alt
  end
  return nil
end

local lsp_cmd = find_lsp()
if lsp_cmd then
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "enma",
    callback = function()
      if #vim.lsp.get_clients({ bufnr = 0, name = "enma-lsp" }) == 0 then
        vim.lsp.start({ name = "enma-lsp", cmd = { lsp_cmd } })
      end
    end,
  })
end

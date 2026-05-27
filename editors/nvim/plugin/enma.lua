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

-- Bundle command
vim.api.nvim_create_user_command("EnmaBundle", function(opts)
  local output_path = opts.args ~= "" and opts.args or nil
  if not output_path then
    output_path = vim.fn.input("Output path: ", "output/bundled.em")
    if output_path == "" then
      vim.notify("Enma Bundle: cancelled", vim.log.levels.WARN)
      return
    end
  end
  local params = {
    command = "enma.bundle",
    arguments = {
      vim.uri_from_bufnr(0),
      opts.bang,  -- :EnmaBundle! enables strip-comments
      output_path,
    },
  }
  vim.lsp.buf.execute_command(params)
  vim.notify("Enma Bundle: writing to " .. output_path, vim.log.levels.INFO)
end, {
  bang = true,   -- ! = strip comments
  nargs = "?",   -- optional output path
  desc = "Bundle Enma imports into a single file",
})

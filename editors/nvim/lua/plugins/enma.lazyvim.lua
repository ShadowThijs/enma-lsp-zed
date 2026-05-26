-- Enma language support for LazyVim / lazy.nvim
-- Drop this file into ~/.config/nvim/lua/plugins/enma.lua
--
-- The parser .so is installed by install.sh into ~/.local/share/nvim/site/parser/
-- The LSP binary is installed into ~/.local/bin/ by install.sh
-- plugin/enma.lua handles the actual registration — this spec just ensures
-- nvim-treesitter knows the language exists for highlighting to activate.

return {
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    init = function()
      -- Register the language before nvim-treesitter loads, using core API
      local ext = vim.fn.has("win32") == 1 and "dll"
        or (vim.fn.has("mac") == 1 and "dylib" or "so")
      local path = vim.fn.stdpath("data") .. "/site/parser/enma." .. ext
      if vim.fn.filereadable(path) == 1 then
        pcall(vim.treesitter.language.add, "enma", { path = path })
      end
    end,
    opts = {
      ensure_installed = { "enma" },
    },
  },
}

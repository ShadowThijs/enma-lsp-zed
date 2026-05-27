local M = {}

function M.setup(opts)
  opts = opts or {}

  local lsp_cmd = opts.lsp_path
    or (vim.fn.executable("enma-lsp") == 1 and "enma-lsp")
    or (vim.fn.executable(vim.fn.expand("~/.local/bin/enma-lsp")) == 1
      and vim.fn.expand("~/.local/bin/enma-lsp"))
    or nil

  if lsp_cmd then
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "enma",
      callback = function()
        vim.lsp.start({
          name = "enma-lsp",
          cmd = { lsp_cmd },
          root_dir = vim.fs.dirname(
            vim.fs.find({ ".git", ".enma-root" }, { upward = true })[1]
          ) or vim.fn.getcwd(),
        })
      end,
    })
  end
end

function M.bundle(opts)
  opts = opts or {}
  local params = {
    command = "enma.bundle",
    arguments = {
      vim.uri_from_bufnr(opts.bufnr or 0),
      opts.strip_comments or false,
      opts.output or nil,
    },
  }
  vim.lsp.buf.execute_command(params)
end

return M

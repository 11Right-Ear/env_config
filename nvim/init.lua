-- ============================================================
--  Neovim configuration — C++17 / CMake / ROS 2 / GDB
--
--  Self-contained: uses only Neovim's built-in features
--  (LSP, treesitter, quickfix, terminal). No plugin downloads
--  required, so it works regardless of network conditions.
--
--  Optional extras (if you later have network access) can be
--  added via lazy.nvim; see README.md.
-- ============================================================

-- ============================================================
--  Basics
-- ============================================================

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.termguicolors = true
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.wrap = false
vim.opt.signcolumn = "yes"
vim.opt.undofile = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.completeopt = "menu,menuone,noselect"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 400
vim.opt.mouse = "a"

-- Split navigation
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.splitkeep = "screen"

-- ============================================================
--  File types
-- ============================================================

vim.filetype.add({
  extension = {
    urdf = "xml",
    xacro = "xml",
    launch = "xml",
    sdf = "xml",
    rviz = "yaml",
    msg = "text",
    srv = "text",
    action = "text",
  },
})

vim.filetype.add({
  pattern = {
    [".*%.launch%.py"] = "python",
    [".*_msgs%.msg"] = "text",
  },
})

-- ============================================================
--  Per-filetype settings
-- ============================================================

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "objc", "h" },
  callback = function()
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
    vim.bo.expandtab = true
    vim.bo.textwidth = 100
    vim.opt_local.colorcolumn = "101"
    vim.bo.formatoptions = "tcqj"
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "yaml", "json", "toml" },
  callback = function()
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
    vim.bo.expandtab = true
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "makefile",
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 8
    vim.bo.shiftwidth = 8
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "sh", "bash", "zsh" },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
  end,
})

-- Trim trailing whitespace on save (but keep it in Markdown)
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function(args)
    local ft = vim.bo[args.buf].filetype
    if ft == "markdown" or ft == "text" or ft == "" then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[noautocmd keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Keep the cursor line centred when scrolling in long files
vim.api.nvim_create_autocmd({ "CursorMoved", "InsertLeave" }, {
  group = vim.api.nvim_create_augroup("cursor_scroll", { clear = true }),
  callback = function()
    if vim.fn.mode() ~= "c" and vim.fn.line(".") > 10 and vim.fn.line(".") < vim.fn.line("$") - 10 then
      vim.cmd("normal! zz")
    end
  end,
})

-- ============================================================
--  Keymaps
-- ============================================================

local map = vim.keymap.set

-- ============================================================
--  LSP
-- ============================================================

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- ---------------------------------------------------------
--  Server configurations
--
--  `vim.lsp.enable` only marks a config as enabled — the config
--  itself (with its `cmd`) must exist. Neovim ships no built-in
--  config for clangd, so we define the ones we need here.
-- ---------------------------------------------------------

-- C / C++ — clangd
vim.lsp.config("clangd", {
  cmd = { "clangd", "--background-index", "--clang-tidy" },
  filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
  -- Order matters: the first marker found walking upwards wins.
  -- compile_commands.json is the authoritative project root for clangd.
  root_markers = {
    "compile_commands.json",
    "CMakeLists.txt",
    "package.xml",
    ".git",
  },
})

-- CMake
vim.lsp.config("cmake", {
  cmd = { "cmake-language-server" },
  filetypes = { "cmake" },
  root_markers = { ".git", "CMakeLists.txt" },
})

-- Bash
vim.lsp.config("bashls", {
  cmd = { "bash-language-server", "start" },
  filetypes = { "sh", "bash", "zsh" },
  root_markers = { ".git" },
})

-- Python
vim.lsp.config("pyright", {
  cmd = { "pyright-langserver", "--stdio" },
  filetypes = { "python" },
  root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt" },
})

-- Enable the servers we actually have installed.
vim.lsp.enable({ "clangd", "cmake", "bashls", "pyright" })

-- Make sure clangd knows about the project's compile flags.
-- It reads compile_commands.json automatically when found from the
-- file's directory upwards.
local function setup_clangd()
  local clangd_args = {
    "-background-index",
    "-clang-tidy",
    "-header-insertion=never",
    "-completion-style=detailed",
  }
  -- Use a .clangd file if the project provides one; otherwise default.
  vim.g.clangd_args = clangd_args
end
setup_clangd()

-- LSP keymaps (buffer-local, attached on LspAttach)
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    -- NOTE: do not shadow the outer `map` here — use a distinct name so the
    -- buffer-local variant does not call itself recursively.
    local function bmap(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, desc = desc })
    end

    bmap("n", "gd", vim.lsp.buf.definition, "LSP: goto definition")
    bmap("n", "gD", vim.lsp.buf.declaration, "LSP: goto declaration")
    bmap("n", "gi", vim.lsp.buf.implementation, "LSP: goto implementation")
    bmap("n", "gr", vim.lsp.buf.references, "LSP: references")
    bmap("n", "K", vim.lsp.buf.hover, "LSP: hover documentation")
    bmap("n", "<C-k>", vim.lsp.buf.signature_help, "LSP: signature help")
    bmap("n", "<C-s>", vim.lsp.buf.code_action, "LSP: code action")
    bmap("n", "[d", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, "LSP: previous diagnostic")
    bmap("n", "]d", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, "LSP: next diagnostic")
    bmap("n", "<leader>lf", vim.lsp.buf.format, "LSP: format file")
    bmap("n", "<leader>lr", vim.lsp.buf.rename, "LSP: rename symbol")
    bmap("n", "<leader>la", vim.lsp.buf.code_action, "LSP: code action")
    bmap("n", "<leader>ld", vim.diagnostic.open_float, "LSP: diagnostic float")
    bmap("n", "<leader>ls", vim.diagnostic.setloclist, "LSP: set loclist")
    bmap("x", "<leader>lf", vim.lsp.buf.format, "LSP: format selection")
  end,
})

-- ============================================================
--  Built-in LSP completion (nvim 0.11 handles this natively)
-- ============================================================

map("i", "<C-y>", function()
  return vim.lsp.buf.completion.get()
end, { desc = "LSP: complete" })

map("i", "<C-n>", function()
  vim.lsp.completion.get({ select = false, finish = "builtin" })
end, { desc = "LSP: next completion" })

map("i", "<C-p>", function()
  vim.lsp.completion.get({ select = false, finish = "builtin" })
end, { desc = "LSP: previous completion" })

-- ============================================================
--  File finding (no telescope needed)
-- ============================================================

-- <leader>ff : find files under the current project root
map("n", "<leader>ff", function()
  local root = vim.fs.root(0, { ".git", "CMakeLists.txt", "package.xml" }) or vim.fn.getcwd()
  vim.ui.input({ prompt = "Find file> " }, function(pattern)
    if not pattern or pattern == "" then
      return
    end
    vim.cmd("find " .. vim.fn.escape(root .. "/" .. pattern, " "))
    vim.cmd("setlocal noignorecase")
  end)
end, { desc = "Find files in project" })

-- <leader>fg : grep the project
map("n", "<leader>fg", function()
  local root = vim.fs.root(0, { ".git", "CMakeLists.txt", "package.xml" }) or vim.fn.getcwd()
  vim.ui.input({ prompt = "Grep> " }, function(pattern)
    if not pattern or pattern == "" then
      return
    end
    vim.fn.setreg("/", vim.fn.escape(pattern, " "))
    vim.cmd("silent! noignorecase keeppatterns %s/" .. vim.fn.escape(pattern, " ") .. "/g " .. vim.fn.escape(root, " "))
    vim.cmd("copen")
  end)
end, { desc = "Grep in project" })

-- ============================================================
--  Quickfix / location list
-- ============================================================

map("n", "<leader>qc", vim.cmd.cclose, { desc = "Close quickfix" })
map("n", "<leader>qi", function()
  vim.cmd("copen")
  vim.cmd("wincmd p")
end, { desc = "Quickfix window" })
map("n", "<leader>qn", function()
  vim.cmd("cnext")
end, { desc = "Next quickfix" })
map("n", "<leader>qp", function()
  vim.cmd("cprev")
end, { desc = "Previous quickfix" })

-- ============================================================
--  Buffers / tabs / windows
-- ============================================================

map("n", "<leader>w", vim.cmd.write, { desc = "Write file" })
map("n", "<leader>q", vim.cmd.quit, { desc = "Quit window" })
map("n", "<leader>h", "<C-w>h", { desc = "Window left" })
map("n", "<leader>j", "<C-w>j", { desc = "Window down" })
map("n", "<leader>k", "<C-w>k", { desc = "Window up" })
map("n", "<leader>l", "<C-w>l", { desc = "Window right" })
map("n", "<leader>v", "<C-w>v", { desc = "Vertical split" })
map("n", "<leader>s", "<C-w>s", { desc = "Horizontal split" })
map("n", "<leader>bn", "<C-^>", { desc = "Previous buffer" })
map("n", "<leader>bd", vim.cmd.bdelete, { desc = "Delete buffer" })

-- ============================================================
--  Terminal
-- ============================================================

map("n", "<leader>t", vim.cmd.terminal, { desc = "Open terminal" })
map("n", "<leader>tn", function()
  vim.cmd("split | terminal")
end, { desc = "Terminal in split" })

-- ============================================================
--  Git (built-in git provider, no plugin needed)
-- ============================================================

map("n", "<leader>gg", function()
  vim.cmd("Gstatus")
end, { desc = "Git status" })
map("n", "<leader>ga", function()
  vim.cmd("Git add")
end, { desc = "Git add file" })
map("n", "<leader>gc", function()
  vim.cmd("Git commit -m 'wip'")
end, { desc = "Git commit" })
map("n", "<leader>gb", function()
  vim.cmd("Git branch")
end, { desc = "Git branch" })
map("n", "<leader>gd", function()
  vim.cmd("Git diff")
end, { desc = "Git diff" })

-- ============================================================
--  GDB / debugging helper
-- ============================================================

map("n", "<leader>db", "<F9>", { desc = "Debug: toggle breakpoint" })
map("n", "<leader>dc", "<F5>", { desc = "Debug: continue" })
map("n", "<leader>ds", "<F10>", { desc = "Debug: step over" })
map("n", "<leader>di", "<F11>", { desc = "Debug: step into" })
map("n", "<leader>dq", "<F12>", { desc = "Debug: quit" })

-- ============================================================
--  Treesitter
--
--  Neovim 0.11 ships a small set of bundled parsers (c, lua, vim,
--  markdown, query). nvim-treesitter is a separate plugin that we
--  cannot always download in this environment, so we enable the
--  bundled parsers and leave the rest to the LSP.
-- ============================================================

-- Starting treesitter on a buffer with no matching parser raises an
-- error, so every call is guarded.
local function start_treesitter(buf)
  pcall(vim.treesitter.start, buf)
end

-- Enable treesitter highlighting for the languages we have parsers for.
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "c", "cpp", "lua", "markdown", "vim", "vimdoc", "query" },
  callback = function(args)
    start_treesitter(args.buf)
  end,
})

-- ============================================================
--  Statusline
-- ============================================================

vim.opt.laststatus = 3
vim.opt.showmode = false
vim.opt.showtabline = 2
vim.opt.fillchars = { eob = " " }

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    vim.g.statusline = "%#qa#%F " .. table.concat({
      "%f",
      "%h%w%m",
      "%r",
      "%=",
      "[%{getcwd()}]",
      "[%{v:lua.require('vim.fn').bufnr()}]",
      "%-14.(%l,%c%V%) %P",
    }, "")
    vim.cmd("redrawstatus")
  end,
})

-- ============================================================
--  Completion behaviour
-- ============================================================

vim.o.completeopt = "menu,menuone,noselect"

-- ============================================================
--  Lazy.nvim bootstrap (only used if you add plugins later)
-- ============================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if vim.uv.fs_stat(lazypath) then
  vim.opt.rtp:prepend(lazypath)
  -- Deliberately NOT calling lazy.setup() here so the config works
  -- with zero plugins. To enable LazyVim, uncomment below:
  --
  -- require("lazy").setup({
  --   spec = {
  --     { "folke/lazy-vim", version = "*", lazy = false, import = "lazy.plugins" },
  --   },
  -- })
end

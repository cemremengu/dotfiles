-- =============================================================================
--  Starter Neovim config (single file)
--  Target: Neovim 0.12+   ·   Put this file at ~/.config/nvim/init.lua
--
--  What you get:
--    • lazy.nvim        plugin manager (installs itself on first start)
--    • nvim-tree        file browser sidebar             <Space>e
--    • telescope        fuzzy find files / text          <Space>ff, <Space>fg
--    • nvim-treesitter  better syntax highlighting (Rust, Go, TOML, ...)
--    • mason + LSP      rust-analyzer, gopls, lua_ls (go-to-def, errors, rename)
--    • blink.cmp        autocompletion popup
--    • conform          format on save (rustfmt, gofmt/goimports)
--    • which-key        press <Space> and wait: shows every shortcut
--    • bufferline       open files as tabs along the top <S-h>/<S-l>
--    • trouble          list of all errors / references  <Space>xx
--    • lualine, gitsigns, mini.pairs, gruvbox colorscheme
--
--  Useful commands:  :Lazy  (plugins)   :Mason  (language servers)
--                    :checkhealth       :restart (reload Neovim after edits)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Leader key — must be set before plugins load. <Space> is the leader.
-- -----------------------------------------------------------------------------
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- nvim-tree replaces the built-in file explorer (netrw), so switch netrw off.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- -----------------------------------------------------------------------------
-- 2. Editor options
-- -----------------------------------------------------------------------------
local opt = vim.opt
opt.number = true            -- line numbers
opt.relativenumber = true    -- relative numbers make 5j / 3k jumps easy
opt.mouse = "a"              -- mouse works everywhere
opt.cursorline = true        -- highlight the current line
opt.signcolumn = "yes"       -- always show the gutter (no text jumping around)
opt.scrolloff = 8            -- keep 8 lines visible above/below the cursor
opt.wrap = false

opt.expandtab = true         -- spaces instead of tabs (Go files still use tabs via gofmt)
opt.tabstop = 4
opt.shiftwidth = 4
opt.smartindent = true

opt.ignorecase = true        -- case-insensitive search...
opt.smartcase = true         -- ...unless you type a capital letter
opt.splitright = true        -- :vsplit opens to the right
opt.splitbelow = true        -- :split opens below
opt.undofile = true          -- undo history survives closing the file
opt.updatetime = 250         -- faster diagnostics / git signs
opt.termguicolors = true
vim.o.winborder = "rounded"  -- rounded borders on hover/help popups

-- Share the system clipboard (y / p work with other apps).
-- On Linux this needs xclip or wl-clipboard installed.
vim.schedule(function() opt.clipboard = "unnamedplus" end)

-- Show errors/warnings at the end of the line (off by default since 0.11).
vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  float = { source = true },
})

-- Reload files changed outside Neovim (AI agents, git checkout, formatters).
-- 'autoread' is on by default but only checks on focus/shell commands, so also
-- check on buffer switch and poll every second. Buffers with unsaved edits are
-- never overwritten — you get a warning instead.
local function checktime()
  if vim.fn.mode() == "n" and vim.fn.getcmdwintype() == "" then vim.cmd("checktime") end
end
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, { callback = checktime })
vim.uv.new_timer():start(1000, 1000, vim.schedule_wrap(checktime))
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  callback = function(args) vim.notify("Reloaded " .. vim.fn.fnamemodify(args.file, ":~:.")) end,
})

-- -----------------------------------------------------------------------------
-- 3. Basic keymaps (plugin keymaps live next to each plugin below)
-- -----------------------------------------------------------------------------
local map = vim.keymap.set
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>quit<CR>", { desc = "Quit window" })

-- Move between split windows with Ctrl + h/j/k/l
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

-- Move selected lines up/down in visual mode
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

map("n", "<leader>d", vim.diagnostic.open_float, { desc = "Show error under cursor" })

-- Briefly highlight text you just yanked (copied)
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function() vim.hl.on_yank() end,
})

-- -----------------------------------------------------------------------------
-- 4. LSP keymaps — only active in buffers where a language server is attached.
--
--    Neovim already provides these by default, no config needed:
--      K      hover docs             grn  rename symbol
--      gra    code actions (fixes)   grr  find references
--      gri    go to implementation   grt  go to type definition
--      gO     symbols in this file   [d / ]d  previous / next error
--      <C-s>  signature help (insert mode)
-- -----------------------------------------------------------------------------
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local buf = args.buf
    local function bmap(lhs, rhs, desc) map("n", lhs, rhs, { buffer = buf, desc = desc }) end
    bmap("gd", vim.lsp.buf.definition, "Go to definition")
    bmap("gD", vim.lsp.buf.declaration, "Go to declaration")
    bmap("<leader>th", function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
    end, "Toggle inlay type hints")
    
    -- Highlight other uses of the symbol under the cursor (after a short pause)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client:supports_method("textDocument/documentHighlight") then
      local group = vim.api.nvim_create_augroup("lsp_highlight_" .. buf, { clear = true })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        group = group, buffer = buf, callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = group, buffer = buf, callback = vim.lsp.buf.clear_references,
      })
    end
  end,
})
-- Inline type hints (very handy in Rust). Toggle with <Space>th.
vim.lsp.inlay_hint.enable(true)

-- -----------------------------------------------------------------------------
-- 5. Install lazy.nvim (plugin manager) automatically on first start
-- -----------------------------------------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- -----------------------------------------------------------------------------
-- 6. Plugins
-- -----------------------------------------------------------------------------

-- Close a buffer (tab) but keep its window open by showing another file there.
-- Asks to save first if it has unsaved changes.
local function close_buffer(buf)
  buf = (buf == nil or buf == 0) and vim.api.nvim_get_current_buf() or buf
  if buf == vim.api.nvim_get_current_buf() then
    vim.cmd("bprevious")
    if vim.api.nvim_get_current_buf() == buf then vim.cmd("enew") end -- it was the last one
  end
  vim.cmd("confirm bdelete " .. buf)
end

require("lazy").setup({
  spec = {

    -- Colorscheme ------------------------------------------------------------
    {
      "ellisonleao/gruvbox.nvim",
      lazy = false,
      priority = 1000, -- load before everything else
      config = function()
        vim.o.background = "dark"
        require("gruvbox").setup({
          contrast = "", -- "hard" (darker), "soft" (lighter), or "" (normal)
	  overrides = { -- grey box behind other uses of the symbol under the cursor
            LspReferenceText = { bg = "#504945" },
            LspReferenceRead = { bg = "#504945" },
            LspReferenceWrite = { bg = "#504945", underline = true },
          },
        })
        vim.cmd.colorscheme("gruvbox")
      end,
    },

    -- File browser -----------------------------------------------------------
    -- Inside the tree: <Enter> open · a new file/folder · d delete · r rename
    --                  c/x/p copy/cut/paste · H toggle hidden · g? all keys
    {
      "nvim-tree/nvim-tree.lua",
      lazy = false,
      dependencies = { "nvim-tree/nvim-web-devicons" }, -- icons (needs a Nerd Font)
      keys = {
        { "<leader>e", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file tree" },
        { "<leader>o", "<cmd>NvimTreeFindFile<CR>", desc = "Show current file in tree" },
      },
      opts = {
        view = { width = 32 },
        renderer = { group_empty = true },
        filters = { dotfiles = false, git_ignored = false },
        update_focused_file = { enable = true },
      },
    },

    -- Open files as tabs along the top ---------------------------------------
    -- <S-h>/<S-l> previous/next · <Space>bd close · click a tab to switch to it
    {
      "akinsho/bufferline.nvim",
      version = "*",
      lazy = false,
      dependencies = { "nvim-tree/nvim-web-devicons" },
      keys = {
        { "<S-h>", "<cmd>BufferLineCyclePrev<CR>", desc = "Previous buffer" },
        { "<S-l>", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
        { "<leader>bd", function() close_buffer() end, desc = "Close buffer" },
        { "<leader>bo", "<cmd>BufferLineCloseOthers<CR>", desc = "Close other buffers" },
        { "<leader>bp", "<cmd>BufferLinePick<CR>", desc = "Pick buffer" },
      },
      opts = {
        options = {
          close_command = close_buffer,       -- the x on a tab
          right_mouse_command = close_buffer, -- right-click a tab
          diagnostics = "nvim_lsp",           -- error/warning count on each tab
          offsets = { { filetype = "NvimTree", text = "Files", separator = true } },
        },
      },
    },

    -- Fuzzy finder -----------------------------------------------------------
    -- <Space>fg (search text in project) needs ripgrep: `rg` on your PATH.
    {
      "nvim-telescope/telescope.nvim",
      version = "*",
      cmd = "Telescope",
      dependencies = {
        "nvim-lua/plenary.nvim",
        { -- faster sorting; only built if `make` is available
          "nvim-telescope/telescope-fzf-native.nvim",
          build = "make",
          cond = function() return vim.fn.executable("make") == 1 end,
        },
      },
      keys = {
        { "<leader>ff", function() require("telescope.builtin").find_files() end, desc = "Find files" },
        { "<leader>fg", function() require("telescope.builtin").live_grep() end, desc = "Search text (grep)" },
        { "<leader>fb", function() require("telescope.builtin").buffers() end, desc = "Open buffers" },
        { "<leader>fr", function() require("telescope.builtin").oldfiles() end, desc = "Recent files" },
        { "<leader>fh", function() require("telescope.builtin").help_tags() end, desc = "Search help" },
        { "<leader>fd", function() require("telescope.builtin").diagnostics() end, desc = "All errors/warnings" },
        { "<leader>fs", function() require("telescope.builtin").lsp_document_symbols() end, desc = "Symbols in file" },
        { "<leader><leader>", function() require("telescope.builtin").buffers() end, desc = "Switch buffer" },
      },
      config = function()
        require("telescope").setup({})
        pcall(require("telescope").load_extension, "fzf")
      end,
    },

    -- Syntax highlighting (Tree-sitter) --------------------------------------
    -- Needs: the `tree-sitter` CLI (0.26.1+), a C compiler, curl and tar.
    -- Neovim already ships Lua, Vimscript, C and Markdown parsers.
    {
      "nvim-treesitter/nvim-treesitter",
      lazy = false, -- this plugin does not support lazy-loading
      build = ":TSUpdate",
      config = function()
        local parsers = {
          "rust", "toml",
          "go", "gomod", "gosum", "gowork",
          "json", "yaml", "bash",
        }
        if vim.fn.executable("tree-sitter") == 1 then
          require("nvim-treesitter").install(parsers) -- no-op once installed
        else
          vim.notify("tree-sitter CLI not found: install it to get Rust/Go highlighting",
            vim.log.levels.WARN)
        end

        -- Turn on tree-sitter highlighting for any file that has a parser.
        vim.api.nvim_create_autocmd("FileType", {
          callback = function(args) pcall(vim.treesitter.start, args.buf) end,
        })
      end,
    },

    -- Language servers (LSP) -------------------------------------------------
    -- mason downloads the servers; mason-lspconfig switches them on.
    -- Open :Mason to see what's installed or add more languages later.
    {
      "mason-org/mason-lspconfig.nvim",
      dependencies = {
        { "mason-org/mason.nvim", opts = {} },
        "neovim/nvim-lspconfig", -- ready-made settings for each server
      },
      config = function()
        -- Run `cargo clippy` instead of `cargo check` for extra Rust lints.
        vim.lsp.config("rust_analyzer", {
          settings = { ["rust-analyzer"] = { check = { command = "clippy" } } },
        })

        require("mason-lspconfig").setup({
          ensure_installed = { "rust_analyzer", "gopls", "lua_ls" },
        })
      end,
    },

    -- Makes lua_ls understand Neovim's API while you edit this config file.
    { "folke/lazydev.nvim", ft = "lua", opts = {} },

    -- Autocompletion ---------------------------------------------------------
    -- <Tab> accept · <C-n>/<C-p> or arrows move · <C-space> open · <C-e> close
    {
      "saghen/blink.cmp",
      version = "1.*", -- release tag = prebuilt fuzzy matcher binary
      dependencies = { "rafamadriz/friendly-snippets" },
      opts = {
        keymap = { preset = "super-tab" }, -- or "default" (C-y) / "enter"
        appearance = { nerd_font_variant = "mono" },
        completion = { documentation = { auto_show = true, auto_show_delay_ms = 300 } },
        signature = { enabled = true },
        sources = {
          default = { "lazydev", "lsp", "path", "snippets", "buffer" },
          providers = {
            lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
          },
        },
        fuzzy = { implementation = "prefer_rust_with_warning" },
      },
    },

    -- Format on save ---------------------------------------------------------
    -- rustfmt comes with rustup, gofmt comes with Go. goimports is used if
    -- installed (go install golang.org/x/tools/cmd/goimports@latest).
    {
      "stevearc/conform.nvim",
      event = "BufWritePre",
      cmd = "ConformInfo",
      keys = {
        { "<leader>cf", function() require("conform").format({ async = true }) end, desc = "Format file" },
      },
      opts = {
        formatters_by_ft = {
          rust = { "rustfmt" },
          go = { "goimports", "gofmt", stop_after_first = true },
        },
        format_on_save = { timeout_ms = 1000, lsp_format = "fallback" },
      },
    },

    -- Error / reference lists ------------------------------------------------
    -- Inside the list: <Enter> jump · o jump & close · q close · ? all keys
    {
      "folke/trouble.nvim",
      cmd = "Trouble",
      keys = {
        { "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", desc = "All errors/warnings" },
        { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<CR>", desc = "Errors in this file" },
        { "<leader>xs", "<cmd>Trouble symbols toggle focus=false<CR>", desc = "Symbols outline" },
        { "<leader>xr", "<cmd>Trouble lsp_references toggle<CR>", desc = "References to symbol" },
        { "<leader>xq", "<cmd>Trouble qflist toggle<CR>", desc = "Quickfix list" },
      },
      opts = {},
    },

    -- Shortcut helper: press <Space> and wait a moment ------------------------
    {
      "folke/which-key.nvim",
      event = "VeryLazy",
      opts = {
        spec = {
          { "<leader>b", group = "buffer" },
          { "<leader>f", group = "find" },
          { "<leader>c", group = "code" },
          { "<leader>t", group = "toggle" },
          { "<leader>x", group = "trouble (lists)" },
          { "gr", group = "LSP" },
        },
      },
    },

    -- Small quality-of-life plugins ------------------------------------------
    { "nvim-lualine/lualine.nvim", opts = { options = { globalstatus = true } } }, -- status bar
    { "lewis6991/gitsigns.nvim", opts = {} },                    -- git +/~/- in the gutter
    { "nvim-mini/mini.pairs", event = "InsertEnter", opts = {} },  -- auto-close (), [], ""
  },

  install = { colorscheme = { "gruvbox" } },
  checker = { enabled = false }, -- don't nag about plugin updates; run :Lazy update yourself
  rocks = { enabled = false },   -- no plugin here needs luarocks
  -- Keep Neovim's bundled parsers (lua, vim, markdown, ...) on the runtimepath.
  -- lazy.nvim looks for them in /usr/lib64/nvim when /usr/lib64 exists (Ubuntu),
  -- but the distro package puts them in /usr/lib/nvim.
  performance = { rtp = { paths = { vim.fn.fnamemodify(vim.v.progpath, ":p:h:h") .. "/lib/nvim" } } },
})

-- Terminal
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Leave terminal mode" })
map("n", "<leader>tt", function()
  vim.cmd("botright split | resize 12 | terminal")
  vim.cmd("startinsert")
end, { desc = "Open terminal below" })


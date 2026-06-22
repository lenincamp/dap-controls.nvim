# dap-controls.nvim

DAP keymaps, session helpers, signs, dap-view setup and common adapter wiring for Neovim.

Bundles related concerns that belong together but are too small to be standalone plugins:

- **keymaps** — full `<leader>d*` keymap suite (continue, step, breakpoints, REPL, watches, eval, run-to-method…)
- **helpers** — session/eval/watch/run-to helpers consumed by keymaps and dap-view config
- **signs** — DAP sign definitions + highlight links, re-applied on `ColorScheme`
- **thread_sync** — dap-view frame navigation patches (syncs `stopped_thread_id`, recovers before step/continue)
- **dap_view** — opinionated default `nvim-dap-view` setup
- **adapters** — opt-in Java, Kotlin and JavaScript/TypeScript DAP configurations

## Requirements

- Neovim ≥ 0.10
- [nvim-dap](https://github.com/mfussenegger/nvim-dap)

### Optional dependencies

- [breakpoints.nvim](https://github.com/lcampoverde/breakpoints.nvim) — persistent breakpoints support
- [picker.nvim](https://github.com/lcampoverde/picker.nvim) — method breakpoint picker
- [nvim-dap-view](https://github.com/igorlfs/nvim-dap-view) — DAP UI (for watch/REPL/thread-sync)
- [jdtls.nvim](https://github.com/lcampoverde/jdtls.nvim) — Java DAP recovery

## Installation

### lazy.nvim

```lua
{
  "lcampoverde/dap-controls.nvim",
  dependencies = {
    "mfussenegger/nvim-dap",
    "igorlfs/nvim-dap-view",
    "lcampoverde/breakpoints.nvim",
    "lcampoverde/picker.nvim",
  },
  keys = function()
    return require("dap-controls.keymaps").lazy_keys()
  end,
  config = function()
    require("dap-controls").setup({
      keymaps = true,
      signs = true,
      listeners = true,
      thread_sync = true,
      repl_paste = true,
      breakpoints = true,
      dap_view = true,
      adapters = {
        java = true,
        kotlin = true,
        javascript = true,
      },
    })
  end,
}
```

## API

### `require("dap-controls").setup(opts)`

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `signs` | `boolean` | `true` | Define DAP signs and highlight links |
| `keymaps` | `boolean` | `false` | Register the `<leader>d*` keymaps |
| `listeners` | `boolean` | `false` | Open dap-view on DAP attach/launch |
| `thread_sync` | `boolean` | `true` | Apply dap-view thread-sync patches |
| `diag_command` | `boolean` | `true` | Register `:DapThreadDiag` command |
| `repl_paste` | `boolean` | `false` | Route multiline `dap-repl` paste through floating eval |
| `breakpoints` | `boolean` | `false` | Setup optional `breakpoints.nvim` integration |
| `dap_view` | `boolean\|table` | `false` | Setup `nvim-dap-view`; accepts `enabled` and `override` |
| `adapters` | `boolean\|table` | `false` | Setup language adapters; accepts `java`, `kotlin`, `javascript` |

### dap-view

`dap-controls` intentionally keeps one `nvim-dap-view` layout: a bottom panel with dap-view sections in the winbar and the terminal on the right when the adapter exposes one.

```text
┌───────────────────────────────────────────────────────┐
│ Code Editor                                           │
├──────────────────────────────────────┬────────────────┤
│ Variables | Watches | Stack | REPL   │ Terminal       │
└──────────────────────────────────────┴────────────────┘
```

Use `override` for targeted dap-view tweaks:

```lua
require("dap-controls").setup({
  dap_view = {
    enabled = true,
    override = {
      windows = { size = 0.35 },
    },
  },
})
```

### Adapters

```lua
require("dap-controls").setup({
  adapters = {
    java = true,
    kotlin = true,
    javascript = true,
  },
})
```

- Java delegates profile creation to `jdtls-nvim` and initializes `jdtls.dap` after `jdtls` attaches.
- Kotlin uses `kotlin-debug-adapter` when available on `$PATH`.
- JavaScript/TypeScript uses Mason's `js-debug-adapter` when installed.

### `require("dap-controls.keymaps")`

| Function | Description |
|----------|-------------|
| `apply(dap, helpers)` | Register all `<leader>d*` keymaps |
| `lazy_keys()` | Return keys table for lazy.nvim `keys =` |
| `lazy_specs()` | Extended specs with loader hints |

### `require("dap-controls.helpers")`

| Function | Description |
|----------|-------------|
| `toggle_dap_view(action?)` | Toggle/open/close dap-view panel |
| `toggle_breakpoint_and_save()` | Toggle breakpoint + persist |
| `conditional_breakpoint_prompt()` | Set conditional breakpoint via input |
| `logpoint_prompt()` | Set logpoint via input |
| `clear_breakpoints_and_save()` | Clear all + persist |
| `eval_expression_prompt()` | Open floating eval buffer |
| `set_expression_prompt()` | Set variable value via input |
| `add_watch_prompt()` | Add watch expression via input |
| `add_watch_from_visual_selection()` | Add watch from `v` selection |
| `open_repl_view()` | Open dap-view REPL tab |
| `eval_visual_selection_in_repl()` | Eval visual selection in REPL |
| `hover_widget()` | Show dap widget hover |
| `run_to_cursor()` | Run to cursor |
| `run_to_method_breakpoint()` | Picker: jump to breakpoint in current method |
| `continue_with_args_prompt()` | Continue with custom args |
| `goto_line_prompt()` | Goto DAP line |
| `show_dap_capabilities()` | Notify adapter capabilities |
| `breakpoints_save/load/picker/assign_group()` | Delegate to breakpoints.nvim |
| `bp_icon_for(lnum, path)` | Breakpoint icon for dap-view render |
| `short_path(path)` | Shorten path to last 2 segments |
| `_open_eval_floating(lines, ft)` | Internal: open eval float pre-filled |
| `_flatten_expr(text)` | Internal: join multiline expr to single line |

### `require("dap-controls.thread_sync")`

| Function | Description |
|----------|-------------|
| `apply()` | Patch `Session._frame_set`, `_step`, `guard.expect_stopped`, `dap.continue` |
| `register_diag_command()` | Register `:DapThreadDiag` user command |

### `require("dap-controls.signs")`

| Function | Description |
|----------|-------------|
| `setup()` | Define signs + register `ColorScheme` autocmd |

## Keymaps

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>dc` | n | Continue |
| `<leader>dC` | n | Run to Cursor |
| `<leader>di` | n | Step Into |
| `<leader>dO` | n | Step Out |
| `<leader>do` | n | Step Over |
| `<leader>dP` | n | Pause |
| `<leader>db` | n | Toggle Breakpoint |
| `<leader>dB` | n | Conditional Breakpoint |
| `<leader>dL` | n | Logpoint |
| `<leader>dD` | n | Clear Breakpoints |
| `<leader>dl` | n | Run Last |
| `<leader>dt` | n | Terminate |
| `<leader>dd` | n | Disconnect |
| `<leader>dr` | n | Open REPL View |
| `<leader>dr` | x | Eval Selection in REPL |
| `<leader>ds` | n | Session |
| `<leader>dw` | n | Widgets |
| `<leader>de` | n/v | Eval |
| `<leader>dE` | n | Eval/Set Expression |
| `<leader>dS` | n | Set Expression |
| `<leader>dW` | n | Add Watch |
| `<leader>dW` | x | Add Watch from Selection |
| `<leader>dj` | n | Down (stack) |
| `<leader>dk` | n | Up (stack) |
| `<leader>dg` | n | Go to Line |
| `<leader>dm` | n | Method Breakpoint Picker |
| `<leader>da` | n | Run with Args |
| `<leader>du` | n | Toggle DAP View |
| `<leader>d?` | n | Show Adapter Capabilities |
| `<leader>dbs` | n | Breakpoints: Save |
| `<leader>dbL` | n | Breakpoints: Load |
| `<leader>dbg` | n | Breakpoints: Assign group |
| `<leader>dbp` | n | Breakpoints: Browse by group |

## License

MIT

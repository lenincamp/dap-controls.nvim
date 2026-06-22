local M = {}

local configured = false

function M.setup()
  if configured then return end
  configured = true

  local ok, breakpoints = pcall(require, "breakpoints")
  if not ok then return end

  breakpoints.setup({
    markers = { "mvnw", "pom.xml", "build.gradle", "build.gradle.kts", "package.json" },
    on_setup = function()
      require("dap-controls.signs").setup()
    end,
  })
end

return M

-- claude-containers.lua: keep each container's windows ringed in its own colour.
--
-- Install: copy this file to ~/.hammerspoon/, then add to ~/.hammerspoon/init.lua:
--   require("claude-containers").start("/path/to/publicart/containers/bin/claude-container")
--
-- A timer, not window events: the Claude processes stop answering Accessibility while busy, so
-- event-driven hooks miss windows exactly when they matter. `claude-container borders` is
-- idempotent and only pushes windows whose colour changed, so a short tick is cheap.
local M = {}

function M.start(cli, seconds)
  assert(cli, "claude-containers.start needs the full path to bin/claude-container")
  seconds = seconds or 5
  local running = false
  local function apply()
    if running then return end          -- never stack runs if one is slow
    running = true
    hs.task.new(cli, function(code, _, err)
      running = false
      if code ~= 0 then print("claude-container borders failed (" .. code .. "): " .. (err or "")) end
    end, { "borders" }):start()
  end
  M.timer = hs.timer.doEvery(seconds, apply)
  apply()
  return M
end

function M.stop() if M.timer then M.timer:stop(); M.timer = nil end end

return M

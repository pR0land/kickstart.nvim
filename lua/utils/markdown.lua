local M = {}

--- @return string|nil
-- utils/markdown.lua update (optional trim)
function M.get_heading_above()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  for i = row, 1, -1 do
    local line = vim.fn.getline(i)
    local heading = line:match '^#+%s+(.-)%s*$' -- Added lazy match and trim
    if heading then
      return heading
    end
  end
  return nil
end

return M

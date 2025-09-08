local M = {}

 function M.select_item(items, opts, callback)
    -- 1. Try Telescope
    local has_telescope, telescope = pcall(require, "telescope")
    if has_telescope then
        local pickers = require("telescope.pickers")
        local finders = require("telescope.finders")
        local conf = require("telescope.config").values
        local actions = require("telescope.actions")
        local action_state = require("telescope.actions.state")

        pickers.new({}, {
            prompt_title = opts.prompt or "Select Item",
            finder = finders.new_table {
                results = items,
                entry_maker = function(entry)
                    return {
                        value = entry,
                        display = opts.format_item and opts.format_item(entry) or tostring(entry),
                        ordinal = opts.format_item and opts.format_item(entry) or tostring(entry),
                    }
                end,
            },
            sorter = conf.generic_sorter({}),
            attach_mappings = function(_, map)
                map("i", "<CR>", function(bufnr)
                    local selection = action_state.get_selected_entry()
                    actions.close(bufnr)
                    if selection then
                        callback(selection.value)
                    end
                end)
                return true
            end,
        }):find()
        return
    end

    -- 2. Try fzf-lua
    local has_fzf, fzf = pcall(require, "fzf-lua")
    if has_fzf then
        fzf.fzf_exec(vim.tbl_map(function(entry)
            return opts.format_item and opts.format_item(entry) or tostring(entry)
        end, items), {
            prompt = opts.prompt or "Select Item> ",
            actions = {
                ["default"] = function(selected)
                    local idx = nil
                    for i, entry in ipairs(items) do
                        if (opts.format_item and opts.format_item(entry) or tostring(entry)) == selected[1] then
                            idx = i
                            break
                        end
                    end
                    if idx then
                        callback(items[idx])
                    end
                end,
            },
        })
        return
    end

    --TODO: 3. Try snacks.picker

    -- 4. Fallback to vim.ui.select
    vim.ui.select(items, opts, callback)
end

return M

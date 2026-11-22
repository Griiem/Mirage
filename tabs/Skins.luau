return function(Window, WindUI, Mirage)

local Skins = Mirage.Skins

local Tab = Window:Tab({
    Title = "Skins",
    Icon = "shirt",
})

Tab:Toggle({
    Title = "Skins enabled",
    Type = "Checkbox",
    Value = true,

    Callback = function(state)
        Skins:SetEnabled(state)
    end,
})

Tab:Button({
    Title = "Refresh skins",
    Desc = "Downloads the index from GitHub and reapplies skins to players in this server",

    Callback = function()
        task.spawn(function()
            local ok = Skins:Refresh()

            if not ok then
                WindUI:Notify({
                    Title = "Mirage",
                    Content = "Could not read skins/index.json.",
                    Icon = "x",
                    Duration = 4,
                })
                return
            end

            WindUI:Notify({
                Title = "Mirage",
                Content = Skins:Count() .. " player(s) with a skin in this server.",
                Icon = "check",
                Duration = 4,
            })
        end)
    end,
})

end

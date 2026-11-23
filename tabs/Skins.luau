local Players = game:GetService("Players")

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

Tab:Button({
    Title = "My status",
    Desc = "Shows what happened with your own skin (also printed in the console)",

    Callback = function()
        local report = Skins:Report(Players.LocalPlayer)

        warn("[Mirage] Status: " .. report)

        WindUI:Notify({
            Title = "Mirage status",
            Content = report,
            Icon = "info",
            Duration = 10,
        })
    end,
})


Tab:Button({
    Title = "Debug character",
    Desc = "Prints details about your character in the console (F9)",

    Callback = function()
        task.spawn(function()
            local lines = Skins:Debug(Players.LocalPlayer)

            for _, line in lines do
                warn("[Mirage] Debug: " .. line)
            end

            WindUI:Notify({
                Title = "Mirage debug",
                Content = "Printed " .. #lines .. " lines in the console (F9).",
                Icon = "info",
                Duration = 5,
            })
        end)
    end,
})

end

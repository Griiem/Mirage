return function(Window, WindUI, Mirage)

local Skins = Mirage.Skins

local Tab = Window:Tab({
    Title = "Skins",
    Icon = "shirt",
})

Tab:Toggle({
    Title = "Skins ativas",
    Type = "Checkbox",
    Value = true,

    Callback = function(state)
        Skins:SetEnabled(state)
    end,
})

Tab:Button({
    Title = "Atualizar skins",
    Desc = "Baixa o index do GitHub e reaplica em quem está no servidor",

    Callback = function()
        task.spawn(function()
            local ok = Skins:Refresh()

            if not ok then
                WindUI:Notify({
                    Title = "Mirage",
                    Content = "Não consegui ler skins/index.json.",
                    Icon = "x",
                    Duration = 4,
                })
                return
            end

            WindUI:Notify({
                Title = "Mirage",
                Content = Skins:Count() .. " jogador(es) com skin neste servidor.",
                Icon = "check",
                Duration = 4,
            })
        end)
    end,
})

end

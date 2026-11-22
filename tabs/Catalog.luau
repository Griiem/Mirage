return function(Window, WindUI, Mirage)

local CatalogUI = Mirage.Require("core/CatalogUI.luau")(Mirage, WindUI)

Mirage.CatalogUI = CatalogUI

local Tab = Window:Tab({
    Title = "Catalog",
    Icon = "shopping-bag",
})

Tab:Button({
    Title = "Open catalog",
    Desc = "Search the Roblox catalog and equip items for free (local only)",

    Callback = function()
        CatalogUI:Toggle()
    end,
})

end

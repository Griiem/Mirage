return function(Mirage, WindUI)
    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local HttpService = game:GetService("HttpService")

    local Skins = Mirage.Skins
    local Catalog = Mirage.Require("core/Catalog.luau")()

    local STATE_FILE = "Mirage/loadout.json"

    local COLORS = {
        Background = Color3.fromRGB(14, 16, 26),
        Panel = Color3.fromRGB(22, 25, 38),
        Card = Color3.fromRGB(32, 36, 56),
        Accent = Color3.fromRGB(104, 118, 255),
        Text = Color3.fromRGB(232, 234, 246),
        Muted = Color3.fromRGB(144, 150, 176),
        Good = Color3.fromRGB(88, 222, 148),
        Bad = Color3.fromRGB(255, 96, 110),
    }

    local KIND_LABELS = {
        shirt = "Shirt",
        pants = "Pants",
        tshirt = "T-Shirt",
        face = "Face",
        accessory = "Accessory",
    }

    local UI = { Connections = {}, Destroyed = false }

    local state = { loadout = {}, names = {} }

    local function notify(content, icon)
        WindUI:Notify({
            Title = "Mirage",
            Content = content,
            Icon = icon or "info",
            Duration = 4,
        })
    end

    local function create(className, props, children)
        local inst = Instance.new(className)
        local parent = props.Parent

        props.Parent = nil

        for key, value in props do
            inst[key] = value
        end

        if children then
            for _, child in children do
                child.Parent = inst
            end
        end

        inst.Parent = parent

        return inst
    end

    local function corner(radius)
        return create("UICorner", { CornerRadius = UDim.new(0, radius) })
    end

    local function stroke(color, thickness, transparency)
        return create("UIStroke", {
            Color = color,
            Thickness = thickness or 1,
            Transparency = transparency or 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        })
    end

    local function padding(amount)
        return create("UIPadding", {
            PaddingTop = UDim.new(0, amount),
            PaddingBottom = UDim.new(0, amount),
            PaddingLeft = UDim.new(0, amount),
            PaddingRight = UDim.new(0, amount),
        })
    end

    local function label(props)
        props.BackgroundTransparency = 1
        props.Font = props.Font or Enum.Font.GothamMedium
        props.TextColor3 = props.TextColor3 or COLORS.Text
        props.TextSize = props.TextSize or 14

        return create("TextLabel", props)
    end

    local function styledButton(props)
        props.AutoButtonColor = true
        props.BackgroundColor3 = props.BackgroundColor3 or COLORS.Card
        props.BorderSizePixel = 0
        props.Font = Enum.Font.GothamMedium
        props.TextColor3 = COLORS.Text
        props.TextSize = props.TextSize or 13

        return create("TextButton", props, { corner(8) })
    end

    local function thumb(id)
        return ("rbxthumb://type=Asset&id=%d&w=150&h=150"):format(id)
    end

    local function loadState()
        if type(isfile) ~= "function" or type(readfile) ~= "function" then
            return
        end

        local ok, decoded = pcall(function()
            if isfile(STATE_FILE) then
                return HttpService:JSONDecode(readfile(STATE_FILE))
            end

            return nil
        end)

        if ok and type(decoded) == "table" then
            state.loadout = type(decoded.loadout) == "table" and decoded.loadout or {}
            state.names = type(decoded.names) == "table" and decoded.names or {}
        end
    end

    local function saveState()
        if type(writefile) ~= "function" then
            return
        end

        pcall(function()
            if type(isfolder) == "function" and not isfolder("Mirage") then
                makefolder("Mirage")
            end

            writefile(STATE_FILE, HttpService:JSONEncode(state))
        end)
    end

    local function copyLoadout()
        local copy = {}

        for key, value in state.loadout do
            if type(value) == "table" then
                copy[key] = table.clone(value)
            else
                copy[key] = value
            end
        end

        return copy
    end

    local function commit()
        saveState()
        Skins:SetLocalLoadout(copyLoadout())
    end

    local function isEquipped(kind, id)
        if kind == "accessory" then
            for _, value in state.loadout.accessories or {} do
                if value == id then
                    return true
                end
            end

            return false
        end

        return state.loadout[kind] == id
    end

    local function toggleEquip(kind, id, name)
        state.names[tostring(id)] = name

        if kind == "accessory" then
            local list = state.loadout.accessories or {}
            local index = table.find(list, id)

            if index then
                table.remove(list, index)
            else
                table.insert(list, id)
            end

            state.loadout.accessories = #list > 0 and list or nil
        elseif state.loadout[kind] == id then
            state.loadout[kind] = nil
        else
            state.loadout[kind] = id
        end

        commit()
    end

    local gui = create("ScreenGui", {
        Name = "MirageCatalog",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 50,
        Enabled = false,
    })

    local function mount()
        local targets = {}

        if type(gethui) == "function" then
            local ok, result = pcall(gethui)

            if ok and result then
                table.insert(targets, result)
            end
        end

        local okCore, core = pcall(function()
            return game:GetService("CoreGui")
        end)

        if okCore and core then
            table.insert(targets, core)
        end

        table.insert(targets, Players.LocalPlayer:WaitForChild("PlayerGui"))

        for _, target in targets do
            local ok = pcall(function()
                gui.Parent = target
            end)

            if ok and gui.Parent == target then
                return
            end
        end
    end

    local main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(0.62, 0.72),
        BackgroundColor3 = COLORS.Background,
        BorderSizePixel = 0,
        Parent = gui,
    }, {
        corner(12),
        stroke(COLORS.Accent, 1, 0.6),
        create("UISizeConstraint", {
            MinSize = Vector2.new(520, 340),
            MaxSize = Vector2.new(760, 480),
        }),
    })

    local titleBar = create("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        Parent = main,
    }, { corner(12) })

    create("Frame", {
        Position = UDim2.new(0, 0, 1, -12),
        Size = UDim2.new(1, 0, 0, 12),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        Parent = titleBar,
    })

    label({
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.new(1, -70, 1, 0),
        Text = "Mirage Catalog",
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = titleBar,
    })

    local closeButton = styledButton({
        Text = "X",
        Position = UDim2.new(1, -42, 0.5, -14),
        Size = UDim2.fromOffset(32, 28),
        Parent = titleBar,
    })

    closeButton.MouseButton1Click:Connect(function()
        gui.Enabled = false
    end)

    local dragging = false
    local dragStart
    local startPosition

    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then

            dragging = true
            dragStart = input.Position
            startPosition = main.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    table.insert(UI.Connections, UserInputService.InputChanged:Connect(function(input)
        if dragging
            and (input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch) then

            local delta = input.Position - dragStart

            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end))

    local sidebar = create("Frame", {
        Name = "Sidebar",
        Position = UDim2.fromOffset(10, 52),
        Size = UDim2.new(0, 160, 1, -62),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        Parent = main,
    }, {
        corner(8),
        padding(8),
        create("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    local content = create("Frame", {
        Name = "Content",
        Position = UDim2.fromOffset(180, 52),
        Size = UDim2.new(1, -190, 1, -62),
        BackgroundTransparency = 1,
        Parent = main,
    })

    local browse = create("Frame", {
        Name = "Browse",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Parent = content,
    })

    local searchBox = create("TextBox", {
        Name = "Search",
        Size = UDim2.new(1, -92, 0, 34),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        PlaceholderText = "Search the catalog...",
        PlaceholderColor3 = COLORS.Muted,
        Text = "",
        TextColor3 = COLORS.Text,
        TextSize = 14,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = browse,
    }, {
        corner(8),
        create("UIPadding", { PaddingLeft = UDim.new(0, 10) }),
    })

    local searchButton = styledButton({
        Text = "Search",
        Position = UDim2.new(1, -84, 0, 0),
        Size = UDim2.fromOffset(84, 34),
        BackgroundColor3 = COLORS.Accent,
        Parent = browse,
    })

    local grid = create("ScrollingFrame", {
        Name = "Grid",
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(1, 0, 1, -82),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = browse,
    }, {
        corner(8),
        padding(8),
        create("UIGridLayout", {
            CellSize = UDim2.fromOffset(120, 164),
            CellPadding = UDim2.fromOffset(8, 8),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    local statusLabel = label({
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(1, 0, 1, -82),
        Text = "",
        TextColor3 = COLORS.Muted,
        ZIndex = 5,
        Parent = browse,
    })

    local footer = create("Frame", {
        Name = "Footer",
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Parent = browse,
    })

    label({
        Size = UDim2.new(1, -130, 1, 0),
        Text = "Click an item to equip or unequip it (local only)",
        TextSize = 12,
        TextColor3 = COLORS.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = footer,
    })

    local loadMore = styledButton({
        Text = "Load more",
        Position = UDim2.new(1, -120, 0.5, -14),
        Size = UDim2.fromOffset(120, 28),
        Visible = false,
        Parent = footer,
    })

    local equipped = create("Frame", {
        Name = "Equipped",
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = content,
    })

    local copyButton = styledButton({
        Text = "Copy loadout JSON",
        Size = UDim2.fromOffset(150, 34),
        BackgroundColor3 = COLORS.Accent,
        Parent = equipped,
    })

    local clearButton = styledButton({
        Text = "Clear all",
        Position = UDim2.fromOffset(158, 0),
        Size = UDim2.fromOffset(90, 34),
        Parent = equipped,
    })

    local hideButton = styledButton({
        Text = "",
        Position = UDim2.fromOffset(256, 0),
        Size = UDim2.new(1, -256, 0, 34),
        Parent = equipped,
    })

    local equippedList = create("ScrollingFrame", {
        Name = "List",
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(1, 0, 1, -42),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Parent = equipped,
    }, {
        corner(8),
        padding(8),
        create("UIListLayout", {
            Padding = UDim.new(0, 6),
            SortOrder = Enum.SortOrder.LayoutOrder,
        }),
    })

    local emptyLabel = label({
        Position = UDim2.fromOffset(0, 42),
        Size = UDim2.new(1, 0, 1, -42),
        Text = "Nothing equipped yet",
        TextColor3 = COLORS.Muted,
        ZIndex = 5,
        Parent = equipped,
    })

    local cardRefreshers = {}
    local sidebarButtons = {}
    local currentCategory = Catalog.Categories[1]
    local nextCursor
    local loading = false
    local searchToken = 0
    local initialized = false

    local function refreshCards()
        for _, refresh in cardRefreshers do
            refresh()
        end
    end

    local function updateHideButton()
        local on = state.loadout.clearAccessories == true

        hideButton.Text = "Hide my current accessories: " .. (on and "ON" or "OFF")
        hideButton.TextColor3 = on and COLORS.Good or COLORS.Text
    end

    local function renderEquipped()
        for _, child in equippedList:GetChildren() do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end

        local count = 0

        local function addRow(kind, id)
            count += 1

            local row = create("Frame", {
                Size = UDim2.new(1, 0, 0, 48),
                BackgroundColor3 = COLORS.Card,
                BorderSizePixel = 0,
                LayoutOrder = count,
                Parent = equippedList,
            }, { corner(8) })

            create("ImageLabel", {
                BackgroundTransparency = 1,
                Position = UDim2.fromOffset(6, 6),
                Size = UDim2.fromOffset(36, 36),
                Image = thumb(id),
                ScaleType = Enum.ScaleType.Fit,
                Parent = row,
            })

            label({
                Position = UDim2.fromOffset(52, 5),
                Size = UDim2.new(1, -140, 0, 20),
                Text = state.names[tostring(id)] or tostring(id),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = row,
            })

            label({
                Position = UDim2.fromOffset(52, 25),
                Size = UDim2.new(1, -140, 0, 16),
                Text = KIND_LABELS[kind] .. " | " .. tostring(id),
                TextSize = 11,
                TextColor3 = COLORS.Muted,
                TextXAlignment = Enum.TextXAlignment.Left,
                Parent = row,
            })

            local remove = styledButton({
                Text = "Remove",
                Position = UDim2.new(1, -78, 0.5, -14),
                Size = UDim2.fromOffset(70, 28),
                Parent = row,
            })

            remove.MouseButton1Click:Connect(function()
                toggleEquip(kind, id, state.names[tostring(id)] or tostring(id))
                renderEquipped()
                refreshCards()
            end)
        end

        for _, kind in { "shirt", "pants", "tshirt", "face" } do
            local id = state.loadout[kind]

            if id then
                addRow(kind, id)
            end
        end

        for _, id in state.loadout.accessories or {} do
            addRow("accessory", id)
        end

        emptyLabel.Visible = count == 0
        updateHideButton()
    end

    local function addCard(item, categoryKind)
        local kind = item.Kind or categoryKind

        local card = create("TextButton", {
            Name = tostring(item.Id),
            Text = "",
            AutoButtonColor = false,
            BackgroundColor3 = COLORS.Card,
            BorderSizePixel = 0,
            Parent = grid,
        }, { corner(8) })

        local cardStroke = stroke(COLORS.Good, 2, 1)
        cardStroke.Parent = card

        create("ImageLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.new(1, -12, 0, 108),
            Image = thumb(item.Id),
            ScaleType = Enum.ScaleType.Fit,
            Parent = card,
        })

        label({
            Position = UDim2.fromOffset(6, 116),
            Size = UDim2.new(1, -12, 0, 28),
            Text = item.Name,
            TextSize = 12,
            TextWrapped = true,
            TextTruncate = Enum.TextTruncate.AtEnd,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Parent = card,
        })

        local tag = label({
            Position = UDim2.fromOffset(6, 145),
            Size = UDim2.new(1, -12, 0, 14),
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Parent = card,
        })

        local function refresh()
            if not kind then
                tag.Text = "Unsupported"
                tag.TextColor3 = COLORS.Bad
                cardStroke.Transparency = 1
            elseif isEquipped(kind, item.Id) then
                tag.Text = "Equipped"
                tag.TextColor3 = COLORS.Good
                cardStroke.Transparency = 0
            else
                tag.Text = KIND_LABELS[kind]
                tag.TextColor3 = COLORS.Muted
                cardStroke.Transparency = 1
            end
        end

        refresh()
        table.insert(cardRefreshers, refresh)

        card.MouseButton1Click:Connect(function()
            if not kind then
                notify("This item type is not supported yet.", "x")
                return
            end

            toggleEquip(kind, item.Id, item.Name)
            refreshCards()
        end)
    end

    local function clearGrid()
        for _, child in grid:GetChildren() do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end

        table.clear(cardRefreshers)
    end

    local function runSearch(reset)
        if loading and not reset then
            return
        end

        searchToken += 1

        local token = searchToken

        loading = true

        if reset then
            clearGrid()
            nextCursor = nil
            loadMore.Visible = false
        end

        statusLabel.Text = "Loading..."
        statusLabel.Visible = true

        local category = currentCategory
        local keyword = searchBox.Text
        local cursor = (not reset) and nextCursor or nil

        task.spawn(function()
            local result, reason = Catalog.Search({
                Category = category.Category,
                Subcategory = category.Subcategory,
                Keyword = keyword,
                Cursor = cursor,
            })

            if UI.Destroyed or token ~= searchToken then
                return
            end

            loading = false

            if not result then
                statusLabel.Text = "Search failed: " .. tostring(reason):sub(1, 120)
                warn("[Mirage] Catalog search failed: " .. tostring(reason))
                return
            end

            for _, item in result.Items do
                addCard(item, category.Kind)
            end

            nextCursor = result.NextCursor
            loadMore.Visible = nextCursor ~= nil and nextCursor ~= ""

            if #result.Items == 0 and reset then
                statusLabel.Text = "No results."
            else
                statusLabel.Text = ""
            end
        end)
    end

    local function setView(name)
        browse.Visible = name == "browse"
        equipped.Visible = name == "equipped"
    end

    local function highlight(active)
        for _, button in sidebarButtons do
            button.BackgroundColor3 = button == active and COLORS.Accent or COLORS.Card
        end
    end

    for index, category in Catalog.Categories do
        local button = styledButton({
            Text = category.Name,
            Size = UDim2.new(1, 0, 0, 32),
            LayoutOrder = index,
            Parent = sidebar,
        })

        table.insert(sidebarButtons, button)

        button.MouseButton1Click:Connect(function()
            currentCategory = category
            setView("browse")
            highlight(button)
            runSearch(true)
        end)
    end

    local equippedButton = styledButton({
        Text = "Equipped",
        Size = UDim2.new(1, 0, 0, 32),
        LayoutOrder = 100,
        Parent = sidebar,
    })

    table.insert(sidebarButtons, equippedButton)

    equippedButton.MouseButton1Click:Connect(function()
        setView("equipped")
        highlight(equippedButton)
        renderEquipped()
    end)

    searchButton.MouseButton1Click:Connect(function()
        setView("browse")
        runSearch(true)
    end)

    searchBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            setView("browse")
            runSearch(true)
        end
    end)

    loadMore.MouseButton1Click:Connect(function()
        runSearch(false)
    end)

    copyButton.MouseButton1Click:Connect(function()
        local payload = HttpService:JSONEncode({
            [tostring(Players.LocalPlayer.UserId)] = state.loadout,
        })

        if type(setclipboard) == "function" then
            setclipboard(payload)
            notify("Loadout JSON copied to the clipboard.", "check")
        else
            print("[Mirage] " .. payload)
            notify("Clipboard not supported. JSON printed in the console.", "info")
        end
    end)

    clearButton.MouseButton1Click:Connect(function()
        state.loadout = {}
        commit()
        renderEquipped()
        refreshCards()
    end)

    hideButton.MouseButton1Click:Connect(function()
        if state.loadout.clearAccessories == true then
            state.loadout.clearAccessories = nil
        else
            state.loadout.clearAccessories = true
        end

        commit()
        updateHideButton()
    end)

    function UI:Toggle()
        gui.Enabled = not gui.Enabled

        if gui.Enabled and not initialized then
            initialized = true
            highlight(sidebarButtons[1])
            runSearch(true)
        end
    end

    function UI:Destroy()
        UI.Destroyed = true

        for _, connection in UI.Connections do
            if connection.Connected then
                connection:Disconnect()
            end
        end

        table.clear(UI.Connections)

        gui:Destroy()
    end

    mount()
    loadState()
    updateHideButton()

    if next(state.loadout) ~= nil then
        Skins:SetLocalLoadout(copyLoadout())
    end

    return UI
end

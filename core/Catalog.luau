local HttpService = game:GetService("HttpService")

return function()
    local Catalog = {}

    Catalog.Categories = {
        { Name = "All", Category = 1 },
        { Name = "Accessories", Category = 11, Kind = "accessory" },
        { Name = "Hair", Category = 11, Subcategory = 20, Kind = "accessory" },
        { Name = "Classic Shirts", Category = 3, Subcategory = 56, Kind = "shirt" },
        { Name = "Classic T-Shirts", Category = 3, Subcategory = 55, Kind = "tshirt" },
        { Name = "Classic Pants", Category = 3, Subcategory = 57, Kind = "pants" },
        { Name = "Faces", Category = 4, Subcategory = 10, Kind = "face" },
    }

    local KIND_BY_ASSET_TYPE = {
        [2] = "tshirt",
        [8] = "accessory",
        [11] = "shirt",
        [12] = "pants",
        [18] = "face",
    }

    for assetType = 41, 47 do
        KIND_BY_ASSET_TYPE[assetType] = "accessory"
    end

    for assetType = 64, 72 do
        KIND_BY_ASSET_TYPE[assetType] = "accessory"
    end

    function Catalog.KindOf(assetType)
        return KIND_BY_ASSET_TYPE[assetType]
    end

    function Catalog.Search(options)
        local params = {
            "Category=" .. tostring(options.Category or 1),
            "Limit=30",
            "SortType=0",
            "SortAggregation=5",
        }

        if options.Subcategory then
            table.insert(params, "Subcategory=" .. tostring(options.Subcategory))
        end

        if options.Keyword and options.Keyword ~= "" then
            table.insert(params, "Keyword=" .. HttpService:UrlEncode(options.Keyword))
        end

        if options.Cursor and options.Cursor ~= "" then
            table.insert(params, "Cursor=" .. HttpService:UrlEncode(options.Cursor))
        end

        local url = "https://catalog.roblox.com/v1/search/items/details?" .. table.concat(params, "&")

        local ok, body = pcall(function()
            return game:HttpGet(url)
        end)

        if not ok then
            return nil, "HttpGet failed (" .. tostring(body) .. ")"
        end

        local decodedOk, decoded = pcall(function()
            return HttpService:JSONDecode(body)
        end)

        if not decodedOk or type(decoded) ~= "table" then
            return nil, "invalid response from the catalog"
        end

        local items = {}

        for _, item in decoded.data or {} do
            if type(item.id) == "number" then
                local kind

                if item.itemType == nil or item.itemType == "Asset" then
                    kind = Catalog.KindOf(item.assetType)
                end

                table.insert(items, {
                    Id = item.id,
                    Name = item.name or "Unknown",
                    Kind = kind,
                    ItemType = item.itemType,
                    Creator = item.creatorName,
                })
            end
        end

        return {
            Items = items,
            NextCursor = decoded.nextPageCursor,
        }
    end

    return Catalog
end

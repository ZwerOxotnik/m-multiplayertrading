require "specializations-data"

local function copy(thing)
    if type(thing) == 'table' then
        local result = {}
        for key, value in pairs(thing) do
            result[key] = copy(value)
        end
        return result
    else
        return thing
    end
end

local buyBox = copy(data.raw.container['steel-chest'])
buyBox.name = "buy-box"
buyBox.icon = "__multiplayertrading__/graphics/icons/buy-box.png"
buyBox.picture.filename = "__multiplayertrading__/graphics/entity/buy-box.png"
buyBox.inventory_size = 1
local buyBoxItem = copy(data.raw.item['steel-chest'])
buyBoxItem.name = "buy-box"
buyBoxItem.icon = "__multiplayertrading__/graphics/icons/buy-box.png"
buyBoxItem.place_result = "buy-box"
local sellBox = copy(data.raw.container['steel-chest'])
sellBox.name = "sell-box"
sellBox.icon = "__multiplayertrading__/graphics/icons/sell-box.png"
sellBox.picture.filename = "__multiplayertrading__/graphics/entity/sell-box.png"
sellBox.inventory_size = 1
local sellBoxItem = copy(data.raw.item['steel-chest'])
sellBoxItem.name = "sell-box"
sellBoxItem.icon = "__multiplayertrading__/graphics/icons/sell-box.png"
sellBoxItem.place_result = "sell-box"

local creditMint = copy(data.raw.radar['radar'])
creditMint.name = "credit-mint"
creditMint.energy_usage = settings.startup['credit-mint-energy-usage'].value

local electricTradingStation = {
    type = "electric-energy-interface",
    name = "electric-trading-station",
    icon = "__base__/graphics/icons/accumulator.png",
    icon_size = 32,
    flags = {"placeable-neutral", "player-creation"},
    minable = {hardness = 0.2, mining_time = 0.5, result = "electric-trading-station"},
    max_health = 100,
    corpse = "medium-remnants",
    collision_mask = {"ghost-layer"},
    collision_box = {{-0.4, -0.9}, {0.4, 0.9}},
    selection_box = {{-0.5, -1}, {0.5, 1}},
    energy_source =
    {
        type = "electric",
        buffer_capacity = "6MJ",
        usage_priority = "tertiary",
        input_flow_limit = "6MW",
        output_flow_limit = "6MW"
    },
    picture = data.raw['electric-energy-interface']['electric-energy-interface'].picture,
    order = "z",
}

data:extend{
    sellBoxItem,
    buyBoxItem,
    sellBox,
    buyBox,
    creditMint,
    electricTradingStation,
    {
        type = "custom-input",
        name = "sellbox-gui-open",
        key_sequence = "mouse-button-1",
    },
    {
        type = "custom-input",
        name = "specialization-gui",
        key_sequence = "j",
    },
    {
        type = "custom-input",
        name = "sellbox-gui-close",
        key_sequence = "E",
    },
    {
        type = "recipe",
        name = "credit-mint",
        ingredients = {{"electronic-circuit", 50}, {"iron-gear-wheel", 50}},
        energy_required = 30,
        results = {{"credit-mint", 1}}
    },
    {
        type = "recipe",
        name = "sell-box",
        ingredients = {{"steel-chest", 1}, {"electronic-circuit", 2}},
        energy_required = 1,
        results = {{"sell-box", 1}}
    },
    {
        type = "recipe",
        name = "buy-box",
        ingredients = {{"steel-chest", 1}, {"electronic-circuit", 2}},
        energy_required = 1,
        results = {{"buy-box", 1}}
    },
    {
        type = "recipe",
        name = "electric-trading-station",
        ingredients = {{"substation", 1}, {"electronic-circuit", 2}},
        energy_required = 5,
        result = "electric-trading-station"
    },
    {
        type = "item",
        name = "credit-mint",
        place_result = "credit-mint", 
        subgroup = "extraction-machine",
        stack_size = 1,
        icon = "__base__/graphics/icons/coin.png",
        icon_size = 32
    },
    {
        type = "item",
        name = "electric-trading-station",
        place_result = "electric-trading-station", 
        subgroup = "energy-pipe-distribution",
        stack_size = 100,
        icon = "__base__/graphics/icons/substation.png",
        icon_size = 32
    }
}

if settings.startup['specializations'].value then
    for _, spec in ipairs(SPECIALIZATIONS) do
        local recipe = {
            type = "recipe",
            name = spec.name,
            ingredients = spec.recipe.ingredients,
            energy_required = spec.recipe.energy_required,
            enabled = false,
            category = spec.recipe.category,
            subgroup = spec.recipe.subgroup,
            icon = spec.recipe.icon,
        }
        if spec.recipe.result then
            recipe.result = spec.recipe.result
        else
            recipe.results = spec.recipe.results
        end
        if spec.recipe.icon then
            recipe.icon_size = 32
        end
        data:extend{recipe}
    end
end
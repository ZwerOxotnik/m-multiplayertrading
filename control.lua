--[[
    Multiplayer Trading by Luke Perkin.
    Some concepts taken from Teamwork mod (credit to DragoNFly1) and Diplomacy mod (credit to ZwerOxotnik).
]]
require "systems/land-claim"
require "systems/specializations"
require "systems/electric-trading-station"


--#region Constants
local floor = math.floor
local START_ITEMS = {name = "small-electric-pole", count = 10}
local IS_LAND_CLAIM = settings.startup['land-claim'].value
---#endregion


--#region Global data
local electric_trading_stations
local credit_mints
local sell_boxes
local orders
local open_order
local early_bird_tech
local credits
---#endregion


--#region global settings
local minting_speed = settings.global['credit-mint-speed'].value
local starting_credits = settings.global['starting-credits'].value
--#endregion


PLACE_NOMANSLAND_ITEMS = {
    ['locomotive'] = true,
    ['cargo-wagon'] = true,
    ['fluid-wagon'] = true,
    ['artillery-wagon'] = true,
    ['tank'] = true,
    ['car'] = true,
    ['player'] = true,
    ['transport-belt'] = true,
    ['fast-transport-belt'] = true,
    ['express-transport-belt'] = true,
    ['pipe'] = true,
    ['straight-rail'] = true,
    ['curved-rail'] = true,
    ['small-electric-pole'] = true,
    ['medium-electric-pole'] = true,
    ['big-electric-pole'] = true,
    ['substation'] = true,
    ['sell-box'] = true,
    ['buy-box'] = true,
}

PLACE_ENEMY_TERRITORY_ITEMS = {
    ['sell-box'] = true,
    ['buy-box'] = true,
}

POLES = {
    'small-electric-pole',
    'medium-electric-pole',
    'big-electric-pole',
    'substation'
}


local function link_data()
    credit_mints = global.credit_mints
    electric_trading_stations = global.electric_trading_stations
    sell_boxes = global.sell_boxes
    orders = global.orders
    open_order = global.open_order
    early_bird_tech = global.early_bird_tech
    credits = global.credits
end


local credits_label = {type = "label", name = "credits", style = "caption_label"}
local function AddCreditsGUI(player)
    local gui = player.gui
    if gui.left['credits'] then
        gui.left['credits'].destroy()
    end
    if not gui.top['credits'] then
        gui.top.add(credits_label)
    end
end


local function CheckGlobalData()
    global.sell_boxes = global.sell_boxes or {}
    global.orders = global.orders or {}
    global.credits = global.credits or {}
    global.credit_mints = global.credit_mints or {}
    global.specializations = global.specializations or {}
    global.output_stat = global.output_stat or {}
    global.early_bird_tech = global.early_bird_tech or {}
    global.open_order = global.open_order or {}
    global.electric_trading_stations = global.electric_trading_stations or {}

    link_data()

    for unit_number, entity in pairs(sell_boxes) do
        if not entity.valid then
            sell_boxes[unit_number] = nil
        end
    end
    for unit_number, data in pairs(credit_mints) do
        if not data.entity.valid then -- TODO: check, is data.entity has weird characters?
            credit_mints[unit_number] = nil
        end
    end
end

local function on_init()
    CheckGlobalData()
    for _, force in pairs(game.forces) do
        ForceCreated({force=force})
    end
    for _, player in pairs(game.players) do
        player.insert(START_ITEMS)
    end
    for _, player in pairs(game.connected_players) do
        AddCreditsGUI(player)
    end
end

local function on_load()
    link_data()
end

function ForceCreated(event)
    local force = event.force
    if credits[force.name] == nil then
        credits[force.name] = starting_credits
    end
    for name, technology in pairs(force.technologies) do
        if string.find(name, "-mpt-") ~= nil then
            technology.enabled = false
        end
    end
end


function ResearchCompleted(event)
    local research = event.research
    local tech_cost_multiplier = settings.startup['early-bird-multiplier'].value
    local base_tech_name = string.gsub(research.name, "%-mpt%-[0-9]+", "")
    if research.force.technologies[base_tech_name .. "-mpt-1"] == nil then
        return
    end
    early_bird_tech[research.force.name .. "/" .. base_tech_name] = true
    for _, force in pairs(game.forces) do
        local force_tech_state_id = force.name .. "/" .. base_tech_name
        local tech = force.technologies[research.name]
        if not tech.researched then
            local progress = force.get_saved_technology_progress(research.name)
            if string.find(research.name, "-mpt-") ~= nil then
                -- Another force has researched the 2nd, 3rd or 4th version of this tech.
                local tier_index = string.find(research.name, "[0-9]$")
                local tier = tonumber(string.sub( research.name, tier_index ))
                if tier < 4 then
                    local next_tech_name =  base_tech_name .. "-mpt-" .. tostring(tier + 1)
                    if progress then
                        progress = progress / math.pow(tech_cost_multiplier, tier + 1)
                        force.set_saved_technology_progress(next_tech_name, progress)
                    end
                    if not early_bird_tech[force_tech_state_id] then
                        force.technologies[next_tech_name].enabled = true
                    end
                    tech.enabled = false
                end
            else
                -- Another force has researched this tech for the 1st time.
                local next_tech_name = research.name .. "-mpt-1"
                if progress then
                    progress = progress / tech_cost_multiplier
                    force.set_saved_technology_progress(next_tech_name, progress)
                end
                force.technologies[next_tech_name].enabled = true
                tech.enabled = false
            end
        end
    end
end

function GetEventPlayer(event)
    if event.player_index then
        return game.get_player(event.player_index)
    else
        return nil
    end
end

function GetEventForce(event)
    if event.player_index then
        return game.get_player(event.player_index).force
    elseif event.robot then
        return event.robot.force
    else
        return nil
    end
end

function Area(position, radius)
    local x = position.x
    local y = position.y
    return {
        {x - radius, y - radius},
        {x + radius, y + radius}
    }
end

local special_builds = {
	["sell-box"] = function(entity)
        entity.operable = false
        sell_boxes[entity.unit_number] = entity
	end,
	["buy-box"] = function(entity)
        entity.operable = false
        sell_boxes[entity.unit_number] = entity
	end,
	["credit-mint"] = function(entity)
        credit_mints[entity.unit_number] = {
            ['entity'] = entity,
            ['progress'] = 0
        }
	end,
	["electric-trading-station"] = function(entity)
        electric_trading_stations[entity.unit_number] = {
            ['entity'] = entity,
            sell_price = 1,
            buy_bid = 1
        }
	end,
}
local function HandleEntityBuild(entity)
    local f = special_builds[entity.name]
	if f then
		f(entity)
	end
end

local function HandleEntityMined(event)
    local entity = event.entity
    local entity_name = entity.name
    if entity.type == "electric-pole" then
        if IS_LAND_CLAIM then
            ClaimPoleRemoved(event.entity)
        end
        return
    elseif entity_name == "credit-mint" then
        credit_mints[entity.unit_number] = nil
    elseif entity_name == "electric-trading-station" then
        electric_trading_stations[entity.unit_number] = nil
    else -- "buy-box", "sell-box"
        sell_boxes[entity.unit_number] = nil
    end
end

local function HandleEntityDied(event)
    local entity = event.entity
    local entity_name = entity.name
    if entity.name == "credit-mint" then
        credit_mints[entity.unit_number] = nil
    elseif entity_name == "electric-trading-station" then
        electric_trading_stations[entity.unit_number] = nil
    else -- "buy-box", "sell-box"
        sell_boxes[entity.unit_number] = nil
    end
end

-- TODO: OPTIMIZE!
local function check_boxes()
    for _, sell_box in pairs(sell_boxes) do
        local sell_order = orders[sell_box.unit_number]
        if sell_order then -- it seems wrong
            local sell_order_name = sell_order.name
            if sell_order_name then
                local item_count = sell_box.get_item_count(sell_order_name)
                if item_count > 0 then
                    local buy_boxes = sell_box.surface.find_entities_filtered{
                        area = Area(sell_box.position, 3),
                        name = "buy-box"
                    }
                    for _, buy_box in pairs(buy_boxes) do -- it seems overcomplex
                        local buy_order = orders[buy_box.unit_number]
                        if buy_box.force ~= sell_box.force and buy_order and buy_order.name == sell_order_name and buy_order.value >= sell_order.value then
                            Transaction(sell_box, buy_box, buy_order, 1)
                        end
                    end
                end
            end
        end
    end
end

local function check_credit_mints()
    for _, credit_mint in pairs(credit_mints) do
        local entity = credit_mint.entity
        local energy = entity.energy / entity.electric_buffer_size
        local progress = credit_mint.progress + (energy * minting_speed)
        if progress >= 0.09 then
            credit_mint.progress = 0
            AddCredits(entity.force, 1)
        else
            credit_mint.progress = progress
        end
    end
end

function CanTransferItemStack(source_inventory, destination_inventory, item_stack)
    return source_inventory.get_item_count(item_stack.name) >= item_stack.count
        and destination_inventory.can_insert(item_stack)
end

function CanTransferCredits(control, amount)
    local force_credits = credits[control.force.name]
    if force_credits >= amount then
        return true
    end
    return false
end

function TransferCredits(buy_force, sell_force, amount)
    AddCredits(buy_force, -amount)
    AddCredits(sell_force, amount)
end

function AddCredits(force, amount)
    local force_name = force.name
    credits[force_name] = credits[force_name] + amount
    force.item_production_statistics.on_flow("coin", amount)
end

---@return table
function Transaction(source_inventory, destination_inventory, order, count)
    if order and source_inventory and destination_inventory and count > 0 then
        local order_name = order.name
        local item_stack = {name = order_name, count = count}
        local cost = order.value * item_stack.count
        local source_has_items = source_inventory.get_item_count(order_name) > 0 -- TODO: change
        local can_xfer_stack = CanTransferItemStack(source_inventory, destination_inventory, item_stack)
        local can_xfer_credits = CanTransferCredits(destination_inventory, cost)
        if can_xfer_stack and can_xfer_credits then
            source_inventory.remove_item(item_stack)
            destination_inventory.insert(item_stack)
            TransferCredits(destination_inventory.force, source_inventory.force, cost)
            return {success = true}
        else
            return {
                success = false,
                ['no_items_in_source'] = not source_has_items,
                ['no_xfer_stack'] = (not can_xfer_stack) and source_has_items,
                ['no_xfer_credits'] = not can_xfer_credits
            }
        end
    end
    return {success = false}
end

function SellboxGUIOpen(player, entity)
    local player_index = player.index
    if entity and entity.valid and open_order[player_index] == nil then
        local same_force = (entity.force == player.force)
        if entity.name == "sell-box" then
            local unit_number = entity.unit_number
            local frame = player.gui.center.add{type = "frame", direction = "vertical", name = "sell-box-gui", caption = "Sell Box"}
            local row1 = frame.add{type = "flow", direction = "horizontal"}
            local item_picker = row1.add{type = "choose-elem-button", elem_type = "item", name = "sell-box-item"}
            local item_value
            if same_force then
                item_value = row1.add{type = "textfield", text = "1", name = "sell-box-value"}
            else
                item_value = row1.add{type = "label", caption = "price: ", name = "sell-box-value"}
                item_picker.locked = true
            end
            local order = orders[unit_number]
            if not order then
                order = {
                    type = "sell",
                    ['entity'] = entity,
                    value = 1
                }
                orders[unit_number] = order
            end
            item_picker.elem_value = order.name
            open_order[player_index] = order
            if same_force then
                item_value.text = tostring(order.value)
            else
                item_value.caption = "price: " .. tostring(order.value)
                local row2 = frame.add{type = "flow", direction = "horizontal"}
                row2.add{type = "button", caption = "Buy 1", name = "buy-button-1"}
                row2.add{type = "button", caption = "Buy Max", name = "buy-button-all"}
            end
        elseif entity.name == "buy-box" then
            local unit_number = entity.unit_number
            local frame = player.gui.center.add{type = "frame", direction = "vertical", name = "buy-box-gui", caption = "Buy Box"}
            local row1 = frame.add{type = "flow", direction = "horizontal"}
            local item_picker = row1.add{type = "choose-elem-button", elem_type = "item", name = "buy-box-item"}
            local item_value
            if same_force then
                item_value = row1.add{type = "textfield", text = "1", name = "buy-box-value"}
            else
                item_value = row1.add{type = "label", caption = "price: ", name = "sell-box-value"}
                item_picker.locked = true
            end
            local order = orders[unit_number]
            if not order then
                order = {
                    type = "buy",
                    ['entity'] = entity,
                    value = 1
                }
                orders[unit_number] = order
            end
            item_picker.elem_value = order.name
            open_order[player_index] = order
            if same_force then
                item_value.text = tostring(order.value)
            else
                item_value.caption = "price: " .. tostring(order.value)
                local row2 = frame.add{type = "flow", direction = "horizontal"}
                row2.add{type = "button", caption = "Sell 1", name = "sell-button-1"}
                row2.add{type = "button", caption = "Sell Max", name = "sell-button-all"}
            end
        end
    end
end

function SellOrBuyGUIClose(event)
    local player = GetEventPlayer(event)
    local gui = player.gui.center
    if gui['sell-box-gui'] then
        open_order[player.index] = nil
        gui['sell-box-gui'].destroy()
    end
    if gui['buy-box-gui'] then
        open_order[player.index] = nil
        gui['buy-box-gui'].destroy()
    end
end

function GUITextChanged(event)
    local player = GetEventPlayer(event)
    local element = event.element
    if element.parent.name == "ets-gui" then -- TODO: check
        ElectricTradingStationTextChanged(event)
    end

    local element_name = element.name
    if element_name == "buy-box-value" then
        orders[open_order[player.index].entity.unit_number].value = tonumber(element.text) or 1
    elseif element_name == "sell-box-value" then
        orders[open_order[player.index].entity.unit_number].value = tonumber(element.text) or 1
    end
end

function GUIElemChanged(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end

    local element = event.element
    local element_name = element.name
    if element_name == "buy-box-item" then
        orders[open_order[player.index].entity.unit_number].name = element.elem_value
    elseif element_name == "sell-box-item" then
        orders[open_order[player.index].entity.unit_number].name = element.elem_value
    end
end

function GUIClick(event)
    local player = GetEventPlayer(event)
    local element = event.element
    local order = open_order[player.index]
    if order == nil then return end
    local order_name = order.name
    if order_name == nil then return end

    local result = nil
    local element_name = element.name
    if element_name == "buy-button-1" then
        result = Transaction(order.entity, player, order, 1)
    elseif element_name == "buy-button-all" then
        local max_count = order.entity.get_item_count(order_name)
        result = Transaction(order.entity, player, order, max_count)
    elseif element_name == "sell-button-1" then
        result = Transaction(player, order.entity, order, 1)
    elseif element_name == "sell-button-all" then
        local entity = order.entity
        local max_count = entity.get_item_count(order_name)
        local count = game.item_prototypes[order_name].stack_size - max_count
        count = math.min( player.get_item_count(order_name), count )
        result = Transaction(player, entity, order, count)
    end
    if result and not result.success then
        if result.no_items_in_source then
            player.print{"message.none-available"}
        end
        if result.no_xfer_credits then
            player.print{"message.no-credits"}
        end
        if result.no_xfer_stack then
            player.print{"message.no-room"}
        end
    end
end

local function on_runtime_mod_setting_changed(event)
    if event.setting_type ~= "runtime-global" then return end

    local setting_name = event.setting
    if setting_name == "credit-mint-speed" then
        minting_speed = settings.global[setting_name].value
    elseif setting_name == "starting-credits" then
        starting_credits = settings.global[setting_name].value
    end
end

-- function GiveCreditsCommand(event)
--     local player = GetEventPlayer(event)
--     if not event.parameter then return end
--     local params = {}
--     for param in string.gmatch(event.parameter, "%g+") do
--         params[#params+1] = param
--     end
--     local other_force_name = params[1]
--     local amount = tonumber(params[2]) or 0
--     if CanTransferCredits(player, amount) then
--         TransferCredits(player.force, {name = other_force_name}, amount)
--     else
--         player.print{"message.no-credits"}
--     end
-- end

-- function CheatCredits(event)
--     local player = GetEventPlayer(event)
--     if not event.parameter then return end
--     local amount = tonumber(event.parameter) or 0
--     AddCredits(player.force, amount)
-- end

local function on_configuration_changed(event)
    local specializations = global.specializations
    for force_name, force in pairs(game.forces) do
        local recipes = force.recipes
        for spec_name, _force_name in pairs(specializations)  do
            if _force_name == force_name then
                recipes[spec_name].enabled = true
            end
        end
    end


    local mod_changes = event.mod_changes["m-multiplayertrading"]
    if not (mod_changes and mod_changes.old_version) then return end

    CheckGlobalData()
    for _, player in pairs(game.connected_players) do
        AddCreditsGUI(player)
    end

    local version = tonumber(string.gmatch(mod_changes.old_version, "%d+.%d+")())
    if version < 0.8 then
        for _unit_number, data in pairs(electric_trading_stations) do
            local unit_number = data.entity.unit_number
            if _unit_number ~= unit_number then -- TODO: check, is data.entity has weird characters?
                electric_trading_stations[unit_number] = {
                    ['entity'] = electric_trading_stations[_unit_number].entity,
                    sell_price = electric_trading_stations[_unit_number].sell_price,
                    buy_bid = electric_trading_stations[_unit_number].buy_bid
                }
                electric_trading_stations[_unit_number] = nil
            end
        end
    end
    if version < 0.7 then
        -- Check unit numbers
        for _unit_number, entity in pairs(sell_boxes) do
            local unit_number = entity.unit_number
            if _unit_number ~= unit_number then
                sell_boxes[unit_number] = sell_boxes[_unit_number]
                sell_boxes[_unit_number] = nil
            end
        end
        for _unit_number, data in pairs(credit_mints) do
            local unit_number = data.entity.unit_number
            if _unit_number ~= unit_number then -- TODO: check, is data.entity has weird characters?
                credit_mints[unit_number] = {
                    ['entity'] = credit_mints[_unit_number].entity,
                    ['progress'] = credit_mints[_unit_number].progress
                }
                credit_mints[_unit_number] = nil
            end
        end
    end
end


script.on_init(on_init)
script.on_load(on_load)
script.on_configuration_changed(on_configuration_changed)


script.on_event(defines.events.on_built_entity, function(event)
    local player = game.get_player(event.player_index)
    local entity = event.created_entity
    local can_build = true
    if IS_LAND_CLAIM then
        can_build = DestroyInvalidEntities(entity, player)
    end
    if can_build then
        if entity.type == "electric-pole" then
            local force = player.force
            DisallowElectricityTheft(entity, force)
            ClaimPoleBuilt(entity)
        else
            HandleEntityBuild(entity)
        end
    end
end)
script.on_event(defines.events.on_robot_built_entity, function(event)
    local entity = event.created_entity
    local can_build = true
    if IS_LAND_CLAIM then
        can_build = DestroyInvalidEntities(entity)
    end
    if can_build then
        if entity.type == "electric-pole" then
            local force = event.robot.force
            DisallowElectricityTheft(entity, force)
            ClaimPoleBuilt(entity)
        else
            HandleEntityBuild(entity)
        end
    end
end)


script.on_event(
    defines.events.on_player_mined_entity,
    HandleEntityMined,
    {
        {filter = "type", type = "electric-pole", mode = "or"},
        {filter = "name", name = "sell-box", mode = "or"},
        {filter = "name", name = "buy-box", mode = "or"},
        {filter = "name", name = "credit-mint", mode = "or"},
        {filter = "name", name = "electric-trading-station", mode = "or"}
    }
)

do
    local filters = {
        {filter = "name", name = "sell-box", mode = "or"},
        {filter = "name", name = "buy-box", mode = "or"},
        {filter = "name", name = "credit-mint", mode = "or"},
        {filter = "name", name = "electric-trading-station", mode = "or"}
    }
    script.on_event(
        defines.events.on_entity_died,
        HandleEntityDied,
        filters
    )
    script.on_event(
        defines.events.on_robot_mined_entity,
        HandleEntityDied,
        filters
    )
    script.on_event(
        defines.events.script_raised_destroy,
        HandleEntityDied,
        filters
    )
end

do
    local function on_player_created(event)
        game.get_player(event.player_index).insert(START_ITEMS)
    end
    script.on_event(defines.events.on_player_created, function(event)
        pcall(on_player_created, event)
    end)
end

do
    local function on_player_joined(event)
        AddCreditsGUI(game.get_player(event.player_index))
    end
    script.on_event(defines.events.on_player_joined_game, function(event)
        pcall(on_player_joined, event)
    end)
end

do
    local function on_player_left_game(event)
        game.get_player(event.player_index).gui.left.credits.destroy()
    end
    script.on_event(defines.events.on_player_left_game, function(event)
        pcall(on_player_left_game, event)
    end)
end


script.on_event("sellbox-gui-open", function(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then return end
    local entity = player.selected
    if not (entity and entity.valid) then return end

    local entity_name = entity.name
    if entity and (entity_name == "sell-box" or entity_name == "buy-box") then
        SellOrBuyGUIClose(event)
        SellboxGUIOpen(player, entity)
    elseif entity and entity_name == "electric-trading-station" then
        ElectricTradingStationGUIClose(event)
        ElectricTradingStationGUIOpen(event)
    else
        SellOrBuyGUIClose(event)
        ElectricTradingStationGUIClose(event)
    end
end)

script.on_event("sellbox-gui-close", function(event)
    SellOrBuyGUIClose(event)
    ElectricTradingStationGUIClose(event)
end)

if settings.startup['specializations'].value then
    script.on_event("specialization-gui", function(event)
        pcall(SpecializationGUI, game.get_player(event.player_index))
    end)
end

script.on_event(defines.events.on_gui_text_changed, GUITextChanged)
script.on_event(defines.events.on_gui_elem_changed, GUIElemChanged)
script.on_event(defines.events.on_gui_click, GUIClick)
script.on_event(defines.events.on_force_created, ForceCreated)
script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)
if settings.startup['early-bird-research'].value then
    script.on_event(defines.events.on_research_finished, ResearchCompleted)
end
-- commands.add_command("give-credits", {"command-help.give-credits"}, GiveCreditsCommand) -- TOO BUGGY

remote.add_interface("multiplayer-trading", {
    ["add-money"] = function(force, amount)
        AddCredits(force, amount)
    end,
    ["get-money"] = function(force)
        return credits[force.name]
    end
})

script.on_nth_tick(60, function()
    UpdateElectricTradingStations(electric_trading_stations)
end)

script.on_nth_tick(15, check_boxes)
script.on_nth_tick(900, check_credit_mints)

-- TODO: optimize
script.on_nth_tick(120, function()
    for _, player in pairs(game.connected_players) do
        player.gui.top['credits'].caption = floor(credits[player.force.name]) .. '$'
    end
end)

if settings.startup['specializations'].value == true then
    script.on_nth_tick(3600, UpdateSpecializations)
end

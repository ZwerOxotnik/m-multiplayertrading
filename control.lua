--[[
    Multiplayer Trading by Luke Perkin.
    Some concepts taken from Teamwork mod (credit to DragoNFly1) and Diplomacy mod (credit to ZwerOxotnik).
]]
require "specializations-data"
require "systems/land-claim"
require "systems/specializations"
require "systems/electric-trading-station"

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

function Init()
    global.sell_boxes = {}
    global.orders = {}
    global.credits = {}
    global.credit_mints = {}
    global.specializations = {}
    global.output_stat = {}
    global.early_bird_tech = {}
    global.open_order = {}
    global.electric_trading_stations = {}
    for _, force in pairs(game.forces) do
        ForceCreated({force=force})
    end
    for player_index, player in ipairs(game.players) do
        PlayerCreated({player_index=player_index})
    end
end

function PlayerCreated(event)
    local player = GetEventPlayer(event)
    player.insert{name = "small-electric-pole", count = 10}
    AddCreditsGUI(player)
end

function ForceCreated(event)
    local force = event.force
    if global.credits[force.name] == nil then
        global.credits[force.name] = settings.global['starting-credits'].value
    end
    for name, technology in pairs(force.technologies) do
        if string.find(name, "-mpt-") ~= nil then
            technology.enabled = false
        end
    end
end

function ModConfigurationChanged(event)
    if global.output_stat == nil then
        global.output_stat = {}
    end
    if global.electric_trading_stations == nil then
        global.electric_trading_stations = {}
    end
    for _, player in pairs(game.players) do
        AddCreditsGUI(player)
    end
end

function AddCreditsGUI(player)
    if player.gui.left['credits'] then
        player.gui.left['credits'].destroy()
    end
    if not player.gui.top['credits'] then
        player.gui.top.add{type = "label", name = "credits", caption = "Credits", style = "caption_label"}
    end
end

function ResearchCompleted(event)
    local research = event.research
    local tech_cost_multiplier = settings.startup['early-bird-multiplier'].value
    local base_tech_name = string.gsub(research.name, "%-mpt%-[0-9]+", "")
    if research.force.technologies[base_tech_name .. "-mpt-1"] == nil then
        return
    end
    global.early_bird_tech[research.force.name .. "/" .. base_tech_name] = true
    for _, force in pairs(game.forces) do
        local force_tech_state_id = force.name .. "/" .. base_tech_name
        if not force.technologies[research.name].researched then
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
                    if not global.early_bird_tech[force_tech_state_id] then
                        force.technologies[next_tech_name].enabled = true
                    end
                    force.technologies[research.name].enabled = false
                end
            else
                -- Another force has researched this tech for the 1st time.
                local next_tech_name = research.name .. "-mpt-1"
                if progress then
                    progress = progress / tech_cost_multiplier
                    force.set_saved_technology_progress(next_tech_name, progress)
                end
                force.technologies[next_tech_name].enabled = true
                force.technologies[research.name].enabled = false
            end
        end
    end
end

function PrintAll(text)
    for i, player in pairs(game.players) do
        player.print(text)
    end
end

function GetEventPlayer(event)
    if event.player_index then
        return game.players[event.player_index]
    else
        return nil
    end
end

function GetEventForce(event)
    if event.player_index then
        return game.players[event.player_index].force
    elseif event.robot then
        return event.robot.force
    else
        return nil
    end
end

function Area(position, radius)
    return {
        {position.x - radius, position.y - radius},
        {position.x + radius, position.y + radius}
    }
end

function HandleEntityBuild(event)
    local entity = event.created_entity
    if not entity.valid then return end
    if entity.name == "sell-box" then
        entity.operable = false
        table.insert(global.sell_boxes, entity)
    end
    if entity.name == "buy-box" then
        entity.operable = false
        table.insert(global.sell_boxes, entity)
    end
    if entity.name == "credit-mint" then
        table.insert(global.credit_mints, {
            ['entity'] = entity,
            ['progress'] = 0
        })
    end
    if settings.startup['land-claim'].value and entity.type == "electric-pole" then
        ClaimPoleBuilt(entity)
    end
    if entity.name == "electric-trading-station" then
        ElectricTradingStationBuilt(entity)
    end
end

function HandleEntityDied(event)
    local entity = event.entity
    if settings.startup['land-claim'].value and entity.type == "electric-pole" then
        ClaimPoleRemoved(entity)
    end
end

function OnTick(event)
    for i, player in pairs(game.players) do
        player.gui.top['credits'].caption = "Credits: " .. math.floor(global.credits[player.force.name])
    end
    for i=#global.sell_boxes, 1, -1 do
        if not global.sell_boxes[i].valid then
            table.remove( global.sell_boxes, i )
        end
    end
    for i, sell_box in ipairs(global.sell_boxes) do
        local sell_order = global.orders[sell_box.unit_number]
        if sell_order and sell_order.name and sell_box.get_item_count(sell_order.name) > 0 then
            buy_boxes = sell_box.surface.find_entities_filtered{
                area = Area(sell_box.position, 3),
                name = "buy-box"
            }
            local item_count = sell_box.get_item_count(sell_order.name)
            local valid_buy_boxes = {}
            for i, buy_box in ipairs(buy_boxes) do
                local buy_order = global.orders[buy_box.unit_number]
                if buy_box.force ~= sell_box.force and buy_order and buy_order.name == sell_order.name and buy_order.value >= sell_order.value then
                    table.insert(valid_buy_boxes, buy_box)
                end
            end
            if #valid_buy_boxes > 0 then
                for i, buy_box in ipairs(valid_buy_boxes) do
                    local buy_order = global.orders[buy_box.unit_number]
                    local result = Transaction(sell_box, buy_box, buy_order, 1)
                end
            end
        end
    end
    for i=#global.credit_mints, 1, -1 do
        if not global.credit_mints[i].entity.valid then
            table.remove( global.credit_mints, i )
        end
    end
    local minting_speed = settings.global['credit-mint-speed'].value
    for i, credit_mint in ipairs(global.credit_mints) do
        local energy = credit_mint.entity.energy / credit_mint.entity.electric_buffer_size
        credit_mint.progress = credit_mint.progress + (energy * minting_speed)
        if credit_mint.progress >= 1 then
            credit_mint.progress = 0
            AddCredits(credit_mint.entity.force, 1)
        end
    end
    if event.tick % 60 == 0 then
        for unit_number, electric_trading_station in pairs(global.electric_trading_stations) do
            if not electric_trading_station.entity.valid then
                global.electric_trading_stations[unit_number] = nil
            end
        end
        UpdateElectricTradingStations(global.electric_trading_stations)
    end
    if settings.startup['specializations'].value and event.tick % (60*60) == 0 then
        UpdateSpecializations(global.specializations, SPECIALIZATIONS)
    end
end

function CanTransferItemStack(source_inventory, destination_inventory, item_stack)
    return source_inventory.get_item_count(item_stack.name) >= item_stack.count
        and destination_inventory.can_insert(item_stack)
end

function CanTransferCredits(control, amount)
    local credits = global.credits[control.force.name]
    if credits >= amount then
        return true
    end
    return false
end

function TransferCredits(buy_force, sell_force, amount)
    AddCredits(buy_force, amount * -1)
    AddCredits(sell_force, amount)
end

function AddCredits(force, amount)
    global.credits[force.name] = global.credits[force.name] + amount
    force.item_production_statistics.on_flow("coin", amount)
end

function Transaction(source_inventory, destination_inventory, order, count)
    if order and source_inventory and destination_inventory and count > 0 then
        local item_stack = {name = order.name, count = count}
        local cost = order.value * item_stack.count
        local source_has_items = source_inventory.get_item_count(order.name) > 0
        local can_xfer_stack = CanTransferItemStack(source_inventory, destination_inventory, item_stack)
        local can_xfer_credits = CanTransferCredits(destination_inventory, cost)
        if can_xfer_stack and can_xfer_credits then
            local items_removed = source_inventory.remove_item(item_stack)
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

function SellboxGUIOpen(event)
    local player = GetEventPlayer(event)
    local entity = player.selected
    if entity and entity.valid and global.open_order[player.index] == nil then
        local same_force = (entity.force == player.force)
        if entity.name == "sell-box" then
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
            local order = global.orders[entity.unit_number]
            if not order then
                order = {
                    type = "sell",
                    ['entity'] = entity,
                    value = 1
                }
                global.orders[entity.unit_number] = order
            end
            if order then
                item_picker.elem_value = order.name
                global.open_order[player.index] = order
                if same_force then
                    item_value.text = tostring(order.value)
                else
                    item_value.caption = "price: " .. tostring(order.value)
                    local row2 = frame.add{type = "flow", direction = "horizontal"}
                    row2.add{type = "button", caption = "Buy 1", name = "buy-button-1"}
                    row2.add{type = "button", caption = "Buy Max", name = "buy-button-all"}
                end
            end
        elseif entity.name == "buy-box" then
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
            local order = global.orders[entity.unit_number]
            if not order then
                order = {
                    type = "buy",
                    ['entity'] = entity,
                    value = 1
                }
                global.orders[entity.unit_number] = order
            end
            if order then
                item_picker.elem_value = order.name
                global.open_order[player.index] = order
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
end

function SellOrBuyGUIClose(event)
    local player = GetEventPlayer(event)
    local gui = player.gui.center
    if gui['sell-box-gui'] then
        global.open_order[player.index] = nil
        gui['sell-box-gui'].destroy()
    end
    if gui['buy-box-gui'] then
        global.open_order[player.index] = nil
        gui['buy-box-gui'].destroy()
    end
end

function GUITextChanged(event)
    local player = GetEventPlayer(event)
    local textfield = event.element
    if textfield.parent.name == "ets-gui" then
        ElectricTradingStationTextChanged(event)
    end
    if textfield.name == "buy-box-value" then
        local buy_box = global.open_order[player.index].entity
        local order = global.orders[buy_box.unit_number]
        order.value = tonumber(textfield.text) or 1
        global.orders[buy_box.unit_number] = order
    end
    if textfield.name == "sell-box-value" then
        local sell_box = global.open_order[player.index].entity
        local order = global.orders[sell_box.unit_number]
        order.value = tonumber(textfield.text) or 1
        global.orders[sell_box.unit_number] = order
    end
end

function GUIElemChanged(event)
    local player = GetEventPlayer(event)
    local elem_picker = event.element
    if elem_picker.name == "buy-box-item" then
        local buy_box = global.open_order[player.index].entity
        local order = global.orders[buy_box.unit_number]
        order.name = elem_picker.elem_value
        global.orders[buy_box.unit_number] = order
    end
    if elem_picker.name == "sell-box-item" then
        local sell_box = global.open_order[player.index].entity
        local order = global.orders[sell_box.unit_number]
        order.name = elem_picker.elem_value
        global.orders[sell_box.unit_number] = order
    end
end

function GUIClick(event)
    local player = GetEventPlayer(event)
    local elem = event.element
    local order = global.open_order[player.index]
    if order ~= nil and order.name ~= nil then
        local result = nil
        if elem.name == "buy-button-1" then
            result = Transaction(order.entity, player, order, 1)
        elseif elem.name == "buy-button-all" then
            local max_count = order.entity.get_item_count(order.name)
            result = Transaction(order.entity, player, order, max_count)
        elseif elem.name == "sell-button-1" then
            result = Transaction(player, order.entity, order, 1)
        elseif elem.name == "sell-button-all" then
            local max_count = order.entity.get_item_count(order.name)
            local count = game.item_prototypes[order.name].stack_size - max_count
            count = math.min( player.get_item_count(order.name), count )
            result = Transaction(player, order.entity, order, count)
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
end

function GiveCreditsCommand(event)
    local player = GetEventPlayer(event)
    if not event.parameter then return end
    local params = {}
    for param in string.gmatch(event.parameter, "%g+") do 
        table.insert(params, param)
    end
    local other_force_name = params[1]
    local amount = tonumber(params[2]) or 0
    if CanTransferCredits(player, amount) then
        TransferCredits(player.force, {name = other_force_name}, amount)
    else
        player.print{"message.no-credits"}
    end
end

function CheatCredits(event)
    local player = GetEventPlayer(event)
    if not event.parameter then return end
    local amount = tonumber(event.parameter) or 0
    AddCredits(player.force, amount)
end

script.on_init(Init)
script.on_configuration_changed(ModConfigurationChanged)
script.on_event(defines.events.on_tick, OnTick)
script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, function(event)
    local can_build = true
    if settings.startup['land-claim'].value then
        can_build = DestroyInvalidEntities(event)
    end
    if can_build then
        DisallowElectricityTheft(event)
        HandleEntityBuild(event)
    end
end)
script.on_event({defines.events.on_entity_died, defines.events.on_player_mined_entity}, HandleEntityDied)
script.on_event(defines.events.on_player_created, PlayerCreated)
script.on_event("sellbox-gui-open", function(event)
    local player = GetEventPlayer(event)
    local entity = player.selected
    if entity and (entity.name == "sell-box" or entity.name == "buy-box") then
        SellOrBuyGUIClose(event)
        SellboxGUIOpen(event)
    elseif entity and entity.name == "electric-trading-station" then
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
    script.on_event("specialization-gui", SpecializationGUI)
end
script.on_event(defines.events.on_gui_text_changed, GUITextChanged)
script.on_event(defines.events.on_gui_elem_changed, GUIElemChanged)
script.on_event(defines.events.on_gui_click, GUIClick)
script.on_event(defines.events.on_force_created, ForceCreated)
if settings.startup['early-bird-research'].value then
    script.on_event(defines.events.on_research_finished, ResearchCompleted)
end
commands.add_command("give-credits", {"command-help.give-credits"}, GiveCreditsCommand)

remote.add_interface("multiplayer-trading", {
    ["add-money"] = function(force, amount)
        AddCredits(force, amount)
    end,
    ["get-money"] = function(force)
        return global.credits[force.name]
    end
})
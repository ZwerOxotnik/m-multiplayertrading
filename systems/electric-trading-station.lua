function ElectricTradingStationBuilt(entity)
    global.electric_trading_stations[entity.unit_number] = {
        ['entity'] = entity,
        sell_price = 1,
        buy_bid = 1
    }
end

function UpdateElectricTradingStations(stations)
    local visited = {}
    for unit_number, electric_trading_station in pairs(stations) do
        if electric_trading_station.entity.valid then
            table.insert(visited, electric_trading_station.entity)
            local source = electric_trading_station.entity
            local adjacent = source.surface.find_entities_filtered{
                area = Area(source.position, 3),
                name = "electric-trading-station"
            }
            local highest_bidder = nil
            local highest_bid = 0
            for _, dest in pairs(adjacent) do
                local dest_bid = global.electric_trading_stations[dest.unit_number].buy_bid
                local dest_full = (dest.energy >= 6000000)
                if dest.force ~= source.force and dest_bid > highest_bid and not dest_full then
                    highest_bid = dest_bid
                    highest_bidder = dest
                end
            end
            if highest_bidder then
                BalanceEnergy(source, highest_bidder)
            end
        end
    end
end

function BalanceEnergy(source, destination)
    local energy_sum = source.energy + destination.energy
    local balanced_energy = energy_sum / 2.0
    local source_diff = balanced_energy - source.energy
    local dest_diff = balanced_energy - destination.energy

    local source_price = global.electric_trading_stations[source.unit_number].sell_price
    local dest_price = global.electric_trading_stations[destination.unit_number].sell_price
    local source_bid = global.electric_trading_stations[source.unit_number].buy_bid
    local dest_bid = global.electric_trading_stations[destination.unit_number].buy_bid

    local source_cost = source_diff * 0.000001
    local dest_cost = dest_diff * 0.000001

    source.power_usage = 0
    source.power_production = 0
    destination.power_usage = 0
    destination.power_production = 0

    if (source_cost > 0 and source_bid < dest_price) then
        -- No trade if source is buying but bid is lower than dest's price.
        return
    else
        source_cost = source_cost * source_bid
        dest_cost = dest_cost * source_bid
    end
    if (dest_cost > 0 and dest_bid < source_price) then
        -- No trade if dest is buying but bid is lower than source's price.
        return
    else
        source_cost = source_cost * dest_bid
        dest_cost = dest_cost * dest_bid
    end

    if (source_cost > 0 and not CanTransferCredits(source, source_cost)) then
        local signal = {type="item", name="accumulator"}
        local message = "Cannot afford to buy power. " .. math.floor(source_cost) .. " short."
        for _, player in pairs(source.force.players) do
            player.add_custom_alert(source, signal, message, true)
        end
        return
    end

    if (dest_cost > 0 and not CanTransferCredits(destination, dest_cost)) then
        local signal = {type="item", name="accumulator"}
        local message = "Cannot afford to buy power. " .. math.floor(dest_cost) .. " short."
        for _, player in pairs(destination.force.players) do
            player.add_custom_alert(destination, signal, message, true)
        end
        return
    end

    -- Trade succesful
    AddCredits(source.force, source_cost * -1)
    AddCredits(destination.force, dest_cost * -1)
    if source_diff < 0 then
        source.power_usage = math.abs(source_diff) / 60.0
        source.power_production = 0
    elseif source_diff > 0 then
        source.power_usage = 0
        source.power_production = math.abs(source_diff) / 60.0
    else
        source.power_usage = 0
        source.power_production = 0
    end
    
    if dest_diff < 0 then
        destination.power_usage = math.abs(source_diff) / 60.0
        destination.power_production = 0
    elseif dest_diff > 0 then
        destination.power_usage = 0
        destination.power_production = math.abs(source_diff) / 60.0
    else
        destination.power_usage = 0
        destination.power_production = 0
    end
end

function DisallowElectricityTheft(event)
    local entity = event.created_entity
    local instigatingForce = GetEventForce(event)
    if instigatingForce and entity.type == "electric-pole" then
        for _, neighbour in pairs(entity.neighbours["copper"]) do
            if instigatingForce ~= neighbour.force and not instigatingForce.get_friend(neighbour.force) then
                entity.disconnect_neighbour(neighbour)
            end
        end
    end
end

function ElectricTradingStationGUIOpen(event)
    local player = GetEventPlayer(event)
    if player.gui.center['ets-gui'] then return end
    local entity = player.selected
    local frame = player.gui.center.add{type = "frame", direction = "vertical", name = "ets-gui", caption = "Electric Trading Station"}
    frame.add{type = "label", caption = "Sell Price per MW"}
    if entity.force == player.force then
        local sell = frame.add{type = "textfield", name = "sell"}
        sell.text = tostring(global.electric_trading_stations[entity.unit_number].sell_price)
    else
        local sell = frame.add{type = "label", name = "sell"}
        sell.caption = tostring(global.electric_trading_stations[entity.unit_number].sell_price)
    end
    frame.add{type = "label", caption = "Buy bid per MW"}
    if entity.force == player.force then
        local buy = frame.add{type = "textfield", name = "buy"}
        buy.text = tostring(global.electric_trading_stations[entity.unit_number].buy_bid)
    else
        local buy = frame.add{type = "label", name = "buy"}
        buy.caption = tostring(global.electric_trading_stations[entity.unit_number].buy_bid)
    end
    if global.open_electric_trading_station == nil then
        global.open_electric_trading_station = {}
    end
    global.open_electric_trading_station[player.index] = entity.unit_number
end

function ElectricTradingStationGUIClose(event)
    local player = GetEventPlayer(event)
    if player.gui.center['ets-gui'] then
        player.gui.center['ets-gui'].destroy()
    end
end

function ElectricTradingStationTextChanged(event)
    local player = GetEventPlayer(event)
    local ets_unit_number = global.open_electric_trading_station[player.index]
    if ets_unit_number == nil then return end
    local textfield = event.element
    if textfield.name == "sell" then
        global.electric_trading_stations[ets_unit_number].sell_price = math.max(tonumber(textfield.text) or 1, 1)
    end
    if textfield.name == "buy" then
        global.electric_trading_stations[ets_unit_number].buy_bid = math.max(tonumber(textfield.text) or 1, 0)
    end
end
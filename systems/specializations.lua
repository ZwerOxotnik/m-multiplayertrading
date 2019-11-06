local SPECIALIZATIONS = require("specializations-data")

function UpdateSpecializations(SPEC_DATA)
    local specializations = global.specializations
    for _, player in pairs(game.players) do -- TODO: change to game.connected_players (don't forget about other events)
        if player.gui.left['specialization-gui'] then
            player.gui.left['specialization-gui'].destroy()
            SpecializationGUI({player_index = player.index})
        end
    end

    for force_name, force in pairs(game.forces) do
        for _, spec in pairs(SPECIALIZATIONS) do
            if specializations[spec.name] == nil then
                local current_sum = GetCurrentStatSumForSpecialization(spec, force)
                local last_stat = GetLastStatForSpecialization(spec, force)
                local production_rate = (current_sum - last_stat.sum)
                last_stat.sum = current_sum
                last_stat.rate = production_rate
                if production_rate >= spec.requirement.production then
                    specializations[spec.name] = force_name
                    force.recipes[spec.name].enabled = true
                    force.print({
                        "message.specialization-unlock", 
                        {GetSpecializationItemNameLocale(spec)}
                    })
                    PrintAll({
                        "message.specialization-notice", 
                        force_name,
                        {GetSpecializationItemNameLocale(spec)}
                    })
                end
            end
        end
    end
end

function SpecializationGUI( event )
    local player = GetEventPlayer(event)
    if player.gui.left['specialization-gui'] then
        player.gui.left['specialization-gui'].destroy()
    else
        local frame = player.gui.left.add{type = "frame", name = "specialization-gui", caption = "Specializations"}
        local flow = frame.add{type = "flow", direction = "vertical"}
        for _, spec in pairs(SPECIALIZATIONS) do
            local row = flow.add{type = "flow", direction = "horizontal"}
            local force_name = global.specializations[spec.name]
            
            local sprite = GetSpecializationItemSprite(spec)
            local tooltip = GetSpecializationItemNameLocale(spec)
            row.add{type = "sprite", sprite = sprite, tooltip = {tooltip}}

            local style = "bold_label"
            if force_name == nil then
                style = "bold_label"
                local requirement = row.add{type = "flow", direction = "vertical"}
                local caption = "Available (produce " .. tostring(spec.requirement.production) .. "/min to unlock)"
                requirement.add{type = "label", caption = caption, style = style}
                local stat = GetLastStatForSpecialization(spec, player.force)
                local progress = stat.rate / spec.requirement.production
                requirement.add{type = "progressbar", name = "progress", value = progress}
            else
                if force_name == player.force.name then
                    style = "bold_green_label"
                else
                    style = "bold_red_label"
                end
                row.add{type = "label", caption = force_name, style = style}
            end
        end
    end
end

function GetCurrentStatSumForSpecialization(spec, force)
    local output_sum = 0
    if spec.requirement.fluid then
        output_sum = force.fluid_production_statistics.get_input_count(spec.requirement.name)
    else
        output_sum = force.item_production_statistics.get_input_count(spec.requirement.name)
    end
    return output_sum
end

function GetLastStatForSpecialization(spec, force)
    local id = force.name .. "/" .. spec.name
    if global.output_stat[id] == nil then
        global.output_stat[id] = {
            sum = 0,
            rate = 0
        }
    end
    return global.output_stat[id]
end

function GetSpecializationItemNameLocale(spec)
    local locale = ""
    if spec.requirement.fluid then
        locale = "fluid-name." .. spec.requirement.name
    else
        locale = "item-name." .. spec.requirement.name
    end
    return locale
end

function GetSpecializationItemSprite(spec)
    local sprite = ""
    if spec.requirement.fluid then
        sprite = "fluid/"..spec.requirement.name
    else
        sprite = "item/"..spec.requirement.name
    end
    return sprite
end
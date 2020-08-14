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

if settings.startup['land-claim'].value then
    local poles = {"small-electric-pole", "medium-electric-pole", "big-electric-pole", "substation"}
    for i, pole_name in ipairs(poles) do
        local prototype = data.raw['electric-pole'][pole_name]
        if prototype then
            if prototype.supply_area_distance < 20 then
                prototype.supply_area_distance = prototype.supply_area_distance * 2
            end
            if prototype.maximum_wire_distance < 20 then
                prototype.maximum_wire_distance = prototype.maximum_wire_distance * 2
            end
        end
    end
end

if settings.startup['early-bird-research'].value then
    -- Find non-upgrade tech where no other tech uses it as a prerequisite.
    local function is_tech_valid_for_early_bird( tech )
        for other_name, other_technology in pairs(data.raw.technology) do
            if other_technology.prerequisites then
                for _, prerequisite in ipairs(other_technology.prerequisites) do
                    if prerequisite == tech.name then
                        return false
                    end
                end
            end
        end
        return true
    end
    local valid_tech = {}
    for tech_name, technology in pairs(data.raw.technology) do
        if not technology.upgrade and technology.unit.count and is_tech_valid_for_early_bird(technology) then
            table.insert(valid_tech, tech_name)
        end
    end
    local earlybird_tech = {}
    for i, tech_name in ipairs(valid_tech) do
        local technology = data.raw.technology[tech_name]
        for i=1, 4 do
            local expensive_tech = copy(technology)
            local multiplier = math.pow(settings.startup['early-bird-multiplier'].value, i)
            expensive_tech.unit.count = expensive_tech.unit.count * multiplier
            expensive_tech.name = tech_name .. "-mpt-" .. tostring(i)
            expensive_tech.localised_name =  {"technology-name.early-bird", {"technology-name." .. tech_name}, tostring(multiplier)}
            expensive_tech.localised_description = {"technology-description." .. tech_name}
            expensive_tech.enabled = false
            table.insert(earlybird_tech, expensive_tech)
        end
    end
    data:extend(earlybird_tech)
end
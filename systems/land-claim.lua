function GetClaimedLand(entity)
    for _, poleName in pairs(POLES) do
        local prototype = game.entity_prototypes[poleName]
        local radius = prototype.supply_area_distance
        if entity.type == "electric-pole" then
            radius = radius + entity.prototype.supply_area_distance
        end
        local claimPoles = entity.surface.find_entities_filtered{
            area = Area(entity.position, radius),
            name = poleName
        }
        for _, pole in pairs(claimPoles) do
            if pole.force ~= entity.force then
                return pole.force
            end
        end
        if #claimPoles > 0 then
            return claimPoles[1].force
        end
    end
    return "no-mans-land"
end

function GetClaimCost(entity)
    if entity.type == "electric-pole" then
        local supply_area = entity.prototype.supply_area_distance
        local cost = supply_area * supply_area * settings.global['land-claim-cost'].value
        return {cost = cost, can_afford = CanTransferCredits(entity, cost)}
    end
    return {cost = false}
end

function ClaimPoleBuilt(entity)
    local claim = GetClaimCost(entity)
    if claim.cost then
        global.credits[entity.force.name] = global.credits[entity.force.name] - claim.cost
    end
end

function ClaimPoleRemoved(entity)
    local claim = GetClaimCost(entity)
    if claim.cost then
        AddCredits(entity.force, claim.cost * -1)
    end
end

function DestroyInvalidEntities(event)
    local entity = event.created_entity
    local player = GetEventPlayer(event)
    local instigatingForce = GetEventForce(event)
    if instigatingForce then
        -- Check if land is claimed.
        local claimedLand = GetClaimedLand(entity)
        local claimCost = GetClaimCost(entity)
        local noBuildDueToEnemyLand = (claimedLand ~= "no-mans-land" 
                                        and claimedLand ~= instigatingForce 
                                        and not claimedLand.get_friend(instigatingForce)
                                        and not PLACE_ENEMY_TERRITORY_ITEMS[entity.name])
        local noBuildDueToNoMansLand = (claimedLand == "no-mans-land" and not PLACE_NOMANSLAND_ITEMS[entity.name])
        local noBuildDueToExpense = (claimCost.cost and not claimCost.can_afford)
        if noBuildDueToExpense then
            player.print{"message.cannot-claim"}
        end
        if player and noBuildDueToEnemyLand then
            player.print{"message.no-build-opponent-land"}
        end
        if player and noBuildDueToNoMansLand then
            player.print{"message.no-mans-land-restriction"}
        end
        -- Don't allow build if invalid build spot.
        if noBuildDueToEnemyLand or noBuildDueToNoMansLand or noBuildDueToExpense then
            if player then
                player.mine_entity(entity, true)
            else
                entity.destroy()
            end
            return false
        end
        return true
    end
end
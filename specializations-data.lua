return {
    {
        name = "iron-gear-wheel-specialization",
        requirement = {
            name = "iron-gear-wheel",
            production = 500
        },
        recipe = {
            ingredients = {{"iron-plate", 1}},
            energy_required = 0.5,
            disables = {"iron-gear-wheel"},
            result = "iron-gear-wheel"
        }
    },
    {
        name = "electronic-circuit-specialization",
        requirement = {
            name = "electronic-circuit",
            production = 350
        },
        recipe = {
            ingredients = {{"copper-cable", 1}, {"iron-plate", 1}},
            energy_required = 0.4,
            result = "electronic-circuit"
        }
    },
    {
        name = "advanced-circuit-specialization",
        requirement = {
            name = "advanced-circuit",
            production = 200
        },
        recipe = {
            ingredients = {{"copper-cable", 2}, {"electronic-circuit", 1}, {"plastic-bar", 1}},
            energy_required = 5,
            result = "advanced-circuit"
        }
    },
    {
        name = "processing-unit-specialization",
        requirement = {
            name = "processing-unit",
            production = 65
        },
        recipe = {
            category = "crafting-with-fluid",
            ingredients = {{"advanced-circuit", 1}, {"electronic-circuit", 15}, {type = "fluid", name = "sulfuric-acid", amount = 3}},
            energy_required = 9,
            result = "processing-unit",
        }
    },
    {
        name = "piercing-rounds-magazine-specialization",
        requirement = {
            name = "piercing-rounds-magazine",
            production = 80
        },
        recipe = {
            ingredients = {{"copper-plate", 3}, {"firearm-magazine", 1}, {"steel-plate", 1}},
            energy_required = 2,
            result = "piercing-rounds-magazine",
        }
    },
    {
        name = "uranium-rounds-magazine-specialization",
        requirement = {
            name = "uranium-rounds-magazine",
            production = 40
        },
        recipe = {
            ingredients = {{"piercing-rounds-magazine", 1}, {"uranium-238", 1}},
            energy_required = 7,
            result = "uranium-rounds-magazine",
        }
    },
    {
        name = "explosives-specialization",
        requirement = {
            name = "explosives",
            production = 250
        },
        recipe = {
            category = "crafting-with-fluid",
            ingredients = {{"coal", 1}, {"sulfur", 1}, {type="fluid", name="water", amount=5}},
            energy_required = 4,
            results = {{"explosives", 3}},
        }
    },
    {
        name = "speed-module-specialization",
        requirement = {
            name = "speed-module",
            production = 20
        },
        recipe = {
            ingredients = {{"electronic-circuit", 3}, {"advanced-circuit", 3}},
            energy_required = 13,
            result = "speed-module",
        }
    },
    {
        name = "effectivity-module-specialization",
        requirement = {
            name = "effectivity-module",
            production = 20
        },
        recipe = {
            ingredients = {{"electronic-circuit", 3}, {"advanced-circuit", 3}},
            energy_required = 13,
            result = "effectivity-module",
        }
    },
    {
        name = "productivity-module-specialization",
        requirement = {
            name = "productivity-module",
            production = 20
        },
        recipe = {
            ingredients = {{"electronic-circuit", 3}, {"advanced-circuit", 3}},
            energy_required = 13,
            result = "productivity-module",
        }
    },
    {
        name = "oil-specialization",
        disable_override = "advanced-oil-processing",
        requirement = {
            fluid = true,
            name = "petroleum-gas",
            production = 4000
        },
        recipe = {
            ingredients =
            {
                {type="fluid", name="water", amount=50},
                {type="fluid", name="crude-oil", amount=100}
            },
            energy_required = 4,
            icon = "__base__/graphics/icons/fluid/advanced-oil-processing.png",
            subgroup = "fluid-recipes",
            category = "oil-processing",
            results =
            {
                {type="fluid", name="heavy-oil", amount=20},
                {type="fluid", name="light-oil", amount=55},
                {type="fluid", name="petroleum-gas", amount=70}
            },
        }
    },
    {
        name = "plastic-bar-specialization",
        requirement = {
            name = "plastic-bar",
            production = 450
        },
        recipe = {
            category = "crafting-with-fluid",
            ingredients = {{"coal", 1}, {type="fluid", name="petroleum-gas", amount=15}},
            energy_required = 0.75,
            results = {{"plastic-bar", 2}},
        }
    },
    {
        name = "solar-panel-specialization",
        requirement = {
            name = "solar-panel",
            production = 150
        },
        recipe = {
            ingredients = {{"copper-plate", 4}, {"steel-plate", 4}, {"electronic-circuit", 10}},
            energy_required = 8,
            result = "solar-panel"
        }
    },
}
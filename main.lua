log.info("Successfully loaded " .. _ENV["!guid"] .. ".")
params = {}
mods["RoRRModdingToolkit-RoRR_Modding_Toolkit"].auto(true)
mods.on_all_mods_loaded(function()
    for k, v in pairs(mods) do
        if type(v) == "table" and v.tomlfuncs then
            Toml = v
        end
    end
    params = {
        ChatKey = 13,
        ConsoleKey = 192,
        TooltipFix = true,
        ArtiSecondaryFix = true,
        MagmaWormHitBoxFix = true,
        UnlockZoom = true
    }
    params = Toml.config_update(_ENV["!guid"], params) -- Load Save
end)

local Chat
local Hud
local BufferedX2 = nil
local player = nil
local WormAttackY = {}
local TalkBuffer = false
local console = nil

local ScaleRatio = 1
Initialize(function()
    console = Instance.find(gm.constants.oConsole)
    local artiX2 = Skill.find("ror-artiX2")
    local artiX = Skill.find("ror-artiX")
    Chat = Instance.find(gm.constants.oInit)

    Callback.add("onStageStart", "SmallFixes-onStageStart", function()
        WormAttackY = {}
    end)
    Callback.add("onPlayerInit", "SmallFixes-onPlayerInit", function(self)
        player = Player.get_client()
    end)

    ScaleRatio = 3840 / gm.window_get_width()
    gm.post_script_hook(gm.constants.ui_resolution_update, function(self, other, result, args)
        ScaleRatio = 3840 / gm.window_get_width()
    end)

    gm.pre_script_hook(gm.constants.prefs_set_zoom_scale, function(self, other, result, args)
        if params.UnlockZoom then
            Global.current_zoom_scale = args[1].value / ScaleRatio
            args[1].value = args[1].value / ScaleRatio
        end
    end)

    gm.post_script_hook(gm.constants.prefs_get_zoom_scale, function(self, other, result, args)
        if params.UnlockZoom then
            Chat.scale_max = ScaleRatio + 4
            result.value = result.value * ScaleRatio
        end
    end)

    --[[
    local StartMenu = nil
    gm.post_code_execute("gml_Object_oStartMenu_Create_0", function(self, other)
        StartMenu = Instance.find(gm.constants.oStartMenu)
        local ModButton = gm.struct_create()
        ModButton.sprite = gm.constants["sTitleIconButtonMods"]
        ModButton.show_new = false
        ModButton.disabled = false
        ModButton.on_press = StartMenu.menu[4].on_press
        ModButton.name = "mods"
        ModButton.test = "mos"
        table.insert(StartMenu.menu, ModButton)
        --log.warning(Wrap.wrap(StartMenu.menu[7].on_press))
        -- StartMenu.menu[7].on_press(StartMenu, StartMenu)
    end)
    gui.add_always_draw_imgui(function()
        if ImGui.IsKeyPressed(81) and not gm._mod_game_ingame() then
            StartMenu.menu_target_exists = true
            local object = Object.find("ror", "SteamMods")
            StartMenu.menu_target_object = Wrap.wrap(object)
           local function myFunc()
                --local ModMenu = Instance.find(object)
                local Mods = GM.variable_global_get("Mods")
                local ModDisplayInfo = GM.variable_global_get("ModDisplayInfo")
                local ModInfo = GM.variable_global_get("ModInfo")
                --ModMenu.loaded_mods = true
                local TestMod = gm.struct_create()
                TestMod.sprite = gm.constants["sTitleIconButtonMods"]
                TestMod.show_new = false
                TestMod.disabled = false
                TestMod.on_press = false
                TestMod.name = "mods"
                TestMod.is_broken = false
                TestMod.display_info = GM.variable_global_get("ModDisplayInfo")
                --TestMod.display_info = 1
                TestMod.mod_info = GM.variable_global_get("ModInfo")
                --TestMod.mod_info = "test"
                --GM.draw_mod_gml_Object_oSteamMods_Create_0()
                Mods.mod_loaded_name.testing = 1
                --ModMenu.mod_info = GM.variable_global_get("ModDisplayInfo")
                
                --table.insert(ModMenu.mod_list, TestMod)
                --table.insert(Mods.mods, TestMod)
                log.warning(Mods)
                Helper.log_struct(Mods)
                Helper.log_struct(Mods.mod_loaded_name)
                Helper.log_struct(ModDisplayInfo)
                Helper.log_struct(ModInfo)
                --Helper.log_struct(ModMenu)
            end
            Alarm.create(myFunc, 30)
        end
    end)]]

    gm.post_script_hook(gm.constants.instance_create_depth, function(self, other, result, args)
        if params.ArtiSecondaryFix then
            -- Fix Nanospear with backup mag
            if result.value.object_index == gm.constants.oEfArtiNanobolt and self.m_id == player.m_id then
                artiX2.required_stock = artiX2.max_stock + 5
                BufferedX2 = result.value
            end
            if result.value.object_index == gm.constants.oEfExplosion and self ~= nil and self.m_id == player.m_id then
                local function ResetSpear()
                    if BufferedX2 ~= nil and Instance.exists(BufferedX2) == false then
                        artiX2.required_stock = 1
                    end
                end
                Alarm.create(ResetSpear, 60)
            end

            -- Nanobomb cooldown
            if result.value.object_index == gm.constants.oArtiNanobomb then

                local function CheckXSkillUsed()
                    if not player.value.x_skill then
                        artiX.required_stock = 1
                    else
                        Alarm.create(CheckXSkillUsed, 1)
                    end
                end
                Alarm.create(CheckXSkillUsed, 1)
                artiX.required_stock = artiX.max_stock + 5
            end
        end

        -- get ground position below worm by gettting the position the fire is placed
        if result.value.object_index == gm.constants.oFireTrail and self.object_index == gm.constants.oWorm then
            table.insert(WormAttackY, result.value.y)
        end
    end)

    -- change worm attack y position to highest point where fire was generated
    gm.pre_script_hook(gm.constants.fire_explosion, function(self, other, result, args)
        if params.MagmaWormHitBoxFix and self.object_index == gm.constants.oWorm then
            args[3].value = WormAttackY[1]
            args[9].value = 5
        end
        WormAttackY = {}
    end)

    -- fix tooltip being in the wrong position
    local ResetRender = false
    gm.pre_script_hook(gm.constants.prefs_set_zoom_scale, function(self, other, result, args)
        ResetRender = true
    end)
    gm.pre_script_hook(gm.constants.ui_hover_tooltip, function(self, other, result, args)
        if params.TooltipFix and (self.object_index == gm.constants.oP or self.object_index == gm.constants.oHUD) and
            ResetRender then
            GM.ui_reset_render_state()
        end
    end)

    -- disable default console keybind by giving an extra arg when calling it with new keybind
    gm.pre_script_hook(gm.constants.anon_gml_Object_oConsole_Create_0_21502241_gml_Object_oConsole_Create_0,
        function(self, other, result, args)
            if not gm.bool(args[2]) then
                return false
            end
        end)

    -- block enter being registered for chat opening, still works for everything else
    gm.pre_code_execute("gml_Object_oInit_KeyPress_13", function(self, other)
        if Chat.chat_talking == false and params.ChatKey ~= 13 then
            return false
        end
    end)

    -- Check if chat is opened the previous frame, to block new keybind if it was.
    -- would otherwise cause issues if new keybind is set to enter
    local function PreviousTalking()
        TalkBuffer = Chat.chat_talking
        Alarm.create(PreviousTalking, 1)
    end
    Alarm.create(PreviousTalking, 1)
end)

-- add key rebind
local awaitingChatKeybind = false
local awaitingConsoleKeybind = false
gui.add_imgui(function()
    if ImGui.Begin("Misc Fixes") then
        ImGui.Text("Open Chat Keybind")
        if awaitingChatKeybind then
            ImGui.Button("<Waiting for Key>")
        else
            if ImGui.Button("          " .. params.ChatKey .. "          ") then
                awaitingChatKeybind = true
            end
        end
        for keyCode = 0, 512 do
            if ImGui.IsKeyPressed(keyCode) and awaitingChatKeybind then
                params.ChatKey = keyCode
                awaitingChatKeybind = false
                break
            end
        end

        ImGui.Text("Open Console Keybind")
        if awaitingConsoleKeybind then
            ImGui.Button("<Waiting for Key>")
        else
            if ImGui.Button("          " .. params.ConsoleKey .. "          ") then
                awaitingConsoleKeybind = true
            end
        end
        for keyCode = 0, 512 do
            if ImGui.IsKeyPressed(keyCode) and awaitingConsoleKeybind then
                params.ConsoleKey = keyCode
                awaitingConsoleKeybind = false
                break
            end
        end
        params.TooltipFix = ImGui.Checkbox("Fix Tooltip Position", params.TooltipFix)
        params.ArtiSecondaryFix = ImGui.Checkbox("Fix Arti Secondary Double Firing", params.ArtiSecondaryFix)
        params.MagmaWormHitBoxFix = ImGui.Checkbox("Fix undodgeable magma worm hitbox", params.MagmaWormHitBoxFix)
        params.UnlockZoom = ImGui.Checkbox("UnlockZoom", params.UnlockZoom)
        Toml.save_cfg(_ENV["!guid"], params)
    end
    ImGui.End()
end)

gui.add_always_draw_imgui(function()
    -- open chat
    if not TalkBuffer and ImGui.IsKeyPressed(params.ChatKey) then
        Chat.chat_talking = true
        Chat.chat_alpha = 60.0
    end
    -- open console
    if ImGui.IsKeyPressed(params.ConsoleKey) then
        if console then
            if gm.bool(console.open) then
                console.set_visible(console.value, console.value, false, true)
            else
                console.set_visible(console.value, console.value, true, true)
            end
        end
    end
end)

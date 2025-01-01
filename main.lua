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
        TooltipFix = true,
        ArtiSecondaryFix = true,
        MagmaWormHitBoxFix = true
    }
    params = Toml.config_update(_ENV["!guid"], params) -- Load Save
end)

local Chat
local Hud
local BufferedX2 = nil
local player = nil
local WormAttackY = {}
local TalkBuffer = false
Initialize(function()
    local artiX2 = Skill.find("ror-artiX2")
    local artiX = Skill.find("ror-artiX")
    Chat = Instance.find(gm.constants.oInit)

    Callback.add("onGameStart", "SmallFixes-onGameStart", function()
        WormAttackY = {}
    end)

    Callback.add("onPlayerInit", "SmallFixes-onPlayerInit", function(self)
        player = Player.get_client()
    end)

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

local awaitingKeybind = false
gui.add_imgui(function()
    if ImGui.Begin("Misc Fixes") then

        ImGui.Text("Open Chat Keybind")
        if awaitingKeybind then
            ImGui.Button("<Waiting for Key>")
        else
            if ImGui.Button("          " .. params.ChatKey .. "          ") then
                awaitingKeybind = true
            end
        end
        for keyCode = 0, 512 do
            if ImGui.IsKeyPressed(keyCode) and awaitingKeybind then
                params.ChatKey = keyCode
                awaitingKeybind = false
                break
            end
        end
        params.TooltipFix = ImGui.Checkbox("Fix Tooltip Position", params.TooltipFix)
        params.ArtiSecondaryFix = ImGui.Checkbox("Fix Arti Secondary Double Firing", params.ArtiSecondaryFix)
        params.MagmaWormHitBoxFix = ImGui.Checkbox("Fix undodgeable magma worm hitbox", params.MagmaWormHitBoxFix)
        Toml.save_cfg(_ENV["!guid"], params)
    end
    ImGui.End()
end)

-- open chat
gui.add_always_draw_imgui(function()
    if not TalkBuffer and ImGui.IsKeyPressed(params.ChatKey) then
        Chat.chat_talking = true
        Chat.chat_alpha = 60.0
    end
end)

-- Touch Controller for the Vanilla 1.12.1 client (Build 5875).
-- All callbacks intentionally use the legacy WoW globals and argument style.

local TC = {}
local joystickRadius = 95
local knobRadius = 38
local dragRadius = joystickRadius - knobRadius
local dragging = false
local unlocked = false
local overlayButton = nil
local overlayDownTime = 0
local mouselookActive = false
local moveState = {}
local actionButtons = {}

local function StopMovement(name)
    if moveState[name] then
        if name == "forward" then MoveForwardStop();
        elseif name == "backward" then MoveBackwardStop();
        elseif name == "leftTurn" then TurnLeftStop();
        elseif name == "rightTurn" then TurnRightStop();
        elseif name == "leftStrafe" then StrafeLeftStop();
        elseif name == "rightStrafe" then StrafeRightStop();
        end
        moveState[name] = nil
    end
end

local function SetMovement(name, active)
    if active and not moveState[name] then
        moveState[name] = true
        if name == "forward" then MoveForwardStart();
        elseif name == "backward" then MoveBackwardStart();
        elseif name == "leftTurn" then TurnLeftStart();
        elseif name == "rightTurn" then TurnRightStart();
        elseif name == "leftStrafe" then StrafeLeftStart();
        elseif name == "rightStrafe" then StrafeRightStart();
        end
    elseif not active then
        StopMovement(name)
    end
end

local function StopEverything()
    StopMovement("forward")
    StopMovement("backward")
    StopMovement("leftTurn")
    StopMovement("rightTurn")
    StopMovement("leftStrafe")
    StopMovement("rightStrafe")
end

local function StartDirectionFromTouch(dx, dy)
    local threshold = dragRadius * 0.30
    local horizontal = math.abs(dx) > math.abs(dy)

    -- Protected movement APIs are called only from OnMouseDown, which is a
    -- hardware event. Calling them from OnUpdate is blocked by the 1.12.1
    -- secure-action rules.
    SetMovement("forward", dy > threshold)
    SetMovement("backward", dy < -threshold)

    if math.abs(dx) > threshold and horizontal then
        if dy >= 0 then
            SetMovement("rightTurn", dx > 0)
            SetMovement("leftTurn", dx < 0)
        else
            SetMovement("rightStrafe", dx > 0)
            SetMovement("leftStrafe", dx < 0)
        end
    end
end

-- Lua 5.0-compatible atan2 replacement. atan2 gives the signed angle from +X.
local function Angle(y, x)
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

function TouchController_OnLoad()
    SlashCmdList["TOUCHCONTROLLER"] = function(message)
        if message and string.find(message, "unlock") then
            unlocked = not unlocked
            TouchControllerJoystick:SetMovable(unlocked)
            TouchControllerBars:SetMovable(unlocked)
            DEFAULT_CHAT_FRAME:AddMessage("Touch Controller positions are " .. (unlocked and "unlocked." or "locked."))
        else
            if TouchControllerRoot:IsShown() then
                TouchControllerRoot:Hide()
                TouchControllerOverlay:Hide()
                TouchControllerJoystick:Hide()
                TouchControllerBars:Hide()
            else
                TouchControllerRoot:Show()
                TouchControllerOverlay:Show()
                TouchControllerJoystick:Show()
                TouchControllerBars:Show()
            end
        end
    end
    SLASH_TOUCHCONTROLLER1 = "/touch"
end

function TouchController_JoystickOnLoad()
    this:SetClampedToScreen(true)
end

function TouchController_JoystickMouseDown()
    if arg1 == "LeftButton" then
        if unlocked then
            this:StartMoving()
        else
            dragging = true
            local scale = TouchControllerJoystick:GetEffectiveScale()
            local cursorX, cursorY = GetCursorPosition()
            cursorX = cursorX / scale
            cursorY = cursorY / scale
            local centerX = TouchControllerJoystick:GetLeft() + joystickRadius
            local centerY = TouchControllerJoystick:GetBottom() + joystickRadius
            StartDirectionFromTouch(cursorX - centerX, cursorY - centerY)
        end
    end
end

function TouchController_JoystickMouseUp()
    if unlocked then
        this:StopMovingOrSizing()
        return
    end
    if dragging then
        dragging = false
        TouchControllerKnob:ClearAllPoints()
        TouchControllerKnob:SetPoint("CENTER", TouchControllerJoystick, "CENTER", 0, 0)
        StopEverything()
    end
end

function TouchController_JoystickUpdate(elapsed)
    if not dragging then return end
    local scale = TouchControllerJoystick:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    cursorX = cursorX / scale
    cursorY = cursorY / scale
    local centerX = TouchControllerJoystick:GetLeft() + joystickRadius
    local centerY = TouchControllerJoystick:GetBottom() + joystickRadius
    local dx = cursorX - centerX
    local dy = cursorY - centerY
    local distance = math.sqrt((dx * dx) + (dy * dy))
    local angle = Angle(dy, dx)

    -- When the finger exceeds the circular radius, normalize the vector.
    -- This preserves theta (direction) while clamping r (displacement).
    if distance > dragRadius then
        dx = (dx / distance) * dragRadius
        dy = (dy / distance) * dragRadius
        distance = dragRadius
    end
    TouchControllerKnob:ClearAllPoints()
    TouchControllerKnob:SetPoint("CENTER", TouchControllerJoystick, "CENTER", dx, dy)

    -- Movement is deliberately not changed here. OnUpdate is not a hardware
    -- event in Vanilla and protected movement calls would be blocked.
end

function TouchController_OverlayOnLoad()
    -- Vanilla 1.12.1 does not provide RegisterForClicks() on ordinary
    -- frames. EnableMouse plus the mouse scripts is sufficient here.
end

function TouchController_OverlayMouseDown(button)
    overlayButton = button
    overlayDownTime = GetTime()
end

function TouchController_OverlayUpdate(elapsed)
    if overlayButton == "RightButton" and not mouselookActive and GetTime() - overlayDownTime > 0.15 then
        mouselookActive = true
        MouselookStart()
    end
end

function TouchController_OverlayMouseUp(button)
    local held = GetTime() - overlayDownTime
    if button == "LeftButton" and held < 0.15 then
        if UnitExists("mouseover") then TargetUnit("mouseover") else TargetNearestEnemy() end
    elseif button == "RightButton" and mouselookActive then
        MouselookStop()
        mouselookActive = false
    end
    overlayButton = nil
end

local function UpdateActionCooldown(button)
    if not button.cooldown then return end
    local start, duration, enabled = GetActionCooldown(button:GetID())
    if start and duration and duration > 0 then
        CooldownFrame_SetTimer(button.cooldown, start, duration, enabled)
    else
        button.cooldown:Hide()
    end
end

function TouchController_CreateActionButtons()
    local i
    for i = 1, 12 do
        local button = CreateFrame("Button", "TouchActionButton" .. i, TouchControllerBars, "ActionButtonTemplate")
        button:SetID(i)
        button:SetScale(1.15)
        -- ActionButtonTemplate in some Vanilla 1.12.1 clients does not
        -- create the cooldown child when the button is made dynamically.
        button.cooldown = CreateFrame("Cooldown", "TouchActionButton" .. i .. "Cooldown", button)
        button.cooldown:SetAllPoints(button)
        button.cooldown:Hide()
        if i <= 6 then
            button:SetPoint("BOTTOMRIGHT", TouchControllerBars, "BOTTOMRIGHT", -((i - 1) * 46), 0)
        else
            button:SetPoint("BOTTOMRIGHT", TouchControllerBars, "BOTTOMRIGHT", -((i - 7) * 46), 48)
        end
        button:SetScript("OnClick", function()
            UseAction(this:GetID())
        end)
        button:SetScript("OnUpdate", function()
            UpdateActionCooldown(this)
        end)
        actionButtons[i] = button
    end
end
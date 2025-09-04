--!strict
-- SpliceUI.lua — UI Library exclusiva para o seu jogo (splice.lol design)
-- Coloque este ModuleScript em ReplicatedStorage como "SpliceUI"
-- Use em um LocalScript (StarterPlayerScripts/StarterGui) com: local UI = require(game.ReplicatedStorage.SpliceUI)
-- A lib usa apenas APIs padrão do Roblox (sem dependências externas)

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")

local SpliceUI = {}
SpliceUI.__index = SpliceUI

--[[
    DESIGN TOKENS (tema splice.lol)
    - Dark Mode padrão, com acento vermelho
    - Glass/blur simulado por transparência + stroke + sombras suaves
]]

local Themes = {
    dark = {
        Name = "dark",
        Colors = {
            background = Color3.fromRGB(10,10,12),
            panel      = Color3.fromRGB(16,16,20),
            glass      = Color3.fromRGB(24,24,28),
            text       = Color3.fromRGB(235,235,240),
            subtext    = Color3.fromRGB(185,185,195),
            accent     = Color3.fromRGB(255,32,32), -- vermelho splice.lol
            accent2    = Color3.fromRGB(255,80,80),
            stroke     = Color3.fromRGB(60,60,70),
            shadow     = Color3.fromRGB(0,0,0),
        },
        Transparency = {
            panel = 0.08,
            glass = 0.22,
        },
        Corner = 14,
        ShadowTransparency = 0.6,
        Font = Enum.Font.Gotham,
    },
    light = {
        Name = "light",
        Colors = {
            background = Color3.fromRGB(245,246,248),
            panel      = Color3.fromRGB(255,255,255),
            glass      = Color3.fromRGB(255,255,255),
            text       = Color3.fromRGB(20,22,24),
            subtext    = Color3.fromRGB(100,104,112),
            accent     = Color3.fromRGB(255,32,32),
            accent2    = Color3.fromRGB(255,80,80),
            stroke     = Color3.fromRGB(220,221,224),
            shadow     = Color3.fromRGB(0,0,0),
        },
        Transparency = {
            panel = 0.0,
            glass = 0.0,
        },
        Corner = 14,
        ShadowTransparency = 0.85,
        Font = Enum.Font.Gotham,
    }
}

local ActiveTheme = Themes.dark

-- Parent override para uso universal (permite montar em qualquer ScreenGui)
local ParentOverride: ScreenGui? = nil

function SpliceUI.SetParentGui(gui: ScreenGui)
    ParentOverride = gui
end

-- Utility: criar Instance rapidamente
local function New(className: string, props: {[string]: any}?, children: {Instance}?)
    local inst = Instance.new(className)
    if props then
        for k,v in pairs(props) do
            (inst :: any)[k] = v
        end
    end
    if children then
        for _,child in ipairs(children) do
            child.Parent = inst
        end
    end
    return inst
end

-- Utility: tween simples
local function PlayTween(obj: Instance, info: TweenInfo, goal: {[string]: any})
    local t = TweenService:Create(obj, info, goal)
    t:Play()
    return t
end

-- Utility: sombra (simples, sem imagens)
local function AddShadow(parent: GuiObject, transparency: number?)
    local shadow = New("Frame", {
        Name = "_Shadow",
        BackgroundColor3 = ActiveTheme.Colors.shadow,
        BackgroundTransparency = transparency or ActiveTheme.ShadowTransparency,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1,1),
        Position = UDim2.fromOffset(0,0),
        ZIndex = (parent.ZIndex or 1) - 1,
    })
    local corner = New("UICorner", {CornerRadius = UDim.new(0, ActiveTheme.Corner)})
    corner.Parent = shadow
    shadow.Parent = parent
    shadow:ClearAllChildren() -- só manter o corner
    corner.Parent = shadow
    shadow.SendToBack = true
    return shadow
end

-- Utility: stroke + cantos
local function StyleGlass(frame: Frame)
    frame.BackgroundColor3 = ActiveTheme.Colors.glass
    frame.BackgroundTransparency = ActiveTheme.Transparency.glass
    frame.BorderSizePixel = 0
    New("UICorner", {CornerRadius = UDim.new(0, ActiveTheme.Corner)}, {} ).Parent = frame
    New("UIStroke", {
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Color = ActiveTheme.Colors.stroke,
        Thickness = 1,
        Transparency = 0.35,
    }).Parent = frame
end

-- Utility: arraste
local function MakeDraggable(frame: Frame, dragHandle: GuiObject?)
    local dragging = false
    local dragStart, startPos

    local function update(input: InputObject)
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            frame.Position.X.Scale,
            startPos.X.Offset + delta.X,
            frame.Position.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    local handle = dragHandle or frame
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then update(input) end
        end
    end)
end

-- ScreenGui raiz
local function createRoot(name: string)
    local sg = New("ScreenGui", {
        Name = name,
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 10,
    })

    local scale = New("UIScale", {Scale = 1})
    scale.Parent = sg

    -- Permite escolher explicitamente o ScreenGui de destino
if ParentOverride and ParentOverride.Parent then
    sg.Parent = ParentOverride
else
    sg.Parent = PLAYER_GUI
end
    return sg, scale
end

-- THEME API
function SpliceUI.setTheme(themeName: string)
    local t = Themes[themeName]
    if t then ActiveTheme = t end
end

function SpliceUI.setAccent(color: Color3)
    ActiveTheme.Colors.accent = color
    ActiveTheme.Colors.accent2 = color:Lerp(Color3.new(1,1,1), 0.4)
end

-- STATE API (simples, em memória)
local State: {[string]: any} = {}
function SpliceUI.SetState(key: string, value: any)
    State[key] = value
end
function SpliceUI.GetState(key: string, default: any)
    local v = State[key]
    if v == nil then return default end
    return v
end

-- COMPONENTES ---------------------------------------------------------------

-- Window (janela com barra de título, abas opcionais)
local Window = {}
Window.__index = Window

function Window.new(opts: {
    title: string?,
    size: UDim2?,
    position: UDim2?,
    resizable: boolean?,
    tabs: {string}?,
    key: string?,
})
    local root, scale = createRoot("SpliceUI")

    local container = New("Frame", {
        Name = "Window",
        Size = opts.size or UDim2.fromOffset(520, 380),
        Position = opts.position or UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
    })
    container.Parent = root

    local panel = New("Frame", {
        Name = "Panel",
        Size = UDim2.fromScale(1,1),
        BackgroundTransparency = 1,
    })
    panel.Parent = container

    local bg = New("Frame", {
        Name = "Glass",
        Size = UDim2.fromScale(1,1),
        Position = UDim2.fromOffset(0,0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    StyleGlass(bg)
    bg.Parent = panel
    AddShadow(bg, ActiveTheme.ShadowTransparency)

    local topbar = New("Frame", {
        Name = "Topbar",
        BackgroundColor3 = ActiveTheme.Colors.panel,
        BackgroundTransparency = ActiveTheme.Transparency.panel,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,42),
        ZIndex = 3,
    })
    New("UICorner", {CornerRadius = UDim.new(0, ActiveTheme.Corner)}).Parent = topbar
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.55}).Parent = topbar
    topbar.Parent = bg

    local title = New("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-120,1,0),
        Position = UDim2.fromOffset(16,0),
        Font = ActiveTheme.Font,
        Text = opts.title or "splice.lol",
        TextColor3 = ActiveTheme.Colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 18,
        ZIndex = 4,
    })
    title.Parent = topbar

    -- Botões de janela
    local closeBtn = New("TextButton", {
        Name = "Close",
        Size = UDim2.fromOffset(28,28),
        Position = UDim2.new(1,-36,0.5,0),
        AnchorPoint = Vector2.new(0.5,0.5),
        BackgroundColor3 = ActiveTheme.Colors.accent,
        BackgroundTransparency = 0.05,
        Text = "✕",
        TextColor3 = Color3.new(1,1,1),
        Font = ActiveTheme.Font,
        TextSize = 16,
        ZIndex = 5,
        AutoButtonColor = false,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 10)}).Parent = closeBtn
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.6}).Parent = closeBtn
    closeBtn.Parent = topbar

    local minimizeBtn = New("TextButton", {
        Name = "Minimize",
        Size = UDim2.fromOffset(28,28),
        Position = UDim2.new(1,-72,0.5,0),
        AnchorPoint = Vector2.new(0.5,0.5),
        BackgroundColor3 = ActiveTheme.Colors.panel,
        BackgroundTransparency = ActiveTheme.Transparency.panel,
        Text = "–",
        TextColor3 = ActiveTheme.Colors.text,
        Font = ActiveTheme.Font,
        TextSize = 16,
        ZIndex = 5,
        AutoButtonColor = false,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 10)}).Parent = minimizeBtn
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.6}).Parent = minimizeBtn
    minimizeBtn.Parent = topbar

    -- Conteúdo
    local content = New("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-24,1,-58),
        Position = UDim2.fromOffset(12, 46),
        ZIndex = 2,
        ClipsDescendants = false,
    })
    content.Parent = bg

    local list = New("UIListLayout", {
        Padding = UDim.new(0,10),
        FillDirection = Enum.FillDirection.Vertical,
        HorizontalAlignment = Enum.HorizontalAlignment.Left,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    list.Parent = content

    -- Drag
    MakeDraggable(container, topbar)

    -- Minimize / Close
    local minimized = false
    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            PlayTween(content, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size = UDim2.new(1,-24,0,0)})
            PlayTween(bg, TweenInfo.new(0.2), {Size = UDim2.new(1,0,0,42)})
        else
            PlayTween(content, TweenInfo.new(0.2), {Size = UDim2.new(1,-24,1,-58)})
            PlayTween(bg, TweenInfo.new(0.2), {Size = UDim2.fromScale(1,1)})
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        root:Destroy()
    end)

    local self = setmetatable({
        Gui = root,
        Window = container,
        Panel = bg,
        Topbar = topbar,
        Content = content,
        Tabs = nil :: any,
        _scale = scale,
        Key = opts.key or ("win_"..HttpService:GenerateGUID(false)),
    }, Window)

    -- Tabs opcionais
    if opts.tabs and #opts.tabs > 0 then
        self.Tabs = SpliceUI.Tabs(content, opts.tabs)
    end

    return self
end

function Window:SetScale(scale: number)
    if self._scale then self._scale.Scale = math.clamp(scale, 0.7, 1.5) end
end

function Window:AddSection(titleText: string)
    local section = New("Frame", {
        Name = "Section",
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        LayoutOrder = 1,
    })

    local head = New("TextLabel", {
        Name = "Header",
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,20),
        Font = ActiveTheme.Font,
        Text = titleText,
        TextColor3 = ActiveTheme.Colors.subtext,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 14,
    })
    head.Parent = section

    local body = New("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
    })
    body.Parent = section

    local grid = New("UIListLayout", {
        Padding = UDim.new(0,8),
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    grid.Parent = body

    section.Parent = self.Content

    return body
end

-- Button
function SpliceUI.Button(parent: Instance, opts: {text: string, key: string?}): TextButton
    local btn = New("TextButton", {
        Name = "Button",
        AutoButtonColor = false,
        BackgroundColor3 = ActiveTheme.Colors.panel,
        BackgroundTransparency = ActiveTheme.Transparency.panel,
        Size = UDim2.new(1,0,0,36),
        Text = opts.text or "Button",
        Font = ActiveTheme.Font,
        TextSize = 16,
        TextColor3 = ActiveTheme.Colors.text,
    })
    New("UICorner", {CornerRadius = UDim.new(0, ActiveTheme.Corner)}).Parent = btn
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.5}).Parent = btn

    -- Hover
    btn.MouseEnter:Connect(function()
        PlayTween(btn, TweenInfo.new(0.12), {BackgroundColor3 = ActiveTheme.Colors.glass, BackgroundTransparency = ActiveTheme.Transparency.glass})
    end)
    btn.MouseLeave:Connect(function()
        PlayTween(btn, TweenInfo.new(0.2), {BackgroundColor3 = ActiveTheme.Colors.panel, BackgroundTransparency = ActiveTheme.Transparency.panel})
    end)

    -- Click flash
    btn.MouseButton1Down:Connect(function()
        PlayTween(btn, TweenInfo.new(0.08), {TextColor3 = ActiveTheme.Colors.accent})
    end)
    btn.MouseButton1Up:Connect(function()
        PlayTween(btn, TweenInfo.new(0.12), {TextColor3 = ActiveTheme.Colors.text})
    end)

    btn.Parent = parent
    return btn
end

-- Toggle
function SpliceUI.Toggle(parent: Instance, opts: {text: string, default: boolean?, key: string?})
    local id = opts.key or ("toggle_"..HttpService:GenerateGUID(false))
    local value = SpliceUI.GetState(id, opts.default == true)

    local frame = New("Frame", {
        Name = "Toggle",
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,36),
    })

    local label = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-56,1,0),
        Position = UDim2.fromOffset(0,0),
        Font = ActiveTheme.Font,
        Text = opts.text or "Toggle",
        TextColor3 = ActiveTheme.Colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 16,
    })
    label.Parent = frame

    local btn = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = value and ActiveTheme.Colors.accent or ActiveTheme.Colors.panel,
        BackgroundTransparency = value and 0.05 or ActiveTheme.Transparency.panel,
        Size = UDim2.fromOffset(44,24),
        Position = UDim2.new(1,-44,0.5,0),
        AnchorPoint = Vector2.new(0,0.5),
        Text = "",
    })
    New("UICorner", {CornerRadius = UDim.new(0, 12)}).Parent = btn
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.5}).Parent = btn
    btn.Parent = frame

    local knob = New("Frame", {
        BackgroundColor3 = Color3.fromRGB(255,255,255),
        Size = UDim2.fromOffset(18,18),
        Position = value and UDim2.fromOffset(24,3) or UDim2.fromOffset(3,3),
        BorderSizePixel = 0,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 9)}).Parent = knob
    knob.Parent = btn

    local function set(v: boolean)
        value = v
        SpliceUI.SetState(id, value)
        PlayTween(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = value and ActiveTheme.Colors.accent or ActiveTheme.Colors.panel,
            BackgroundTransparency = value and 0.05 or ActiveTheme.Transparency.panel,
        })
        PlayTween(knob, TweenInfo.new(0.15), {
            Position = value and UDim2.fromOffset(24,3) or UDim2.fromOffset(3,3)
        })
    end

    btn.MouseButton1Click:Connect(function()
        set(not value)
    end)

    frame.Parent = parent

    return {
        Instance = frame,
        Get = function() return value end,
        Set = set,
        Changed = Instance.new("BindableEvent")
    }
end

-- Slider
function SpliceUI.Slider(parent: Instance, opts: {text: string, min: number, max: number, step: number?, default: number?, key: string?})
    local id = opts.key or ("slider_"..HttpService:GenerateGUID(false))
    local min = opts.min or 0
    local max = opts.max or 100
    local step = opts.step or 1
    local value = SpliceUI.GetState(id, opts.default or min)

    local frame = New("Frame", {
        Name = "Slider",
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,46),
    })

    local top = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,22)})
    top.Parent = frame

    local label = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-60,1,0),
        Font = ActiveTheme.Font,
        Text = opts.text or "Slider",
        TextColor3 = ActiveTheme.Colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 16,
    })
    label.Parent = top

    local valLabel = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0,60,1,0),
        Position = UDim2.new(1,-60,0,0),
        Font = ActiveTheme.Font,
        Text = tostring(value),
        TextColor3 = ActiveTheme.Colors.subtext,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextSize = 14,
    })
    valLabel.Parent = top

    local bar = New("Frame", {
        BackgroundColor3 = ActiveTheme.Colors.panel,
        BackgroundTransparency = ActiveTheme.Transparency.panel,
        Size = UDim2.new(1,0,0,10),
        Position = UDim2.new(0,0,0,28),
        BorderSizePixel = 0,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 6)}).Parent = bar
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.5}).Parent = bar
    bar.Parent = frame

    local fill = New("Frame", {
        BackgroundColor3 = ActiveTheme.Colors.accent,
        BackgroundTransparency = 0.05,
        Size = UDim2.new((value-min)/(max-min),0,1,0),
        BorderSizePixel = 0,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 6)}).Parent = fill
    fill.Parent = bar

    local knob = New("Frame", {
        BackgroundColor3 = Color3.new(1,1,1),
        Size = UDim2.fromOffset(14,14),
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.new((value-min)/(max-min),0,0.5,0),
        BorderSizePixel = 0,
    })
    New("UICorner", {CornerRadius = UDim.new(0,7)}).Parent = knob
    knob.Parent = bar

    local sliding = false

    local function set(newVal: number)
        newVal = math.clamp(newVal, min, max)
        if step > 0 then newVal = math.round(newVal/step)*step end
        value = newVal
        SpliceUI.SetState(id, value)
        valLabel.Text = tostring(value)
        PlayTween(fill, TweenInfo.new(0.08), {Size = UDim2.new((value-min)/(max-min),0,1,0)})
        PlayTween(knob, TweenInfo.new(0.08), {Position = UDim2.new((value-min)/(max-min),0,0.5,0)})
    end

    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            local rel = (input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X
            set(min + rel*(max-min))
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            local rel = (input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X
            set(min + rel*(max-min))
        end
    end)

    frame.Parent = parent

    return {
        Instance = frame,
        Get = function() return value end,
        Set = set,
        Changed = Instance.new("BindableEvent")
    }
end

-- Dropdown
function SpliceUI.Dropdown(parent: Instance, opts: {text: string, items: {string}, default: string?, key: string?})
    local id = opts.key or ("dropdown_"..HttpService:GenerateGUID(false))
    local value = SpliceUI.GetState(id, opts.default or (opts.items[1] or ""))

    local frame = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,36)})

    local label = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.35,0,1,0),
        Font = ActiveTheme.Font,
        Text = opts.text or "Dropdown",
        TextColor3 = ActiveTheme.Colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 16,
    })
    label.Parent = frame

    local box = New("TextButton", {
        AutoButtonColor = false,
        BackgroundColor3 = ActiveTheme.Colors.panel,
        BackgroundTransparency = ActiveTheme.Transparency.panel,
        Size = UDim2.new(0.65,0,1,0),
        Position = UDim2.new(0.35,8,0,0),
        Text = value,
        Font = ActiveTheme.Font,
        TextSize = 16,
        TextColor3 = ActiveTheme.Colors.text,
        ClipsDescendants = true,
    })
    New("UICorner", {CornerRadius = UDim.new(0, ActiveTheme.Corner)}).Parent = box
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.5}).Parent = box
    box.Parent = frame

    local listFrame = New("Frame", {
        BackgroundColor3 = ActiveTheme.Colors.glass,
        BackgroundTransparency = ActiveTheme.Transparency.glass,
        Size = UDim2.new(1,0,0,0),
        Position = UDim2.new(0,0,1,4),
        BorderSizePixel = 0,
        Visible = false,
        ClipsDescendants = true,
        ZIndex = 50,
    })
    New("UICorner", {CornerRadius = UDim.new(0, ActiveTheme.Corner)}).Parent = listFrame
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.4}).Parent = listFrame
    listFrame.Parent = box

    local uilist = New("UIListLayout", {Padding = UDim.new(0,4)})
    uilist.Parent = listFrame

    local function open()
        listFrame.Visible = true
        PlayTween(listFrame, TweenInfo.new(0.12), {Size = UDim2.new(1,0,0,#opts.items*30 + 10)})
    end
    local function close()
        PlayTween(listFrame, TweenInfo.new(0.12), {Size = UDim2.new(1,0,0,0)}).Completed:Wait()
        listFrame.Visible = false
    end

    box.MouseButton1Click:Connect(function()
        if listFrame.Visible then close() else open() end
    end)

    local function set(v: string)
        value = v
        SpliceUI.SetState(id, value)
        box.Text = value
        close()
    end

    for _,item in ipairs(opts.items) do
        local opt = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = ActiveTheme.Colors.panel,
            BackgroundTransparency = ActiveTheme.Transparency.panel,
            Size = UDim2.new(1,-8,0,26),
            Text = item,
            Font = ActiveTheme.Font,
            TextSize = 14,
            TextColor3 = ActiveTheme.Colors.text,
            ZIndex = 51,
        })
        New("UICorner", {CornerRadius = UDim.new(0, 10)}).Parent = opt
        New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.6}).Parent = opt
        opt.MouseEnter:Connect(function()
            PlayTween(opt, TweenInfo.new(0.08), {BackgroundColor3 = ActiveTheme.Colors.glass, BackgroundTransparency = ActiveTheme.Transparency.glass})
        end)
        opt.MouseLeave:Connect(function()
            PlayTween(opt, TweenInfo.new(0.12), {BackgroundColor3 = ActiveTheme.Colors.panel, BackgroundTransparency = ActiveTheme.Transparency.panel})
        end)
        opt.MouseButton1Click:Connect(function()
            set(item)
        end)
        opt.Parent = listFrame
    end

    frame.Parent = parent

    return {
        Instance = frame,
        Get = function() return value end,
        Set = set,
        Changed = Instance.new("BindableEvent")
    }
end

-- Tabs (contêiner com botões)
function SpliceUI.Tabs(parent: Instance, tabNames: {string})
    local frame = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,40)})
    frame.Parent = parent

    local list = New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0,8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    list.Parent = frame

    local tabPages: {[string]: Frame} = {}
    local tabs: {[string]: TextButton} = {}

    local pages = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Name = "Pages",
    })
    pages.Parent = parent

    local function selectTab(name: string)
        for tabName, btn in pairs(tabs) do
            local active = (tabName == name)
            PlayTween(btn, TweenInfo.new(0.12), {
                TextColor3 = active and ActiveTheme.Colors.accent or ActiveTheme.Colors.text
            })
            tabPages[tabName].Visible = active
        end
    end

    for _,name in ipairs(tabNames) do
        local btn = New("TextButton", {
            AutoButtonColor = false,
            BackgroundColor3 = ActiveTheme.Colors.panel,
            BackgroundTransparency = ActiveTheme.Transparency.panel,
            Size = UDim2.fromOffset(120,36),
            Text = name,
            Font = ActiveTheme.Font,
            TextSize = 16,
            TextColor3 = ActiveTheme.Colors.text,
        })
        New("UICorner", {CornerRadius = UDim.new(0, ActiveTheme.Corner)}).Parent = btn
        New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.6}).Parent = btn
        btn.Parent = frame

        local page = New("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1,0,0,0),
            AutomaticSize = Enum.AutomaticSize.Y,
            Visible = false,
            Name = name,
        })
        New("UIListLayout", {Padding = UDim.new(0,8)}).Parent = page
        page.Parent = pages

        btn.MouseEnter:Connect(function()
            PlayTween(btn, TweenInfo.new(0.1), {BackgroundColor3 = ActiveTheme.Colors.glass, BackgroundTransparency = ActiveTheme.Transparency.glass})
        end)
        btn.MouseLeave:Connect(function()
            PlayTween(btn, TweenInfo.new(0.12), {BackgroundColor3 = ActiveTheme.Colors.panel, BackgroundTransparency = ActiveTheme.Transparency.panel})
        end)
        btn.MouseButton1Click:Connect(function()
            selectTab(name)
        end)

        tabs[name] = btn
        tabPages[name] = page
    end

    -- Select first tab
    if #tabNames > 0 then selectTab(tabNames[1]) end

    return {
        Instance = frame,
        Pages = tabPages,
        Select = selectTab,
    }
end

-- Label
function SpliceUI.Label(parent: Instance, text: string)
    local lbl = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,20),
        Font = ActiveTheme.Font,
        Text = text,
        TextColor3 = ActiveTheme.Colors.subtext,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 14,
    })
    lbl.Parent = parent
    return lbl
end

-- Input
function SpliceUI.Input(parent: Instance, opts: {placeholder: string?, key: string?})
    local id = opts.key or ("input_"..HttpService:GenerateGUID(false))
    local value = SpliceUI.GetState(id, "")

    local box = New("TextBox", {
        BackgroundColor3 = ActiveTheme.Colors.panel,
        BackgroundTransparency = ActiveTheme.Transparency.panel,
        Size = UDim2.new(1,0,0,36),
        PlaceholderText = opts.placeholder or "Digite...",
        Text = value,
        Font = ActiveTheme.Font,
        TextSize = 16,
        TextColor3 = ActiveTheme.Colors.text,
        PlaceholderColor3 = ActiveTheme.Colors.subtext,
        ClearTextOnFocus = false,
    })
    New("UICorner", {CornerRadius = UDim.new(0, ActiveTheme.Corner)}).Parent = box
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.5}).Parent = box

    box.FocusLost:Connect(function()
        SpliceUI.SetState(id, box.Text)
    end)

    box.Parent = parent

    return {
        Instance = box,
        Get = function() return box.Text end,
        Set = function(t: string) box.Text = t SpliceUI.SetState(id, t) end,
        Changed = box:GetPropertyChangedSignal("Text"),
    }
end

-- Notificações toast
function SpliceUI.Notify(message: string, duration: number?)
    duration = duration or 2.0

    local sg = PLAYER_GUI:FindFirstChild("SpliceUI_Notify") or New("ScreenGui", {
        Name = "SpliceUI_Notify",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 50,
    })
    sg.Parent = PLAYER_GUI

    local toast = New("Frame", {
        BackgroundColor3 = ActiveTheme.Colors.glass,
        BackgroundTransparency = ActiveTheme.Transparency.glass,
        Size = UDim2.fromOffset(320, 48),
        AnchorPoint = Vector2.new(1,1),
        Position = UDim2.new(1,-16,1,-16),
        BorderSizePixel = 0,
        ZIndex = 100,
    })
    New("UICorner", {CornerRadius = UDim.new(0, 12)}).Parent = toast
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.4}).Parent = toast

    local label = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1,1),
        Font = ActiveTheme.Font,
        Text = message,
        TextColor3 = ActiveTheme.Colors.text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextSize = 16,
        Position = UDim2.fromOffset(14,0),
    })
    label.Parent = toast

    toast.Parent = sg

    toast.BackgroundTransparency = 1
    label.TextTransparency = 1
    PlayTween(toast, TweenInfo.new(0.18), {BackgroundTransparency = ActiveTheme.Transparency.glass})
    PlayTween(label, TweenInfo.new(0.18), {TextTransparency = 0})

    task.delay(duration, function()
        PlayTween(toast, TweenInfo.new(0.18), {BackgroundTransparency = 1})
        PlayTween(label, TweenInfo.new(0.18), {TextTransparency = 1}).Completed:Wait()
        toast:Destroy()
    end)
end

-- Helpers de criação rápida -------------------------------------------------
function SpliceUI.CreateWindow(opts)
    return Window.new(opts)
end

-- Exemplo de builder de seção de controles
function SpliceUI.AddControlRow(parent: Instance, left: Instance, right: Instance?)
    local row = New("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1,0,0,36)})
    local list = New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0,8),
    })
    list.Parent = row

    left.Parent = row
    left.Size = UDim2.new(right and 0.5 or 1, -4, 1, 0)
    if right then
        right.Parent = row
        right.Size = UDim2.new(0.5, -4, 1, 0)
    end
    row.Parent = parent
    return row
end

-- Retorno do módulo ---------------------------------------------------------
return SpliceUI

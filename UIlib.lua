-- UIlib.lua — Kavo-compatible, universal, estilo splice.lol (executor-safe)
-- Uso (igual Kavo):
-- local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/AKGuimas/LuaUILibTest/refs/heads/main/UIlib.lua"))()
-- local Win  = Library.CreateLib("SpliceUI · Teste", "DarkTheme")
-- local Tab  = Win:NewTab("Geral")
-- local Sec  = Tab:NewSection("Ações")
-- Sec:NewButton("Toast (2s)", "", function() Library.Notify("Executado!", 2) end)
-- Sec:NewToggle("Modo", "", function(v) print("Toggle:", v) end)
-- Sec:NewSlider("Potência", "0..100", 0, 100, function(v) print("Slider:", v) end)
-- Sec:NewDropdown("Perfil", "", {"Padrão","Rápido","Lento"}, function(v) print("Perfil:", v) end)
-- Sec:NewTextBox("Comando", "Digite e Enter…", function(t) print("Textbox:", t) end)

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local LOCAL_PLAYER = Players.LocalPlayer
local PLAYER_GUI = LOCAL_PLAYER:WaitForChild("PlayerGui")

---------------------------------------------------------------------
-- Núcleo (tema + utilitários)
---------------------------------------------------------------------
local SpliceUI = {}
SpliceUI.__index = SpliceUI

local Themes = {
  dark = {
    Colors = {
      background = Color3.fromRGB(10,10,12),
      panel      = Color3.fromRGB(16,16,20),
      glass      = Color3.fromRGB(24,24,28),
      text       = Color3.fromRGB(235,235,240),
      subtext    = Color3.fromRGB(185,185,195),
      accent     = Color3.fromRGB(255,32,32),
      stroke     = Color3.fromRGB(60,60,70),
      shadow     = Color3.fromRGB(0,0,0),
    },
    Transparency = { panel = 0.08, glass = 0.22 },
    Corner = 14,
    ShadowTransparency = 0.6,
    Font = Enum.Font.Gotham,
  },
  light = {
    Colors = {
      background = Color3.fromRGB(245,246,248),
      panel      = Color3.fromRGB(255,255,255),
      glass      = Color3.fromRGB(255,255,255),
      text       = Color3.fromRGB(20,22,24),
      subtext    = Color3.fromRGB(100,104,112),
      accent     = Color3.fromRGB(255,32,32),
      stroke     = Color3.fromRGB(220,221,224),
      shadow     = Color3.fromRGB(0,0,0),
    },
    Transparency = { panel = 0.0, glass = 0.0 },
    Corner = 14,
    ShadowTransparency = 0.85,
    Font = Enum.Font.Gotham,
  }
}
local ActiveTheme = Themes.dark

-- Overlay fixo no topo da ScreenGui para listas/menus
local function getOverlayFor(inst: Instance)
    local sg = inst:FindFirstAncestorWhichIsA("ScreenGui")
    if not sg then return nil end
    local overlay = sg:FindFirstChild("__SpliceUI_Overlay")
    if not overlay then
        overlay = Instance.new("Frame")
        overlay.Name = "__SpliceUI_Overlay"
        overlay.BackgroundTransparency = 1
        overlay.BorderSizePixel = 0
        overlay.Size = UDim2.fromScale(1,1)
        overlay.ZIndex = 1000 -- MUITO acima de todo o resto
        overlay.Parent = sg
    end
    return overlay
end


local ParentOverride = nil
function SpliceUI.SetParentGui(gui) ParentOverride = gui end

local function New(className, props, children)
  local inst = Instance.new(className)
  if props then for k,v in pairs(props) do inst[k]=v end end
  if children then for _,c in ipairs(children) do c.Parent = inst end end
  return inst
end
local function PlayTween(obj, info, goal)
  local t = TweenService:Create(obj, info, goal) t:Play() return t
end
local function StyleGlass(frame)
  frame.BackgroundColor3 = ActiveTheme.Colors.glass
  frame.BackgroundTransparency = ActiveTheme.Transparency.glass
  frame.BorderSizePixel = 0
  New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent = frame
  New("UIStroke",{ApplyStrokeMode=Enum.ApplyStrokeMode.Border, Color=ActiveTheme.Colors.stroke, Thickness=1, Transparency=0.35}).Parent = frame
end
local function AddShadow(parent, transparency)
  local f = New("Frame", {
    Name="_Shadow", BackgroundColor3=ActiveTheme.Colors.shadow,
    BackgroundTransparency = transparency or ActiveTheme.ShadowTransparency,
    BorderSizePixel=0, Size=UDim2.fromScale(1,1),
    ZIndex = math.max(1, (parent.ZIndex or 2) - 1)
  })
  New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent = f
  f.Parent = parent
  return f
end
local function MakeDraggable(frame, handle)
  local dragging, start, startPos = false, nil, nil
  local h = handle or frame
  h.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
      dragging=true; start=i.Position; startPos=frame.Position
      i.Changed:Connect(function() if i.UserInputState==Enum.UserInputState.End then dragging=false end end)
    end
  end)
  h.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
      local d = i.Position - start
      frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
  end)
end

-- Ícones vetoriais (sem asset): X e traço
local function PaintXIcon(btn: GuiButton)
    local a = Instance.new("Frame")
    a.Size = UDim2.new(0, 14, 0, 2)
    a.AnchorPoint = Vector2.new(0.5, 0.5)
    a.Position = UDim2.fromScale(0.5, 0.5)
    a.BackgroundColor3 = Color3.new(1,1,1)
    a.BorderSizePixel = 0
    a.Rotation = 45
    a.ZIndex = btn.ZIndex + 1
    a.Parent = btn

    local b = a:Clone()
    b.Rotation = -45
    b.Parent = btn
end

local function PaintMinusIcon(btn: GuiButton)
    local m = Instance.new("Frame")
    m.Size = UDim2.new(0, 14, 0, 2)
    m.AnchorPoint = Vector2.new(0.5, 0.5)
    m.Position = UDim2.fromScale(0.5, 0.5)
    m.BackgroundColor3 = Color3.new(1,1,1)
    m.BorderSizePixel = 0
    m.ZIndex = btn.ZIndex + 1
    m.Parent = btn
end


local function resolveParent()
  if ParentOverride and ParentOverride.Parent then return ParentOverride end
  local ok,h = pcall(function() if typeof(gethui)=="function" then return gethui() end end)
  if ok and typeof(h)=="Instance" then return h end
  local ok2,h2 = pcall(function() if typeof(get_hidden_gui)=="function" then return get_hidden_gui() end end)
  if ok2 and typeof(h2)=="Instance" then return h2 end
  local core = game:GetService("CoreGui")
  if core then return core end
  return PLAYER_GUI
end

local function createRoot(name)
  local sg = Instance.new("ScreenGui")
  sg.Name=name; sg.ResetOnSpawn=false; sg.IgnoreGuiInset=true
  sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; sg.DisplayOrder=10
  local scale = Instance.new("UIScale") scale.Scale=1 scale.Parent=sg

  local parent = resolveParent()
  if parent==game:GetService("CoreGui") then
    pcall(function() if syn and syn.protect_gui then syn.protect_gui(sg) end end)
  end
  sg.Parent = parent
  return sg, scale
end

function SpliceUI.setTheme(n) if Themes[n] then ActiveTheme = Themes[n] end end
function SpliceUI.setAccent(c)
  ActiveTheme.Colors.accent = c
end

local State = {}
function SpliceUI.SetState(k,v) State[k]=v end
function SpliceUI.GetState(k,default) local v=State[k]; if v==nil then return default end; return v end

---------------------------------------------------------------------
-- Window + Tabs
---------------------------------------------------------------------
local Window = {} Window.__index = Window
function Window.new(opts)
  local root, scale = createRoot("SpliceUI")
  local container = New("Frame", {Name="Window", Size=opts.size or UDim2.fromOffset(620,480),
    Position=opts.position or UDim2.fromScale(0.5,0.5), AnchorPoint=Vector2.new(0.5,0.5),
    BackgroundTransparency=1 }); container.Parent = root

  local panel = New("Frame",{Name="Panel", Size=UDim2.fromScale(1,1), BackgroundTransparency=1})
  panel.Parent = container

  local bg = New("Frame",{Name="Glass", Size=UDim2.fromScale(1,1), BorderSizePixel=0, ZIndex=2})
  StyleGlass(bg) bg.Parent=panel AddShadow(bg, ActiveTheme.ShadowTransparency)

  local top = New("Frame",{Name="Topbar", BackgroundColor3=ActiveTheme.Colors.panel,
    BackgroundTransparency=ActiveTheme.Transparency.panel, Size=UDim2.new(1,0,0,42), ZIndex=3})
  New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent=top
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.55}).Parent=top
  top.Parent = bg

  local title = New("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-120,1,0), Position=UDim2.fromOffset(16,0),
    Font=ActiveTheme.Font, Text=opts.title or "splice.lol", TextColor3=ActiveTheme.Colors.text,
    TextXAlignment=Enum.TextXAlignment.Left, TextSize=18, ZIndex=4})
  title.Parent = top

  local btnClose = New("TextButton",{AutoButtonColor=false, Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-36,0.5,0),
    AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=ActiveTheme.Colors.accent, BackgroundTransparency=0.05,
    Text="✕", TextColor3=Color3.new(1,1,1), Font=ActiveTheme.Font, TextSize=16, ZIndex=5})
  New("UICorner",{CornerRadius=UDim.new(0,10)}).Parent=btnClose
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.6}).Parent=btnClose
  btnClose.Parent = top

  PaintXIcon(btnclose)

  local btnMin = New("TextButton",{AutoButtonColor=false, Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-72,0.5,0),
    AnchorPoint=Vector2.new(0.5,0.5), BackgroundColor3=ActiveTheme.Colors.panel,
    BackgroundTransparency=ActiveTheme.Transparency.panel, Text="–", TextColor3=ActiveTheme.Colors.text,
    Font=ActiveTheme.Font, TextSize=16, ZIndex=5})
  New("UICorner",{CornerRadius=UDim.new(0,10)}).Parent=btnMin
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.6}).Parent=btnMin
  btnMin.Parent = top

  PaintMinusIcon(btnMin)

  -- Conteúdo com scroll
  local content = Instance.new("ScrollingFrame")
  content.Name="Content"; content.BackgroundTransparency=1
  content.Size=UDim2.new(1,-24,1,-58); content.Position=UDim2.fromOffset(12,46)
  content.BorderSizePixel=0; content.ZIndex=2
  content.ScrollingDirection = Enum.ScrollingDirection.Y
  content.AutomaticCanvasSize = Enum.AutomaticSize.Y
  content.CanvasSize = UDim2.new()
  content.ScrollBarImageTransparency = 0.6
  content.ClipsDescendants=true
  content.Parent = bg

  local contentLayout = Instance.new("UIListLayout")
  contentLayout.Padding = UDim.new(0,10)
  contentLayout.FillDirection = Enum.FillDirection.Vertical
  contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
  contentLayout.Parent = content

  MakeDraggable(container, top)
  local minimized=false
  btnMin.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
      PlayTween(content, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size=UDim2.new(1,-24,0,0)})
      PlayTween(bg, TweenInfo.new(0.22), {Size=UDim2.new(1,0,0,42)})
    else
      PlayTween(content, TweenInfo.new(0.22), {Size=UDim2.new(1,-24,1,-58)})
      PlayTween(bg, TweenInfo.new(0.22), {Size=UDim2.fromScale(1,1)})
    end
  end)
  btnClose.MouseButton1Click:Connect(function() root:Destroy() end)

  local self = setmetatable({
    Gui=root, Window=container, Panel=bg, Topbar=top, Content=content,
    Tabs=nil, _scale=scale, ActiveTab=nil
  }, Window)

  self.Tabs = SpliceUI.Tabs(content, {})
  return self
end

function Window:SetScale(s) if self._scale then self._scale.Scale = math.clamp(s,0.7,1.5) end end

function Window:AddSection(titleText: string, tabName: string?)
    local dest: Instance = self.Content
    local target = tabName or self.ActiveTab
    if self.Tabs and target and self.Tabs.Pages[target] then
        dest = self.Tabs.Pages[target]
    end

    local card = New("Frame", {
        BackgroundColor3 = ActiveTheme.Colors.panel,
        BackgroundTransparency = ActiveTheme.Transparency.panel,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ClipsDescendants = true,
        ZIndex = 8,
    })
    New("UICorner", {CornerRadius = UDim.new(0, ActiveTheme.Corner)}).Parent = card
    New("UIStroke", {Color = ActiveTheme.Colors.stroke, Transparency = 0.65}).Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 12)
    pad.PaddingRight  = UDim.new(0, 12)
    pad.PaddingTop    = UDim.new(0, 10)
    pad.PaddingBottom = UDim.new(0, 10)
    pad.Parent = card

    local header = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,22), ZIndex=9})
    header.Parent = card
    New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,-8,1,0),
        Font = ActiveTheme.Font,
        Text = titleText or "Seção",
        TextColor3 = ActiveTheme.Colors.subtext,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 15,
        ZIndex = 9,
    }).Parent = header

    New("Frame", {
        BackgroundColor3 = ActiveTheme.Colors.stroke,
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Size = UDim2.new(1,0,0,1),
        ZIndex = 9,
    }).Parent = card

    local body = New("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0,0),
        AutomaticSize = Enum.AutomaticSize.Y,
        ZIndex = 9,
    })
    body.Parent = card

    New("UIListLayout", {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
    }).Parent = body

    card.Parent = dest
    return body
end


function SpliceUI.Tabs(parent, tabNames)
  local row = New("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,40)})
  row.Parent = parent
  New("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8), SortOrder=Enum.SortOrder.LayoutOrder}).Parent=row

  -- páginas (conteúdo) – dentro do Content que já tem scroll
  local pages = New("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Name="Pages"})
  pages.Parent = parent

  local tabPages, tabs, current = {}, {}, nil
  local function selectTab(name)
    current = name
    for nm,btn in pairs(tabs) do
      local active = (nm==name)
      PlayTween(btn, TweenInfo.new(0.12), {TextColor3 = active and ActiveTheme.Colors.accent or ActiveTheme.Colors.text})
      if tabPages[nm] then tabPages[nm].Visible = active end
    end
  end

  local function addTab(name)
    if tabs[name] then return tabPages[name] end
    local btn = New("TextButton",{AutoButtonColor=false, BackgroundColor3=ActiveTheme.Colors.panel,
      BackgroundTransparency=ActiveTheme.Transparency.panel, Size=UDim2.fromOffset(120,36),
      Text=name, Font=ActiveTheme.Font, TextSize=16, TextColor3=ActiveTheme.Colors.text})
    New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent=btn
    New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.6}).Parent=btn
    btn.Parent=row

    local page = New("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Visible=false, Name=name})
    New("UIListLayout",{Padding=UDim.new(0,8)}).Parent=page
    page.Parent = pages

    btn.MouseEnter:Connect(function() PlayTween(btn, TweenInfo.new(0.1), {BackgroundColor3=ActiveTheme.Colors.glass, BackgroundTransparency=ActiveTheme.Transparency.glass}) end)
    btn.MouseLeave:Connect(function() PlayTween(btn, TweenInfo.new(0.12), {BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel}) end)
    btn.MouseButton1Click:Connect(function() selectTab(name) end)

    tabs[name]=btn; tabPages[name]=page
    if not current then selectTab(name) end
    return page
  end

  for _,n in ipairs(tabNames) do addTab(n) end

  return { Instance=row, Pages=tabPages, Select=selectTab, Add=addTab }
end

---------------------------------------------------------------------
-- Componentes
---------------------------------------------------------------------
function SpliceUI.Label(parent: Instance, text: string, opts: {muted: boolean?, size: number?}?)
    opts = opts or {}
    local lbl = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),          -- altura automática
        AutomaticSize = Enum.AutomaticSize.Y,  -- <<< cresce conforme o texto
        Font = ActiveTheme.Font,
        Text = text or "",
        TextColor3 = (opts.muted and ActiveTheme.Colors.subtext) or ActiveTheme.Colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        LineHeight = 1.1,
        TextSize = opts.size or 14,
    })
    -- padding inferior suave para não “grudar”
    local pad = Instance.new("UIPadding")
    pad.PaddingBottom = UDim.new(0, 2)
    pad.Parent = lbl

    lbl.Parent = parent
    return lbl
end


function SpliceUI.Button(parent, opts)
  local btn = New("TextButton",{AutoButtonColor=false, BackgroundColor3=ActiveTheme.Colors.panel,
    BackgroundTransparency=ActiveTheme.Transparency.panel, Size=UDim2.new(1,0,0,36),
    Text=opts.text or "Button", Font=ActiveTheme.Font, TextSize=16, TextColor3=ActiveTheme.Colors.text})
  New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent=btn
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent=btn
  btn.MouseEnter:Connect(function() PlayTween(btn, TweenInfo.new(0.12), {BackgroundColor3=ActiveTheme.Colors.glass, BackgroundTransparency=ActiveTheme.Transparency.glass}) end)
  btn.MouseLeave:Connect(function() PlayTween(btn, TweenInfo.new(0.2), {BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel}) end)
  btn.MouseButton1Down:Connect(function() PlayTween(btn, TweenInfo.new(0.08), {TextColor3 = ActiveTheme.Colors.accent}) end)
  btn.MouseButton1Up:Connect(function() PlayTween(btn, TweenInfo.new(0.12), {TextColor3 = ActiveTheme.Colors.text}) end)
  btn.Parent=parent; return btn
end

function SpliceUI.Toggle(parent, opts)
  local id = opts.key or ("toggle_"..tostring(math.random(1,1e9)))
  local value = SpliceUI.GetState(id, opts.default==true)

  local frame = New("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,36)})
  local label = New("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-56,1,0), Font=ActiveTheme.Font,
    Text=opts.text or "Toggle", TextColor3=ActiveTheme.Colors.text, TextXAlignment=Enum.TextXAlignment.Left, TextSize=16})
  label.Parent=frame

  local btn = New("TextButton",{AutoButtonColor=false, BackgroundColor3=value and ActiveTheme.Colors.accent or ActiveTheme.Colors.panel,
    BackgroundTransparency=value and 0.05 or ActiveTheme.Transparency.panel, Size=UDim2.fromOffset(44,24),
    Position=UDim2.new(1,-44,0.5,0), AnchorPoint=Vector2.new(0,0.5), Text=""})
  New("UICorner",{CornerRadius=UDim.new(0,12)}).Parent=btn
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent=btn
  btn.Parent=frame

  local knob = New("Frame",{BackgroundColor3=Color3.new(1,1,1), Size=UDim2.fromOffset(18,18),
    Position=value and UDim2.fromOffset(24,3) or UDim2.fromOffset(3,3), BorderSizePixel=0})
  New("UICorner",{CornerRadius=UDim.new(0,9)}).Parent=knob
  knob.Parent=btn

  local changed = Instance.new("BindableEvent")

  local function set(v)
    value=v; SpliceUI.SetState(id,value)
    PlayTween(btn, TweenInfo.new(0.15), {BackgroundColor3=value and ActiveTheme.Colors.accent or ActiveTheme.Colors.panel,
      BackgroundTransparency=value and 0.05 or ActiveTheme.Transparency.panel})
    PlayTween(knob, TweenInfo.new(0.15), {Position=value and UDim2.fromOffset(24,3) or UDim2.fromOffset(3,3)})
    changed:Fire(value)
  end

  btn.MouseButton1Click:Connect(function() set(not value) end)
  frame.Parent=parent
  return { Instance=frame, Get=function() return value end, Set=set, Changed=changed.Event }
end

function SpliceUI.Slider(parent, opts)
  local id = opts.key or ("slider_"..tostring(math.random(1,1e9)))
  local min = opts.min or 0; local max = opts.max or 100; local step = opts.step or 1
  local value = SpliceUI.GetState(id, opts.default or min)
  local frame = New("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,46)}); frame.Parent=parent

  local changed = Instance.new("BindableEvent")

  local top = New("Frame",{BackgroundTransparency=1, Size=UDim2.new(1,0,0,22)}); top.Parent=frame
  local label = New("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(1,-60,1,0), Font=ActiveTheme.Font,
    Text=opts.text or "Slider", TextColor3=ActiveTheme.Colors.text, TextXAlignment=Enum.TextXAlignment.Left, TextSize=16})
  label.Parent=top
  local valLabel = New("TextLabel",{BackgroundTransparency=1, Size=UDim2.new(0,60,1,0), Position=UDim2.new(1,-60,0,0),
    Font=ActiveTheme.Font, Text=tostring(value), TextColor3=ActiveTheme.Colors.subtext, TextXAlignment=Enum.TextXAlignment.Right, TextSize=14})
  valLabel.Parent=top

  local bar = New("Frame",{BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel,
    Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,0,28), BorderSizePixel=0})
  New("UICorner",{CornerRadius=UDim.new(0,6)}).Parent=bar
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent=bar
  bar.Parent=frame

  local fill = New("Frame",{BackgroundColor3=ActiveTheme.Colors.accent, BackgroundTransparency=0.05,
    Size=UDim2.new((value-min)/(max-min),0,1,0), BorderSizePixel=0})
  New("UICorner",{CornerRadius=UDim.new(0,6)}).Parent=fill
  fill.Parent=bar

  local knob = New("Frame",{BackgroundColor3=Color3.new(1,1,1), Size=UDim2.fromOffset(14,14),
    AnchorPoint=Vector2.new(0.5,0.5), Position=UDim2.new((value-min)/(max-min),0,0.5,0), BorderSizePixel=0})
  New("UICorner",{CornerRadius=UDim.new(0,7)}).Parent=knob
  knob.Parent=bar

  local sliding=false
  local function set(v)
    v = math.clamp(v,min,max)
    if step>0 then v = math.floor((v-min)/step+0.5)*step + min end
    value=v; SpliceUI.SetState(id,value); valLabel.Text=tostring(value)
    PlayTween(fill, TweenInfo.new(0.08), {Size=UDim2.new((value-min)/(max-min),0,1,0)})
    PlayTween(knob, TweenInfo.new(0.08), {Position=UDim2.new((value-min)/(max-min),0,0.5,0)})
    changed:Fire(value)
  end

  bar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
      sliding=true
      local rel=(i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X
      set(min+rel*(max-min))
    end
  end)
  UserInputService.InputChanged:Connect(function(i)
    if sliding and i.UserInputType==Enum.UserInputType.MouseMovement then
      local rel=(i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X
      set(min+rel*(max-min))
    end
  end)
  UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then sliding=false end end)

  return { Instance=frame, Get=function() return value end, Set=set, Changed=changed.Event }
end

function SpliceUI.Input(parent, opts)
  local id = opts.key or ("input_"..tostring(math.random(1,1e9)))
  local value = SpliceUI.GetState(id, "")
  local box = New("TextBox",{BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel,
    Size=UDim2.new(1,0,0,36), PlaceholderText=opts.placeholder or "Digite...",
    Text=value, Font=ActiveTheme.Font, TextSize=16, TextColor3=ActiveTheme.Colors.text,
    PlaceholderColor3=ActiveTheme.Colors.subtext, ClearTextOnFocus=false})
  New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent=box
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent=box
  box.FocusLost:Connect(function() SpliceUI.SetState(id, box.Text) end)
  box.Parent=parent
  return { Instance=box, Get=function() return box.Text end, Set=function(t) box.Text=t SpliceUI.SetState(id,t) end, Changed=box:GetPropertyChangedSignal("Text") }
end

function SpliceUI.Dropdown(parent: Instance, opts: {text: string, items: {string}, default: string?, key: string?})
    local id = opts.key or ("dropdown_"..HttpService:GenerateGUID(false))
    local value = SpliceUI.GetState(id, opts.default or (opts.items[1] or ""))

    local frame = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,36)})
    local label = New("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.35,0,1,0),
        Font = ActiveTheme.Font,
        Text = opts.text or "Dropdown",
        TextColor3 = ActiveTheme.Colors.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 16,
    }); label.Parent = frame

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
        ClipsDescendants = false,
        ZIndex = 20,
    })
    New("UICorner", {CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent = box
    New("UIStroke", {Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent = box
    box.Parent = frame

    -- overlay de topo na MESMA ScreenGui
    local overlay = getOverlayFor(box)
    local listFrame = Instance.new("Frame")
    listFrame.Name = "List"
    listFrame.BackgroundColor3 = ActiveTheme.Colors.glass
    listFrame.BackgroundTransparency = ActiveTheme.Transparency.glass
    listFrame.BorderSizePixel = 0
    listFrame.Visible = false
    listFrame.Size = UDim2.fromOffset(0,0)
    listFrame.ZIndex = 2000
    listFrame.Parent = overlay

    New("UICorner", {CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent = listFrame
    New("UIStroke", {Color=ActiveTheme.Colors.stroke, Transparency=0.4}).Parent = listFrame

    local uilist = New("UIListLayout", {Padding=UDim.new(0,4)}); uilist.Parent = listFrame

    local function positionList()
        local p = box.AbsolutePosition
        local s = box.AbsoluteSize
        listFrame.Position = UDim2.fromOffset(p.X, p.Y + s.Y + 4)
        listFrame.Size = UDim2.fromOffset(s.X, listFrame.Size.Y.Offset)
    end

    local function open()
        positionList()
        listFrame.Visible = true
        TweenService:Create(
            listFrame,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.fromOffset(box.AbsoluteSize.X, #opts.items*30 + 10)}
        ):Play()
    end

    local function close()
        local tw = TweenService:Create(
            listFrame,
            TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {Size = UDim2.fromOffset(box.AbsoluteSize.X, 0)}
        )
        tw.Completed:Connect(function() listFrame.Visible = false end)
        tw:Play()
    end

    box.MouseButton1Click:Connect(function()
        if listFrame.Visible then close() else open() end
    end)

    -- reposiciona se a tela mudar / enquanto visível
    RunService.RenderStepped:Connect(function()
        if listFrame.Visible then positionList() end
    end)

    -- fecha ao clicar fora
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe or not listFrame.Visible then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        local pos = input.Position
        local a = listFrame.AbsolutePosition
        local s = listFrame.AbsoluteSize
        local inList = (pos.X>=a.X and pos.X<=a.X+s.X and pos.Y>=a.Y and pos.Y<=a.Y+s.Y)

        local bA = box.AbsolutePosition
        local bS = box.AbsoluteSize
        local inBox = (pos.X>=bA.X and pos.X<=bA.X+bS.X and pos.Y>=bA.Y and pos.Y<=bA.Y+bS.Y)

        if not inList and not inBox then
            close()
        end
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
            ZIndex = 2001,
        })
        New("UICorner", {CornerRadius=UDim.new(0,10)}).Parent = opt
        New("UIStroke", {Color=ActiveTheme.Colors.stroke, Transparency=0.6}).Parent = opt
        opt.MouseEnter:Connect(function()
            PlayTween(opt, TweenInfo.new(0.08), {BackgroundColor3=ActiveTheme.Colors.glass, BackgroundTransparency=ActiveTheme.Transparency.glass})
        end)
        opt.MouseLeave:Connect(function()
            PlayTween(opt, TweenInfo.new(0.12), {BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel})
        end)
        opt.MouseButton1Click:Connect(function() set(item) end)
        opt.Parent = listFrame
    end

    frame.Parent = parent
    return {
        Instance = frame,
        Get = function() return value end,
        Set = set,
        Changed = Instance.new("BindableEvent"),
    }
end


  local function set(v)
    value=v; SpliceUI.SetState(id,value); box.Text=value; close()
  end

  for _,item in ipairs(opts.items) do
    local opt = New("TextButton",{AutoButtonColor=false, BackgroundColor3=ActiveTheme.Colors.panel,
      BackgroundTransparency=ActiveTheme.Transparency.panel, Size=UDim2.new(1,-8,0,26), Text=item,
      Font=ActiveTheme.Font, TextSize=14, TextColor3=ActiveTheme.Colors.text, ZIndex=301})
    New("UICorner",{CornerRadius=UDim.new(0,10)}).Parent=opt
    New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.6}).Parent=opt
    opt.MouseEnter:Connect(function() PlayTween(opt, TweenInfo.new(0.08), {BackgroundColor3=ActiveTheme.Colors.glass, BackgroundTransparency=ActiveTheme.Transparency.glass}) end)
    opt.MouseLeave:Connect(function() PlayTween(opt, TweenInfo.new(0.12), {BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel}) end)
    opt.MouseButton1Click:Connect(function() set(item) end)
    opt.Parent=listFrame
  end

  frame.Parent=parent
  return { Instance=frame, Get=function() return value end, Set=set, Changed=Instance.new("BindableEvent").Event }
end)

---------------------------------------------------------------------
-- Notificações (stack com contador)
---------------------------------------------------------------------
local notifyRoot, notifyList
local function getNotifyRoot()
  if notifyRoot and notifyRoot.Parent then return notifyRoot, notifyList end
  notifyRoot = Instance.new("ScreenGui")
  notifyRoot.Name="SpliceUI_Notify"; notifyRoot.ResetOnSpawn=false; notifyRoot.IgnoreGuiInset=true
  notifyRoot.ZIndexBehavior=Enum.ZIndexBehavior.Sibling; notifyRoot.DisplayOrder=9999
  notifyRoot.Parent = resolveParent()
  notifyList = Instance.new("Frame")
  notifyList.Name="List"; notifyList.AnchorPoint=Vector2.new(1,1)
  notifyList.Position=UDim2.new(1,-16,1,-16); notifyList.Size=UDim2.fromOffset(360,0)
  notifyList.BackgroundTransparency=1; notifyList.AutomaticSize=Enum.AutomaticSize.Y
  notifyList.Parent=notifyRoot
  local layout = Instance.new("UIListLayout")
  layout.FillDirection=Enum.FillDirection.Vertical
  layout.VerticalAlignment=Enum.VerticalAlignment.Bottom
  layout.HorizontalAlignment=Enum.HorizontalAlignment.Right
  layout.Padding=UDim.new(0,8); layout.SortOrder=Enum.SortOrder.LayoutOrder
  layout.Parent=notifyList
  return notifyRoot, notifyList
end

-- === SUBSTITUIR a função SpliceUI.Notify por esta ===
function SpliceUI.Notify(message, duration)
    duration = tonumber(duration) or 2
    local _, list = getNotifyRoot()

    local toast = Instance.new("Frame")
    toast.Name = "Toast"
    toast.Size = UDim2.fromOffset(360,56)
    toast.BackgroundColor3 = ActiveTheme.Colors.glass
    toast.BackgroundTransparency = ActiveTheme.Transparency.glass
    toast.BorderSizePixel = 0
    toast.LayoutOrder = -time()
    toast.Parent = list

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0,12)
    corner.Parent = toast

    local stroke = Instance.new("UIStroke")
    stroke.Color = ActiveTheme.Colors.stroke
    stroke.Transparency = 0.4
    stroke.Parent = toast

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1,-74,1,0)
    label.Position = UDim2.fromOffset(14,0)
    label.Font = ActiveTheme.Font
    label.Text = message
    label.TextColor3 = ActiveTheme.Colors.text
    label.TextWrapped = true
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextSize = 16
    label.Parent = toast

    local counter = Instance.new("TextLabel")
    counter.BackgroundTransparency = 1
    counter.Size = UDim2.fromOffset(60,20)
    counter.Position = UDim2.new(1,-62,0,8)
    counter.Font = ActiveTheme.Font
    counter.TextColor3 = ActiveTheme.Colors.subtext
    counter.TextSize = 14
    counter.TextXAlignment = Enum.TextXAlignment.Right
    counter.Text = string.format("%.1fs", duration)
    counter.Parent = toast

    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = ActiveTheme.Colors.accent
    bar.BackgroundTransparency = 0.1
    bar.BorderSizePixel = 0
    bar.AnchorPoint = Vector2.new(0,1)
    bar.Position = UDim2.new(0,14,1,-8)
    bar.Size = UDim2.new(0,0,0,4)
    bar.Parent = toast
    local barC = Instance.new("UICorner")
    barC.CornerRadius = UDim.new(0,2)
    barC.Parent = bar

    -- fade-in
    toast.BackgroundTransparency = 1
    label.TextTransparency = 1
    counter.TextTransparency = 1
    TweenService:Create(toast, TweenInfo.new(0.18), {BackgroundTransparency=ActiveTheme.Transparency.glass}):Play()
    TweenService:Create(label, TweenInfo.new(0.18), {TextTransparency=0}):Play()
    TweenService:Create(counter, TweenInfo.new(0.18), {TextTransparency=0}):Play()
    TweenService:Create(bar, TweenInfo.new(duration), {Size=UDim2.new(1,-28,0,4)}):Play()

    -- contador + desligamento garantido
    local endTime = time() + duration
    local updConn
    updConn = RunService.Heartbeat:Connect(function()
        local left = math.max(0, endTime - time())
        counter.Text = string.format("%.1fs", left)
        if left <= 0 and updConn then updConn:Disconnect() updConn=nil end
    end)

    local function fadeOut()
        if updConn then updConn:Disconnect() updConn=nil end
        local t1 = TweenService:Create(toast, TweenInfo.new(0.18), {BackgroundTransparency=1})
        local t2 = TweenService:Create(label, TweenInfo.new(0.18), {TextTransparency=1})
        local t3 = TweenService:Create(counter, TweenInfo.new(0.18), {TextTransparency=1})
        t1.Completed:Connect(function() if toast then toast:Destroy() end end)
        t1:Play(); t2:Play(); t3:Play()
    end

    -- dispara sempre, mesmo se Heartbeat parar
    task.delay(duration, fadeOut)

    return toast
end


---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
function SpliceUI.CreateWindow(opts) return Window.new(opts) end

---------------------------------------------------------------------
-- Adapter Kavo
---------------------------------------------------------------------
local Library = {}

local ThemeMap = {
  DarkTheme = { theme="dark",  accent=Color3.fromRGB(255,32,32) },
  LightTheme= { theme="light", accent=Color3.fromRGB(255,32,32) },
  GrapeTheme= { theme="dark",  accent=Color3.fromRGB(160,70,200) },
  BloodTheme= { theme="dark",  accent=Color3.fromRGB(220,40,40) },
  Ocean     = { theme="dark",  accent=Color3.fromRGB(0,160,255) },
  Midnight  = { theme="dark",  accent=Color3.fromRGB(255,32,32) },
  Sentinel  = { theme="dark",  accent=Color3.fromRGB(255,32,32) },
  Synapse   = { theme="dark",  accent=Color3.fromRGB(255,32,32) },
}

local WindowMT = {} WindowMT.__index = WindowMT
local TabMT    = {} TabMT.__index    = TabMT
local SectionMT= {} SectionMT.__index= SectionMT

local function applyTheme(name)
  local m = ThemeMap[name or "DarkTheme"] or ThemeMap.DarkTheme
  SpliceUI.setTheme(m.theme); SpliceUI.setAccent(m.accent)
end

function Library.CreateLib(title, themeName)
  applyTheme(themeName)
  local self = {}
  self._win  = SpliceUI.CreateWindow({ title = title or "splice.lol", size = UDim2.fromOffset(620,500) })
  self._tabs = {}
  return setmetatable(self, WindowMT)
end

function WindowMT:NewTab(name)
  if not self._win.Tabs.Pages[name] then
    self._win.Tabs.Add(name)
  end
  local obj = setmetatable({ _win=self._win, _name=name }, TabMT)
  self._tabs[name]=obj
  self._win.Tabs.Select(name)
  return obj
end

function TabMT:NewSection(title)
  self._win.Tabs.Select(self._name)
  local body = self._win:AddSection(title, self._name)
  return setmetatable({ _parent=body }, SectionMT)
end

-- Widgets (callbacks no estilo Kavo)
function SectionMT:NewButton(text, info, callback)
  local b = SpliceUI.Button(self._parent, {text=tostring(text or "Button")})
  b.MouseButton1Click:Connect(function() if typeof(callback)=="function" then callback() end end)
  return b
end

function SectionMT:NewToggle(text, info, callback)
  local t = SpliceUI.Toggle(self._parent, {text=tostring(text or "Toggle"), default=false})
  t.Changed:Connect(function() if typeof(callback)=="function" then callback(t.Get()) end end)
  return t
end

function SectionMT:NewSlider(text, info, min, max, callback)
  local s = SpliceUI.Slider(self._parent, {text=tostring(text or "Slider"), min=tonumber(min) or 0, max=tonumber(max) or 100, default=tonumber(min) or 0})
  s.Changed:Connect(function() if typeof(callback)=="function" then callback(s.Get()) end end)
  return s
end

function SectionMT:NewDropdown(text, info, list, callback)
  local d = SpliceUI.Dropdown(self._parent, {text=tostring(text or "Dropdown"), items=(typeof(list)=="table" and list or {"A","B"}), default=(typeof(list)=="table" and list[1]) or "A"})
  local old = d.Set
  d.Set = function(v) old(v); if typeof(callback)=="function" then callback(v) end end
  return d
end

function SectionMT:NewTextBox(text, placeholder, callback)
  SpliceUI.Label(self._parent, tostring(text or "Textbox"))
  local i = SpliceUI.Input(self._parent, {placeholder = tostring(placeholder or "Digite...")})
  i.Changed:Connect(function() if typeof(callback)=="function" then callback(i.Get()) end end)
  i.Instance.FocusLost:Connect(function() if typeof(callback)=="function" then callback(i.Get()) end end)
  return i
end

function SectionMT:NewLabel(text) return SpliceUI.Label(self._parent, tostring(text or "Label")) end
function SectionMT:NewKeybind(text, info, defaultKey, callback)
  SpliceUI.Label(self._parent, tostring(text or "Keybind"))
  local key = defaultKey or Enum.KeyCode.RightShift
  UserInputService.InputBegan:Connect(function(i,gpe) if gpe then return end; if i.KeyCode==key and typeof(callback)=="function" then callback() end end)
end
function SectionMT:NewColorPicker(text, info, defaultColor, callback)
  local choices = {"Vermelho","Ciano","Verde","Roxo"}
  local d = SpliceUI.Dropdown(self._parent, {text=tostring(text or "Color"), items=choices, default="Vermelho"})
  local function map(c)
    if c=="Ciano" then return Color3.fromRGB(0,220,255) elseif c=="Verde" then return Color3.fromRGB(40,220,120) elseif c=="Roxo" then return Color3.fromRGB(170,90,255) else return Color3.fromRGB(255,32,32) end
  end
  local old=d.Set; d.Set=function(v) old(v); if typeof(callback)=="function" then callback(map(v)) end end
  return d
end

-- API extra
function Library.Notify(msg, dur) SpliceUI.Notify(msg, dur or 2) end
function Library.SetParentGui(gui) SpliceUI.SetParentGui(gui) end

return Library

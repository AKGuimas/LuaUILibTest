-- UIlib.lua — Kavo-compatible, universal, estilo splice.lol
-- Uso (igual Kavo):
-- local Library = loadstring(game:HttpGet("RAW_URL/UIlib.lua"))()
-- local Window  = Library.CreateLib("Meu Jogo", "DarkTheme")
-- local Tab     = Window:NewTab("Geral")
-- local Sec     = Tab:NewSection("Ações")
-- Sec:NewButton("Executar", "", function() end)
-- Sec:NewToggle("God", "", function(v) end)
-- Sec:NewSlider("Speed", "0..100", 0, 100, function(v) end)
-- Sec:NewDropdown("Perfil", "", {"Padrão","Rápido"}, function(v) end)
-- Sec:NewTextBox("Comando", "Digite...", function(t) end)
-- Library.Notify("Olá!", 2)

-- ╭───────────────────────────────────────────────────────────────────────────╮
-- │ Serviços                                                                  │
-- ╰───────────────────────────────────────────────────────────────────────────╯
local TweenService        = game:GetService("TweenService")
local UserInputService    = game:GetService("UserInputService")
local RunService          = game:GetService("RunService")
local Players             = game:GetService("Players")
local HttpService         = game:GetService("HttpService")
local CoreGui             = game:GetService("CoreGui")

local LOCAL_PLAYER        = Players.LocalPlayer
local PLAYER_GUI          = LOCAL_PLAYER and LOCAL_PLAYER:FindFirstChildOfClass("PlayerGui")

-- ╭───────────────────────────────────────────────────────────────────────────╮
-- │ Núcleo visual (SpliceUI)                                                  │
-- ╰───────────────────────────────────────────────────────────────────────────╯
local SpliceUI = {}
SpliceUI.__index = SpliceUI

-- Tema
local Themes = {
  dark = {
    Name="dark",
    Colors={
      background = Color3.fromRGB(10,10,12),
      panel      = Color3.fromRGB(16,16,20),
      glass      = Color3.fromRGB(24,24,28),
      text       = Color3.fromRGB(235,235,240),
      subtext    = Color3.fromRGB(185,185,195),
      accent     = Color3.fromRGB(255,32,32),
      stroke     = Color3.fromRGB(60,60,70),
      shadow     = Color3.fromRGB(0,0,0),
    },
    Transparency = { panel=0.08, glass=0.22 },
    Corner = 14,
    ShadowTransparency = 0.6,
    Font = Enum.Font.Gotham,
  },
  light = {
    Name="light",
    Colors={
      background = Color3.fromRGB(245,246,248),
      panel      = Color3.fromRGB(255,255,255),
      glass      = Color3.fromRGB(255,255,255),
      text       = Color3.fromRGB(20,22,24),
      subtext    = Color3.fromRGB(100,104,112),
      accent     = Color3.fromRGB(255,32,32),
      stroke     = Color3.fromRGB(220,221,224),
      shadow     = Color3.fromRGB(0,0,0),
    },
    Transparency = { panel=0.0, glass=0.0 },
    Corner = 14,
    ShadowTransparency = 0.85,
    Font = Enum.Font.Gotham,
  }
}
local ActiveTheme = Themes.dark

-- Parent override (opcional)
local ParentOverride :: ScreenGui? = nil
function SpliceUI.SetParentGui(gui) ParentOverride = gui end

-- Utils
local function New(className, props, children)
  local inst = Instance.new(className)
  if props then for k,v in pairs(props) do (inst :: any)[k] = v end end
  if children then for _,c in ipairs(children) do c.Parent = inst end end
  return inst
end
local function T(obj, ti, goal)
  local t = TweenService:Create(obj, ti, goal); t:Play(); return t
end

local function AddShadow(parent: GuiObject, transparency)
  local s = New("Frame", {
    Name="_Shadow",
    BackgroundColor3 = ActiveTheme.Colors.shadow,
    BackgroundTransparency = transparency or ActiveTheme.ShadowTransparency,
    BorderSizePixel = 0,
    Size = UDim2.fromScale(1,1),
    ZIndex = math.max(1, (parent.ZIndex or 2) - 1),
  })
  s.Parent = parent
  New("UICorner", {CornerRadius=UDim.new(0, ActiveTheme.Corner)}).Parent = s
  return s
end

local function StyleGlass(frame: Frame)
  frame.BackgroundColor3 = ActiveTheme.Colors.glass
  frame.BackgroundTransparency = ActiveTheme.Transparency.glass
  frame.BorderSizePixel = 0
  New("UICorner", {CornerRadius=UDim.new(0, ActiveTheme.Corner)}).Parent = frame
  New("UIStroke", {
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    Color = ActiveTheme.Colors.stroke,
    Thickness = 1,
    Transparency = 0.35,
  }).Parent = frame
end

local function MakeDraggable(frame: Frame, handle: GuiObject?)
  local dragging, dragStart, startPos = false, nil, nil
  local h = handle or frame

  local function update(input)
    local d = input.Position - dragStart
    frame.Position = UDim2.new(
      frame.Position.X.Scale, startPos.X.Offset + d.X,
      frame.Position.Y.Scale, startPos.Y.Offset + d.Y
    )
  end

  h.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
      dragging = true
      dragStart = i.Position
      startPos  = frame.Position
      i.Changed:Connect(function()
        if i.UserInputState == Enum.UserInputState.End then dragging = false end
      end)
    end
  end)
  h.InputChanged:Connect(function(i)
    if (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) and dragging then
      update(i)
    end
  end)
end

-- Resolve parent universal (gethui/get_hidden_gui/CoreGui/PlayerGui)
local function resolveParent()
  if ParentOverride and ParentOverride.Parent then return ParentOverride end

  local ok,hui = pcall(function() if typeof(gethui)=="function" then return gethui() end end)
  if ok and typeof(hui)=="Instance" then return hui end
  local ok2,hidden = pcall(function() if typeof(get_hidden_gui)=="function" then return get_hidden_gui() end end)
  if ok2 and typeof(hidden)=="Instance" then return hidden end

  if CoreGui then return CoreGui end
  return PLAYER_GUI
end

-- Root ScreenGui
local function createRoot(name: string)
  local sg = Instance.new("ScreenGui")
  sg.Name = name
  sg.ResetOnSpawn = false
  sg.IgnoreGuiInset = true
  sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  sg.DisplayOrder = 10

  local sc = Instance.new("UIScale")
  sc.Scale = 1
  sc.Parent = sg

  local parent = resolveParent()
  if parent == CoreGui then
    pcall(function() if syn and typeof(syn.protect_gui)=="function" then syn.protect_gui(sg) end end)
  end
  sg.Parent = parent
  return sg, sc
end

-- Theme API
function SpliceUI.setTheme(name) if Themes[name] then ActiveTheme = Themes[name] end end
function SpliceUI.setAccent(c3) ActiveTheme.Colors.accent = c3 end

-- Estado simples
local State = {}
function SpliceUI.SetState(k,v) State[k]=v end
function SpliceUI.GetState(k,def) local v=State[k]; if v==nil then return def end; return v end

-- ╭───────────────────────────────────────────────────────────────────────────╮
-- │ Janela / Tabs                                                             │
-- ╰───────────────────────────────────────────────────────────────────────────╯
local Window = {}; Window.__index = Window

function Window.new(opts)
  local root, scale = createRoot("SpliceUI")
  local container = New("Frame", {
    Name="Window", Size=opts.size or UDim2.fromOffset(620, 480),
    Position=opts.position or UDim2.fromScale(.5,.5), AnchorPoint=Vector2.new(.5,.5),
    BackgroundTransparency=1,
  }); container.Parent = root

  local panel = New("Frame", {Name="Panel", Size=UDim2.fromScale(1,1), BackgroundTransparency=1}); panel.Parent = container
  local bg    = New("Frame", {Name="Glass", Size=UDim2.fromScale(1,1), ZIndex=2}); StyleGlass(bg); bg.Parent=panel; AddShadow(bg, ActiveTheme.ShadowTransparency)

  local topbar = New("Frame", {
    Name="Topbar", BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel,
    Size=UDim2.new(1,0,0,42), ZIndex=3
  })
  New("UICorner", {CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent = topbar
  New("UIStroke", {Color=ActiveTheme.Colors.stroke, Transparency=0.55}).Parent = topbar
  topbar.Parent = bg

  local title = New("TextLabel", {
    BackgroundTransparency=1, Size=UDim2.new(1,-120,1,0), Position=UDim2.fromOffset(16,0),
    Font=ActiveTheme.Font, Text=opts.title or "splice.lol", TextColor3=ActiveTheme.Colors.text,
    TextXAlignment=Enum.TextXAlignment.Left, TextSize=18, ZIndex=4
  }); title.Parent = topbar

  local closeBtn = New("TextButton", {
    AutoButtonColor=false, Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-36,.5,0), AnchorPoint=Vector2.new(.5,.5),
    BackgroundColor3=ActiveTheme.Colors.accent, BackgroundTransparency=0.05, Text="✕", TextColor3=Color3.new(1,1,1),
    Font=ActiveTheme.Font, TextSize=16, ZIndex=5
  })
  New("UICorner", {CornerRadius=UDim.new(0,10)}).Parent = closeBtn
  New("UIStroke", {Color=ActiveTheme.Colors.stroke, Transparency=0.6}).Parent = closeBtn
  closeBtn.Parent = topbar

  local minimizeBtn = New("TextButton", {
    AutoButtonColor=false, Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-72,.5,0), AnchorPoint=Vector2.new(.5,.5),
    BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel, Text="–", TextColor3=ActiveTheme.Colors.text,
    Font=ActiveTheme.Font, TextSize=16, ZIndex=5
  })
  New("UICorner", {CornerRadius=UDim.new(0,10)}).Parent = minimizeBtn
  New("UIStroke", {Color=ActiveTheme.Colors.stroke, Transparency=0.6}).Parent = minimizeBtn
  minimizeBtn.Parent = topbar

  -- Conteúdo (scroll)
  local content = Instance.new("ScrollingFrame")
  content.Name = "Content"
  content.BackgroundTransparency = 1
  content.Size = UDim2.new(1,-24,1,-58)
  content.Position = UDim2.fromOffset(12,46)
  content.ScrollingDirection = Enum.ScrollingDirection.Y
  content.AutomaticCanvasSize = Enum.AutomaticSize.Y
  content.CanvasSize = UDim2.new()
  content.ScrollBarImageTransparency = 0.6
  content.BorderSizePixel = 0
  content.ZIndex = 2
  content.Parent = bg

  local layout = Instance.new("UIListLayout")
  layout.Padding = UDim.new(0,10)
  layout.FillDirection = Enum.FillDirection.Vertical
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Parent = content

  MakeDraggable(container, topbar)

  local minimized = false
  minimizeBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
      T(content, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Size=UDim2.new(1,-24,0,0)})
      T(bg, TweenInfo.new(0.2), {Size=UDim2.new(1,0,0,42)})
    else
      T(content, TweenInfo.new(0.2), {Size=UDim2.new(1,-24,1,-58)})
      T(bg, TweenInfo.new(0.2), {Size=UDim2.fromScale(1,1)})
    end
  end)
  closeBtn.MouseButton1Click:Connect(function() root:Destroy() end)

  local self = setmetatable({
    Gui=root, Window=container, Panel=bg, Topbar=topbar, Content=content,
    Tabs=nil, _scale=scale, ActiveTab=nil, Key=opts.key or ("win_"..HttpService:GenerateGUID(false))
  }, Window)

  if opts.tabs and #opts.tabs>0 then
    self.Tabs = SpliceUI.Tabs(content, opts.tabs)
    self.ActiveTab = opts.tabs[1]
  end
  return self
end

function Window:SetScale(s) if self._scale then self._scale.Scale = math.clamp(s, 0.7, 1.6) end end

function Window:AddSection(titleText, tabName)
  local dest: Instance = self.Content
  local target = tabName or self.ActiveTab
  if self.Tabs and target and self.Tabs.Pages[target] then dest = self.Tabs.Pages[target] end

  local section = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y})
  local head = New("TextLabel", {
    BackgroundTransparency=1, Size=UDim2.new(1,0,0,20),
    Font=ActiveTheme.Font, Text=tostring(titleText or ""), TextColor3=ActiveTheme.Colors.subtext,
    TextXAlignment=Enum.TextXAlignment.Left, TextSize=14
  }); head.Parent = section

  local body = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y})
  body.Parent = section
  New("UIListLayout", {Padding=UDim.new(0,8), FillDirection=Enum.FillDirection.Vertical, SortOrder=Enum.SortOrder.LayoutOrder}).Parent = body

  section.Parent = dest
  return body
end

-- Tabs (com pages roláveis)
function SpliceUI.Tabs(parent: Instance, names: {string})
  local row = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,40)})
  row.Parent = parent
  New("UIListLayout", {FillDirection=Enum.FillDirection.Horizontal, Padding=UDim.new(0,8), SortOrder=Enum.SortOrder.LayoutOrder}).Parent=row

  local pages = Instance.new("ScrollingFrame")
  pages.Name = "Pages"
  pages.BackgroundTransparency = 1
  pages.Size = UDim2.new(1,0,0,0)
  pages.AutomaticSize = Enum.AutomaticSize.Y
  pages.ScrollingDirection = Enum.ScrollingDirection.Y
  pages.AutomaticCanvasSize = Enum.AutomaticSize.Y
  pages.CanvasSize = UDim2.new()
  pages.ScrollBarImageTransparency = 0.6
  pages.BorderSizePixel = 0
  pages.Parent = parent

  local tabPages, tabs, current = {}, {}, nil

  local function select(name)
    current = name
    for nm, btn in pairs(tabs) do
      local active = (nm == name)
      T(btn, TweenInfo.new(0.12), {TextColor3 = active and ActiveTheme.Colors.accent or ActiveTheme.Colors.text})
      if tabPages[nm] then tabPages[nm].Visible = active end
    end
  end

  local function addTab(name)
    if tabs[name] then return tabPages[name] end
    local btn = New("TextButton", {
      AutoButtonColor=false,
      BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel,
      Size=UDim2.fromOffset(120,36),
      Text=name, Font=ActiveTheme.Font, TextSize=16, TextColor3=ActiveTheme.Colors.text
    })
    New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent=btn
    New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.6}).Parent=btn
    btn.Parent = row
    btn.MouseEnter:Connect(function() T(btn, TweenInfo.new(0.1), {BackgroundColor3=ActiveTheme.Colors.glass, BackgroundTransparency=ActiveTheme.Transparency.glass}) end)
    btn.MouseLeave:Connect(function() T(btn, TweenInfo.new(0.12), {BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel}) end)
    btn.MouseButton1Click:Connect(function() select(name) end)

    local page = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,0), AutomaticSize=Enum.AutomaticSize.Y, Visible=false, Name=name})
    New("UIListLayout", {Padding=UDim.new(0,8)}).Parent = page
    page.Parent = pages

    tabs[name] = btn
    tabPages[name] = page
    if not current then select(name) end
    return page
  end

  for _,n in ipairs(names) do addTab(n) end

  return {Instance=row, Pages=tabPages, Select=select, Add=addTab}
end

-- ╭───────────────────────────────────────────────────────────────────────────╮
-- │ Componentes                                                               │
-- ╰───────────────────────────────────────────────────────────────────────────╯
function SpliceUI.Label(parent, text)
  local lbl = New("TextLabel", {
    BackgroundTransparency=1, Size=UDim2.new(1,0,0,20),
    Font=ActiveTheme.Font, Text=tostring(text or ""),
    TextColor3=ActiveTheme.Colors.subtext, TextXAlignment=Enum.TextXAlignment.Left, TextSize=14
  })
  lbl.Parent = parent
  return lbl
end

function SpliceUI.Button(parent, opts)
  local btn = New("TextButton", {
    AutoButtonColor=false,
    BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel,
    Size=UDim2.new(1,0,0,36),
    Text=opts and opts.text or "Button",
    Font=ActiveTheme.Font, TextSize=16, TextColor3=ActiveTheme.Colors.text
  })
  New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent = btn
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent = btn
  btn.MouseEnter:Connect(function() T(btn, TweenInfo.new(0.12), {BackgroundColor3=ActiveTheme.Colors.glass, BackgroundTransparency=ActiveTheme.Transparency.glass}) end)
  btn.MouseLeave:Connect(function() T(btn, TweenInfo.new(0.2),  {BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel}) end)
  btn.MouseButton1Down:Connect(function() T(btn, TweenInfo.new(0.08), {TextColor3 = ActiveTheme.Colors.accent}) end)
  btn.MouseButton1Up:Connect(function()   T(btn, TweenInfo.new(0.12), {TextColor3 = ActiveTheme.Colors.text}) end)
  btn.Parent = parent
  return btn
end

function SpliceUI.Toggle(parent, opts)
  local id    = (opts and opts.key) or ("toggle_"..HttpService:GenerateGUID(false))
  local value = SpliceUI.GetState(id, opts and (opts.default==true) or false)

  local frame = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,36)})

  local label = New("TextLabel", {
    BackgroundTransparency=1, Size=UDim2.new(1,-56,1,0),
    Font=ActiveTheme.Font, Text=(opts and opts.text) or "Toggle",
    TextColor3=ActiveTheme.Colors.text, TextXAlignment=Enum.TextXAlignment.Left, TextSize=16
  }); label.Parent = frame

  local btn = New("TextButton", {
    AutoButtonColor=false,
    BackgroundColor3 = value and ActiveTheme.Colors.accent or ActiveTheme.Colors.panel,
    BackgroundTransparency = value and 0.05 or ActiveTheme.Transparency.panel,
    Size=UDim2.fromOffset(44,24), Position=UDim2.new(1,-44,0.5,0),
    AnchorPoint=Vector2.new(0,0.5), Text=""
  })
  New("UICorner",{CornerRadius=UDim.new(0,12)}).Parent=btn
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent=btn
  btn.Parent = frame

  local knob = New("Frame", {
    BackgroundColor3=Color3.new(1,1,1), Size=UDim2.fromOffset(18,18),
    Position=value and UDim2.fromOffset(24,3) or UDim2.fromOffset(3,3),
    BorderSizePixel=0
  })
  New("UICorner",{CornerRadius=UDim.new(0,9)}).Parent=knob
  knob.Parent = btn

  local changed = Instance.new("BindableEvent")

  local function set(v: boolean)
    value=v; SpliceUI.SetState(id, value)
    T(btn,  TweenInfo.new(0.15, Enum.EasingStyle.Quad), {BackgroundColor3 = value and ActiveTheme.Colors.accent or ActiveTheme.Colors.panel, BackgroundTransparency = value and 0.05 or ActiveTheme.Transparency.panel})
    T(knob, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {Position = value and UDim2.fromOffset(24,3) or UDim2.fromOffset(3,3)})
    changed:Fire(value)
  end

  btn.MouseButton1Click:Connect(function() set(not value) end)

  frame.Parent = parent
  return {Instance=frame, Get=function() return value end, Set=set, Changed=changed.Event}
end

function SpliceUI.Slider(parent, opts)
  local id   = (opts and opts.key) or ("slider_"..HttpService:GenerateGUID(false))
  local min  = (opts and opts.min) or 0
  local max  = (opts and opts.max) or 100
  if max == min then max = min + 1 end
  local step = (opts and opts.step) or 1
  local val  = SpliceUI.GetState(id, (opts and opts.default) or min)

  local frame = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,46)})
  local changed = Instance.new("BindableEvent")

  local top = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,22)}); top.Parent = frame
  local label = New("TextLabel", {
    BackgroundTransparency=1, Size=UDim2.new(1,-60,1,0), Font=ActiveTheme.Font,
    Text=(opts and opts.text) or "Slider", TextColor3=ActiveTheme.Colors.text, TextXAlignment=Enum.TextXAlignment.Left, TextSize=16
  }); label.Parent = top

  local valLabel = New("TextLabel", {
    BackgroundTransparency=1, Size=UDim2.new(0,60,1,0), Position=UDim2.new(1,-60,0,0),
    Font=ActiveTheme.Font, Text=tostring(val), TextColor3=ActiveTheme.Colors.subtext,
    TextXAlignment=Enum.TextXAlignment.Right, TextSize=14
  }); valLabel.Parent = top

  local bar = New("Frame", {
    BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel,
    Size=UDim2.new(1,0,0,10), Position=UDim2.new(0,0,0,28), BorderSizePixel=0
  })
  New("UICorner",{CornerRadius=UDim.new(0,6)}).Parent=bar
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent=bar
  bar.Parent = frame

  local function alphaFromValue(v) return (v-min)/(max-min) end
  local fill = New("Frame", {
    BackgroundColor3=ActiveTheme.Colors.accent, BackgroundTransparency=0.05,
    Size=UDim2.new(alphaFromValue(val),0,1,0), BorderSizePixel=0
  })
  New("UICorner",{CornerRadius=UDim.new(0,6)}).Parent=fill
  fill.Parent = bar

  local knob = New("Frame", {
    BackgroundColor3=Color3.new(1,1,1), Size=UDim2.fromOffset(14,14),
    AnchorPoint=Vector2.new(.5,.5), Position=UDim2.new(alphaFromValue(val),0,.5,0), BorderSizePixel=0
  })
  New("UICorner",{CornerRadius=UDim.new(0,7)}).Parent=knob
  knob.Parent = bar

  local sliding = false
  local function set(newVal)
    newVal = math.clamp(newVal, min, max)
    if step > 0 then newVal = math.round(newVal/step)*step end
    val = newVal
    SpliceUI.SetState(id, val)
    valLabel.Text = tostring(val)
    T(fill, TweenInfo.new(0.08), {Size = UDim2.new(alphaFromValue(val),0,1,0)})
    T(knob, TweenInfo.new(0.08), {Position = UDim2.new(alphaFromValue(val),0,.5,0)})
    changed:Fire(val)
  end

  local function posToValue(px)
    local rel = (px - bar.AbsolutePosition.X)/math.max(1, bar.AbsoluteSize.X)
    return min + (max-min)*math.clamp(rel,0,1)
  end

  bar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
      sliding = true
      set(posToValue(i.Position.X))
    end
  end)
  UserInputService.InputChanged:Connect(function(i)
    if sliding and i.UserInputType == Enum.UserInputType.MouseMovement then
      set(posToValue(i.Position.X))
    end
  end)
  UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
  end)

  frame.Parent = parent
  return {Instance=frame, Get=function() return val end, Set=set, Changed=changed.Event}
end

-- TextBox estilizado
function SpliceUI.Input(parent, opts)
  local id    = (opts and opts.key) or ("input_"..HttpService:GenerateGUID(false))
  local value = SpliceUI.GetState(id, "")

  local box = New("TextBox", {
    BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel,
    Size=UDim2.new(1,0,0,36),
    PlaceholderText = (opts and opts.placeholder) or "Digite...",
    Text = value,
    Font=ActiveTheme.Font, TextSize=16, TextColor3=ActiveTheme.Colors.text,
    PlaceholderColor3=ActiveTheme.Colors.subtext, ClearTextOnFocus=false,
  })
  New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent=box
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent=box

  box.FocusLost:Connect(function()
    SpliceUI.SetState(id, box.Text)
  end)

  box.Parent = parent
  return {
    Instance = box,
    Get=function() return box.Text end,
    Set=function(t) box.Text=t; SpliceUI.SetState(id,t) end,
    Changed = box:GetPropertyChangedSignal("Text"),
  }
end

-- Dropdown com overlay e fechamento ao clicar fora
function SpliceUI.Dropdown(parent, opts)
  local id     = (opts and opts.key) or ("dropdown_"..HttpService:GenerateGUID(false))
  local items  = (opts and opts.items) or {"A","B"}
  local value  = SpliceUI.GetState(id, (opts and opts.default) or items[1] or "")
  local onChange = Instance.new("BindableEvent")

  local frame = New("Frame", {BackgroundTransparency=1, Size=UDim2.new(1,0,0,36)})

  local label = New("TextLabel", {
    BackgroundTransparency=1, Size=UDim2.new(0.35,0,1,0),
    Font=ActiveTheme.Font, Text=(opts and opts.text) or "Dropdown",
    TextColor3=ActiveTheme.Colors.text, TextXAlignment=Enum.TextXAlignment.Left, TextSize=16
  }); label.Parent = frame

  local box = New("TextButton", {
    AutoButtonColor=false, BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel,
    Size=UDim2.new(0.65,0,1,0), Position=UDim2.new(0.35,8,0,0),
    Text=value, Font=ActiveTheme.Font, TextSize=16, TextColor3=ActiveTheme.Colors.text
  })
  New("UICorner",{CornerRadius=UDim.new(0,ActiveTheme.Corner)}).Parent=box
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.5}).Parent=box
  box.Parent = frame

  -- Overlay na mesma raiz universal (fora de clips)
  local overlayParent = resolveParent()
  local listFrame = New("Frame", {
    BackgroundColor3=ActiveTheme.Colors.glass, BackgroundTransparency=ActiveTheme.Transparency.glass,
    Size=UDim2.fromOffset(0,0), BorderSizePixel=0, Visible=false, ZIndex=300
  })
  New("UICorner",{CornerRadius=UDim.new(0, ActiveTheme.Corner)}).Parent=listFrame
  New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.4}).Parent=listFrame
  listFrame.Parent = overlayParent

  local uilist = New("UIListLayout", {Padding=UDim.new(0,4)}); uilist.Parent = listFrame

  local function positionList()
    local p = box.AbsolutePosition
    local s = box.AbsoluteSize
    listFrame.Position = UDim2.fromOffset(p.X, p.Y + s.Y + 4)
    listFrame.Size = UDim2.fromOffset(s.X, listFrame.Size.Y.Offset)
  end

  local function close()
    T(listFrame, TweenInfo.new(0.12), {Size = UDim2.fromOffset(box.AbsoluteSize.X, 0)}).Completed:Wait()
    listFrame.Visible = false
  end

  local function open()
    positionList()
    listFrame.Visible = true
    T(listFrame, TweenInfo.new(0.12), {Size = UDim2.fromOffset(box.AbsoluteSize.X, #items*30 + 10)})
  end

  -- popula opções
  local function clearOptions()
    for _,c in ipairs(listFrame:GetChildren()) do
      if c:IsA("TextButton") then c:Destroy() end
    end
  end

  local function set(v)
    value = v; SpliceUI.SetState(id, value); box.Text = value
    onChange:Fire(value)
    close()
  end

  local function populate()
    clearOptions()
    for _,it in ipairs(items) do
      local opt = New("TextButton", {
        AutoButtonColor=false, BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel,
        Size=UDim2.new(1,-8,0,26), Text=tostring(it), Font=ActiveTheme.Font, TextSize=14, TextColor3=ActiveTheme.Colors.text, ZIndex=301
      })
      New("UICorner",{CornerRadius=UDim.new(0,10)}).Parent=opt
      New("UIStroke",{Color=ActiveTheme.Colors.stroke, Transparency=0.6}).Parent=opt
      opt.MouseEnter:Connect(function() T(opt, TweenInfo.new(0.08), {BackgroundColor3=ActiveTheme.Colors.glass, BackgroundTransparency=ActiveTheme.Transparency.glass}) end)
      opt.MouseLeave:Connect(function() T(opt, TweenInfo.new(0.12), {BackgroundColor3=ActiveTheme.Colors.panel, BackgroundTransparency=ActiveTheme.Transparency.panel}) end)
      opt.MouseButton1Click:Connect(function() set(it) end)
      opt.Parent = listFrame
    end
  end
  populate()

  -- abrir/fechar
  box.MouseButton1Click:Connect(function()
    if listFrame.Visible then close() else open() end
  end)
  RunService.RenderStepped:Connect(function()
    if listFrame.Visible then positionList() end
  end)

  -- fechar ao clicar fora
  UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not listFrame.Visible then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    local pos = input.Position
    local a   = listFrame.AbsolutePosition
    local s   = listFrame.AbsoluteSize
    local insideList = (pos.X>=a.X and pos.X<=a.X+s.X and pos.Y>=a.Y and pos.Y<=a.Y+s.Y)

    local bA, bS = box.AbsolutePosition, box.AbsoluteSize
    local insideBox = (pos.X>=bA.X and pos.X<=bA.X+bS.X and pos.Y>=bA.Y and pos.Y<=bA.Y+bS.Y)

    if not insideList and not insideBox then close() end
  end)

  frame.Parent = parent

  return {
    Instance = frame,
    Get=function() return value end,
    Set=function(v) set(v) end,
    SetList=function(newList) items = newList or {}; populate() end,
    Changed = onChange.Event,
  }
end

-- ╭───────────────────────────────────────────────────────────────────────────╮
-- │ Notificações (toast empilhadas + contador + barra)                        │
-- ╰───────────────────────────────────────────────────────────────────────────╯
local notifyRoot :: ScreenGui?; local notifyList :: Frame?
local function getNotifyRoot()
  if notifyRoot and notifyRoot.Parent then return notifyRoot, notifyList end

  notifyRoot = Instance.new("ScreenGui")
  notifyRoot.Name = "SpliceUI_Notify"
  notifyRoot.ResetOnSpawn = false
  notifyRoot.IgnoreGuiInset = true
  notifyRoot.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
  notifyRoot.DisplayOrder = 9999
  notifyRoot.Parent = resolveParent()

  notifyList = Instance.new("Frame")
  notifyList.Name = "List"
  notifyList.AnchorPoint = Vector2.new(1,1)
  notifyList.Position = UDim2.new(1,-16,1,-16)
  notifyList.Size = UDim2.fromOffset(360,0)
  notifyList.BackgroundTransparency = 1
  notifyList.AutomaticSize = Enum.AutomaticSize.Y
  notifyList.Parent = notifyRoot

  local layout = Instance.new("UIListLayout")
  layout.FillDirection = Enum.FillDirection.Vertical
  layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
  layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
  layout.Padding = UDim.new(0,8)
  layout.SortOrder = Enum.SortOrder.LayoutOrder
  layout.Parent = notifyList

  return notifyRoot, notifyList
end

function SpliceUI.Notify(message, duration)
  duration = tonumber(duration) or 2.0
  local _, list = getNotifyRoot()
  local order = -os.clock()

  local toast = Instance.new("Frame")
  toast.Name = "Toast"
  toast.Size = UDim2.fromOffset(360,56)
  toast.BackgroundColor3 = ActiveTheme.Colors.glass
  toast.BackgroundTransparency = ActiveTheme.Transparency.glass
  toast.BorderSizePixel = 0
  toast.LayoutOrder = order
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
  label.Text = tostring(message or "")
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
  local barCorner = Instance.new("UICorner"); barCorner.CornerRadius = UDim.new(0,2); barCorner.Parent = bar

  -- Entrada
  toast.BackgroundTransparency = 1
  label.TextTransparency = 1
  counter.TextTransparency = 1

  T(toast,   TweenInfo.new(0.18, Enum.EasingStyle.Quad), {BackgroundTransparency=ActiveTheme.Transparency.glass})
  T(label,   TweenInfo.new(0.18), {TextTransparency=0})
  T(counter, TweenInfo.new(0.18), {TextTransparency=0})
  T(bar,     TweenInfo.new(duration), {Size=UDim2.new(1,-28,0,4)})

  local start = os.clock()
  local hb; hb = RunService.Heartbeat:Connect(function()
    local left = math.max(0, duration - (os.clock() - start))
    counter.Text = string.format("%.1fs", left)
    if left <= 0 then
      if hb then hb:Disconnect() end
      local t1 = TweenService:Create(toast, TweenInfo.new(0.18), {BackgroundTransparency=1})
      local t2 = TweenService:Create(label, TweenInfo.new(0.18), {TextTransparency=1})
      local t3 = TweenService:Create(counter, TweenInfo.new(0.18), {TextTransparency=1})
      t1:Play(); t2:Play(); t3:Play()
      t1.Completed:Connect(function() toast:Destroy() end)
    end
  end)

  return toast
end

-- Helpers de criação
function SpliceUI.CreateWindow(opts) return Window.new(opts) end

-- ╭───────────────────────────────────────────────────────────────────────────╮
-- │ Adapter Kavo (API igual à Kavo)                                           │
-- ╰───────────────────────────────────────────────────────────────────────────╯
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

local WindowMT  = {}; WindowMT.__index  = WindowMT
local TabMT     = {}; TabMT.__index     = TabMT
local SectionMT = {}; SectionMT.__index = SectionMT

local function applyTheme(name)
  local m = ThemeMap[name or "DarkTheme"] or ThemeMap.DarkTheme
  SpliceUI.setTheme(m.theme); SpliceUI.setAccent(m.accent)
end

function Library.CreateLib(title, themeName)
  applyTheme(themeName)
  local self = {}
  self._win  = SpliceUI.CreateWindow({ title = title or "splice.lol", size = UDim2.fromOffset(640,520) })
  self._tabs = {}
  self._win.Tabs = SpliceUI.Tabs(self._win.Content, {})
  return setmetatable(self, WindowMT)
end

function WindowMT:NewTab(name)
  if self._tabs[name] then return self._tabs[name] end
  self._win.Tabs.Add(name)
  self._win.ActiveTab = self._win.ActiveTab or name
  local obj = setmetatable({ _win=self._win, _name=name }, TabMT)
  self._tabs[name] = obj
  return obj
end

function TabMT:NewSection(title)
  self._win.ActiveTab = self._name
  self._win.Tabs.Select(self._name)
  local body = self._win:AddSection(title, self._name)
  return setmetatable({_parent=body}, SectionMT)
end

-- Widgets Kavo
function SectionMT:NewButton(text, info, callback)
  local b = SpliceUI.Button(self._parent, {text=tostring(text or "Button")})
  b.MouseButton1Click:Connect(function() if typeof(callback)=="function" then callback() end end)
  return b
end

function SectionMT:NewToggle(text, info, callback)
  local t = SpliceUI.Toggle(self._parent, {text=tostring(text or "Toggle"), default=false})
  if t.Changed then
    t.Changed:Connect(function() if typeof(callback)=="function" then callback(t.Get()) end end)
  end
  return t
end

function SectionMT:NewSlider(text, info, min, max, callback)
  local s = SpliceUI.Slider(self._parent, {text=tostring(text or "Slider"), min=tonumber(min) or 0, max=tonumber(max) or 100, default=tonumber(min) or 0})
  if s.Changed then
    s.Changed:Connect(function() if typeof(callback)=="function" then callback(s.Get()) end end)
  end
  return s
end

function SectionMT:NewDropdown(text, info, list, callback)
  local d = SpliceUI.Dropdown(self._parent, {text=tostring(text or "Dropdown"), items=(typeof(list)=="table" and list or {"A","B"}), default=(typeof(list)=="table" and list[1]) or "A"})
  if d.Changed then d.Changed:Connect(function() if typeof(callback)=="function" then callback(d.Get()) end end) end
  return d
end

function SectionMT:NewTextBox(text, placeholder, callback)
  SpliceUI.Label(self._parent, tostring(text or "Textbox"))
  local i = SpliceUI.Input(self._parent, {placeholder = tostring(placeholder or "Digite...")})
  if i.Changed then
    i.Changed:Connect(function()
      if typeof(callback)=="function" then callback(i.Get()) end
    end)
  end
  if i.Instance and i.Instance.FocusLost then
    i.Instance.FocusLost:Connect(function()
      if typeof(callback)=="function" then callback(i.Get()) end
    end)
  end
  return i
end

function SectionMT:NewLabel(text)
  return SpliceUI.Label(self._parent, tostring(text or "Label"))
end

-- Extras (simples)
function SectionMT:NewKeybind(text, info, defaultKey, callback)
  SpliceUI.Label(self._parent, tostring(text or "Keybind"))
  local key = defaultKey or Enum.KeyCode.RightShift
  UserInputService.InputBegan:Connect(function(i,gpe) if gpe then return end; if i.KeyCode==key and typeof(callback)=="function" then callback() end end)
end

function SectionMT:NewColorPicker(text, info, defaultColor, callback)
  local choices = {"Vermelho","Ciano","Verde","Roxo"}
  local d = SpliceUI.Dropdown(self._parent, {text=tostring(text or "Color"), items=choices, default="Vermelho"})
  local function map(c)
    if c=="Ciano" then return Color3.fromRGB(0,220,255)
    elseif c=="Verde" then return Color3.fromRGB(40,220,120)
    elseif c=="Roxo" then return Color3.fromRGB(170,90,255)
    else return Color3.fromRGB(255,32,32) end
  end
  if d.Changed then d.Changed:Connect(function() if typeof(callback)=="function" then callback(map(d.Get())) end end) end
  return d
end

-- Expor utilidades
function Library.Notify(msg, dur) SpliceUI.Notify(msg, dur or 2) end
function Library.SetParentGui(gui) SpliceUI.SetParentGui(gui) end

return Library

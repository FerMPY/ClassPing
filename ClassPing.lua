-- ClassPing: FPS and latency in your class color.
-- Hover the line for a performance tooltip. Right-click it (or /cp) for settings.
-- /cp lock | unlock | reset | size N | font | home | show | hide

local ADDON = ...
local MEDIA = "Interface\\AddOns\\ClassPing\\Media\\"
local DEFAULTS = {
  point = "TOP", relPoint = "TOP", x = 0, y = -22,
  locked = true, shown = true, size = 12, home = false,
  font = "Prototype", outline = "OUTLINE", classColor = true, warn = true,
}

local db
local classHex, classRGB = "ffffff", { r = 1, g = 1, b = 1 }
local DIM, WARN = "|cff9d9d9d", "|cffff5a3c"

------------------------------------------------------------------------
-- fonts
------------------------------------------------------------------------
local FONTS = {
  { "Prototype",          MEDIA .. "Prototype.ttf" },
  { "Expressway",         MEDIA .. "Expressway_Free.ttf" },
  { "PT Sans Narrow",     MEDIA .. "PTSansNarrow-Bold.ttf" },
  { "Liberation Sans",    MEDIA .. "LiberationSans-Regular.ttf" },
  { "Fira Mono",          MEDIA .. "FiraMono-Regular.ttf" },
  { "DejaVu Sans Mono",   MEDIA .. "DejaVuSansMono.ttf" },
  { "Friz Quadrata (game)", "Fonts\\FRIZQT__.TTF" },
  { "Arial Narrow (game)",  "Fonts\\ARIALN.TTF" },
  { "Morpheus (game)",      "Fonts\\MORPHEUS.TTF" },
  { "Skurri (game)",        "Fonts\\skurri.TTF" },
}
local OUTLINES = { { "None", "" }, { "Outline", "OUTLINE" }, { "Thick outline", "THICKOUTLINE" } }

local function FontPath(name)
  for _, e in ipairs(FONTS) do if e[1] == name then return e[2] end end
  return FONTS[1][2]
end

local function AddSharedMediaFonts()
  local LibStub = rawget(_G, "LibStub")
  local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
  if not lsm then return end
  local have = {}
  for _, e in ipairs(FONTS) do have[e[1]] = true; have[e[2]] = true end
  local list = lsm:List("font") or {}
  local names = {}
  for _, n in ipairs(list) do names[#names + 1] = n end
  table.sort(names)
  for _, n in ipairs(names) do
    local path = lsm:Fetch("font", n, true)
    if path and not have[n] and not have[path] then
      FONTS[#FONTS + 1] = { n, path }; have[n] = true; have[path] = true
    end
  end
end

------------------------------------------------------------------------
-- class color
------------------------------------------------------------------------
local function ResolveClassColor()
  local _, classFile = UnitClass("player")
  local colors = rawget(_G, "CUSTOM_CLASS_COLORS") or RAID_CLASS_COLORS
  local c = classFile and colors and colors[classFile]
  if c and c.r then
    classRGB = { r = c.r, g = c.g, b = c.b }
    classHex = string.format("%02x%02x%02x",
      math.floor(c.r * 255 + 0.5), math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
  end
end

------------------------------------------------------------------------
-- fps history (last 60 s, sampled every 0.5 s)
------------------------------------------------------------------------
local hist, histN, histMax = {}, 0, 120
local function Sample(fps)
  histN = histN % histMax + 1
  hist[histN] = fps
end
local function Stats()
  local n, sum, mn, mx = 0, 0, math.huge, 0
  for i = 1, histMax do
    local v = hist[i]
    if v then n = n + 1; sum = sum + v; if v < mn then mn = v end; if v > mx then mx = v end end
  end
  if n == 0 then return 0, 0, 0 end
  return sum / n, mn, mx
end

------------------------------------------------------------------------
-- addon memory / cpu
------------------------------------------------------------------------
local GetNumAddOns_ = (C_AddOns and C_AddOns.GetNumAddOns) or GetNumAddOns
local GetAddOnInfo_ = (C_AddOns and C_AddOns.GetAddOnInfo) or GetAddOnInfo
local function TopAddons(kind, count)
  if not GetNumAddOns_ then return {} end
  local get
  if kind == "cpu" then
    if UpdateAddOnCPUUsage then UpdateAddOnCPUUsage() end
    get = GetAddOnCPUUsage
  else
    if UpdateAddOnMemoryUsage then UpdateAddOnMemoryUsage() end
    get = GetAddOnMemoryUsage
  end
  if not get then return {}, 0 end
  local list, total = {}, 0
  for i = 1, GetNumAddOns_() do
    local v = get(i) or 0
    total = total + v
    if v > 0 then
      local name, title = GetAddOnInfo_(i)
      list[#list + 1] = { (title or name or "?"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), v }
    end
  end
  table.sort(list, function(a, b) return a[2] > b[2] end)
  while #list > count do list[#list] = nil end
  return list, total
end

local function fmtMem(kb)
  if kb >= 1024 then return string.format("%.1f MB", kb / 1024) end
  return string.format("%.0f KB", kb)
end

------------------------------------------------------------------------
-- frame
------------------------------------------------------------------------
local f = CreateFrame("Button", "ClassPingFrame", UIParent)
f:SetSize(120, 16)
f:SetMovable(true)
f:SetClampedToScreen(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
f:SetFrameStrata("MEDIUM")

f.bg = f:CreateTexture(nil, "BACKGROUND")
f.bg:SetAllPoints()
f.bg:SetColorTexture(0, 0, 0, 0.5)
f.bg:Hide()

f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
f.text:SetPoint("CENTER")
f.text:SetJustifyH("CENTER")

local lastText
local function Dirty() lastText = nil end

local function SafeSetFont(fs, path, size, outline)
  local ok = fs:SetFont(path, size, outline)
  if ok ~= true then
    fs:SetFont(STANDARD_TEXT_FONT, size, outline)
    return false
  end
  return true
end

local function ApplyFont()
  SafeSetFont(f.text, FontPath(db.font), db.size, db.outline)
  Dirty()
end

local function ApplyPosition()
  f:ClearAllPoints()
  f:SetPoint(db.point, UIParent, db.relPoint, db.x, db.y)
end

local function SavePosition()
  local point, _, relPoint, x, y = f:GetPoint()
  db.point, db.relPoint, db.x, db.y = point, relPoint, math.floor(x + 0.5), math.floor(y + 0.5)
end

local function ApplyLock()
  if db.locked then f.bg:Hide() else f.bg:Show() end
end

local function Hex()
  return db.classColor and classHex or "ffffff"
end

local function Num(value, bad)
  if bad and db.warn then return WARN .. value .. "|r" end
  return "|cff" .. Hex() .. value .. "|r"
end

local function Redraw()
  if not db then return end
  local fps = math.floor((GetFramerate() or 0) + 0.5)
  local _, _, home, world = GetNetStats()
  home, world = home or 0, world or 0
  local ms = world > 0 and world or home

  local text = Num(fps, fps < 30) .. DIM .. " fps   |r"
  if db.home and world > 0 then
    text = text .. Num(home, home > 250) .. DIM .. "/|r" .. Num(world, world > 250) .. DIM .. " ms|r"
  else
    text = text .. Num(ms, ms > 250) .. DIM .. " ms|r"
  end

  if text == lastText then return end
  lastText = text
  f.text:SetText(text)
  f:SetSize(f.text:GetStringWidth() + 12, math.max(f.text:GetStringHeight() + 6, 16))
end

------------------------------------------------------------------------
-- tooltip
------------------------------------------------------------------------
local GOOD, OK, BAD = { 0.35, 0.95, 0.40 }, { 1.00, 0.85, 0.20 }, { 1.00, 0.35, 0.25 }
-- higher is better (fps): v >= good -> green, v >= ok -> yellow, else red
local function GradeHigh(v, good, ok)
  if v >= good then return GOOD elseif v >= ok then return OK else return BAD end
end
-- lower is better (ms, memory): v <= good -> green, v <= ok -> yellow, else red
local function GradeLow(v, good, ok)
  if v <= good then return GOOD elseif v <= ok then return OK else return BAD end
end
local function Hex3(c) return string.format("|cff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255) end
local function Col(text, c) return Hex3(c) .. text .. "|r" end
local function Line(tt, label, value, c, dim)
  local lr, lg, lb = 1, 0.82, 0
  if dim then lr, lg, lb = 0.7, 0.7, 0.7 end
  if c then tt:AddDoubleLine(label, value, lr, lg, lb, c[1], c[2], c[3])
  else tt:AddDoubleLine(label, value, lr, lg, lb, 1, 1, 1) end
end

local function ShowTooltip()
  local tt = GameTooltip
  -- open the tooltip on the side of the line that has room
  local anchor = "ANCHOR_BOTTOM"
  local cx, cy = f:GetCenter()
  local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
  if cx and cy and sw and sh then
    local scale = f:GetEffectiveScale() / UIParent:GetEffectiveScale()
    cx, cy = cx * scale, cy * scale
    if cy < sh * 0.5 then anchor = "ANCHOR_TOP" end
    if cx < sw * 0.2 then anchor = "ANCHOR_RIGHT" elseif cx > sw * 0.8 then anchor = "ANCHOR_LEFT" end
  end
  tt:SetOwner(f, anchor)
  tt:ClearLines()
  local r, g, b = classRGB.r, classRGB.g, classRGB.b
  if not db.classColor then r, g, b = 1, 1, 1 end
  tt:AddLine("ClassPing", r, g, b)

  local fps = GetFramerate() or 0
  local avg, mn, mx = Stats()
  tt:AddLine(" ")
  Line(tt, "Framerate", string.format("%.0f fps", fps), GradeHigh(fps, 60, 30))
  Line(tt, "  last 60 s",
    "avg " .. Col(string.format("%.0f", avg), GradeHigh(avg, 60, 30)) ..
    "   min " .. Col(string.format("%.0f", mn), GradeHigh(mn, 60, 30)) ..
    "   max " .. Col(string.format("%.0f", mx), GradeHigh(mx, 60, 30)), nil, true)
  local cap = tonumber(GetCVar and GetCVar("maxFPS") or 0) or 0
  if cap > 0 then Line(tt, "  fps cap", string.format("%d", cap), nil, true) end

  local bin, bout, home, world = GetNetStats()
  home, world = home or 0, world or 0
  tt:AddLine(" ")
  Line(tt, "Latency (home)",  string.format("%d ms", home),  GradeLow(home, 100, 250))
  Line(tt, "Latency (world)", string.format("%d ms", world), GradeLow(world, 100, 250))
  Line(tt, "Bandwidth", string.format("%.1f KB/s down   %.1f KB/s up", bin or 0, bout or 0))

  local mem, memTotal = TopAddons("mem", 5)
  memTotal = memTotal or 0
  tt:AddLine(" ")
  Line(tt, "Addon memory", fmtMem(memTotal), GradeLow(memTotal, 30 * 1024, 80 * 1024))
  for _, e in ipairs(mem) do
    Line(tt, "  " .. e[1], fmtMem(e[2]), GradeLow(e[2], 5 * 1024, 15 * 1024), true)
  end
  local lua = collectgarbage("count")
  Line(tt, "Lua memory", fmtMem(lua), GradeLow(lua, 150 * 1024, 400 * 1024))

  if GetCVar and GetCVar("scriptProfile") == "1" then
    local cpu = TopAddons("cpu", 5)
    tt:AddLine(" ")
    tt:AddLine("Addon CPU (ms since login)", 1, 0.82, 0)
    local top = cpu[1] and cpu[1][2] or 0
    for _, e in ipairs(cpu) do
      Line(tt, "  " .. e[1], string.format("%.0f ms", e[2]), GradeLow(e[2], top * 0.25, top * 0.6), true)
    end
  end

  tt:AddLine(" ")
  if db.locked then
    tt:AddLine("Right-click or /cp: settings", 0.5, 0.84, 1)
  else
    tt:AddLine("Unlocked: drag to move. Right-click: settings", 0.5, 0.84, 1)
  end
  tt:Show()
end

local OpenSettings  -- defined below

f:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition() end)
f:SetScript("OnClick", function(_, button) if button == "RightButton" then OpenSettings() end end)
f:SetScript("OnEnter", function(self) self.hover = true; ShowTooltip() end)
f:SetScript("OnLeave", function(self) self.hover = false; GameTooltip:Hide() end)

local acc, ttAcc = 0, 0
f:SetScript("OnUpdate", function(self, elapsed)
  acc = acc + elapsed
  if acc >= 0.5 then
    acc = 0
    Sample(GetFramerate() or 0)
    Redraw()
  end
  if self.hover then
    ttAcc = ttAcc + elapsed
    if ttAcc >= 1 then ttAcc = 0; ShowTooltip() end
  end
end)

------------------------------------------------------------------------
-- settings panel (built under pcall so a template mismatch never kills the line)
------------------------------------------------------------------------
local panel
local refreshers = {}
local function RefreshAll() for _, r in ipairs(refreshers) do r() end end

-- builds the settings controls inside any parent frame (the window and the Options > AddOns page)
local function BuildControls(parent)
  local function Label(parent, text, size)
    local fs = parent:CreateFontString(nil, "ARTWORK", size == "big" and "GameFontNormalLarge" or "GameFontHighlight")
    fs:SetText(text)
    return fs
  end

  local function Check(parent, text, get, set)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb.label = Label(parent, text)
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    cb.Refresh = function(self) self:SetChecked(get()) end
    return cb
  end

  local function Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
  end

  local title = Label(parent, "ClassPing", "big")
  title:SetPoint("TOPLEFT", 16, -16)
  local sub = Label(parent, "FPS and latency in your class color. Hover the line for details.")
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
  sub:SetTextColor(0.7, 0.7, 0.7)

  -- position
  local posHead = Label(parent, "Position")
  posHead:SetPoint("TOPLEFT", sub, "BOTTOMLEFT", 0, -18)
  posHead:SetTextColor(1, 0.82, 0)

  local lockCB = Check(parent, "Lock position", function() return db.locked end, function(v) db.locked = v; ApplyLock() end)
  lockCB:SetPoint("TOPLEFT", posHead, "BOTTOMLEFT", -2, -6)
  local lockHint = Label(parent, "then drag the line where you want it")
  lockHint:SetPoint("LEFT", lockCB.label, "RIGHT", 12, 0)
  lockHint:SetTextColor(0.6, 0.6, 0.6)

  local moveBtn = Button(parent, "Unlock and move", 130, function()
    db.locked = false; ApplyLock(); RefreshAll()
    print("|cff" .. classHex .. "ClassPing|r: unlocked - drag the line, then tick Lock position or /cp lock.")
  end)
  moveBtn:SetPoint("LEFT", lockCB.label, "RIGHT", 12, 0)
  lockHint:ClearAllPoints(); lockHint:SetPoint("LEFT", moveBtn, "RIGHT", 8, 0)
  local resetBtn = Button(parent, "Reset position", 130, function()
    for _, k in ipairs({ "point", "relPoint", "x", "y" }) do db[k] = DEFAULTS[k] end
    ApplyPosition()
  end)
  resetBtn:SetPoint("TOPLEFT", lockCB, "BOTTOMLEFT", 2, -6)

  -- text
  local textHead = Label(parent, "Text")
  textHead:SetPoint("TOPLEFT", resetBtn, "BOTTOMLEFT", -2, -18)
  textHead:SetTextColor(1, 0.82, 0)

  local sizeLabel = Label(parent, "Font size")
  sizeLabel:SetPoint("TOPLEFT", textHead, "BOTTOMLEFT", 0, -10)
  local sizeMinus = Button(parent, "-", 24, function() if db.size > 8 then db.size = db.size - 1; ApplyFont(); Redraw(); RefreshAll() end end)
  sizeMinus:SetPoint("LEFT", sizeLabel, "LEFT", 110, 0)
  local sizeValue = Label(parent, "12")
  sizeValue:SetPoint("LEFT", sizeMinus, "RIGHT", 8, 0)
  local sizePlus = Button(parent, "+", 24, function() if db.size < 24 then db.size = db.size + 1; ApplyFont(); Redraw(); RefreshAll() end end)
  sizePlus:SetPoint("LEFT", sizeMinus, "RIGHT", 36, 0)

  local fontLabel = Label(parent, "Font")
  fontLabel:SetPoint("TOPLEFT", sizeLabel, "BOTTOMLEFT", 0, -14)
  local fontBtn = Button(parent, "Prototype", 200, nil)
  fontBtn:SetPoint("LEFT", fontLabel, "LEFT", 110, 0)

  local outlineLabel = Label(parent, "Outline")
  outlineLabel:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -14)
  local outlineBtn = Button(parent, "Outline", 200, function()
    local idx = 1
    for i, o in ipairs(OUTLINES) do if o[2] == db.outline then idx = i end end
    db.outline = OUTLINES[idx % #OUTLINES + 1][2]
    ApplyFont(); Redraw(); RefreshAll()
  end)
  outlineBtn:SetPoint("LEFT", outlineLabel, "LEFT", 110, 0)

  local preview = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  preview:SetPoint("LEFT", fontBtn, "RIGHT", 16, 0)
  preview:SetText("53 fps   42 ms")

  -- colors and content
  local colHead = Label(parent, "Colors")
  colHead:SetPoint("TOPLEFT", outlineLabel, "BOTTOMLEFT", 0, -18)
  colHead:SetTextColor(1, 0.82, 0)

  local classCB = Check(parent, "Use class color for numbers", function() return db.classColor end, function(v) db.classColor = v; Dirty(); Redraw() end)
  classCB:SetPoint("TOPLEFT", colHead, "BOTTOMLEFT", -2, -6)
  local warnCB = Check(parent, "Red numbers under 30 fps or over 250 ms", function() return db.warn end, function(v) db.warn = v; Dirty(); Redraw() end)
  warnCB:SetPoint("TOPLEFT", classCB, "BOTTOMLEFT", 0, -2)
  local homeCB = Check(parent, "Show home and world latency (home/world ms)", function() return db.home end, function(v) db.home = v; Dirty(); Redraw() end)
  homeCB:SetPoint("TOPLEFT", warnCB, "BOTTOMLEFT", 0, -2)
  local shownCB = Check(parent, "Show the line", function() return db.shown end, function(v) db.shown = v; if v then f:Show() else f:Hide() end end)
  shownCB:SetPoint("TOPLEFT", homeCB, "BOTTOMLEFT", 0, -2)

  local slashHint = Label(parent, "/cp opens these settings in a window.  Also: /cp lock | unlock | reset | size N | font | home | show | hide")
  slashHint:SetPoint("TOPLEFT", shownCB, "BOTTOMLEFT", 2, -18)
  slashHint:SetTextColor(0.6, 0.6, 0.6)

  -- font picker popup
  local picker = CreateFrame("Frame", nil, parent, rawget(_G, "BackdropTemplateMixin") and "BackdropTemplate" or nil)
  parent.picker = picker
  picker:SetSize(240, 10)
  picker:SetPoint("TOPLEFT", fontBtn, "BOTTOMLEFT", 0, -2)
  picker:SetFrameStrata("DIALOG")
  picker:EnableMouse(true)
  picker:Hide()
  if picker.SetBackdrop then
    picker:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  else
    picker.bg = picker:CreateTexture(nil, "BACKGROUND"); picker.bg:SetAllPoints(); picker.bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
  end
  picker.rows, picker.page = {}, 1
  local PER_PAGE = 12
  for i = 1, PER_PAGE do
    local row = CreateFrame("Button", nil, picker)
    row:SetSize(226, 18)
    row:SetPoint("TOPLEFT", 7, -7 - (i - 1) * 18)
    row.hl = row:CreateTexture(nil, "HIGHLIGHT"); row.hl:SetAllPoints(); row.hl:SetColorTexture(1, 1, 1, 0.12)
    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); row.text:SetPoint("LEFT", 4, 0); row.text:SetJustifyH("LEFT")
    row:SetScript("OnClick", function(self)
      if self.fontName then db.font = self.fontName; ApplyFont(); Redraw(); RefreshAll(); picker:Hide() end
    end)
    picker.rows[i] = row
  end
  picker.prev = Button(picker, "<", 28, function() picker.page = math.max(1, picker.page - 1); picker:Fill() end)
  picker.prev:SetPoint("BOTTOMLEFT", 7, 6)
  picker.next = Button(picker, ">", 28, function() picker.page = picker.page + 1; picker:Fill() end)
  picker.next:SetPoint("BOTTOMRIGHT", -7, 6)
  picker.pageText = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  picker.pageText:SetPoint("BOTTOM", 0, 10)

  function picker:Fill()
    local pages = math.max(1, math.ceil(#FONTS / PER_PAGE))
    if self.page > pages then self.page = pages end
    local first = (self.page - 1) * PER_PAGE
    local shown = 0
    for i, row in ipairs(self.rows) do
      local e = FONTS[first + i]
      if e then
        row.fontName = e[1]
        SafeSetFont(row.text, e[2], 13, "")
        row.text:SetText((e[1] == db.font and "|cff00ff00" or "") .. e[1])
        row:Show(); shown = shown + 1
      else
        row.fontName = nil; row:Hide()
      end
    end
    self:SetHeight(7 + shown * 18 + 34)
    self.pageText:SetText(self.page .. " / " .. pages)
    if pages > 1 then self.prev:Show(); self.next:Show(); self.pageText:Show()
    else self.prev:Hide(); self.next:Hide(); self.pageText:Hide(); self:SetHeight(7 + shown * 18 + 7) end
  end
  fontBtn:SetScript("OnClick", function()
    if picker:IsShown() then picker:Hide() else picker:Fill(); picker:Show() end
  end)

  local function Refresh()
    if not db then return end
    lockCB:Refresh(); classCB:Refresh(); warnCB:Refresh(); homeCB:Refresh(); shownCB:Refresh()
    sizeValue:SetText(tostring(db.size))
    fontBtn:SetText(db.font)
    for _, o in ipairs(OUTLINES) do if o[2] == db.outline then outlineBtn:SetText(o[1]) end end
    SafeSetFont(preview, FontPath(db.font), db.size, db.outline)
    preview:SetTextColor(classRGB.r, classRGB.g, classRGB.b)
  end
  local function Hook(ev, fn)
    if parent:GetScript(ev) then parent:HookScript(ev, fn) else parent:SetScript(ev, fn) end
  end
  Hook("OnShow", function() picker:Hide(); Refresh() end)
  Hook("OnHide", function() picker:Hide() end)
  refreshers[#refreshers + 1] = Refresh
  return Refresh

end

local function BuildPanel()
  ------------------------------------------------------------------------
  panel = CreateFrame("Frame", "ClassPingOptions", UIParent, rawget(_G, "BackdropTemplateMixin") and "BackdropTemplate" or nil)
  panel.name = "ClassPing"
  panel:SetSize(520, 420)
  panel:SetPoint("CENTER")
  panel:SetFrameStrata("DIALOG")
  panel:SetMovable(true)
  panel:EnableMouse(true)
  panel:SetClampedToScreen(true)
  panel:RegisterForDrag("LeftButton")
  panel:SetScript("OnDragStart", panel.StartMoving)
  panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
  if panel.SetBackdrop then
    panel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 24,
      insets = { left = 6, right = 6, top = 6, bottom = 6 } })
  else
    panel.bg = panel:CreateTexture(nil, "BACKGROUND"); panel.bg:SetAllPoints(); panel.bg:SetColorTexture(0.05, 0.05, 0.05, 0.95)
  end
  local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function() panel:Hide() end)
  tinsert(UISpecialFrames, "ClassPingOptions")  -- Escape closes it
  panel:Hide()

  BuildControls(panel)
end

OpenSettings = function()
  if not panel then print("|cff" .. classHex .. "ClassPing|r: settings window failed to build - run /console scriptErrors 1 and /reload to see why") return end
  if panel:IsShown() then panel:Hide() else panel:Show() end
end

local function RegisterPanel()
  local ok, err = pcall(function()
    local page = CreateFrame("Frame", "ClassPingOptionsPage", UIParent)
    page.name = "ClassPing"
    page:Hide()
    BuildControls(page)
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
      local cat = Settings.RegisterCanvasLayoutCategory(page, page.name)
      cat.ID = page.name
      Settings.RegisterAddOnCategory(cat)
    elseif InterfaceOptions_AddCategory then
      InterfaceOptions_AddCategory(page)
    end
  end)
  if not ok then print("|cff" .. classHex .. "ClassPing|r: could not add to the AddOns options list: " .. tostring(err)) end
end


------------------------------------------------------------------------
-- events
------------------------------------------------------------------------
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" then
    if arg1 ~= ADDON then return end
    ClassPingDB = ClassPingDB or {}
    db = ClassPingDB
    for k, v in pairs(DEFAULTS) do if db[k] == nil then db[k] = v end end
    ApplyFont(); ApplyPosition(); ApplyLock()
    if db.shown then self:Show() else self:Hide() end
    local ok, err = pcall(BuildPanel)
    if not ok then
      panel = nil
      f.buildError = tostring(err)
      geterrorhandler()("ClassPing settings window: " .. tostring(err))  -- lands in BugSack
    end
    RegisterPanel()
    self:UnregisterEvent("ADDON_LOADED")
  elseif event == "PLAYER_LOGIN" then
    ResolveClassColor()
    AddSharedMediaFonts()
    Dirty(); Redraw()
  end
end)

------------------------------------------------------------------------
-- slash
------------------------------------------------------------------------
local function say(msg) print("|cff" .. classHex .. "ClassPing|r: " .. msg) end

SLASH_CLASSPING1 = "/cp"
SLASH_CLASSPING2 = "/classping"
SlashCmdList.CLASSPING = function(msg)
  local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  cmd = cmd:lower()
  if cmd == "lock" then
    db.locked = true; ApplyLock(); say("locked.")
  elseif cmd == "unlock" then
    db.locked = false; ApplyLock(); say("unlocked - drag it, then /cp lock.")
  elseif cmd == "reset" then
    for _, k in ipairs({ "point", "relPoint", "x", "y" }) do db[k] = DEFAULTS[k] end
    ApplyPosition(); say("position reset.")
  elseif cmd == "size" then
    local n = tonumber(arg)
    if n and n >= 8 and n <= 24 then
      db.size = math.floor(n); ApplyFont(); Redraw(); say("font size " .. db.size .. ".")
    else
      say("size takes a number from 8 to 24, e.g. /cp size 14")
    end
  elseif cmd == "font" then
    if arg == "" then
      local names = {}
      for _, e in ipairs(FONTS) do names[#names + 1] = e[1] end
      say("current: " .. db.font .. ". Available: " .. table.concat(names, ", "))
    else
      local match
      for _, e in ipairs(FONTS) do if e[1]:lower() == arg:lower() then match = e[1] end end
      if not match then for _, e in ipairs(FONTS) do if not match and e[1]:lower():find(arg:lower(), 1, true) then match = e[1] end end end
      if match then db.font = match; ApplyFont(); Redraw(); say("font: " .. match) else say("no font called '" .. arg .. "'. /cp font lists them.") end
    end
  elseif cmd == "debug" then
    say("version 2.5, line shown=" .. tostring(f:IsShown()) .. " visible=" .. tostring(f:IsVisible()))
    if not panel then
      say("settings window: NOT BUILT. error=" .. tostring(f.buildError))
    else
      local w, h = panel:GetSize()
      local pt, rel, rp, x, y = panel:GetPoint()
      say(string.format("settings window: shown=%s visible=%s size=%dx%d alpha=%.2f scale=%.2f strata=%s point=%s %s %s %d %d",
        tostring(panel:IsShown()), tostring(panel:IsVisible()), w, h, panel:GetAlpha(), panel:GetEffectiveScale(),
        tostring(panel:GetFrameStrata()), tostring(pt), tostring(rel and rel.GetName and rel:GetName()), tostring(rp), x or 0, y or 0))
      say("parent=" .. tostring(panel:GetParent() and panel:GetParent():GetName()) .. " backdrop=" .. tostring(panel.SetBackdrop ~= nil))
    end
  elseif cmd == "open" then
    if panel then panel:ClearAllPoints(); panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0); panel:SetAlpha(1); panel:Show(); say("forced open.") else say("no window to open.") end
  elseif cmd == "home" then
    db.home = not db.home; Dirty(); Redraw()
    say(db.home and "showing home/world latency." or "showing world latency only.")
  elseif cmd == "show" then
    db.shown = true; f:Show(); say("shown.")
  elseif cmd == "hide" then
    db.shown = false; f:Hide(); say("hidden. /cp show brings it back.")
  else
    OpenSettings()
  end
end

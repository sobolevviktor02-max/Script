print("[SpeedMenu] загрузка скрипта...")
pcall(function() game:GetService("StarterGui"):SetCore("SendNotification",{Title="W1NTEZ YT",Text="Скрипт запущен, строю меню…",Duration=4}) end)
local __smOk, __smErr = xpcall(function()
--[[
  ⚡ Скрипт от W1NTEZ YT на любую игру (Luau)
  • Скорость, ноклип, полёт, бессмертие, телепорт, FOV
  • Прокрутка колёсиком / пальцем, окно можно растягивать за уголок ◢
  • Настройки сохраняются между запусками (если есть writefile)
  • RightShift — скрыть / показать, заголовок — перетаскивать, «—» — свернуть
]]

-- ждём, пока игра и игрок полностью загрузятся (нужно для любых игр и запускателей)
pcall(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	local P = game:GetService("Players")
	local t0 = os.clock()
	while not P.LocalPlayer and os.clock() - t0 < 30 do task.wait(0.1) end
end)
-- САМОВОССТАНОВЛЕНИЕ: если прошлый запуск не дошёл до конца (флаг остался), сбрасываем сохранённый вид/тему/кнопки и стартуем «с чистого листа»
pcall(function()
	if type(isfile) == "function" and type(writefile) == "function" then
		local dirty = false
		if isfile("SpeedMenu_boot.flag") then
			local okR, c = pcall(readfile, "SpeedMenu_boot.flag")
			dirty = not (okR and c == "ok")
		end
		if dirty then
			for _, f in ipairs({"SpeedMenu_ui.json", "SpeedMenu_hot.json", "SpeedMenu_theme.txt", "SpeedMenu_bgcfg.json"}) do
				pcall(function() if isfile(f) then if type(delfile) == "function" then delfile(f) else writefile(f, "") end end end)
			end
			pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "W1NTEZ YT", Text = "Прошлый запуск не завершился — вид меню сброшен, запускаю заново.", Duration = 6}) end)
		end
		writefile("SpeedMenu_boot.flag", tostring(os.time()))
	end
end)
-- если скрипт уже запущен — сначала полностью закрываем прошлую копию
if type(_G.SpeedMenuClose) == "function" then pcall(_G.SpeedMenuClose) end
_G.SpeedMenuCleanup = {}
-- запоминаем все подписки на события, чтобы «Закрыть скрипт» могла их отключить
local __trk = {conns = {}}
do
	local ty = typeof or type
	local function wrapSignal(sig)
		return setmetatable({}, {__index = function(_, k)
			if k == "Connect" or k == "connect" or k == "Once" then
				return function(_, fn)
					local c = sig[k](sig, fn)
					table.insert(__trk.conns, c)
					return c
				end
			end
			local v = sig[k]
			if type(v) == "function" then return function(_, ...) return v(sig, ...) end end
			return v
		end})
	end
	function __trk.wrap(svc)
		return setmetatable({}, {
			__index = function(_, k)
				local v = svc[k]
				if ty(v) == "RBXScriptSignal" then return wrapSignal(v) end
				if type(v) == "function" then return function(_, ...) return v(svc, ...) end end
				return v
			end,
			__newindex = function(_, k, v) svc[k] = v end,
		})
	end
end

__trk.errlog = {}
__trk.closed = false
table.insert(_G.SpeedMenuCleanup, function() __trk.closed = true end)
function __trk.report(tag, e)
	local msg = "[" .. tostring(tag) .. "] " .. tostring(e)
	table.insert(__trk.errlog, msg)
	warn("[SpeedMenu] ошибка в блоке " .. msg)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {Title = "Speed Menu: ошибка", Text = string.sub(msg, 1, 140), Duration = 8})
	end)
end

local Players      = game:GetService("Players")
local UIS          = __trk.wrap(game:GetService("UserInputService"))
local RunService   = __trk.wrap(game:GetService("RunService"))
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local lp           = Players.LocalPlayer

local DEFAULT, MIN, MAX = 16, 0, 500
local FMIN, FMAX = 5, 300
local VMIN, VMAX = 40, 120
local speed, enabled = 50, false
local flySpeed, flying = 60, false
local noclip, god = false, false
local fov = 70
local esp, antiAfk = false, false
local JMIN, JMAX = 0, 300
local infJump, jumpOn, jumpPower = false, false, 50
local fuelOn, durOn, planeGhost, seeThrough = false, false, false, false
local sprintOn, sprintMult, wasSprint, voidOn = false, 2, false, false

-- ===== сохранение настроек =====
local SAVE_FILE = "SpeedMenu.json"
local canSave = type(writefile) == "function" and type(readfile) == "function"
if canSave then
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SAVE_FILE)) end)
	if ok and type(data) == "table" then
		MAX = math.clamp(tonumber(data.maxSpeed) or MAX, 50, 100000)
		speed = math.clamp(tonumber(data.speed) or speed, MIN, MAX)
		flySpeed = math.clamp(tonumber(data.flySpeed) or flySpeed, FMIN, FMAX)
		fov = math.clamp(tonumber(data.fov) or fov, VMIN, VMAX)
		jumpPower = math.clamp(tonumber(data.jumpPower) or jumpPower, JMIN, JMAX)
	end
end
local saveQueued = false
local function save()
	if not canSave or saveQueued then return end
	saveQueued = true
	task.delay(1, function()
		saveQueued = false
		pcall(function()
			writefile(SAVE_FILE, HttpService:JSONEncode({speed = speed, maxSpeed = MAX, flySpeed = flySpeed, fov = fov, jumpPower = jumpPower}))
		end)
	end)
end

-- ===== куда класть меню =====
local function guiParent()
	-- проверяем, что в контейнер реально можно положить меню (на некоторых запускателях CoreGui закрыт)
	local function usable(p)
		if not p then return false end
		return (pcall(function()
			local f = Instance.new("Folder")
			f.Parent = p
			f:Destroy()
		end))
	end
	local ok, res = pcall(function() return gethui and gethui() end)
	if ok and res and usable(res) then return res end
	local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and cg and usable(cg) then return cg end
	return lp:WaitForChild("PlayerGui")
end
local parent = guiParent()
local old = parent:FindFirstChild("SpeedMenu")
if old then old:Destroy() end

-- ===== палитра и помощники =====
local C = {
	bg     = Color3.fromRGB(18, 16, 28),
	head   = Color3.fromRGB(26, 22, 42),
	card   = Color3.fromRGB(30, 26, 46),
	field  = Color3.fromRGB(42, 37, 64),
	btn    = Color3.fromRGB(54, 47, 84),
	accent = Color3.fromRGB(139, 92, 246),
	on     = Color3.fromRGB(124, 58, 237),
	off    = Color3.fromRGB(58, 52, 86),
	danger = Color3.fromRGB(170, 55, 70),
	text   = Color3.fromRGB(240, 238, 255),
	sub    = Color3.fromRGB(165, 158, 205),
}

local function new(class, props, kids)
	local o = Instance.new(class)
	if class == "ScreenGui" then __trk.guis = __trk.guis or {}; table.insert(__trk.guis, o) end
	for k, v in pairs(props) do o[k] = v end
	for _, c in ipairs(kids or {}) do c.Parent = o end
	return o
end
local function round(r) return new("UICorner", {CornerRadius = UDim.new(0, r)}) end
local function getHum() local c = lp.Character return c and c:FindFirstChildOfClass("Humanoid") end
local function getHRP() local c = lp.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function isPress(i) return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch end
local function isMove(i) return i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch end
local function tween(o, props) TweenService:Create(o, TweenInfo.new(0.15, Enum.EasingStyle.Quad), props):Play() end
-- надёжный телепорт: слезает с сиденья, гасит скорость, двигает всего персонажа целиком и пару кадров подтверждает позицию
local function safeTP(cf)
	local c = lp.Character
	local hrp = getHRP()
	if not (c and hrp) then return false end
	pcall(function()
		local h = c:FindFirstChildOfClass("Humanoid")
		if h and h.SeatPart then h.Sit = false end
	end)
	local function put()
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		if not pcall(function() c:PivotTo(cf) end) then hrp.CFrame = cf end
	end
	put()
	task.spawn(function()
		for _ = 1, 3 do
			RunService.Heartbeat:Wait()
			if not hrp.Parent then return end
			put()
		end
	end)
	return true
end

-- ===== окно =====
local gui = new("ScreenGui", {Name = "SpeedMenu", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
local main = new("Frame", {
	Size = UDim2.fromOffset(480, 400), Position = UDim2.new(0.5, -240, 0.5, -200),
	BackgroundColor3 = C.bg, BorderSizePixel = 0, Parent = gui,
}, {round(14), new("UIStroke", {Color = Color3.fromRGB(150, 80, 255), Thickness = 2})})

local header = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.head, BorderSizePixel = 0, Parent = main}, {round(12)})
new("Frame", {Size = UDim2.new(1, 0, 0, 12), Position = UDim2.new(0, 0, 1, -12), BackgroundColor3 = C.head, BorderSizePixel = 0, Parent = header})
new("Frame", {Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Parent = header}, {
	new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(124, 58, 237), Color3.fromRGB(217, 70, 239))}),
})
new("TextLabel", {
	Size = UDim2.new(1, -84, 1, 0), Position = UDim2.fromOffset(14, 0), BackgroundTransparency = 1,
	Text = "⚡ Скрипт от W1NTEZ YT на любую игру", Font = Enum.Font.GothamBold, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = C.text,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = header,
})
local minBtn = new("TextButton", {
	Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, -36, 0, 6), Text = "—", Font = Enum.Font.GothamBold, TextSize = 16,
	TextColor3 = C.text, BackgroundColor3 = C.btn, Parent = header,
}, {round(6)})

local scroll = new("ScrollingFrame", {
	Size = UDim2.new(1, 0, 1, -36), Position = UDim2.fromOffset(0, 36), BackgroundTransparency = 1, BorderSizePixel = 0,
	ScrollBarThickness = 4, ScrollBarImageColor3 = C.accent, ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ElasticBehavior = Enum.ElasticBehavior.Never, Parent = main,
}, {
	new("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
	new("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 16), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 14)}),
})

-- ===== строительные блоки =====
local function card(title, h, order)
	local f = new("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = order, Parent = scroll}, {round(10)})
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 6), BackgroundTransparency = 1, Text = title,
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Left, Parent = f,
	})
	return f
end
local function label(p, text, y, w)
	return new("TextLabel", {
		Size = UDim2.new(1, -(w or 118), 0, 28), Position = UDim2.fromOffset(12, y), BackgroundTransparency = 1, Text = text,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = p,
	})
end
local function numBox(p, y, v)
	return new("TextBox", {
		Size = UDim2.fromOffset(90, 28), Position = UDim2.new(1, -102, 0, y), Text = tostring(v), ClearTextOnFocus = false,
		Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.text, BackgroundColor3 = C.field, Parent = p,
	}, {round(6)})
end
local function slider(p, y)
	local track = new("Frame", {Size = UDim2.new(1, -24, 0, 8), Position = UDim2.fromOffset(12, y), BackgroundColor3 = C.field, BorderSizePixel = 0, Parent = p}, {round(4)})
	local fill = new("Frame", {Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.accent, BorderSizePixel = 0, Parent = track}, {round(4)})
	local knob = new("Frame", {
		Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track,
	}, {round(9)})
	local hit = new("TextButton", {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, -11), BackgroundTransparency = 1, Text = "", Parent = track})
	return track, fill, knob, hit
end
local function row(p, y, h)
	return new("Frame", {Size = UDim2.new(1, -24, 0, h), Position = UDim2.fromOffset(12, y), BackgroundTransparency = 1, Parent = p}, {
		new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder}),
	})
end
local function cellSize(n) return UDim2.new(1 / n, -6 * (n - 1) / n, 1, 0) end
local function cell(r, n, text, bg)
	return new("TextButton", {
		Size = cellSize(n), LayoutOrder = #r:GetChildren(), Text = text, Font = Enum.Font.GothamBold, TextSize = 12,
		TextColor3 = C.text, BackgroundColor3 = bg or C.btn, Parent = r,
	}, {round(8)})
end
local function cellBox(r, n, placeholder)
	return new("TextBox", {
		Size = cellSize(n), LayoutOrder = #r:GetChildren(), Text = "", PlaceholderText = placeholder, ClearTextOnFocus = false,
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text, PlaceholderColor3 = Color3.fromRGB(120, 126, 160),
		BackgroundColor3 = C.field, Parent = r,
	}, {round(6)})
end

-- ===== карточка: скорость =====
local c1 = card("СКОРОСТЬ ХОДЬБЫ", 202, 1)
local toggle = new("TextButton", {
	Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 28), Font = Enum.Font.GothamBold, TextSize = 14,
	Text = "ВЫКЛ", TextColor3 = C.text, BackgroundColor3 = C.danger, Parent = c1,
}, {round(8)})
label(c1, "Значение", 66)
local box = numBox(c1, 66, speed)
local track, fill, knob, hit = slider(c1, 108)
local presetRow = row(c1, 124, 28)
local presetBtns = {}
for _, v in ipairs({16, 50, 100, 200, 350}) do
	local b = cell(presetRow, 6, tostring(v))
	table.insert(presetBtns, {b, v})
end
local maxPreset = cell(presetRow, 6, "МАКС")
label(c1, "Предел скорости", 162)
local limBox = numBox(c1, 162, MAX)

-- ===== карточка: режимы =====
local c2 = card("РЕЖИМЫ", 114, 2)
local modeRow = row(c2, 28, 34)
local noclipBtn = cell(modeRow, 3, "Ноклип", C.off)
local flyBtn    = cell(modeRow, 3, "Полёт", C.off)
local godBtn    = cell(modeRow, 3, "Бессмертие", C.off)
local planeRow  = row(c2, 68, 34)
local planeBtn  = cell(planeRow, 2, "Сквозь препятствия", C.off)
local seeBtn    = cell(planeRow, 2, "Прозрачный", C.off)

-- ===== карточка: полёт =====
local c3 = card("СКОРОСТЬ ПОЛЁТА", 112, 3)
label(c3, "Значение", 28)
local fbox = numBox(c3, 28, flySpeed)
local ftrack, ffill, fknob, fhit = slider(c3, 70)
new("TextLabel", {
	Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 86), BackgroundTransparency = 1,
	Text = "WASD + Space ↑ / LeftCtrl ↓  (на телефоне — джойстик)", Font = Enum.Font.Gotham, TextSize = 10,
	TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = c3,
})

-- ===== карточка: телепорт =====
local c4 = card("ТЕЛЕПОРТ", 106, 4)
local tpRow = row(c4, 28, 28)
local tpBoxes = {cellBox(tpRow, 3, "X"), cellBox(tpRow, 3, "Y"), cellBox(tpRow, 3, "Z")}
local tpBtnRow = row(c4, 62, 32)
local posBtn   = cell(tpBtnRow, 3, "Моя поз.")
local tpBtn    = cell(tpBtnRow, 3, "ТП", C.accent)
local spawnBtn = cell(tpBtnRow, 3, "На спавн")

-- ===== карточка: камера =====
local c5 = card("КАМЕРА", 84, 5)
label(c5, "Угол обзора (FOV)", 28)
local fovBox = numBox(c5, 28, fov)
local fovTrack, fovFill, fovKnob, fovHit = slider(c5, 70)

-- ===== карточка: прочее =====
local c6 = card("ПРОЧЕЕ", 74, 6)
local miscRow = row(c6, 28, 34)
local espBtn    = cell(miscRow, 3, "ESP", C.off)
local afkBtn    = cell(miscRow, 3, "Анти-АФК", C.off)
local rejoinBtn = cell(miscRow, 3, "Перезайти")

-- ===== карточка: прыжок =====
local c7 = card("ПРЫЖОК", 124, 7)
local jumpRow = row(c7, 28, 32)
local jumpBtn = cell(jumpRow, 2, "Своя высота", C.off)
local infBtn  = cell(jumpRow, 2, "Беск. прыжок", C.off)
label(c7, "Сила прыжка", 66)
local jbox = numBox(c7, 66, jumpPower)
local jtrack, jfill, jknob, jhit = slider(c7, 108)

-- ===== карточка: топливо =====
local c8 = card("БЕСКОНЕЧНОЕ ТОПЛИВО", 104, 8)
local fuelBtn = new("TextButton", {
	Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 28), Font = Enum.Font.GothamBold, TextSize = 13,
	Text = "Беск. топливо", TextColor3 = C.text, BackgroundColor3 = C.off, Parent = c8,
}, {round(8)})
local fuelBox = new("TextBox", {
	Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 66), Text = "fuel, gas, petrol, бензин, топливо",
	PlaceholderText = "имена значений через запятую", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
	TextColor3 = C.text, PlaceholderColor3 = Color3.fromRGB(120, 126, 160), BackgroundColor3 = C.field, Parent = c8,
}, {round(6)})

-- ===== карточка: самолёт / сканер =====
local c9 = card("САМОЛЁТ И СКАНЕР ЗНАЧЕНИЙ", 258, 9)
local durBtn = new("TextButton", {
	Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 28), Font = Enum.Font.GothamBold, TextSize = 13,
	Text = "Неломаемый самолёт", TextColor3 = C.text, BackgroundColor3 = C.off, Parent = c9,
}, {round(8)})
local durBox = new("TextBox", {
	Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 66), Text = "health, hp, durab, прочн",
	PlaceholderText = "имена значений через запятую", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
	TextColor3 = C.text, PlaceholderColor3 = Color3.fromRGB(120, 126, 160), BackgroundColor3 = C.field, Parent = c9,
}, {round(6)})
local scanBtn = new("TextButton", {
	Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 100), Font = Enum.Font.GothamBold, TextSize = 13,
	Text = "Сканировать значения (сядь в самолёт)", TextColor3 = C.text, BackgroundColor3 = C.btn, Parent = c9,
}, {round(8)})
local scanOut = new("TextLabel", {
	Size = UDim2.new(1, -24, 0, 112), Position = UDim2.fromOffset(12, 138), BackgroundColor3 = C.field, Text = "Здесь появятся имена значений",
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c9,
}, {round(6), new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), PaddingTop = UDim.new(0, 4)})})

-- ===== уголок для растягивания =====
local grip = new("TextButton", {
	Size = UDim2.fromOffset(20, 20), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -3),
	BackgroundTransparency = 1, Text = "◢", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.sub, ZIndex = 5, Parent = main,
})

-- ===== обновление интерфейса =====
local function paint(btn, on, onC, offC)
	tween(btn, {BackgroundColor3 = on and (onC or C.on) or (offC or C.off)})
end
local function refreshUI()
	local r = (speed - MIN) / (MAX - MIN)
	fill.Size = UDim2.fromScale(r, 1); knob.Position = UDim2.fromScale(r, 0.5)
	if not box:IsFocused() then box.Text = tostring(speed) end
	toggle.Text = enabled and ("ВКЛ  ·  " .. speed) or "ВЫКЛ"
	paint(toggle, enabled, C.on, C.danger)

	local fr = (flySpeed - FMIN) / (FMAX - FMIN)
	ffill.Size = UDim2.fromScale(fr, 1); fknob.Position = UDim2.fromScale(fr, 0.5)
	if not fbox:IsFocused() then fbox.Text = tostring(flySpeed) end

	local vr = (fov - VMIN) / (VMAX - VMIN)
	fovFill.Size = UDim2.fromScale(vr, 1); fovKnob.Position = UDim2.fromScale(vr, 0.5)
	if not fovBox:IsFocused() then fovBox.Text = tostring(fov) end

	paint(noclipBtn, noclip); paint(flyBtn, flying); paint(godBtn, god)
	paint(espBtn, esp); paint(afkBtn, antiAfk)

	local jr = (jumpPower - JMIN) / (JMAX - JMIN)
	jfill.Size = UDim2.fromScale(jr, 1); jknob.Position = UDim2.fromScale(jr, 0.5)
	if not jbox:IsFocused() then jbox.Text = tostring(jumpPower) end
	paint(jumpBtn, jumpOn); paint(infBtn, infJump)
	paint(fuelBtn, fuelOn)
	paint(durBtn, durOn)
	paint(planeBtn, planeGhost)
	paint(seeBtn, seeThrough)
end

local function setSpeed(v)
	v = tonumber(v); if not v then return end
	speed = math.clamp(math.floor(v + 0.5), MIN, MAX); refreshUI(); save()
end
local function setFly(v)
	v = tonumber(v); if not v then return end
	flySpeed = math.clamp(math.floor(v + 0.5), FMIN, FMAX); refreshUI(); save()
end
local function setFov(v)
	v = tonumber(v); if not v then return end
	fov = math.clamp(math.floor(v + 0.5), VMIN, VMAX); refreshUI(); save()
	if fov == 70 and workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView = 70 end
end
local function setJump(v)
	v = tonumber(v); if not v then return end
	jumpPower = math.clamp(math.floor(v + 0.5), JMIN, JMAX); refreshUI(); save()
end

for _, p in ipairs(presetBtns) do
	p[1].MouseButton1Click:Connect(function() setSpeed(p[2]) end)
end
toggle.MouseButton1Click:Connect(function()
	enabled = not enabled
	if not enabled then local h = getHum() if h then h.WalkSpeed = DEFAULT end end
	refreshUI()
end)
box.FocusLost:Connect(function() setSpeed(box.Text) end)
maxPreset.MouseButton1Click:Connect(function() setSpeed(MAX) end)
limBox.FocusLost:Connect(function()
	MAX = math.clamp(math.floor((tonumber(limBox.Text) or MAX) + 0.5), 50, 100000)
	limBox.Text = tostring(MAX)
	if speed > MAX then speed = MAX end
	refreshUI(); save()
end)
fbox.FocusLost:Connect(function() setFly(fbox.Text) end)
fovBox.FocusLost:Connect(function() setFov(fovBox.Text) end)

-- ползунки (на время перетаскивания отключаем прокрутку)
local function bindSlider(trk, hitBtn, lo, hi, setter)
	local dragging = false
	local function fromX(x)
		local r = math.clamp((x - trk.AbsolutePosition.X) / trk.AbsoluteSize.X, 0, 1)
		local top = type(hi) == "function" and hi() or hi
		setter(lo + (top - lo) * r)
	end
	hitBtn.InputBegan:Connect(function(i)
		if isPress(i) then dragging = true; scroll.ScrollingEnabled = false; fromX(i.Position.X) end
	end)
	UIS.InputChanged:Connect(function(i) if dragging and isMove(i) then fromX(i.Position.X) end end)
	UIS.InputEnded:Connect(function(i)
		if isPress(i) and dragging then dragging = false; scroll.ScrollingEnabled = true end
	end)
end
bindSlider(track, hit, MIN, function() return MAX end, setSpeed)
bindSlider(ftrack, fhit, FMIN, FMAX, setFly)
bindSlider(fovTrack, fovHit, VMIN, VMAX, setFov)
bindSlider(jtrack, jhit, JMIN, JMAX, setJump)
jbox.FocusLost:Connect(function() setJump(jbox.Text) end)

-- ===== прыжок: своя высота и бесконечный прыжок =====
jumpBtn.MouseButton1Click:Connect(function()
	jumpOn = not jumpOn
	if not jumpOn then
		local h = getHum()
		if h then h.JumpPower = 50 end
	end
	refreshUI()
end)
infBtn.MouseButton1Click:Connect(function() infJump = not infJump refreshUI() end)
UIS.JumpRequest:Connect(function()
	if not infJump then return end
	local h = getHum()
	if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
end)

-- ===== ноклип =====
RunService.Stepped:Connect(function()
	if not noclip then return end
	local c = lp.Character
	if not c then return end
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
	end
end)
noclipBtn.MouseButton1Click:Connect(function() noclip = not noclip refreshUI() end)

-- ===== полёт =====
local bv, bg
local function stopFly()
	if bv then bv:Destroy() bv = nil end
	if bg then bg:Destroy() bg = nil end
	local h = getHum()
	if h then h.PlatformStand = false end
end
local function startFly()
	stopFly()
	local hrp, h = getHRP(), getHum()
	if not (hrp and h) then return end
	bv = new("BodyVelocity", {MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.zero, Parent = hrp})
	bg = new("BodyGyro", {MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 9e4, CFrame = hrp.CFrame, Parent = hrp})
	h.PlatformStand = true
end
flyBtn.MouseButton1Click:Connect(function()
	flying = not flying
	if flying then startFly() else stopFly() end
	refreshUI()
end)

RunService.RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	if cam and fov ~= 70 and cam.FieldOfView ~= fov then cam.FieldOfView = fov end

	if not flying or not bv or not bg then return end
	local hrp, h = getHRP(), getHum()
	if not (hrp and h and cam) then return end
	local move = h.MoveDirection
	local vel = Vector3.zero
	if move.Magnitude > 0 then
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local fwd = flat.Magnitude > 0 and move:Dot(flat.Unit) or 0
		vel = move * flySpeed + Vector3.new(0, look.Y * fwd * flySpeed, 0)
	end
	if not UIS:GetFocusedTextBox() then
		if UIS:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, flySpeed, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vel -= Vector3.new(0, flySpeed, 0) end
	end
	bv.Velocity = vel
	bg.CFrame = CFrame.new(hrp.Position, hrp.Position + Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z))
end)

-- ===== бессмертие (клиентское) =====
godBtn.MouseButton1Click:Connect(function()
	god = not god
	local h = getHum()
	if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, not god) end) end
	refreshUI()
end)

-- ===== телепорт и спавн =====
local spawnCF
local function captureSpawn()
	local c = lp.Character
	local hrp = c and c:WaitForChild("HumanoidRootPart", 5)
	if hrp then task.wait(0.5); spawnCF = hrp.CFrame end
end
task.spawn(captureSpawn)

posBtn.MouseButton1Click:Connect(function()
	local hrp = getHRP()
	if not hrp then return end
	local p = hrp.Position
	tpBoxes[1].Text, tpBoxes[2].Text, tpBoxes[3].Text = tostring(math.floor(p.X + 0.5)), tostring(math.floor(p.Y + 0.5)), tostring(math.floor(p.Z + 0.5))
end)
tpBtn.MouseButton1Click:Connect(function()
	local hrp = getHRP()
	local x, y, z = tonumber(tpBoxes[1].Text), tonumber(tpBoxes[2].Text), tonumber(tpBoxes[3].Text)
	if hrp and x and y and z then safeTP(CFrame.new(x, y, z)) end
end)
spawnBtn.MouseButton1Click:Connect(function()
	local hrp = getHRP()
	if hrp and spawnCF then safeTP(spawnCF) end
end)

-- ===== ESP: подсветка и имена игроков =====
local espObjs = {}
local function clearEsp(plr)
	local o = espObjs[plr]
	if o then o.hl:Destroy(); o.bb:Destroy(); espObjs[plr] = nil end
end
local function applyEsp(plr)
	do return end -- заменено новым ESP ниже
	if plr == lp then return end
	clearEsp(plr)
	local c = plr.Character
	local head = c and c:FindFirstChild("Head")
	if not head then return end
	local hl = new("Highlight", {
		Adornee = c, FillColor = Color3.fromRGB(255, 80, 80), FillTransparency = 0.7, OutlineColor = Color3.new(1, 1, 1),
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = gui,
	})
	local lab = new("TextLabel", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = plr.DisplayName, Font = Enum.Font.GothamBold,
		TextSize = 13, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.5,
	})
	local bb = new("BillboardGui", {
		Adornee = head, Size = UDim2.fromOffset(140, 30), StudsOffset = Vector3.new(0, 2.5, 0), AlwaysOnTop = true, Parent = gui,
	}, {lab})
	espObjs[plr] = {hl = hl, bb = bb, lab = lab}
end
local function refreshEsp()
	for plr in pairs(espObjs) do clearEsp(plr) end
	if esp then for _, p in ipairs(Players:GetPlayers()) do applyEsp(p) end end
end
local function watchPlayer(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(0.5)
		if esp and not __trk.closed then applyEsp(plr) end
	end)
end
for _, p in ipairs(Players:GetPlayers()) do if p ~= lp then watchPlayer(p) end end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(clearEsp)
espBtn.MouseButton1Click:Connect(function()
	esp = not esp
	refreshEsp(); refreshUI()
end)
RunService.Heartbeat:Connect(function()
	if not esp then return end
	local hrp = getHRP()
	if not hrp then return end
	for plr, o in pairs(espObjs) do
		local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if r then o.lab.Text = plr.DisplayName .. " · " .. math.floor((r.Position - hrp.Position).Magnitude) .. "м" end
	end
end)

-- ===== анти-АФК =====
lp.Idled:Connect(function()
	if not antiAfk then return end
	pcall(function()
		local vu = game:GetService("VirtualUser")
		vu:CaptureController()
		vu:ClickButton2(Vector2.new())
	end)
end)
afkBtn.MouseButton1Click:Connect(function() antiAfk = not antiAfk refreshUI() end)

-- ===== перезаход =====
rejoinBtn.MouseButton1Click:Connect(function()
	local TS = game:GetService("TeleportService")
	pcall(function()
		if #Players:GetPlayers() <= 1 then
			TS:Teleport(game.PlaceId, lp)
		else
			TS:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp)
		end
	end)
end)

-- ===== бесконечное топливо (поиск значений по имени) =====
local fuelMax = setmetatable({}, {__mode = "k"})
local function parseKeys(text)
	local keys = {}
	for k in text:gmatch("[^,]+") do
		k = k:gsub("^%s+", ""):gsub("%s+$", ""):lower()
		if k ~= "" then table.insert(keys, k) end
	end
	return keys
end
local function isNum(o) return o:IsA("NumberValue") or o:IsA("IntValue") end

local function keepValues(text, store)
	local keys = parseKeys(text)
	if #keys == 0 then return end
	local function match(n)
		n = n:lower()
		for _, k in ipairs(keys) do if n:find(k, 1, true) then return true end end
		return false
	end
	local function isMax(n) return n:lower():find("max", 1, true) ~= nil end

	local roots = {lp}
	if lp.Character then table.insert(roots, lp.Character) end
	local h = getHum()
	local seat = h and h.SeatPart
	if seat then
		local m = seat:FindFirstAncestorOfClass("Model")
		while m and m.Parent and m.Parent:IsA("Model") do m = m.Parent end
		if m then table.insert(roots, m) end
	end

	for _, root in ipairs(roots) do
		local list = root:GetDescendants()
		table.insert(list, root)
		for _, d in ipairs(list) do
			if d:IsDescendantOf(lp.PlayerGui) then continue end
			if isNum(d) and match(d.Name) and not isMax(d.Name) then
				local mx = 0
				if d.Parent then
					for _, s in ipairs(d.Parent:GetChildren()) do
						if s ~= d and isNum(s) and isMax(s.Name) and match(s.Name) then mx = math.max(mx, s.Value) end
					end
				end
				local rec = math.max(type(store[d]) == "number" and store[d] or 0, d.Value, mx)
				store[d] = rec
				if d.Value < rec then d.Value = rec end
			end
			for name, val in pairs(d:GetAttributes()) do
				if type(val) == "number" and match(name) and not isMax(name) then
					store[d] = store[d] or {}
					if type(store[d]) == "table" then
						local rec = math.max(store[d][name] or 0, val)
						store[d][name] = rec
						if val < rec then d:SetAttribute(name, rec) end
					end
				end
			end
		end
	end
end

local durMax = setmetatable({}, {__mode = "k"})

fuelBtn.MouseButton1Click:Connect(function()
	fuelOn = not fuelOn
	if fuelOn then for k in pairs(fuelMax) do fuelMax[k] = nil end end
	refreshUI()
end)
durBtn.MouseButton1Click:Connect(function()
	durOn = not durOn
	if durOn then for k in pairs(durMax) do durMax[k] = nil end end
	refreshUI()
end)
local keepTimer = 0
RunService.Heartbeat:Connect(function(dt)
	if not (fuelOn or durOn) then return end
	keepTimer += dt
	if keepTimer < 0.4 then return end
	keepTimer = 0
	if fuelOn then pcall(keepValues, fuelBox.Text, fuelMax) end
	if durOn then pcall(keepValues, durBox.Text, durMax) end
end)

-- ===== сканер: показывает имена числовых значений рядом с тобой и в твоём самолёте =====
scanBtn.MouseButton1Click:Connect(function()
	local roots = {lp}
	if lp.Character then table.insert(roots, lp.Character) end
	local h = getHum()
	local seat = h and h.SeatPart
	if seat then
		local m = seat:FindFirstAncestorOfClass("Model")
		while m and m.Parent and m.Parent:IsA("Model") do m = m.Parent end
		if m then table.insert(roots, m) end
	end
	local counts, vals, order = {}, {}, {}
	local function add(name, v)
		if not counts[name] then counts[name] = 0; table.insert(order, name) end
		counts[name] += 1; vals[name] = v
	end
	for _, root in ipairs(roots) do
		local list = root:GetDescendants()
		table.insert(list, root)
		for _, d in ipairs(list) do
			if d:IsDescendantOf(lp.PlayerGui) then continue end
			if isNum(d) then add(d.Name, d.Value) end
			for n, v in pairs(d:GetAttributes()) do
				if type(v) == "number" then add(n .. "*", v) end
			end
		end
	end
	if #order == 0 then
		scanOut.Text = seat and "Числовых значений не найдено — возможно, игра хранит их на сервере." or "Значений не найдено. Сядь в самолёт и нажми снова."
		return
	end
	local hot = {"fuel", "gas", "health", "hp", "durab", "energy", "stamina", "boost", "топлив", "прочн"}
	local function isHot(n)
		n = n:lower()
		for _, k in ipairs(hot) do if n:find(k, 1, true) then return true end end
		return false
	end
	table.sort(order, function(a, b)
		local ha, hb = isHot(a), isHot(b)
		if ha ~= hb then return ha end
		return a < b
	end)
	local parts = {}
	for i, n in ipairs(order) do
		if i > 60 then table.insert(parts, "… ещё " .. (#order - 60)); break end
		table.insert(parts, n .. (counts[n] > 1 and ("×" .. counts[n]) or "") .. "=" .. tostring(math.floor(vals[n] * 100) / 100))
	end
	local status = seat and "Самолёт найден. " or "Ты не сидишь в самолёте — покажу только данные игрока. "
	scanOut.Text = status .. table.concat(parts, " · ") .. "\n(* — атрибут)"
end)

-- ===== самолёт сквозь препятствия (экспериментально, только на твоей стороне) =====
local ghosted = {}
local function flash(btn, text)
	local orig = btn.Text
	btn.Text = text
	task.delay(2, function() if btn.Parent then btn.Text = orig end end)
end
local function planeModel()
	local h = getHum()
	local seat = h and h.SeatPart
	if not seat then return nil end
	local m = seat:FindFirstAncestorOfClass("Model")
	while m and m.Parent and m.Parent:IsA("Model") and m.Parent:GetExtentsSize().Magnitude < 400 do
		m = m.Parent
	end
	return m
end
RunService.Stepped:Connect(function()
	if not planeGhost then return end
	local m = planeModel()
	if not m then return end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			ghosted[p] = true
			p.CanCollide = false
		end
	end
end)
planeBtn.MouseButton1Click:Connect(function()
	planeGhost = not planeGhost
	if planeGhost and not planeModel() then flash(planeBtn, "Самолёт не найден") end
	if not planeGhost then
		for p in pairs(ghosted) do
			if p.Parent then p.CanCollide = true end
			ghosted[p] = nil
		end
	end
	refreshUI()
end)

-- ===== прозрачный самолёт (только внешний вид, виден только тебе) =====
local seen = {}
RunService.RenderStepped:Connect(function()
	if not seeThrough then return end
	local m = planeModel()
	if not m then return end
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			seen[p] = true
			p.LocalTransparencyModifier = 0.7
		end
	end
end)
seeBtn.MouseButton1Click:Connect(function()
	seeThrough = not seeThrough
	if seeThrough and not planeModel() then flash(seeBtn, "Самолёт не найден") end
	if not seeThrough then
		for p in pairs(seen) do
			if p.Parent then p.LocalTransparencyModifier = 0 end
			seen[p] = nil
		end
	end
	refreshUI()
end)

-- ===== респавн =====
lp.CharacterAdded:Connect(function(c)
	c:WaitForChild("HumanoidRootPart")
	local h = c:WaitForChild("Humanoid")
	bv, bg = nil, nil
	task.spawn(captureSpawn)
	if __trk.closed then return end
	if flying then startFly() end
	if god then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end) end
end)

-- ===== окно: перетаскивание, растягивание, сворачивание, скрытие =====
local dragWin, dragStart, startPos
header.InputBegan:Connect(function(i)
	if isPress(i) then dragWin, dragStart, startPos = true, i.Position, main.Position end
end)
local resizing, rStart, rSize
grip.InputBegan:Connect(function(i)
	if isPress(i) then resizing, rStart, rSize = true, i.Position, main.AbsoluteSize end
end)
UIS.InputChanged:Connect(function(i)
	if not isMove(i) then return end
	if dragWin then
		local d = i.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	elseif resizing then
		local d = i.Position - rStart
		main.Size = UDim2.fromOffset(math.clamp(rSize.X + d.X, 340, 640), math.clamp(rSize.Y + d.Y, 350, 720))
	end
end)
UIS.InputEnded:Connect(function(i)
	if isPress(i) then dragWin, resizing = false, false end
end)

local folded, expandedSize = false, main.Size
minBtn.MouseButton1Click:Connect(function()
	folded = not folded
	if folded then expandedSize = main.Size end
	scroll.Visible = not folded
	grip.Visible = not folded
	main.Size = folded and UDim2.fromOffset(expandedSize.X.Offset, 36) or expandedSize
	minBtn.Text = folded and "+" or "—"
end)
UIS.InputBegan:Connect(function(i, gp)
	if not gp and i.KeyCode == Enum.KeyCode.RightShift then main.Visible = not main.Visible end
end)

-- ===== каждый кадр: скорость и бессмертие =====
RunService.Heartbeat:Connect(function()
	local h = getHum()
	if not h then return end
	local typing = UIS:GetFocusedTextBox() ~= nil
	local touchOnly = UIS.TouchEnabled and not UIS.KeyboardEnabled
	local sprinting = sprintOn and not typing and (
		(not touchOnly and UIS:IsKeyDown(Enum.KeyCode.LeftShift)) or (touchOnly and h.MoveDirection.Magnitude > 0)
	)
	local target = enabled and speed or nil
	if sprinting then target = (target or DEFAULT) * sprintMult end
	if target and h.WalkSpeed ~= target then h.WalkSpeed = target end
	if wasSprint and not sprinting and not enabled then h.WalkSpeed = DEFAULT end
	wasSprint = sprinting
	if jumpOn then
		if not h.UseJumpPower then h.UseJumpPower = true end
		if h.JumpPower ~= jumpPower then h.JumpPower = jumpPower end
	end
	if god then
		if h.MaxHealth ~= math.huge then h.MaxHealth = math.huge end
		if h.Health < h.MaxHealth then h.Health = h.MaxHealth end
	end
end)

-- =====================================================================
-- ===== v4: гравитация, анти-бездна, спринт, свободная камера, игроки,
-- =====      секундомер, сохранённые позиции
-- =====================================================================
local function toggleBtn(p, y, text)
	return new("TextButton", {
		Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, y), Font = Enum.Font.GothamBold, TextSize = 13,
		Text = text, TextColor3 = C.text, BackgroundColor3 = C.off, Parent = p,
	}, {round(8)})
end

do
-- ----- гравитация -----
local gravOn, gravPct = false, 100
local c10 = card("ГРАВИТАЦИЯ", 124, 10)
local gravBtn = toggleBtn(c10, 28, "Своя гравитация")
label(c10, "Процент от обычной", 66)
local gbox = numBox(c10, 66, gravPct)
local gtrack, gfill, gknob, ghit = slider(c10, 108)
local function setGrav(v)
	v = tonumber(v); if not v then return end
	gravPct = math.clamp(math.floor(v + 0.5), 10, 300)
	local r = (gravPct - 10) / 290
	gfill.Size = UDim2.fromScale(r, 1); gknob.Position = UDim2.fromScale(r, 0.5)
	if not gbox:IsFocused() then gbox.Text = tostring(gravPct) end
end
setGrav(gravPct)
bindSlider(gtrack, ghit, 10, 300, setGrav)
gbox.FocusLost:Connect(function() setGrav(gbox.Text) end)
gravBtn.MouseButton1Click:Connect(function()
	gravOn = not gravOn
	paint(gravBtn, gravOn)
	if not gravOn then workspace.Gravity = 196.2 end
end)
RunService.Heartbeat:Connect(function()
	if gravOn then workspace.Gravity = 196.2 * gravPct / 100 end
end)
end

do
-- ----- движение: анти-бездна и спринт -----
local c11 = card("ДВИЖЕНИЕ", 104, 11)
local mvRow = row(c11, 28, 32)
local voidBtn   = cell(mvRow, 2, "Анти-бездна", C.off)
local sprintBtn = cell(mvRow, 2, "Спринт", C.off)
label(c11, "Множитель спринта", 66)
local sbox = numBox(c11, 66, sprintMult)
sbox.FocusLost:Connect(function()
	sprintMult = math.clamp(tonumber(sbox.Text) or sprintMult, 1, 10)
	sbox.Text = tostring(sprintMult)
end)
sprintBtn.MouseButton1Click:Connect(function()
	sprintOn = not sprintOn
	paint(sprintBtn, sprintOn)
end)
voidBtn.MouseButton1Click:Connect(function()
	voidOn = not voidOn
	paint(voidBtn, voidOn)
end)
_G.SpeedMenuVoidBtn = voidBtn -- кнопка видна из других блоков (модуль «Анти-падение»)

local lastSafe
RunService.Heartbeat:Connect(function()
	if not voidOn then return end
	local hrp, h = getHRP(), getHum()
	if not (hrp and h) then return end
	if not h.SeatPart and h.FloorMaterial ~= Enum.Material.Air then lastSafe = hrp.CFrame end
	local limit = math.max(workspace.FallenPartsDestroyHeight, -2000) + 60
	if hrp.Position.Y < limit and lastSafe then
		hrp.AssemblyLinearVelocity = Vector3.zero
		safeTP(lastSafe + Vector3.new(0, 5, 0))
	end
end)
end

-- ----- свободная камера -----
local c12 = card("СВОБОДНАЯ КАМЕРА", 108, 12)
local freeBtn = toggleBtn(c12, 28, "Свободная камера")
new("TextLabel", {
	Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 66), BackgroundTransparency = 1,
	Text = "Джойстик / WASD — двигать, Space и Ctrl — вверх и вниз, тянуть по экрану (на ПК — правой кнопкой) — повернуть. Скорость как у полёта.",
	Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c12,
})
local freeOn, freePos, fyaw, fpitch, didAnchor = false, nil, 0, 0, false
local function stopFree()
	freeOn = false
	local cam, hrp, h = workspace.CurrentCamera, getHRP(), getHum()
	if hrp and didAnchor then hrp.Anchored = false end
	didAnchor = false
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		if h then cam.CameraSubject = h end
	end
	paint(freeBtn, false)
end
freeBtn.MouseButton1Click:Connect(function()
	if freeOn then stopFree() return end
	local cam, hrp, h = workspace.CurrentCamera, getHRP(), getHum()
	if not (cam and hrp and h) then return end
	freeOn = true
	paint(freeBtn, true)
	if not h.SeatPart then hrp.Anchored = true; didAnchor = true end
	freePos = cam.CFrame.Position
	local rx, ry = cam.CFrame:ToOrientation()
	fpitch, fyaw = rx, ry
	cam.CameraType = Enum.CameraType.Scriptable
end)
RunService.RenderStepped:Connect(function(dt)
	if not freeOn then return end
	local cam, h = workspace.CurrentCamera, getHum()
	if not (cam and h) then return end
	local cf = CFrame.fromOrientation(fpitch, fyaw, 0)
	local move = h.MoveDirection
	local vel = Vector3.zero
	if move.Magnitude > 0 then
		local look = cf.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local fwd = flat.Magnitude > 0 and move:Dot(flat.Unit) or 0
		vel = move * flySpeed + Vector3.new(0, look.Y * fwd * flySpeed, 0)
	end
	if not UIS:GetFocusedTextBox() then
		if UIS:IsKeyDown(Enum.KeyCode.Space) then vel += Vector3.new(0, flySpeed, 0) end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then vel -= Vector3.new(0, flySpeed, 0) end
	end
	freePos += vel * dt
	cam.CFrame = CFrame.new(freePos) * cf
end)
UIS.InputChanged:Connect(function(i, gp)
	if not freeOn or gp then return end
	local rotate = (i.UserInputType == Enum.UserInputType.MouseMovement and UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2))
		or i.UserInputType == Enum.UserInputType.Touch
	if rotate then
		fyaw -= i.Delta.X * 0.005
		fpitch = math.clamp(fpitch - i.Delta.Y * 0.005, -1.5, 1.5)
	end
end)
lp.CharacterAdded:Connect(function() if freeOn then stopFree() end end)

do
-- ----- список игроков (поиск, расстояние, телепорт, наблюдение) -----
local c13 = card("ИГРОКИ (👁 — следить камерой, имя — телепорт)", 262, 13)
local pSearch = new("TextBox", {
	Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 28), Text = "", PlaceholderText = "🔍 поиск игрока…", ClearTextOnFocus = false,
	Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text, PlaceholderColor3 = Color3.fromRGB(120, 126, 160), BackgroundColor3 = C.field, Parent = c13,
}, {round(6)})
local plist = new("ScrollingFrame", {
	Size = UDim2.new(1, -24, 0, 170), Position = UDim2.fromOffset(12, 62), BackgroundColor3 = C.field, BorderSizePixel = 0,
	ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = c13,
}, {
	round(6),
	new("UIListLayout", {Padding = UDim.new(0, 4)}),
	new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)}),
})
local pInfo = new("TextLabel", {
	Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 236), BackgroundTransparency = 1, Text = "",
	Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = c13,
})
local watching = nil
local function stopWatch()
	watching = nil
	pcall(function()
		local cam, h = workspace.CurrentCamera, getHum()
		if cam and h then cam.CameraSubject = h end
	end)
end
local pRows = {}
local function rebuildPlayers()
	for _, ch in ipairs(plist:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
	pRows = {}
	local q = string.lower(pSearch.Text or "")
	local n = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= lp then
			n = n + 1
			local hit = q == "" or string.find(string.lower(p.DisplayName), q, 1, true) or string.find(string.lower(p.Name), q, 1, true)
			if hit then
				local fr = new("Frame", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Parent = plist})
				local b = new("TextButton", {
					Size = UDim2.new(1, -34, 1, 0), Text = p.DisplayName .. "  (@" .. p.Name .. ")", Font = Enum.Font.Gotham, TextSize = 12,
					TextColor3 = C.text, BackgroundColor3 = C.btn, TextTruncate = Enum.TextTruncate.AtEnd, Parent = fr,
				}, {round(6)})
				local eye = new("TextButton", {
					Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -28, 0, 0), Text = "👁", Font = Enum.Font.GothamBold, TextSize = 14,
					TextColor3 = C.text, BackgroundColor3 = C.btn, Parent = fr,
				}, {round(6)})
				b.MouseButton1Click:Connect(function()
					local theirs = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if theirs then safeTP(theirs.CFrame + Vector3.new(0, 4, 0)) end
				end)
				eye.MouseButton1Click:Connect(function()
					if watching == p then stopWatch() return end
					local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
					local cam = workspace.CurrentCamera
					if h and cam then watching = p; cam.CameraSubject = h end
				end)
				pRows[p] = b
			end
		end
	end
	pInfo.Text = "На сервере: " .. (#Players:GetPlayers()) .. " игроков"
end
rebuildPlayers()
pSearch:GetPropertyChangedSignal("Text"):Connect(rebuildPlayers)
Players.PlayerAdded:Connect(function() task.wait(0.2) if not __trk.closed then pcall(rebuildPlayers) end end)
Players.PlayerRemoving:Connect(function(p) if __trk.closed then return end if watching == p then stopWatch() end task.defer(function() pcall(rebuildPlayers) end) end)
lp.CharacterAdded:Connect(function() watching = nil end)
-- расстояние до каждого игрока на кнопке — раз в секунду
local pAlive = true
table.insert(_G.SpeedMenuCleanup, function() pAlive = false end)
task.spawn(function()
	while pAlive do
		task.wait(1)
		local mine = getHRP()
		for p, b in pairs(pRows) do
			pcall(function()
				if b.Parent then
					local t = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					local d = (mine and t) and math.floor((mine.Position - t.Position).Magnitude) or nil
					b.Text = p.DisplayName .. "  (@" .. p.Name .. ")" .. (d and ("  · " .. d .. " м") or "")
				end
			end)
		end
	end
end)
table.insert(_G.SpeedMenuCleanup, stopWatch)
end

do
-- ----- секундомер и дистанция -----
local c14 = card("СЕКУНДОМЕР И ДИСТАНЦИЯ", 108, 14)
local swLabel = new("TextLabel", {
	Size = UDim2.new(1, -24, 0, 28), Position = UDim2.fromOffset(12, 26), BackgroundTransparency = 1, Text = "00:00.0  ·  0 м",
	Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Parent = c14,
})
local swRow = row(c14, 62, 34)
local swStart = cell(swRow, 2, "Старт", C.on)
local swReset = cell(swRow, 2, "Сброс")
local swRun, swTime, swDist, swLast = false, 0, 0, nil
local function swRefresh()
	local m = math.floor(swTime / 60)
	local s = swTime - m * 60
	swLabel.Text = string.format("%02d:%04.1f  ·  %d м", m, s, math.floor(swDist))
	swStart.Text = swRun and "Стоп" or "Старт"
	swStart.BackgroundColor3 = swRun and C.danger or C.on
end
swStart.MouseButton1Click:Connect(function()
	swRun = not swRun
	swLast = nil
	swRefresh()
end)
swReset.MouseButton1Click:Connect(function()
	swTime, swDist, swLast = 0, 0, nil
	swRefresh()
end)
RunService.Heartbeat:Connect(function(dt)
	if not swRun then return end
	swTime += dt
	local hrp = getHRP()
	if hrp then
		local p = hrp.Position
		if swLast then
			local d = (p - swLast).Magnitude
			if d < 150 then swDist += d end -- большие скачки (телепорт) не считаем
		end
		swLast = p
	end
	swRefresh()
end)
end

do
-- ----- сохранённые позиции -----
local c15 = card("СОХРАНЁННЫЕ ПОЗИЦИИ", 108, 15)
local slots = {}
local saveRow = row(c15, 28, 32)
local goRow = row(c15, 66, 32)
for i = 1, 3 do
	local sb = cell(saveRow, 3, "Сохр. " .. i)
	local gb = cell(goRow, 3, "ТП " .. i, C.accent)
	sb.MouseButton1Click:Connect(function()
		local hrp = getHRP()
		if hrp then slots[i] = hrp.CFrame; flash(sb, "Сохранено ✓") end
	end)
	gb.MouseButton1Click:Connect(function()
		local hrp = getHRP()
		if not slots[i] then flash(gb, "Пусто") return end
		if hrp then safeTP(slots[i]) end
	end)
end
end

-- ===== АИМ (наведение на игроков) =====
-- обёрнут в функцию, чтобы не упереться в лимит локальных переменных основного скрипта
xpcall(function() --[[аим и бот]]
	local AIM_FILE = "SpeedMenuAim2.json"
	local PARTS = {"Голова", "Торс", "Авто"}
	local PRIOS = {"Прицел", "Дистанц.", "Здоровье"}
	local KEYS  = {"ПКМ", "ЛКМ", "E", "Q", "Shift"}

	local aimOn, teamCheck, wallCheck = false, true, true
	local friendCheck, sticky, predOn, showInd, crossOn = false, false, false, true, true
	local allMode = true
	local queueOn = true -- НОВОЕ: цели по очереди
	local ballistic, dropOn, autoPing = true, false, true -- точность: расчёт упреждения, падение пули, пинг
	local teamGames = {}
	local autoFire, skipFF, bulletSpeed = false, true, 0
	local circMode, aimLocked = 1, false
	local aimFov, aimSmooth, aimDist, predMs = 150, 1, 1000, 100
	local partI, prioI, keyI = 1, 1, 1
	local wlText = ""
	local stickyChar

	-- ----- загрузка настроек -----
	local function num(v, lo, hi, def) return math.clamp(tonumber(v) or def, lo, hi) end
	if canSave then
		local ok, d = pcall(function() return HttpService:JSONDecode(readfile(AIM_FILE)) end)
		if ok and type(d) == "table" then
			if type(d.teamCheck) == "boolean" then teamCheck = d.teamCheck end
			if type(d.wallCheck) == "boolean" then wallCheck = d.wallCheck end
			if type(d.friendCheck) == "boolean" then friendCheck = d.friendCheck end
			if type(d.sticky) == "boolean" then sticky = d.sticky end
			if type(d.predOn) == "boolean" then predOn = d.predOn end
			if type(d.showInd) == "boolean" then showInd = d.showInd end
			if type(d.crossOn) == "boolean" then crossOn = d.crossOn end
			if type(d.allMode) == "boolean" then allMode = d.allMode end
			if type(d.queueOn) == "boolean" then queueOn = d.queueOn end
			if type(d.ballistic) == "boolean" then ballistic = d.ballistic end
			if type(d.dropOn) == "boolean" then dropOn = d.dropOn end
			if type(d.autoPing) == "boolean" then autoPing = d.autoPing end
			if type(d.teamGames) == "table" then teamGames = d.teamGames end
			if type(d.autoFire) == "boolean" then autoFire = d.autoFire end
			if type(d.skipFF) == "boolean" then skipFF = d.skipFF end
			bulletSpeed = num(d.bulletSpeed, 0, 5000, 0)
			circMode = num(d.circMode, 1, 3, 1)
			aimFov = num(d.aimFov, 20, 600, aimFov)
			aimSmooth = num(d.aimSmooth, 1, 30, aimSmooth)
			aimDist = num(d.aimDist, 50, 5000, aimDist)
			predMs = num(d.predMs, 0, 500, predMs)
			partI = num(d.partI, 1, #PARTS, 1)
			prioI = num(d.prioI, 1, #PRIOS, 1)
			keyI = num(d.keyI, 1, #KEYS, 1)
			if type(d.wl) == "string" then wlText = d.wl end
		end
	end
	local queued = false
	local function saveAim()
		if not canSave or queued then return end
		queued = true
		task.delay(1, function()
			queued = false
			pcall(function()
				writefile(AIM_FILE, HttpService:JSONEncode({
					teamCheck = teamCheck, wallCheck = wallCheck, friendCheck = friendCheck, sticky = sticky,
					predOn = predOn, showInd = showInd, crossOn = crossOn, allMode = allMode, queueOn = queueOn,
					ballistic = ballistic, dropOn = dropOn, autoPing = autoPing,
					teamGames = teamGames, autoFire = autoFire, skipFF = skipFF, bulletSpeed = bulletSpeed,
					circMode = circMode, aimFov = aimFov, aimSmooth = aimSmooth, aimDist = aimDist,
					predMs = predMs, partI = partI, prioI = prioI, keyI = keyI, wl = wlText,
				}))
			end)
		end)
	end

	-- ----- интерфейс -----
	local c16 = card("АИМ", 700, 16)
	local aimBtn = toggleBtn(c16, 28, "Аим (RightAlt — вкл/выкл)")
	local r1 = row(c16, 66, 32)
	local teamBtn = cell(r1, 2, "Не в команду", C.on)
	local wallBtn = cell(r1, 2, "Не сквозь стены", C.on)
	local r2 = row(c16, 104, 32)
	local friendBtn = cell(r2, 3, "Не друзей", C.off)
	local stickyBtn = cell(r2, 3, "Липкая цель", C.off)
	local predBtn   = cell(r2, 3, "Упреждение", C.off)
	local r3 = row(c16, 142, 32)
	local partBtn = cell(r3, 3, "")
	local prioBtn = cell(r3, 3, "")
	local keyBtn  = cell(r3, 3, "")
	for _, b in ipairs({partBtn, prioBtn, keyBtn, friendBtn, stickyBtn, predBtn}) do b.TextSize = 11 end
	local r5 = row(c16, 388, 32)
	local gameBtn = cell(r5, 1, "", C.off)
	gameBtn.TextSize = 11
	local r6 = row(c16, 426, 32)
	local autoBtn = cell(r6, 2, "Автострельба", C.off)
	local ffBtn = cell(r6, 2, "Не в защиту (FF)", C.on)
	autoBtn.TextSize = 11; ffBtn.TextSize = 11
	label(c16, "Скорость пули", 464)
	local bulletB = numBox(c16, 464, bulletSpeed)
	local r7 = row(c16, 502, 32)
	local colBtn = cell(r7, 1, "")
	colBtn.TextSize = 11
	local r8 = row(c16, 540, 32) -- НОВОЕ
	local queueBtn = cell(r8, 1, "", C.on)
	queueBtn.TextSize = 11
	local r9 = row(c16, 578, 32) -- ТОЧНОСТЬ
	local ballBtn = cell(r9, 3, "Баллистика", C.on)
	local dropBtn = cell(r9, 3, "Падение пули", C.off)
	local pingBtn = cell(r9, 3, "Авто-пинг", C.on)
	ballBtn.TextSize = 11; dropBtn.TextSize = 11; pingBtn.TextSize = 11
	local r4 = row(c16, 180, 32)
	local indBtn = cell(r4, 3, "Индикатор", C.on)
	local crossBtn = cell(r4, 3, "Прицел", C.on)
	local allBtn = cell(r4, 3, "Все цели", C.on)
	indBtn.TextSize = 11; crossBtn.TextSize = 11; allBtn.TextSize = 11

	label(c16, "Радиус (px)", 218)
	local fovB = numBox(c16, 218, aimFov)
	label(c16, "Плавность (1 = мгновенно)", 252)
	local smB = numBox(c16, 252, aimSmooth)
	label(c16, "Макс. дистанция", 286)
	local distB = numBox(c16, 286, aimDist)
	label(c16, "Упреждение (мс)", 320)
	local predB = numBox(c16, 320, predMs)

	local wlBox = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 356), Text = wlText,
		PlaceholderText = "белый список ников через запятую", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
		TextColor3 = C.text, PlaceholderColor3 = Color3.fromRGB(120, 126, 160), BackgroundColor3 = C.field, Parent = c16,
	}, {round(6)})
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 56), Position = UDim2.fromOffset(12, 618), BackgroundTransparency = 1,
		Text = "Точность: Баллистика считает точку перехвата с учётом скорости пули (задай её выше, 0 = мгновенная), Падение пули добавляет поправку на гравитацию, Авто-пинг компенсирует задержку. ПК: держи выбранную кнопку. Телефон: аим работает всегда, пока включён. По очереди: аим держит одну цель, пока она не умрёт или не пропадёт, потом берёт следующую (порядок — по приоритету). Все цели: игроки и NPC, без фильтров. Скорость пули 0 = мгновенная.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c16,
	})

	-- круг радиуса, линия и подпись цели
	local circGui = new("ScreenGui", {Name = "AimCircle", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = gui.Parent or parent})
	local circle = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(aimFov * 2, aimFov * 2), BackgroundTransparency = 1, Visible = false, Parent = circGui,
	}, {new("UICorner", {CornerRadius = UDim.new(1, 0)}), new("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.3})})
	local line = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(255, 80, 80), BorderSizePixel = 0,
		Size = UDim2.fromOffset(0, 2), Visible = false, Parent = circGui,
	})
	local tag = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, Size = UDim2.fromOffset(180, 16),
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4,
		Visible = false, Parent = circGui,
	})
	local function hideInd() line.Visible = false; tag.Visible = false end

	-- прицел строго по центру экрана
	local cross = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Visible = crossOn, Parent = circGui,
	})
	local function crossPart(w, h)
		return new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h),
			BackgroundColor3 = Color3.fromRGB(255, 60, 60), BorderSizePixel = 0, Parent = cross,
		}, {new("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1})})
	end
	crossPart(24, 2); crossPart(2, 24)
	new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1, Parent = cross,
	}, {new("UICorner", {CornerRadius = UDim.new(1, 0)}), new("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1.5})})

	local queueChar, queueLost, queueGap
	local function refresh()
		paint(aimBtn, aimOn); paint(teamBtn, teamCheck); paint(wallBtn, wallCheck)
		paint(friendBtn, friendCheck); paint(stickyBtn, sticky); paint(predBtn, predOn); paint(indBtn, showInd); paint(crossBtn, crossOn); paint(allBtn, allMode)
		local here = teamGames[tostring(game.PlaceId)] == true
		paint(gameBtn, here)
		gameBtn.Text = here and "В этой игре: не целиться в тиммейтов ✓" or "В этой игре: целиться во всех"
		paint(autoBtn, autoFire); paint(ffBtn, skipFF)
		paint(queueBtn, queueOn)
		paint(ballBtn, ballistic); paint(dropBtn, dropOn); paint(pingBtn, autoPing)
		queueBtn.Text = queueOn and "Цели по очереди: ВКЛ" or "Цели по очереди: ВЫКЛ"
		colBtn.Text = "Цвет круга: " .. ({"белый", "радуга", "красный при захвате"})[circMode]
		paint(colBtn, circMode ~= 1)
		partBtn.Text = "Цель: " .. PARTS[partI]
		prioBtn.Text = "Приор.: " .. PRIOS[prioI]
		keyBtn.Text = "Кнопка: " .. KEYS[keyI]
	end
	local function setAim(v)
		aimOn = v
		circle.Visible = v
		if not v then stickyChar = nil; queueChar = nil; hideInd() end
		refresh()
	end

	aimBtn.MouseButton1Click:Connect(function() setAim(not aimOn) end)
	teamBtn.MouseButton1Click:Connect(function() teamCheck = not teamCheck refresh() saveAim() end)
	wallBtn.MouseButton1Click:Connect(function() wallCheck = not wallCheck refresh() saveAim() end)
	friendBtn.MouseButton1Click:Connect(function() friendCheck = not friendCheck refresh() saveAim() end)
	stickyBtn.MouseButton1Click:Connect(function() sticky = not sticky stickyChar = nil refresh() saveAim() end)
	predBtn.MouseButton1Click:Connect(function() predOn = not predOn refresh() saveAim() end)
	indBtn.MouseButton1Click:Connect(function() showInd = not showInd if not showInd then hideInd() end refresh() saveAim() end)
	allBtn.MouseButton1Click:Connect(function() allMode = not allMode stickyChar = nil queueChar = nil refresh() saveAim() end)
	queueBtn.MouseButton1Click:Connect(function() queueOn = not queueOn queueChar = nil queueLost = nil refresh() saveAim() end)
	ballBtn.MouseButton1Click:Connect(function() ballistic = not ballistic refresh() saveAim() end)
	dropBtn.MouseButton1Click:Connect(function() dropOn = not dropOn refresh() saveAim() end)
	pingBtn.MouseButton1Click:Connect(function() autoPing = not autoPing refresh() saveAim() end)
	crossBtn.MouseButton1Click:Connect(function() crossOn = not crossOn cross.Visible = crossOn refresh() saveAim() end)
	colBtn.MouseButton1Click:Connect(function() circMode = circMode % 3 + 1 refresh() saveAim() end)
	autoBtn.MouseButton1Click:Connect(function() autoFire = not autoFire refresh() saveAim() end)
	ffBtn.MouseButton1Click:Connect(function() skipFF = not skipFF refresh() saveAim() end)
	bulletB.FocusLost:Connect(function() bulletSpeed = num(bulletB.Text, 0, 5000, bulletSpeed) bulletB.Text = tostring(bulletSpeed) saveAim() end)
	gameBtn.MouseButton1Click:Connect(function()
		local k = tostring(game.PlaceId)
		teamGames[k] = (not teamGames[k]) or nil
		stickyChar = nil; queueChar = nil
		refresh() saveAim()
	end)
	partBtn.MouseButton1Click:Connect(function() partI = partI % #PARTS + 1 refresh() saveAim() end)
	prioBtn.MouseButton1Click:Connect(function() prioI = prioI % #PRIOS + 1 stickyChar = nil queueChar = nil refresh() saveAim() end)
	keyBtn.MouseButton1Click:Connect(function() keyI = keyI % #KEYS + 1 refresh() saveAim() end)

	fovB.FocusLost:Connect(function()
		aimFov = num(fovB.Text, 20, 600, aimFov)
		fovB.Text = tostring(aimFov)
		circle.Size = UDim2.fromOffset(aimFov * 2, aimFov * 2)
		saveAim()
	end)
	smB.FocusLost:Connect(function() aimSmooth = num(smB.Text, 1, 30, aimSmooth) smB.Text = tostring(aimSmooth) saveAim() end)
	distB.FocusLost:Connect(function() aimDist = num(distB.Text, 50, 5000, aimDist) distB.Text = tostring(aimDist) saveAim() end)
	predB.FocusLost:Connect(function() predMs = num(predB.Text, 0, 500, predMs) predB.Text = tostring(predMs) saveAim() end)

	-- ----- белый список и друзья -----
	local wlSet = {}
	local function parseWl()
		wlSet = {}
		for n in wlText:gmatch("[^,]+") do
			n = n:gsub("^%s+", ""):gsub("%s+$", ""):lower()
			if n ~= "" then wlSet[n] = true end
		end
	end
	parseWl()
	wlBox.FocusLost:Connect(function() wlText = wlBox.Text parseWl() saveAim() end)

	local friendCache, friendPending = {}, {}
	local function isFriend(p)
		local v = friendCache[p.UserId]
		if v ~= nil then return v end
		if not friendPending[p.UserId] then
			friendPending[p.UserId] = true
			task.spawn(function()
				local ok, r = pcall(function() return lp:IsFriendsWith(p.UserId) end)
				friendCache[p.UserId] = ok and r == true
			end)
		end
		return false
	end

	-- ----- выбор цели -----
	local function visible(cam, part, char)
		if not wallCheck then return true end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {lp.Character, char}
		return workspace:Raycast(cam.CFrame.Position, part.Position - cam.CFrame.Position, params) == nil
	end

	local function screenDist(cam, part, center)
		local sp, on = cam:WorldToViewportPoint(part.Position)
		if not on then return math.huge end
		return (Vector2.new(sp.X, sp.Y) - center).Magnitude
	end

	local function pickPart(c, cam, center)
		local head = c:FindFirstChild("Head")
		local torso = c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") or c:FindFirstChild("HumanoidRootPart")
		if partI == 1 then return head or torso end
		if partI == 2 then return torso or head end
		local best, bestD = nil, math.huge
		for _, n in ipairs({"Head", "UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso"}) do
			local pt = c:FindFirstChild(n)
			if pt then
				local d = screenDist(cam, pt, center)
				if d < bestD and visible(cam, pt, c) then best, bestD = pt, d end
			end
		end
		return best or head or torso
	end

	-- ----- список целей: игроки и NPC -----
	-- живой ли персонаж: труп (здоровье 0, состояние Dead, нет частей тела) целью не считается
	-- запоминаем всех, кто хоть раз умирал (событие Died): игры иногда возвращают трупу здоровье
	local deadSet = setmetatable({}, {__mode = "k"})
	local watched = setmetatable({}, {__mode = "k"})
	local DEAD_FLAGS = {"Dead", "IsDead", "Died", "Downed", "IsDowned", "Knocked", "Eliminated", "Ragdolled"}
	local function watchDeath(hum, c)
		if watched[hum] then return end
		watched[hum] = true
		pcall(function() hum.Died:Connect(function() deadSet[c] = os.clock() end) end)
	end
	local HP_NAMES = {"Health", "HP", "health", "hp", "CurrentHealth"}
	local function isAlive(c, hum)
		if not c or not c.Parent then return false end
		hum = hum or c:FindFirstChildOfClass("Humanoid")
		if not hum then return false end
		-- игрок уже возродился в другом теле (или тела нет) — старое тело это труп
		local owner = Players:GetPlayerFromCharacter(c)
		if owner and owner.Character ~= c then deadSet[c] = os.clock() end
		local dt0 = deadSet[c]
		if dt0 then
			-- игроки: труп навсегда; боты: «воскресают» только если 5с жили с нормальным здоровьем
			if owner or hum.Health <= 0 or os.clock() - dt0 < 5 or hum:GetState() == Enum.HumanoidStateType.Dead then return false end
			deadSet[c] = nil
		end
		watchDeath(hum, c)
		if hum.Health <= 0 then deadSet[c] = os.clock() return false end
		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Dead then deadSet[c] = os.clock() return false end
		-- своя система здоровья игры: атрибуты и числовые значения
		for _, n in ipairs(HP_NAMES) do
			local av = c:GetAttribute(n) or hum:GetAttribute(n)
			if type(av) == "number" and av <= 0 then deadSet[c] = os.clock() return false end
			local nv = c:FindFirstChild(n) or hum:FindFirstChild(n)
			if nv and (nv:IsA("NumberValue") or nv:IsA("IntValue")) and nv.Value <= 0 then deadSet[c] = os.clock() return false end
		end
		for _, n in ipairs(DEAD_FLAGS) do
			if c:GetAttribute(n) == true or hum:GetAttribute(n) == true then return false end
			local bv = c:FindFirstChild(n)
			if bv and bv:IsA("BoolValue") and bv.Value then return false end
		end
		return c:FindFirstChild("HumanoidRootPart") ~= nil or c:FindFirstChild("Head") ~= nil
	end
	local npcs, npcT = {}, 0
	local function refreshNpcs()
		local list = {}
		local all = workspace:GetDescendants()
		for i = 1, math.min(#all, 20000) do
			local d = all[i]
			if d:IsA("Humanoid") and d.Health > 0 then
				local m = d.Parent
				if m and m:IsA("Model") and m ~= lp.Character and not Players:GetPlayerFromCharacter(m) and isAlive(m, d) then
					table.insert(list, {char = m, name = m.Name, npc = true})
				end
			end
		end
		npcs = list
	end
	local function entities()
		local list = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp and p.Character then table.insert(list, {plr = p, char = p.Character, name = p.DisplayName}) end
		end
		-- боты (NPC) — всегда в списке целей; список обновляется раз в секунду
		if os.clock() - npcT > 4 then npcT = os.clock(); pcall(refreshNpcs) end
		for _, e in ipairs(npcs) do
			if e.char and e.char.Parent then table.insert(list, e) end
		end
		return list
	end
	local function allowed(ent)
		local c = ent.char
		if not c or not c.Parent or c == lp.Character then return nil end
		local p = ent.plr
		if p and p.Team and p.Team == lp.Team and teamGames[tostring(game.PlaceId)] then return nil end
		if p and not allMode then
			if teamCheck and p.Team and p.Team == lp.Team then return nil end
			if friendCheck and isFriend(p) then return nil end
			if wlSet[p.Name:lower()] or wlSet[p.DisplayName:lower()] then return nil end
		end
		local hum = c:FindFirstChildOfClass("Humanoid")
		if not isAlive(c, hum) then return nil end
		if skipFF and c:FindFirstChildOfClass("ForceField") then return nil end
		return hum
	end

	-- ----- ТОЧНОСТЬ: своя оценка скорости цели, пинг, расчёт точки перехвата -----
	local Stats = game:GetService("Stats")
	local pingVal, pingT = 0, 0
	local function getPing()
		local now = os.clock()
		if now - pingT > 0.5 then
			pingT = now
			local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
			pingVal = (ok and tonumber(v) or 0) / 1000
		end
		return pingVal
	end

	-- скорость считаем по смещению позиции и сглаживаем (AssemblyLinearVelocity часто врёт)
	local trk = setmetatable({}, {__mode = "k"})
	local function velOf(part)
		local now, pos = os.clock(), part.Position
		local r = trk[part]
		if not r then
			r = {p = pos, t = now, v = part.AssemblyLinearVelocity}
			trk[part] = r
			return r.v
		end
		local dt = now - r.t
		-- чужие игроки двигаются «рывками» по сети: считаем скорость только когда позиция реально обновилась,
		-- иначе в кадрах без обновления скорость падала в 0 и прицел дёргался
		if (pos - r.p).Magnitude > 0.003 then
			local raw = dt > 0.5 and part.AssemblyLinearVelocity or (pos - r.p) / math.max(dt, 0.008)
			if raw.Magnitude > 120 or (pos - r.p).Magnitude > 25 then raw = r.v end -- телепорт/респавн не считаем скоростью
			r.v = r.v:Lerp(raw, 0.3)
			r.p, r.t = pos, now
		elseif dt > 0.25 then
			r.v = r.v * 0.5 -- цель стоит
			r.t = now
		end
		return r.v
	end

	-- точка перехвата: итеративно уточняем время полёта пули
	local function solve(origin, part, hum)
		local pos = part.Position
		local doLead = predOn or (ballistic and bulletSpeed > 0)
		if not doLead then return pos end
		local v = velOf(part)
		if hum and hum.FloorMaterial ~= Enum.Material.Air then v = Vector3.new(v.X, 0, v.Z) end -- шаги не дают дрожание по Y
		local lag = (predOn and predMs / 1000 or 0) + (autoPing and getPing() * 0.5 or 0)
		local aim = pos
		if ballistic and bulletSpeed > 0 then
			local t = (pos - origin).Magnitude / bulletSpeed
			for _ = 1, 4 do
				aim = pos + v * (t + lag)
				t = (aim - origin).Magnitude / bulletSpeed
			end
			if dropOn then aim += Vector3.new(0, 0.5 * workspace.Gravity * t * t, 0) end
		else
			aim = pos + v * lag
		end
		return aim
	end

	local partMem = setmetatable({}, {__mode = "k"})
	local aimMem = setmetatable({}, {__mode = "k"})
	local function evaluate(cam, ent, center)
		local hum = allowed(ent)
		if not hum then return nil end
		local c = ent.char
		local part = pickPart(c, cam, center)
		if not part then return nil end
		-- не перескакиваем между головой и торсом: держим выбранную часть минимум 0.4с
		local nowE = os.clock()
		local pm = partMem[c]
		if pm and pm.part ~= part and pm.part.Parent and nowE - pm.t < 0.4 then
			part = pm.part
		elseif not pm or pm.part ~= part then
			partMem[c] = {part = part, t = nowE}
		end
		-- выбранная часть закрыта — берём любую видимую
		if not visible(cam, part, c) then
			local alt
			for _, n in ipairs({"UpperTorso", "Torso", "HumanoidRootPart", "LowerTorso", "Head"}) do
				local pt = c:FindFirstChild(n)
				if pt and pt ~= part and visible(cam, pt, c) then alt = pt break end
			end
			if not alt then return nil end
			part = alt
		end
		local mine = getHRP()
		local dist = (part.Position - (mine and mine.Position or cam.CFrame.Position)).Magnitude
		if dist > aimDist then return nil end
		local pos = solve(cam.CFrame.Position, part, hum)
		-- лёгкое сглаживание точки прицеливания (убирает мелкую дрожь от сетевых рывков цели)
		local am = aimMem[c]
		if am and am.part == part and nowE - am.t < 0.3 and (am.p - pos).Magnitude < 6 then
			pos = am.p:Lerp(pos, 1 - math.exp(-math.max(nowE - am.t, 0) / 0.03))
		end
		aimMem[c] = {p = pos, t = nowE, part = part}
		local sp, on = cam:WorldToViewportPoint(pos)
		if not on then return nil end
		local sp2 = Vector2.new(sp.X, sp.Y)
		local sd = (sp2 - center).Magnitude
		if sd > aimFov then return nil end
		local score = prioI == 1 and sd or (prioI == 2 and dist or hum.Health)
		return {ent = ent, name = ent.name, pos = pos, sp = sp2, score = score, hum = hum, dist = dist, part = part}
	end

	-- ----- НОВОЕ: очередь целей -----
	queueGap = 0
	local queueCool = setmetatable({}, {__mode = "k"})
	local function charAlive(c)
		return isAlive(c)
	end
	local function getQueueTarget(cam, list, center)
		local now = os.clock()
		if queueChar then
			for _, e in ipairs(list) do
				if e.char == queueChar then
					local t = evaluate(cam, e, center)
					if t then queueLost = nil; return t end
				end
			end
			-- текущая цель не подходит: мертва — берём следующую сразу;
			-- жива, но пропала (за стеной/вне круга) — ждём 0.6с, потом откладываем на 4с
			if charAlive(queueChar) then
				queueLost = queueLost or now
				if now - queueLost < 0.6 then return nil end
				queueCool[queueChar] = now + 4
			end
			queueChar, queueLost = nil, nil
			queueGap = now + 0.25
		end
		if now < queueGap then return nil end
		local best, bestCool
		for _, e in ipairs(list) do
			local t = evaluate(cam, e, center)
			if t then
				if (queueCool[e.char] or 0) > now then
					if not bestCool or t.score < bestCool.score then bestCool = t end
				elseif not best or t.score < best.score then
					best = t
				end
			end
		end
		best = best or bestCool
		if best then queueChar = best.ent.char end
		return best
	end

	local function getTarget(cam)
		local center = cam.ViewportSize / 2
		local list = entities()
		if queueOn then return getQueueTarget(cam, list, center) end
		if sticky and stickyChar then
			for _, e in ipairs(list) do
				if e.char == stickyChar then
					local t = evaluate(cam, e, center)
					if t then return t end
				end
			end
			stickyChar = nil
		end
		local best
		for _, e in ipairs(list) do
			local t = evaluate(cam, e, center)
			if t and (not best or t.score < best.score) then best = t end
		end
		if best and sticky then stickyChar = best.ent.char end
		return best
	end

	local function keyDown()
		local k = KEYS[keyI]
		if k == "ПКМ" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) end
		if k == "ЛКМ" then return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end
		if k == "Shift" then return UIS:IsKeyDown(Enum.KeyCode.LeftShift) end
		return UIS:IsKeyDown(Enum.KeyCode[k])
	end

	local function showTarget(cam, t)
		if not showInd then hideInd() return end
		local center = cam.ViewportSize / 2
		local d = t.sp - center
		local len = d.Magnitude
		line.Size = UDim2.fromOffset(len, 2)
		line.Position = UDim2.fromOffset(center.X + d.X / 2, center.Y + d.Y / 2)
		line.Rotation = math.deg(math.atan2(d.Y, d.X))
		line.Visible = true
		tag.Position = UDim2.fromOffset(t.sp.X, t.sp.Y + 14)
		tag.Text = string.format("%s · %d хп · %dм", t.name, math.floor(t.hum.Health), math.floor(t.dist))
		tag.Visible = true
	end

	local circStroke = circle:FindFirstChildOfClass("UIStroke")
	RunService.Heartbeat:Connect(function()
		if not circStroke then return end
		if circMode == 2 then
			circStroke.Color = Color3.fromHSV((os.clock() * 0.25) % 1, 1, 1)
		elseif circMode == 3 then
			circStroke.Color = aimLocked and Color3.fromRGB(255, 60, 60) or Color3.new(1, 1, 1)
		else
			circStroke.Color = Color3.new(1, 1, 1)
		end
	end)

	local vuAim = game:GetService("VirtualUser")
	local lastFire = 0
	local function useWeapon(cam)
		local c = lp.Character
		local tool = c and c:FindFirstChildOfClass("Tool")
		if tool then
			pcall(function() tool:Activate() end)
		else
			local h = getHum()
			local bp = lp:FindFirstChildOfClass("Backpack")
			local t2 = bp and bp:FindFirstChildOfClass("Tool")
			if h and t2 then pcall(function() h:EquipTool(t2) end) end
		end
		pcall(function() vuAim:ClickButton1(Vector2.new(), cam.CFrame) end)
	end
	local function fire(cam)
		local now = os.clock()
		if now - lastFire < 0.1 then return end
		lastFire = now
		useWeapon(cam)
	end

	pcall(function() RunService:UnbindFromRenderStep("SpeedMenuAim") end)
	RunService:BindToRenderStep("SpeedMenuAim", Enum.RenderPriority.Camera.Value + 1, function(dt)
		aimLocked = false
		local cam = workspace.CurrentCamera
		if not aimOn or freeOn or not cam then hideInd() return end
		local touchOnly = UIS.TouchEnabled and not UIS.KeyboardEnabled
		local active = touchOnly or (not UIS:GetFocusedTextBox() and keyDown())
		if not active then stickyChar = nil; queueChar = nil; queueLost = nil; hideInd() return end
		if stickyChar and not isAlive(stickyChar) then stickyChar = nil end
		if queueChar and not isAlive(queueChar) then queueChar, queueLost = nil, nil; queueGap = os.clock() + 0.25 end
		local t = getTarget(cam)
		if t then
			showTarget(cam, t)
			aimLocked = true
			local goal = CFrame.lookAt(cam.CFrame.Position, t.pos)
			local err = math.acos(math.clamp(cam.CFrame.LookVector:Dot(goal.LookVector), -1, 1))
			local a = aimSmooth <= 1 and 1 or 1 - (1 - 1 / aimSmooth) ^ (dt * 60)
			if err < math.rad(0.15) then a = 0 elseif err < math.rad(1.5) then a = 1 end -- почти навелись: фиксируем точно, без дрожания
			if err > math.rad(25) then a = math.max(a, 0.6) end -- далеко: быстро подтягиваем, потом доводим плавно
			cam.CFrame = a >= 1 and goal or cam.CFrame:Lerp(goal, a)
			-- стреляем, когда прицел внутри угловых размеров части тела цели
			local tol = math.max(math.atan(t.part.Size.Magnitude * 0.25 / math.max(t.dist, 1)), math.rad(0.4))
			if autoFire and err <= tol then fire(cam) end
		else
			hideInd()
		end
	end)

	UIS.InputBegan:Connect(function(i, gp)
		if not gp and i.KeyCode == Enum.KeyCode.RightAlt then setAim(not aimOn) end
	end)

	-- в своём блоке, чтобы не упереться в лимит локальных переменных
	do
	-- =================================================================
	-- ===== БОТ v2: умный — ищет путь, прячется от тупиков, стреляет очередями
	-- =================================================================
	local PFS = game:GetService("PathfindingService")
	local c17 = card("БОТ (играет за тебя)", 176, 17)
	local botBtn = toggleBtn(c17, 28, "Бот: ВЫКЛ")
	label(c17, "Дистанция боя", 66)
	local keepB = numBox(c17, 66, 30)
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 64), Position = UDim2.fromOffset(12, 102), BackgroundTransparency = 1,
		Text = "Бот v2: выбирает цель с учётом дистанции, видимости и здоровья, обходит препятствия по навигационной сетке, держит дистанцию боя, двигается боком, стреляет очередями только когда цель в прицеле и видна, не застревает. Бессмертие включается само.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c17,
	})

	local botOn, botGod = false, false
	local keepDist = 30
	local botTarget, targetSince = nil, 0
	local lastPick, lastMove, lastJump = 0, 0, 0
	local unseenSince = nil -- когда текущая цель пропала из виду
	local strafeDir, strafeUntil = 1, 0
	local burstUntil, pauseUntil, lastShot = 0, 0, 0
	local lastPos, lastPosT, stuck = nil, 0, 0
	local botSkip = setmetatable({}, {__mode = "k"})
	local wps, wpI, pathBusy, pathT, pathGoal, pathFails = nil, 1, false, 0, nil, 0
	local wanderT = 0
	local vu = game:GetService("VirtualUser")

	keepB.FocusLost:Connect(function() keepDist = num(keepB.Text, 5, 300, keepDist) keepB.Text = tostring(keepDist) end)

	local function setBot(v)
		botOn = v
		botBtn.Text = v and "Бот: ВКЛ (бессмертный)" or "Бот: ВЫКЛ"
		paint(botBtn, v)
		wps, pathGoal, botTarget = nil, nil, nil
		if v then
			if not god then
				god = true; botGod = true
				local h = getHum()
				if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end) end
				refreshUI()
			end
		else
			if botGod then
				god = false; botGod = false
				local h = getHum()
				if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end) end
				refreshUI()
			end
			local h, r = getHum(), getHRP()
			if h and r then h:MoveTo(r.Position) end
		end
	end
	botBtn.MouseButton1Click:Connect(function() setBot(not botOn) end)

	local function rayParams(extra)
		local p = RaycastParams.new()
		p.FilterType = Enum.RaycastFilterType.Exclude
		p.FilterDescendantsInstances = {lp.Character, extra}
		return p
	end
	local function botSees(hrp, part, char)
		local head = lp.Character and lp.Character:FindFirstChild("Head")
		local o = head and head.Position or hrp.Position
		return workspace:Raycast(o, part.Position - o, rayParams(char)) == nil
	end

	-- оценка цели: чем меньше, тем лучше
	local function scoreOf(hrp, ent, now)
		local hum = allowed(ent)
		if not hum then return nil end
		if (botSkip[ent.char] or 0) > now then return nil end
		local r = ent.char:FindFirstChild("HumanoidRootPart")
		if not r then return nil end
		local d = (r.Position - hrp.Position).Magnitude
		local vis = botSees(hrp, ent.char:FindFirstChild("Head") or r, ent.char)
		return d + (vis and 0 or 35) + math.min(hum.Health, 200) * 0.25, r, d, vis
	end

	local function requestPath(to)
		if pathBusy then return end
		pathBusy = true
		pathGoal, pathT = to, os.clock()
		task.spawn(function()
			local hrp = getHRP()
			if hrp then
				local path = PFS:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
				local ok = pcall(function() path:ComputeAsync(hrp.Position, to) end)
				if ok and path.Status == Enum.PathStatus.Success then
					wps = path:GetWaypoints(); wpI = 2; pathFails = 0
				else
					wps = nil; pathFails += 1
				end
			end
			pathBusy = false
		end)
	end
	local function followPath(hum, hrp)
		local wp = wps and wps[wpI]
		if not wp then return false end
		local flat = Vector3.new(wp.Position.X, hrp.Position.Y, wp.Position.Z)
		if (flat - hrp.Position).Magnitude < 4 then
			wpI += 1
			wp = wps[wpI]
			if not wp then wps = nil; return false end
		end
		if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
		hum:MoveTo(wp.Position)
		return true
	end
	local function goTo(hum, hrp, pos, now)
		-- заново строим путь, если цель сместилась или путь устарел
		if not pathBusy and (not wps or not pathGoal or (pathGoal - pos).Magnitude > 12 or now - pathT > 1.5) then
			requestPath(pos)
		end
		if not followPath(hum, hrp) then hum:MoveTo(pos) end
	end

	pcall(function() RunService:UnbindFromRenderStep("SpeedMenuBot") end)
	RunService:BindToRenderStep("SpeedMenuBot", Enum.RenderPriority.Camera.Value + 2, function(dt)
		if not botOn then return end
		local cam = workspace.CurrentCamera
		local hum, hrp = getHum(), getHRP()
		if not (cam and hum and hrp) or hum.Health <= 0 then return end
		local now = os.clock()

		-- ----- очередь целей: держим одну, пока не умрёт / не станет недостижимой -----
		if now - lastPick > 0.1 then
			lastPick = now
			local cs, cvis
			if botTarget then
				local s, _, _, v = scoreOf(hrp, botTarget, now)
				cs, cvis = s, v
			end
			if not cs then
				botTarget, unseenSince = nil, nil -- мертва / ушла / в пропуске
			elseif cvis then
				unseenSince = nil
			else
				unseenSince = unseenSince or now
			end
			-- новую берём только если цели нет или она 3с не видна, а другая есть
			if not botTarget or (unseenSince and now - unseenSince > 3) then
				local best, bestS
				for _, ent in ipairs(entities()) do
					if ent ~= botTarget then
						local s = scoreOf(hrp, ent, now)
						if s and (not bestS or s < bestS) then best, bestS = ent, s end
					end
				end
				if best then
					if botTarget then botSkip[botTarget.char] = now + 5 end
					botTarget, targetSince, unseenSince = best, now, nil
					wps, pathGoal, pathFails = nil, nil, 0
				end
			end
		end
		local ent = botTarget
		local tRoot = ent and allowed(ent) and ent.char:FindFirstChild("HumanoidRootPart")

		-- ----- нет цели: патрулируем по навигации -----
		if not tRoot then
			if now - wanderT > 4 or not wps then
				wanderT = now
				requestPath(hrp.Position + Vector3.new(math.random(-60, 60), 0, math.random(-60, 60)))
			end
			if not followPath(hum, hrp) then
				if now - lastMove > 3 then
					lastMove = now
					hum:MoveTo(hrp.Position + Vector3.new(math.random(-40, 40), 0, math.random(-40, 40)))
				end
			end
			return
		end

		local head = ent.char:FindFirstChild("Head")
		local dist = (tRoot.Position - hrp.Position).Magnitude
		local seen = botSees(hrp, head or tRoot, ent.char)
		local inRange = dist <= keepDist + 25

		-- ----- движение -----
		if seen and inRange then
			-- бой: держим дистанцию и двигаемся боком, не упираясь в стены
			wps = nil
			if now > strafeUntil then strafeDir = -strafeDir; strafeUntil = now + 0.6 + math.random() * 1.0 end
			local toT = (tRoot.Position - hrp.Position) * Vector3.new(1, 0, 1)
			local dir = toT.Magnitude > 0.1 and toT.Unit or hrp.CFrame.LookVector
			local right = Vector3.new(-dir.Z, 0, dir.X)
			local mv = right * strafeDir
			if dist > keepDist + 6 then mv += dir elseif dist < keepDist - 6 then mv -= dir * 1.5 end
			if mv.Magnitude < 0.1 then mv = right end
			mv = mv.Unit
			if workspace:Raycast(hrp.Position, mv * 6, rayParams(ent.char)) then
				strafeDir = -strafeDir
				mv = (right * strafeDir - dir * 0.3).Unit
			end
			if now - lastMove > 0.15 then
				lastMove = now
				hum:MoveTo(hrp.Position + mv * 10)
			end
			if now - lastJump > 2.5 + math.random() * 1.5 then lastJump = now; hum.Jump = true end
		else
			-- далеко или за препятствием: идём по пути к цели
			if pathFails >= 3 then
				botSkip[ent.char] = now + 8 -- недостижима: временно забываем
				botTarget, wps, pathFails = nil, nil, 0
				return
			end
			goTo(hum, hrp, tRoot.Position, now)
		end

		-- ----- детектор застревания -----
		if now - lastPosT > 1 then
			if lastPos and (hrp.Position - lastPos).Magnitude < 1.2 and hum.MoveDirection.Magnitude > 0 then
				stuck += 1
				hum.Jump = true
				strafeDir = -strafeDir
				wps = nil
				if stuck >= 3 then botSkip[ent.char] = now + 6; botTarget = nil; stuck = 0 end
			else
				stuck = 0
			end
			lastPos, lastPosT = hrp.Position, now
		end

		-- ----- прицел: голова, а если не видна — торс; с упреждением и плавным поворотом -----
		local part = (head and botSees(hrp, head, ent.char)) and head or tRoot
		local pos = solve(cam.CFrame.Position, part, ent.char:FindFirstChildOfClass("Humanoid"))
		local goal = CFrame.lookAt(cam.CFrame.Position, pos)
		local err0 = math.acos(math.clamp(cam.CFrame.LookVector:Dot(goal.LookVector), -1, 1))
		-- быстро: ~80% за кадр, а при малой ошибке — точная фиксация
		local a = 1 - (1 - 0.8) ^ (dt * 60)
		if err0 < math.rad(3) or err0 > math.rad(60) then a = 1 end
		cam.CFrame = cam.CFrame:Lerp(goal, math.clamp(a, 0, 1))

		-- ----- стрельба очередями: только если видим цель и прицел внутри хитбокса -----
		local err = math.acos(math.clamp(cam.CFrame.LookVector:Dot(goal.LookVector), -1, 1))
		local tol = math.max(math.atan(part.Size.Magnitude * 0.25 / math.max(dist, 1)), math.rad(0.5))
		local aligned = err <= tol
		if seen and aligned and dist <= keepDist + 60 and now > pauseUntil then
			if burstUntil < now then burstUntil = now + 0.4 + math.random() * 0.5 end
			if now - lastShot > 0.1 then
				lastShot = now
				useWeapon(cam)
			end
			if now > burstUntil then pauseUntil = now + 0.15 + math.random() * 0.15 end
		end
	end)

	-- ===== УБИТЬ ВСЕХ: по очереди добивает каждую цель =====
	local c20 = card("УБИТЬ ВСЕХ", 122, 20)
	local killBtn = toggleBtn(c20, 28, "Убить всех: ВЫКЛ")
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 48), Position = UDim2.fromOffset(12, 66), BackgroundTransparency = 1,
		Text = "Телепортируется к каждой цели по очереди и стреляет оружием из рук, пока цель не умрёт. Работает только с оружием, у которого урон считает клиент. Цели те же, что у аима.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c20,
	})
	local killOn, killT, killUntil, lastHit = false, nil, 0, 0
	local skip = {}
	killBtn.MouseButton1Click:Connect(function()
		killOn = not killOn
		killT = nil
		paint(killBtn, killOn)
		killBtn.Text = killOn and "Убить всех: ВКЛ" or "Убить всех: ВЫКЛ"
	end)
	RunService.Heartbeat:Connect(function()
		if not killOn then return end
		local hum, hrp, cam = getHum(), getHRP(), workspace.CurrentCamera
		if not (hum and hrp and cam) or hum.Health <= 0 then return end
		local now = os.clock()
		if not (killT and allowed(killT) and now < killUntil) then
			if killT and allowed(killT) then skip[killT.char] = now + 8 end
			killT = nil
			local bestD = math.huge
			for _, e in ipairs(entities()) do
				if allowed(e) and not (skip[e.char] and skip[e.char] > now) then
					local r = e.char:FindFirstChild("HumanoidRootPart")
					if r then
						local d = (r.Position - hrp.Position).Magnitude
						if d < bestD then killT, bestD = e, d end
					end
				end
			end
			killUntil = now + 2
		end
		local e2 = killT
		local r = e2 and e2.char:FindFirstChild("HumanoidRootPart")
		if not r then return end
		safeTP(r.CFrame * CFrame.new(0, 0, 6))
		hrp.AssemblyLinearVelocity = Vector3.zero
		local part = e2.char:FindFirstChild("Head") or r
		cam.CFrame = CFrame.lookAt(cam.CFrame.Position, part.Position)
		if now - lastHit > 0.08 then
			lastHit = now
			useWeapon(cam)
		end
	end)
	end -- do (бот и «убить всех»)

	_G.SpeedMenuAimLib = {entities = entities, alive = isAlive}
	-- для профилей игр: снимок и применение настроек аима
	local AIM_NUM = {aimFov = {20, 600}, aimSmooth = {1, 30}, aimDist = {50, 5000}, predMs = {0, 500}, bulletSpeed = {0, 5000}, partI = {1, #PARTS}, prioI = {1, #PRIOS}}
	local AIM_BOOL = {"teamCheck", "wallCheck", "friendCheck", "sticky", "predOn", "queueOn", "ballistic", "autoPing", "autoFire", "skipFF"}
	_G.SpeedMenuAimLib.setAim = setAim
	_G.SpeedMenuAimLib.getAim = function() return aimOn end
	_G.SpeedMenuAimLib.snapshot = function()
		return {
			aimFov = aimFov, aimSmooth = aimSmooth, aimDist = aimDist, predMs = predMs, bulletSpeed = bulletSpeed,
			partI = partI, prioI = prioI, teamCheck = teamCheck, wallCheck = wallCheck, friendCheck = friendCheck,
			sticky = sticky, predOn = predOn, queueOn = queueOn, ballistic = ballistic, autoPing = autoPing,
			autoFire = autoFire, skipFF = skipFF,
		}
	end
	_G.SpeedMenuAimLib.apply = function(t)
		if type(t) ~= "table" then return end
		if t.aimFov then aimFov = num(t.aimFov, 20, 600, aimFov) end
		if t.aimSmooth then aimSmooth = num(t.aimSmooth, 1, 30, aimSmooth) end
		if t.aimDist then aimDist = num(t.aimDist, 50, 5000, aimDist) end
		if t.predMs then predMs = num(t.predMs, 0, 500, predMs) end
		if t.bulletSpeed then bulletSpeed = num(t.bulletSpeed, 0, 5000, bulletSpeed) end
		if t.partI then partI = num(t.partI, 1, #PARTS, partI) end
		if t.prioI then prioI = num(t.prioI, 1, #PRIOS, prioI) end
		if type(t.teamCheck) == "boolean" then teamCheck = t.teamCheck end
		if type(t.wallCheck) == "boolean" then wallCheck = t.wallCheck end
		if type(t.friendCheck) == "boolean" then friendCheck = t.friendCheck end
		if type(t.sticky) == "boolean" then sticky = t.sticky end
		if type(t.predOn) == "boolean" then predOn = t.predOn end
		if type(t.queueOn) == "boolean" then queueOn = t.queueOn end
		if type(t.ballistic) == "boolean" then ballistic = t.ballistic end
		if type(t.autoPing) == "boolean" then autoPing = t.autoPing end
		if type(t.autoFire) == "boolean" then autoFire = t.autoFire end
		if type(t.skipFF) == "boolean" then skipFF = t.skipFF end
		pcall(refresh)
		saveAim()
	end

	refresh()
end, function(e) __trk.report("аим и бот", e) end)


-- =====================================================================
-- ===== ESP игроков: рамка, имя, здоровье, дистанция, линии, подсветка
-- =====      зелёный = цель видна, красный = за стеной
-- =====================================================================
xpcall(function() --[[ESP]]
	local o = {box = true, name = true, hp = true, dist = true, trace = true, cham = true, corner = true, fill = true, dot = true}
	local maxDist = 2000

	local c18 = card("ESP (игроки и боты)", 222, 18)
	local masterBtn = toggleBtn(c18, 28, "ESP: ВЫКЛ")
	local r1 = row(c18, 66, 32)
	local r2 = row(c18, 104, 32)
	local r3 = row(c18, 142, 32)
	local btns = {
		box   = cell(r1, 3, "Рамка", C.on),
		name  = cell(r1, 3, "Имя", C.on),
		hp    = cell(r1, 3, "Здоровье", C.on),
		dist  = cell(r2, 3, "Дистанция", C.on),
		trace = cell(r2, 3, "Линии", C.on),
		cham  = cell(r2, 3, "Подсветка", C.on),
		corner = cell(r3, 3, "Уголки", C.on),
		fill  = cell(r3, 3, "Заливка", C.on),
		dot   = cell(r3, 3, "Голова", C.on),
	}
	for key, b in pairs(btns) do
		b.TextSize = 11
		b.MouseButton1Click:Connect(function() o[key] = not o[key]; paint(b, o[key]) end)
	end
	label(c18, "Макс. дистанция", 180)
	local maxB = numBox(c18, 180, maxDist)
	maxB.FocusLost:Connect(function()
		maxDist = math.clamp(tonumber(maxB.Text) or maxDist, 50, 10000)
		maxB.Text = tostring(maxDist)
	end)
	masterBtn.MouseButton1Click:Connect(function() esp = not esp; refreshUI() end)

	local oldGui = parent:FindFirstChild("SpeedMenuEsp")
	if oldGui then oldGui:Destroy() end
	local eg = new("ScreenGui", {Name = "SpeedMenuEsp", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = parent})

	local pool = {}
	local function label2(size, anchorX, anchorY, color)
		return new("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromOffset(200, 14), AnchorPoint = Vector2.new(anchorX, anchorY),
			Font = Enum.Font.GothamBold, TextSize = size, TextColor3 = color, TextStrokeTransparency = 0.35,
			TextStrokeColor3 = Color3.new(0, 0, 0), Visible = false, Parent = eg,
		})
	end
	local function outlined(props)
		props.BorderSizePixel = 0; props.Visible = false; props.Parent = eg
		return new("Frame", props, {new("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.35})})
	end
	local function make(plr)
		local e = {}
		e.fill = new("Frame", {BorderSizePixel = 0, BackgroundTransparency = 0.88, Visible = false, Parent = eg})
		e.box = new("Frame", {BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, Parent = eg},
			{new("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 1.5})})
		e.stroke = e.box:FindFirstChildOfClass("UIStroke")
		e.cor = {}
		for i = 1, 8 do e.cor[i] = outlined({BackgroundColor3 = Color3.new(1, 1, 1)}) end
		e.name = label2(13, 0.5, 1, Color3.new(1, 1, 1))
		e.info = label2(11, 0.5, 0, Color3.fromRGB(215, 222, 245))
		e.hpTxt = label2(10, 1, 0, Color3.new(1, 1, 1))
		e.hpTxt.Size = UDim2.fromOffset(30, 12)
		e.hpTxt.TextXAlignment = Enum.TextXAlignment.Right
		e.hpBg = new("Frame", {BackgroundColor3 = Color3.fromRGB(15, 15, 20), BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false, Parent = eg},
			{new("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.2})})
		e.hpFill = new("Frame", {
			BorderSizePixel = 0, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromScale(1, 1), Parent = e.hpBg,
		})
		e.dot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BorderSizePixel = 0, Visible = false, Parent = eg},
			{new("UICorner", {CornerRadius = UDim.new(1, 0)}), new("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1.2})})
		e.line = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false, BackgroundTransparency = 0.25, Parent = eg})
		e.hl = new("Highlight", {
			FillTransparency = 0.7, OutlineTransparency = 0.1, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			Enabled = false, Parent = eg,
		})
		e.vis, e.t = false, 0
		pool[plr] = e
		return e
	end
	local function hide(e)
		e.box.Visible = false; e.name.Visible = false; e.info.Visible = false; e.fill.Visible = false
		e.hpBg.Visible = false; e.hpTxt.Visible = false; e.dot.Visible = false
		e.line.Visible = false; e.hl.Enabled = false
		for i = 1, 8 do e.cor[i].Visible = false end
	end
	local function setSeg(f, x, y, w, h, col)
		f.Position = UDim2.fromOffset(x, y); f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = col; f.Visible = true
	end
	local shown
	pcall(function() RunService:UnbindFromRenderStep("SpeedMenuEsp") end)
	RunService:BindToRenderStep("SpeedMenuEsp", Enum.RenderPriority.Camera.Value + 3, function(dt)
		if shown ~= esp then
			shown = esp
			paint(masterBtn, esp)
			masterBtn.Text = esp and "ESP: ВКЛ" or "ESP: ВЫКЛ"
		end
		local cam = workspace.CurrentCamera
		if not esp or not cam then
			for _, e in pairs(pool) do hide(e) end
			return
		end
		local mine = getHRP()
		local from = mine and mine.Position or cam.CFrame.Position
		local vp = cam.ViewportSize
		local now = os.clock()
		-- тот же список, что у аима: игроки + боты
		local lib = _G.SpeedMenuAimLib
		local aliveFn = lib and lib.alive
		local list = {}
		if lib and lib.entities then
			local okL, res = pcall(lib.entities)
			if okL and type(res) == "table" then list = res end
		else
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl ~= lp and pl.Character then table.insert(list, {plr = pl, char = pl.Character, name = pl.DisplayName}) end
			end
		end
		for _, ent in ipairs(list) do
			local c = ent.char
			local p = ent.plr
			if c and c.Parent then
				local e = pool[c] or make(c)
				e.last = now
				local hum = c:FindFirstChildOfClass("Humanoid")
				local head = c and c:FindFirstChild("Head")
				local root = c and c:FindFirstChild("HumanoidRootPart")
				local ok = false
				local live = hum and head and root and ((aliveFn and aliveFn(c, hum)) or (not aliveFn and hum.Health > 0))
				if live then
					local dist = (root.Position - from).Magnitude
					if dist <= maxDist then
						-- рамка строится от корневой части по размерам рига, а не по голове:
						-- голова качается при ходьбе и анимациях, из-за этого рамка «плавала»
						local rp = root.Position
						-- лёгкое сглаживание в мире (не на экране, чтобы рамка не отставала от поворота камеры)
						if e.p and (e.p - rp).Magnitude < 10 then
							rp = e.p:Lerp(rp, 1 - math.exp(-(dt or 0.016) / 0.02))
						end
						e.p = rp
						local sc = math.max(root.Size.Y / 2, 0.5)
						local r15 = hum.RigType == Enum.HumanoidRigType.R15
						local up = (r15 and 2.2 or 2.0) * sc
						local down = r15 and (hum.HipHeight + sc) or (3 * sc)
						local top = cam:WorldToViewportPoint(rp + Vector3.new(0, up, 0))
						local bot = cam:WorldToViewportPoint(rp - Vector3.new(0, down, 0))
						if top.Z > 0 and bot.Z > 0 then
							ok = true
							if now - e.t > 0.25 then
								e.t = now
								local params = RaycastParams.new()
								params.FilterType = Enum.RaycastFilterType.Exclude
								params.FilterDescendantsInstances = {lp.Character, c}
								e.vis = workspace:Raycast(cam.CFrame.Position, root.Position - cam.CFrame.Position, params) == nil
							end
							local col = e.vis and Color3.fromRGB(90, 255, 140) or Color3.fromRGB(255, 80, 85)
							local h = math.floor(math.max(bot.Y - top.Y, 10) + 0.5)
							local w = math.floor(h * 0.5 + 0.5)
							local cx = math.floor((top.X + bot.X) / 2 + 0.5) -- целые пиксели, без дрожания
							local ty = math.floor(top.Y + 0.5)
							local by = ty + h
							local x0 = cx - math.floor(w / 2)
							local x1 = x0 + w

							-- рамка: уголки (красиво) или обычный прямоугольник
							local useCorner = o.box and o.corner
							e.box.Visible = o.box and not o.corner
							if e.box.Visible then
								e.box.Position = UDim2.fromOffset(x0, ty)
								e.box.Size = UDim2.fromOffset(w, h)
								e.stroke.Color = col
							end
							if useCorner then
								local L = math.max(math.floor(math.min(w, h) * 0.3), 4)
								local th = h > 60 and 2 or 1
								local cr = e.cor
								setSeg(cr[1], x0, ty, L, th, col)          setSeg(cr[2], x0, ty, th, L, col)
								setSeg(cr[3], x1 - L, ty, L, th, col)      setSeg(cr[4], x1 - th, ty, th, L, col)
								setSeg(cr[5], x0, by - th, L, th, col)     setSeg(cr[6], x0, by - L, th, L, col)
								setSeg(cr[7], x1 - L, by - th, L, th, col) setSeg(cr[8], x1 - th, by - L, th, L, col)
							else
								for i = 1, 8 do e.cor[i].Visible = false end
							end
							e.fill.Visible = o.box and o.fill
							if e.fill.Visible then
								e.fill.Position = UDim2.fromOffset(x0, ty)
								e.fill.Size = UDim2.fromOffset(w, h)
								e.fill.BackgroundColor3 = col
							end

							e.name.Visible = o.name
							e.name.Position = UDim2.fromOffset(cx, ty - 3)
							e.name.Text = (p and "" or "[бот] ") .. (ent.name or c.Name)
							e.name.TextColor3 = (p and p.Team and p.TeamColor.Color) or (p and Color3.new(1, 1, 1)) or Color3.fromRGB(255, 190, 80)

							e.info.Visible = o.dist
							e.info.Position = UDim2.fromOffset(cx, by + 3)
							e.info.Text = math.floor(dist) .. " м"

							local f = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
							e.hpBg.Visible = o.hp
							e.hpTxt.Visible = o.hp
							if o.hp then
								e.hpBg.Position = UDim2.fromOffset(x0 - 7, ty)
								e.hpBg.Size = UDim2.fromOffset(4, h)
								e.hpFill.Size = UDim2.new(1, -2, f, -2)
								e.hpFill.Position = UDim2.new(0, 1, 1, -1)
								e.hpFill.BackgroundColor3 = Color3.fromHSV(f * 0.33, 0.85, 1)
								e.hpTxt.Position = UDim2.fromOffset(x0 - 10, math.floor(ty + (1 - f) * (h - 12)))
								e.hpTxt.Text = tostring(math.floor(hum.Health + 0.5))
							end

							-- точка на голове (по корню, а не по голове — не дрожит при анимациях)
							e.dot.Visible = false
							if o.dot then
								local hp3 = cam:WorldToViewportPoint(rp + Vector3.new(0, up - 0.55 * sc, 0))
								if hp3.Z > 0 then
									e.dot.Position = UDim2.fromOffset(math.floor(hp3.X + 0.5), math.floor(hp3.Y + 0.5))
									e.dot.BackgroundColor3 = col
									e.dot.Visible = true
								end
							end

							if o.trace then
								local a = Vector2.new(vp.X / 2, vp.Y)
								local b = Vector2.new(cx, by)
								local d = b - a
								e.line.Visible = true
								e.line.Size = UDim2.fromOffset(d.Magnitude, 1)
								e.line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
								e.line.Rotation = math.deg(math.atan2(d.Y, d.X))
								e.line.BackgroundColor3 = col
							else
								e.line.Visible = false
							end

							e.hl.Enabled = o.cham
							if o.cham then
								e.hl.Adornee = c
								e.hl.FillColor = col
								e.hl.OutlineColor = Color3.new(1, 1, 1)
							end
						end
					end
				end
				if not ok then hide(e) end
			end
		end
		-- убираем рамки исчезнувших: трупы, вышедшие игроки, удалённые боты
		for k, e in pairs(pool) do
			if e.last ~= now then
				hide(e)
				if now - (e.last or 0) > 2 then
					for _, key in ipairs({"box", "name", "info", "hpBg", "hpTxt", "line", "hl", "fill", "dot"}) do e[key]:Destroy() end
					for i = 1, 8 do e.cor[i]:Destroy() end
					pool[k] = nil
				end
			end
		end
	end)
end, function(e) __trk.report("ESP", e) end)

-- ===== НЕВИДИМКА =====
xpcall(function() --[[невидимка]]
	local on, pct = false, 100
	local orig, origGui = {}, {}
	local origDist

	local c19 = card("НЕВИДИМКА", 142, 19)
	local invBtn = toggleBtn(c19, 28, "Невидимка: ВЫКЛ")
	label(c19, "Прозрачность (%)", 66)
	local pBox = numBox(c19, 66, pct)
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 102), BackgroundTransparency = 1,
		Text = "100 = полностью невидим, меньшее значение оставляет тело видимым. Для других игроков работает, только если игра принимает такие изменения с клиента.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c19,
	})
	pBox.FocusLost:Connect(function()
		pct = math.clamp(math.floor((tonumber(pBox.Text) or pct) + 0.5), 0, 100)
		pBox.Text = tostring(pct)
	end)

	local function restore()
		for d, v in pairs(orig) do
			if d.Parent then pcall(function() d.Transparency = v end) end
			orig[d] = nil
		end
		for g, v in pairs(origGui) do
			if g.Parent then pcall(function() g.Enabled = v end) end
			origGui[g] = nil
		end
		local h = getHum()
		if h and origDist then pcall(function() h.DisplayDistanceType = origDist end) end
		origDist = nil
	end

	table.insert(_G.SpeedMenuCleanup, function() on = false; restore() end)
	invBtn.MouseButton1Click:Connect(function()
		on = not on
		paint(invBtn, on)
		invBtn.Text = on and "Невидимка: ВКЛ" or "Невидимка: ВЫКЛ"
		if not on then restore() end
	end)

	RunService.Heartbeat:Connect(function()
		if not on then return end
		local c = lp.Character
		if not c then return end
		local t = pct / 100
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") or d:IsA("Texture") then
				if orig[d] == nil then orig[d] = d.Transparency end
				if d.Name ~= "HumanoidRootPart" and d.Transparency ~= t then d.Transparency = t end
			elseif d:IsA("BillboardGui") then
				if origGui[d] == nil then origGui[d] = d.Enabled end
				if d.Enabled then d.Enabled = false end
			end
		end
		local h = getHum()
		if h then
			if origDist == nil then origDist = h.DisplayDistanceType end
			if h.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
				h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
	end)
end, function(e) __trk.report("невидимка", e) end)

-- =====================================================================
-- ===== ESP КОНФЕТ: метки, линии и КАРТА несобранных конфет
-- =====================================================================
xpcall(function() --[[ESP конфет]]
	local FILE = "SpeedMenuCandy.json"
	local on, tracers, mapOn, hideDone = false, true, false, true
	local keysText = "candy, candies, конфет, corn, sweet, lollipop, halloween, treat"
	local maxDist = 5000
	local done, doneN = {}, 0 -- «собранные»: ключ позиции (сетка 4 стада) -> true

	if canSave then
		local ok, d = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
		if ok and type(d) == "table" then
			if type(d.tracers) == "boolean" then tracers = d.tracers end
			if type(d.map) == "boolean" then mapOn = d.map end
			if type(d.hideDone) == "boolean" then hideDone = d.hideDone end
			if type(d.keys) == "string" then keysText = d.keys end
			maxDist = math.clamp(tonumber(d.maxDist) or maxDist, 50, 20000)
			if type(d.done) == "table" then
				for _, k in ipairs(d.done) do
					if type(k) == "string" and not done[k] then done[k] = true; doneN = doneN + 1 end
				end
			end
		end
	end
	local saving = false
	local function saveCandy()
		if not canSave or saving then return end
		saving = true
		task.delay(1, function()
			saving = false
			pcall(function()
				local arr = {}
				for k in pairs(done) do
					if #arr >= 800 then break end
					table.insert(arr, k)
				end
				writefile(FILE, HttpService:JSONEncode({
					tracers = tracers, map = mapOn, hideDone = hideDone, keys = keysText, maxDist = maxDist, done = arr,
				}))
			end)
		end)
	end

	-- ----- интерфейс -----
	local cc = card("ESP КОНФЕТ (несобранные)", 338, 21)
	local mainBtn = toggleBtn(cc, 28, "ESP конфет: ВЫКЛ")
	local rowT = row(cc, 66, 32)
	local traceBtn = cell(rowT, 2, "Линии", tracers and C.on or C.off)
	local mapBtn = cell(rowT, 2, "Карта", mapOn and C.on or C.off)
	local rowD = row(cc, 104, 32)
	local doneBtn = cell(rowD, 2, "Скрывать собранные", hideDone and C.on or C.off)
	local resetBtn = cell(rowD, 2, "Сбросить собранные", C.btn)
	local rowG = row(cc, 142, 32)
	local diagBtn = cell(rowG, 2, "Диагностика", C.btn)
	local rareBtn = cell(rowG, 2, "Только редкие", C.off)
	diagBtn.TextSize = 11; rareBtn.TextSize = 11
	traceBtn.TextSize = 11; mapBtn.TextSize = 11; doneBtn.TextSize = 11; resetBtn.TextSize = 11
	label(cc, "Макс. дистанция", 180)
	local distBox = numBox(cc, 180, maxDist)
	local keyBox = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 218), Text = keysText,
		PlaceholderText = "слова в имени конфеты через запятую", ClearTextOnFocus = false, Font = Enum.Font.Gotham, TextSize = 12,
		TextColor3 = C.text, PlaceholderColor3 = Color3.fromRGB(120, 126, 160), BackgroundColor3 = C.field, Parent = cc,
	}, {round(6)})
	local status = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 84), Position = UDim2.fromOffset(12, 250), BackgroundTransparency = 1,
		Text = "Включи ESP: покажу все конфеты, которые ещё лежат на карте.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = cc,
	})

	local keys = {}
	local function parseKeys()
		keys = {}
		for k in keysText:gmatch("[^,]+") do
			k = k:gsub("^%s+", ""):gsub("%s+$", ""):lower()
			if k ~= "" then table.insert(keys, k) end
		end
	end
	parseKeys()
	local function matches(name)
		name = name:lower()
		for _, k in ipairs(keys) do
			if name:find(k, 1, true) then return true end
		end
		return false
	end

	-- ----- состояние объектов -----
	local found, active, scanT, refT = {}, {}, 0, 0
	local updateStatusT = 0
	local rareOnly, diagHold = false, 0
	local rareSet = setmetatable({}, {__mode = "k"})
	local nearObj = setmetatable({}, {__mode = "k"}) -- подходил ли я к этой конфете вплотную
	local lastPos = setmetatable({}, {__mode = "k"})

	local function posOf(o)
		if o:IsA("BasePart") then return o.Position end
		if o:IsA("Tool") then
			local h = o:FindFirstChild("Handle")
			return h and h:IsA("BasePart") and h.Position or nil
		end
		local ok, cf = pcall(function() return o:GetPivot() end)
		return ok and cf and cf.Position or nil
	end
	local function doneKey(pos)
		return math.floor(pos.X / 4 + 0.5) .. "," .. math.floor(pos.Y / 4 + 0.5) .. "," .. math.floor(pos.Z / 4 + 0.5)
	end
	local function markDone(pos)
		local k = doneKey(pos)
		if not done[k] then done[k] = true; doneN = doneN + 1; saveCandy() end
	end
	-- спрятана ли конфета (собранные игра обычно прячет или отключает подбор)
	local function hiddenObj(o)
		if o:IsA("BasePart") then return o.Transparency >= 0.95 end
		local anyPart = false
		for _, d in ipairs(o:GetDescendants()) do
			if d:IsA("BasePart") then
				anyPart = true
				if d.Transparency < 0.95 then return false end
			end
		end
		return anyPart
	end
	local function promptOff(o)
		local ok, pp = pcall(function() return o:FindFirstChildWhichIsA("ProximityPrompt", true) end)
		return ok and pp ~= nil and pp.Enabled == false
	end

	-- пересчёт списка несобранных: исчезла/спрятана конфета, к которой я подходил, — значит, собрана
	local function refreshActive(from)
		local list = {}
		for _, f in ipairs(found) do
			local o = f.obj
			local alive = o ~= nil and o.Parent ~= nil
			local pos = alive and posOf(o) or nil
			local gone = (not alive) or pos == nil
			if not gone and (hiddenObj(o) or promptOff(o)) then gone = true end
			if gone then
				if nearObj[o] and lastPos[o] then markDone(lastPos[o]) end
			else
				lastPos[o] = pos
				if (pos - from).Magnitude < 10 then nearObj[o] = true end
				if (not rareOnly or rareSet[o]) and not (hideDone and done[doneKey(pos)]) then table.insert(list, f) end
			end
		end
		active = list
	end

	-- поиск: по всему workspace, части внутри уже найденной модели пропускаем
	local function scan()
		local list, taken = {}, {}
		if #keys == 0 then found = list return end
		for _, d in ipairs(workspace:GetDescendants()) do
			if #list >= 400 then break end
			if d:IsA("BasePart") or d:IsA("Model") or d:IsA("Tool") then
				if matches(d.Name) then
					local skip = false
					local a = d.Parent
					while a and a ~= workspace do
						if taken[a] then skip = true break end
						a = a.Parent
					end
					if not skip and lp.Character and d:IsDescendantOf(lp.Character) then skip = true end
					if not skip then
						local mdl = d:FindFirstAncestorOfClass("Model")
						if mdl and mdl:FindFirstChildOfClass("Humanoid") then skip = true end -- вещи на персонажах не считаем
					end
					if not skip and d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") then skip = true end
					if not skip then
						taken[d] = true
						table.insert(list, {obj = d, name = d.Name})
					end
				end
			end
		end
		found = list
	end

	-- ----- ДИАГНОСТИКА: чем отличаются конфеты друг от друга (собранные / несобранные) -----
	local function sigOf(o)
		local t = {o.ClassName}
		local part = o
		if o:IsA("Model") then part = o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart", true)
		elseif o:IsA("Tool") then part = o:FindFirstChild("Handle") end
		if part and part:IsA("BasePart") then
			pcall(function()
				table.insert(t, "T=" .. (math.floor(part.Transparency * 100) / 100))
				table.insert(t, "Touch=" .. tostring(part.CanTouch) .. " Coll=" .. tostring(part.CanCollide) .. " Anch=" .. tostring(part.Anchored))
				table.insert(t, "Mat=" .. tostring(part.Material))
				local c = part.Color
				table.insert(t, "Rgb=" .. math.floor(c.R * 255) .. "," .. math.floor(c.G * 255) .. "," .. math.floor(c.B * 255))
			end)
		end
		pcall(function()
			local ak = {}
			for k, v in pairs(o:GetAttributes()) do table.insert(ak, k .. "=" .. tostring(v)) end
			table.sort(ak)
			if #ak > 0 then table.insert(t, "Attr{" .. table.concat(ak, ";") .. "}") end
		end)
		pcall(function()
			local ch, n = {}, 0
			for _, c in ipairs(o:GetDescendants()) do
				n = n + 1
				if n > 20 then break end
				local s2 = c.ClassName
				if c:IsA("ProximityPrompt") then s2 = s2 .. "(on=" .. tostring(c.Enabled) .. ")" end
				table.insert(ch, s2)
			end
			table.sort(ch)
			table.insert(t, "Kids{" .. table.concat(ch, ",") .. "}")
		end)
		return table.concat(t, " | ")
	end
	local function analyze()
		local groups, order = {}, {}
		for _, f in ipairs(found) do
			local ok, sg = pcall(sigOf, f.obj)
			if ok then
				local g = groups[sg]
				if not g then
					g = {sig = sg, n = 0, sample = f.name, objs = {}}
					groups[sg] = g
					table.insert(order, g)
				end
				g.n = g.n + 1
				table.insert(g.objs, f.obj)
			end
		end
		table.sort(order, function(a, b) return a.n < b.n end)
		rareSet = setmetatable({}, {__mode = "k"})
		if #order > 1 then
			local lim = math.max(3, math.floor(#found * 0.1))
			for _, g in ipairs(order) do
				if g.n <= lim then
					for _, o in ipairs(g.objs) do rareSet[o] = true end
				end
			end
		end
		return order
	end
	diagBtn.MouseButton1Click:Connect(function()
		pcall(scan)
		local order = analyze()
		local lines = {"[SpeedMenu] ДИАГНОСТИКА КОНФЕТ: найдено " .. #found .. ", групп: " .. #order}
		for _, g in ipairs(order) do
			table.insert(lines, "[" .. g.n .. " шт] " .. g.sig .. "  (пример: " .. g.sample .. ")")
		end
		local text = table.concat(lines, "\n")
		print(text)
		pcall(function() if setclipboard then setclipboard(text) end end)
		local short = {}
		for i, g in ipairs(order) do
			if i > 4 then break end
			table.insert(short, g.n .. " шт: " .. g.sig:sub(1, 80))
		end
		status.Text = "Найдено " .. #found .. ", групп: " .. #order .. ". " .. table.concat(short, " || ") ..
			(setclipboard and " (полный отчёт скопирован)" or " (полный отчёт в консоли)")
		diagHold = os.clock() + 25
	end)
	rareBtn.MouseButton1Click:Connect(function()
		rareOnly = not rareOnly
		paint(rareBtn, rareOnly)
		if rareOnly then pcall(scan); pcall(analyze) end
		refT = 0
	end)

	-- ----- рисование: метки + линии + карта -----
	local oldG = parent:FindFirstChild("SpeedMenuCandy")
	if oldG then oldG:Destroy() end
	local cg = new("ScreenGui", {Name = "SpeedMenuCandy", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = parent})
	local PINK, YELLOW = Color3.fromRGB(255, 120, 200), Color3.fromRGB(255, 230, 80)
	local pool = {}
	local function item(i)
		local p = pool[i]
		if p then return p end
		p = {
			lbl = new("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(190, 14),
				Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = PINK,
				TextStrokeTransparency = 0.3, Visible = false, Parent = cg,
			}),
			line = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundColor3 = PINK,
				Size = UDim2.fromOffset(0, 1.5), Visible = false, Parent = cg,
			}),
		}
		pool[i] = p
		return p
	end

	local MAP = 230
	local mapF = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -90), Size = UDim2.fromOffset(MAP, MAP + 18),
		BackgroundColor3 = Color3.fromRGB(14, 16, 26), BackgroundTransparency = 0.15, BorderSizePixel = 0, Visible = false, Parent = cg,
	}, {round(8), new("UIStroke", {Color = PINK, Thickness = 1.5})})
	local mapHead = new("TextLabel", {
		Size = UDim2.new(1, -8, 0, 18), Position = UDim2.fromOffset(4, 0), BackgroundTransparency = 1, Text = "Карта конфет",
		Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = PINK, TextXAlignment = Enum.TextXAlignment.Left, Parent = mapF,
	})
	local mapArea = new("Frame", {
		Size = UDim2.fromOffset(MAP - 8, MAP - 8), Position = UDim2.fromOffset(4, 18), BackgroundTransparency = 1,
		ClipsDescendants = true, Parent = mapF,
	})
	local meDot = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, ZIndex = 3, Parent = mapArea,
	}, {new("UICorner", {CornerRadius = UDim.new(1, 0)}), new("UIStroke", {Color = Color3.new(0, 0, 0), Thickness = 1})})
	local dots = {}
	local function dot(i)
		local d = dots[i]
		if d then return d end
		d = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(7, 7), BackgroundColor3 = PINK, BorderSizePixel = 0,
			Visible = false, ZIndex = 2, Parent = mapArea,
		}, {new("UICorner", {CornerRadius = UDim.new(1, 0)})})
		dots[i] = d
		return d
	end

	local function updateStatus(nearest)
		status.Text = "Не собрано: " .. #active .. " · собрано (запомнено): " .. doneN ..
			(nearest and (" · ближайшая: " .. math.floor(nearest) .. " м") or "") ..
			(rareOnly and next(rareSet) == nil and ". Отличающихся групп нет — у всех конфет одинаковые свойства." or ". Исчезнувшие после подхода считаются собранными.")
	end

	local function setOn(v)
		on = v
		mainBtn.Text = on and "ESP конфет: ВКЛ" or "ESP конфет: ВЫКЛ"
		paint(mainBtn, on)
		if on then scanT = 0 end
	end
	mainBtn.MouseButton1Click:Connect(function() setOn(not on) end)
	traceBtn.MouseButton1Click:Connect(function() tracers = not tracers paint(traceBtn, tracers) saveCandy() end)
	mapBtn.MouseButton1Click:Connect(function() mapOn = not mapOn paint(mapBtn, mapOn) saveCandy() end)
	doneBtn.MouseButton1Click:Connect(function() hideDone = not hideDone paint(doneBtn, hideDone) refT = 0 saveCandy() end)
	resetBtn.MouseButton1Click:Connect(function()
		done, doneN, refT = {}, 0, 0
		saveCandy()
	end)
	distBox.FocusLost:Connect(function()
		maxDist = math.clamp(tonumber(distBox.Text) or maxDist, 50, 20000)
		distBox.Text = tostring(maxDist)
		saveCandy()
	end)
	keyBox.FocusLost:Connect(function()
		keysText = keyBox.Text
		parseKeys()
		scanT = 0
		saveCandy()
	end)

	pcall(function() RunService:UnbindFromRenderStep("SpeedMenuCandy") end)
	RunService:BindToRenderStep("SpeedMenuCandy", Enum.RenderPriority.Camera.Value + 4, function()
		local cam = workspace.CurrentCamera
		if not on or not cam then
			for _, p in pairs(pool) do p.lbl.Visible = false; p.line.Visible = false end
			for _, d in pairs(dots) do d.Visible = false end
			mapF.Visible = false
			return
		end
		local now = os.clock()
		local mine = getHRP()
		local from = mine and mine.Position or cam.CFrame.Position
		if now - refT > 0.25 or now - scanT > 2 then
			refT = now
			pcall(refreshActive, from) -- сначала проверяем исчезнувшие, потом обновляем поиск
		end
		if now - scanT > 2 then
			scanT = now
			pcall(scan)
			if rareOnly then pcall(analyze) end
		end

		local vp = cam.ViewportSize
		local n, nearest = 0, nil
		local pts = {}
		for _, f in ipairs(active) do
			local o = f.obj
			if o and o.Parent then
				local pos = posOf(o)
				if pos then
					local dist = (pos - from).Magnitude
					if dist <= maxDist then
						if not nearest or dist < nearest then nearest = dist end
						table.insert(pts, {pos = pos, dist = dist})
						local sp = cam:WorldToViewportPoint(pos)
						if sp.Z > 0 then
							n = n + 1
							local p = item(n)
							p.lbl.Visible = true
							p.lbl.Position = UDim2.fromOffset(math.floor(sp.X + 0.5), math.floor(sp.Y + 0.5))
							p.lbl.Text = "🍬 " .. f.name .. " · " .. math.floor(dist) .. " м"
							if tracers then
								local a = Vector2.new(vp.X / 2, vp.Y)
								local b = Vector2.new(sp.X, sp.Y)
								local d = b - a
								p.line.Visible = true
								p.line.Size = UDim2.fromOffset(d.Magnitude, 1.5)
								p.line.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
								p.line.Rotation = math.deg(math.atan2(d.Y, d.X))
							else
								p.line.Visible = false
							end
						end
					end
				end
			end
		end
		for i = n + 1, #pool do pool[i].lbl.Visible = false; pool[i].line.Visible = false end

		-- карта: вид сверху, север (−Z) вверху; масштаб подгоняется под все несобранные конфеты
		mapF.Visible = mapOn
		if mapOn then
			local minX, maxX, minZ, maxZ = from.X, from.X, from.Z, from.Z
			for _, q in ipairs(pts) do
				minX = math.min(minX, q.pos.X); maxX = math.max(maxX, q.pos.X)
				minZ = math.min(minZ, q.pos.Z); maxZ = math.max(maxZ, q.pos.Z)
			end
			local w, h = math.max(maxX - minX, 20), math.max(maxZ - minZ, 20)
			local size = MAP - 8 - 16
			local sc = math.min(size / w, size / h)
			local ox = 8 + (size - w * sc) / 2
			local oz = 8 + (size - h * sc) / 2
			meDot.Position = UDim2.fromOffset(ox + (from.X - minX) * sc, oz + (from.Z - minZ) * sc)
			local shown = 0
			for _, q in ipairs(pts) do
				if shown >= 200 then break end
				shown = shown + 1
				local d = dot(shown)
				d.Visible = true
				d.BackgroundColor3 = (q.dist == nearest) and YELLOW or PINK
				d.Position = UDim2.fromOffset(ox + (q.pos.X - minX) * sc, oz + (q.pos.Z - minZ) * sc)
			end
			for i = shown + 1, #dots do dots[i].Visible = false end
			mapHead.Text = "Карта · не собрано: " .. #pts .. (nearest and (" · ближайшая " .. math.floor(nearest) .. " м (жёлтая)") or "")
		end
		if now - (updateStatusT or 0) > 0.5 and now > diagHold then
			updateStatusT = now
			updateStatus(nearest)
		end
	end)
end, function(e) __trk.report("ESP конфет", e) end)

-- =====================================================================
-- ===== УТИЛИТЫ: FPS и пинг, Fullbright, без тумана, анти-лаг, зум,
-- =====         время суток, наблюдение за игроком, смена сервера, авто-перезаход
-- =====================================================================
xpcall(function() --[[утилиты]]
	local Lighting = game:GetService("Lighting")
	local StatsSvc = game:GetService("Stats")
	local GuiService = game:GetService("GuiService")
	local TeleportService = game:GetService("TeleportService")

	local hudOn, fbOn, fogOn, lagOn, zoomOn, rejoinOn, timeOn = false, false, false, false, false, false, false
	local clockVal = 14

	local cu = card("УТИЛИТЫ", 330, 22)
	local u1 = row(cu, 28, 32)
	local hudBtn = cell(u1, 2, "FPS и пинг", C.off)
	local fbBtn = cell(u1, 2, "Fullbright", C.off)
	local u2 = row(cu, 66, 32)
	local fogBtn = cell(u2, 2, "Без тумана", C.off)
	local lagBtn = cell(u2, 2, "Анти-лаг", C.off)
	local u3 = row(cu, 104, 32)
	local zoomBtn = cell(u3, 2, "Макс. зум камеры", C.off)
	local rejBtn = cell(u3, 2, "Авто-перезаход", C.off)
	for _, b in ipairs({hudBtn, fbBtn, fogBtn, lagBtn, zoomBtn, rejBtn}) do b.TextSize = 11 end
	label(cu, "Время суток (0–24)", 142)
	local timeBox = numBox(cu, 142, clockVal)
	local u4 = row(cu, 180, 32)
	local timeBtn = cell(u4, 1, "Зафиксировать время", C.off)
	timeBtn.TextSize = 11
	local specLabel = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 20), Position = UDim2.fromOffset(12, 218), BackgroundTransparency = 1,
		Text = "Наблюдение: выкл", Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.sub,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = cu,
	})
	local u5 = row(cu, 242, 32)
	local prevBtn = cell(u5, 3, "◀")
	local stopBtn = cell(u5, 3, "Стоп наблюдения")
	local nextBtn = cell(u5, 3, "▶")
	stopBtn.TextSize = 10
	local u6 = row(cu, 282, 32)
	local hopBtn = cell(u6, 1, "Другой сервер", C.accent)

	-- ----- FPS и пинг -----
	local oldHud = parent:FindFirstChild("SpeedMenuHud")
	if oldHud then oldHud:Destroy() end
	local hg = new("ScreenGui", {Name = "SpeedMenuHud", ResetOnSpawn = false, IgnoreGuiInset = true, Parent = parent})
	local hud = new("TextLabel", {
		Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(150, 20), BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4, Text = "", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text,
		Visible = false, Parent = hg,
	}, {round(5)})
	local acc, frames = 0, 0
	RunService.RenderStepped:Connect(function(dt)
		if not hudOn then return end
		acc = acc + dt
		frames = frames + 1
		if acc >= 0.5 then
			local fps = math.floor(frames / acc + 0.5)
			local ping = 0
			pcall(function() ping = math.floor(StatsSvc.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
			hud.Text = "FPS " .. fps .. " · пинг " .. ping .. " мс"
			acc, frames = 0, 0
		end
	end)
	hudBtn.MouseButton1Click:Connect(function() hudOn = not hudOn hud.Visible = hudOn paint(hudBtn, hudOn) end)

	-- ----- освещение: Fullbright, без тумана, время суток (значения возвращаются при выключении) -----
	local oFb, oFog, oTime = nil, nil, nil
	local atmo = setmetatable({}, {__mode = "k"})
	local function fbApply()
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.fromRGB(178, 178, 178)
		Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
	end
	local function fogApply()
		Lighting.FogEnd = 1e6
		for _, a in ipairs(Lighting:GetChildren()) do
			if a:IsA("Atmosphere") then
				if not atmo[a] then atmo[a] = {a.Density, a.Haze} end
				a.Density = 0
				a.Haze = 0
			end
		end
	end
	fbBtn.MouseButton1Click:Connect(function()
		fbOn = not fbOn
		paint(fbBtn, fbOn)
		if fbOn then
			oFb = {Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient}
			fbApply()
		elseif oFb then
			Lighting.Brightness, Lighting.Ambient, Lighting.OutdoorAmbient = oFb[1], oFb[2], oFb[3]
		end
	end)
	fogBtn.MouseButton1Click:Connect(function()
		fogOn = not fogOn
		paint(fogBtn, fogOn)
		if fogOn then
			oFog = Lighting.FogEnd
			fogApply()
		else
			if oFog then Lighting.FogEnd = oFog end
			for a, v in pairs(atmo) do
				if a.Parent then a.Density, a.Haze = v[1], v[2] end
				atmo[a] = nil
			end
		end
	end)
	local function setClock(v)
		v = tonumber(v)
		if not v then return end
		clockVal = math.clamp(v, 0, 24)
		timeBox.Text = tostring(clockVal)
	end
	timeBox.FocusLost:Connect(function() setClock(timeBox.Text) end)
	timeBtn.MouseButton1Click:Connect(function()
		timeOn = not timeOn
		paint(timeBtn, timeOn)
		timeBtn.Text = timeOn and "Время зафиксировано" or "Зафиксировать время"
		if timeOn then oTime = Lighting.ClockTime
		elseif oTime then Lighting.ClockTime = oTime end
	end)

	-- ----- анти-лаг: ниже качество, без теней, частиц и пост-эффектов -----
	local lagStore = setmetatable({}, {__mode = "k"})
	local lagConn, oQuality, oShadows
	local function isFx(d)
		return d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles")
			or d:IsA("BlurEffect") or d:IsA("BloomEffect") or d:IsA("SunRaysEffect") or d:IsA("DepthOfFieldEffect")
	end
	local function lagOne(d)
		if isFx(d) then
			if lagStore[d] == nil then lagStore[d] = d.Enabled end
			d.Enabled = false
		end
	end
	lagBtn.MouseButton1Click:Connect(function()
		lagOn = not lagOn
		paint(lagBtn, lagOn)
		if lagOn then
			pcall(function()
				oQuality = settings().Rendering.QualityLevel
				settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
			end)
			oShadows = Lighting.GlobalShadows
			Lighting.GlobalShadows = false
			lagConn = workspace.DescendantAdded:Connect(function(d) if lagOn then pcall(lagOne, d) end end)
			task.spawn(function()
				local n = 0
				for _, d in ipairs(workspace:GetDescendants()) do
					pcall(lagOne, d)
					n = n + 1
					if n % 400 == 0 then task.wait() end
				end
				for _, d in ipairs(Lighting:GetChildren()) do pcall(lagOne, d) end
			end)
		else
			if lagConn then lagConn:Disconnect() lagConn = nil end
			pcall(function() if oQuality then settings().Rendering.QualityLevel = oQuality end end)
			if oShadows ~= nil then Lighting.GlobalShadows = oShadows end
			for d, v in pairs(lagStore) do
				if d.Parent then d.Enabled = v end
				lagStore[d] = nil
			end
		end
	end)

	-- ----- зум камеры -----
	local oZoom
	zoomBtn.MouseButton1Click:Connect(function()
		zoomOn = not zoomOn
		paint(zoomBtn, zoomOn)
		if zoomOn then
			oZoom = {lp.CameraMaxZoomDistance, lp.CameraMinZoomDistance}
		elseif oZoom then
			lp.CameraMaxZoomDistance, lp.CameraMinZoomDistance = oZoom[1], oZoom[2]
		end
	end)

	-- игры иногда сбрасывают значения: поддерживаем включённое раз в 0.3 с
	local enfT = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - enfT < 0.3 then return end
		enfT = now
		if fbOn then pcall(fbApply) end
		if fogOn then pcall(fogApply) end
		if timeOn then Lighting.ClockTime = clockVal end
		if zoomOn then
			if lp.CameraMaxZoomDistance < 1000 then lp.CameraMaxZoomDistance = 1000 end
			if lp.CameraMinZoomDistance > 0.5 then lp.CameraMinZoomDistance = 0.5 end
		end
	end)

	-- ----- авто-перезаход после отключения (но не при «вход с другого устройства») -----
	local lastRejoin = 0
	pcall(function()
		GuiService.ErrorMessageChanged:Connect(function()
			if not rejoinOn then return end
			local okm, msg = pcall(function() return GuiService:GetErrorMessage() end)
			msg = okm and tostring(msg):lower() or ""
			if msg:find("different device") or msg:find("same account") then return end
			if os.clock() - lastRejoin < 30 then return end
			lastRejoin = os.clock()
			task.wait(2)
			pcall(function() TeleportService:Teleport(game.PlaceId, lp) end)
		end)
	end)
	rejBtn.MouseButton1Click:Connect(function() rejoinOn = not rejoinOn paint(rejBtn, rejoinOn) end)

	-- ----- наблюдение за игроком -----
	local specIdx, specOn = 0, false
	local function others()
		local t = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= lp then table.insert(t, p) end
		end
		table.sort(t, function(a, b) return a.Name:lower() < b.Name:lower() end)
		return t
	end
	local function specStop()
		specOn = false
		specLabel.Text = "Наблюдение: выкл"
		local cam, h = workspace.CurrentCamera, getHum()
		if cam and h then cam.CameraSubject = h end
	end
	local function specGo(step)
		local t = others()
		if #t == 0 then specStop() return end
		specIdx = ((specIdx - 1 + step) % #t) + 1
		local p = t[specIdx]
		local h = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		if h and workspace.CurrentCamera then
			workspace.CurrentCamera.CameraSubject = h
			specOn = true
			specLabel.Text = "Наблюдаю: " .. p.DisplayName .. " (" .. specIdx .. "/" .. #t .. ")"
		else
			specLabel.Text = p.DisplayName .. ": нет персонажа"
		end
	end
	prevBtn.MouseButton1Click:Connect(function() specGo(-1) end)
	nextBtn.MouseButton1Click:Connect(function() specGo(1) end)
	stopBtn.MouseButton1Click:Connect(specStop)
	RunService.Heartbeat:Connect(function()
		if not specOn then return end
		local cam = workspace.CurrentCamera
		local subj = cam and cam.CameraSubject
		if not subj or not subj.Parent then specStop() end -- игрок вышел
	end)

	-- ----- смена сервера -----
	local hopBusy = false
	hopBtn.MouseButton1Click:Connect(function()
		if hopBusy then return end
		hopBusy = true
		task.delay(8, function() hopBusy = false end)
		task.spawn(function()
			local req = (syn and syn.request) or http_request or request
			local target
			if req then
				local ok, res = pcall(function()
					return req({Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100", Method = "GET"})
				end)
				if ok and res and res.Body then
					local okj, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
					if okj and type(data) == "table" and type(data.data) == "table" then
						local cands = {}
						for _, s in ipairs(data.data) do
							if s.id ~= game.JobId and (s.playing or 0) < (s.maxPlayers or 0) - 1 then table.insert(cands, s.id) end
						end
						if #cands > 0 then target = cands[math.random(#cands)] end
					end
				end
			else
				flash(hopBtn, "Нет запросов — случайный сервер")
			end
			pcall(function()
				if target then
					TeleportService:TeleportToPlaceInstance(game.PlaceId, target, lp)
				else
					TeleportService:Teleport(game.PlaceId, lp)
				end
			end)
		end)
	end)
end, function(e) __trk.report("утилиты", e) end)


-- =====================================================================
-- ===== ИГРА И ПРОФИЛЬ: скрипт узнаёт игру и подбирает настройки именно под неё
-- =====================================================================
xpcall(function() --[[игры]]
	local Market = game:GetService("MarketplaceService")
	local FILE = "SpeedMenu_games.json"
	local gid = tostring(game.GameId ~= 0 and game.GameId or game.PlaceId)

	-- ----- сохранённые профили -----
	local store = {auto = true, games = {}, fav = {}}
	if canSave then
		local ok, d = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
		if ok and type(d) == "table" then
			if type(d.auto) == "boolean" then store.auto = d.auto end
			if type(d.games) == "table" then store.games = d.games end
			if type(d.fav) == "table" then store.fav = d.fav end
		end
	end
	local saveQ = false
	local function persist()
		if not canSave or saveQ then return end
		saveQ = true
		task.delay(0.5, function()
			saveQ = false
			pcall(function() writefile(FILE, HttpService:JSONEncode(store)) end)
		end)
	end

	-- ----- свои профили для конкретных игр: добавляй сюда по PlaceId или GameId -----
	-- вид: ["ID"] = {genre = "шутер", speed = 40, jumpPower = 60, fov = 80, esp = true, antiAfk = false, aim = {aimFov = 150}}
	local KNOWN = {
		["4924922222"] = {genre = "ролевая", fov = 80, antiAfk = false},   -- Brookhaven
	}

	-- ----- жанры: по названию игры и по именам объектов -----
	local GENRES = {
		{id = "шутер", words = {"fps", "shoot", "gun", "weapon", "ammo", "bullet", "reload", "rifle", "pistol", "sniper", "warfare", "battlefield", "arsenal", "rivals", "phantom", "bad business", "strucid", "criminality"}},
		{id = "паркур", words = {"obby", "parkour", "checkpoint", "stage", "tower of", "killbrick"}},
		{id = "симулятор", words = {"simulator", "tycoon", "clicker", "idle", "farm", "grind", "incremental"}},
		{id = "хоррор", words = {"horror", "doors", "piggy", "backrooms", "scary", "haunted", "nightmare"}},
	}
	local PRESETS = {
		["шутер"]    = {esp = true, aim = {aimFov = 160, aimSmooth = 4, wallCheck = true, teamCheck = true, predOn = true, sticky = true}},
		["паркур"]   = {speed = 32, jumpPower = 65, fov = 80},
		["симулятор"] = {antiAfk = true},
		["хоррор"]   = {fov = 85, tool = {fullbright = true}},
		["экшн"]     = {esp = true},
		["детектив"] = {esp = true},
		["выживание"] = {fov = 80},
		["стратегия"] = {antiAfk = true},
	}
	local gameName = "…"
	local genre = "обычная"
	pcall(function() gameName = Market:GetProductInfo(game.PlaceId).Name end)
	if gameName == "…" then gameName = game.Name end

	local function hits(text)
		text = tostring(text):lower()
		for _, g in ipairs(GENRES) do
			for _, w in ipairs(g.words) do
				if text:find(w, 1, true) then return g.id end
			end
		end
	end
	local function detect()
		local g = hits(gameName)
		if g then return g end
		local votes = {}
		local function scan(root, limit)
			if not root then return end
			local ok, list = pcall(function() return root:GetDescendants() end)
			if not ok then return end
			for i = 1, math.min(#list, limit) do
				local gg = hits(list[i].Name)
				if gg then votes[gg] = (votes[gg] or 0) + 1 end
			end
		end
		scan(game:GetService("ReplicatedStorage"), 1500)
		scan(game:GetService("StarterPack"), 200)
		scan(lp:FindFirstChildOfClass("Backpack"), 200)
		scan(game:GetService("Lighting"), 100)
		local best, bn = nil, 2 -- минимум 3 совпадения, чтобы не ошибаться
		for id, n in pairs(votes) do
			if n > bn then best, bn = id, n end
		end
		return best
	end

	-- ----- применение / снимок -----
	local function snapshot()
		local lib = _G.SpeedMenuAimLib
		return {
			name = gameName, genre = genre, speed = speed, jumpPower = jumpPower, fov = fov, esp = esp, antiAfk = antiAfk,
			aim = lib and lib.snapshot and lib.snapshot() or nil,
			tool = _G.SpeedMenuTools and _G.SpeedMenuTools.snapshot and _G.SpeedMenuTools.snapshot() or nil,
		}
	end
	local function applyProfile(p)
		if type(p) ~= "table" then return end
		if tonumber(p.speed) then speed = math.clamp(math.floor(tonumber(p.speed) + 0.5), MIN, MAX) end
		if tonumber(p.jumpPower) then jumpPower = math.clamp(math.floor(tonumber(p.jumpPower) + 0.5), JMIN, JMAX) end
		if tonumber(p.fov) then fov = math.clamp(math.floor(tonumber(p.fov) + 0.5), VMIN, VMAX) end
		if type(p.esp) == "boolean" then esp = p.esp end
		if type(p.antiAfk) == "boolean" then antiAfk = p.antiAfk end
		local lib = _G.SpeedMenuAimLib
		if p.aim and lib and lib.apply then pcall(lib.apply, p.aim) end
		if type(p.tool) == "table" and _G.SpeedMenuTools then
			for k, v in pairs(p.tool) do pcall(_G.SpeedMenuTools.set, k, v) end
		end
		refreshUI(); save()
	end

	_G.SpeedMenuProfile = {snapshot = snapshot, apply = applyProfile}

	-- ----- интерфейс -----
	local c23 = card("ИГРА И ПРОФИЛЬ", 214, 23)
	local nameL = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 26), BackgroundTransparency = 1, Text = gameName,
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = c23,
	})
	local infoL = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 46), BackgroundTransparency = 1, Text = "…",
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c23,
	})
	local rA = row(c23, 82, 32)
	local saveB = cell(rA, 2, "Сохранить для игры", C.on)
	local resetB = cell(rA, 2, "Сбросить профиль", C.btn)
	local rB = row(c23, 120, 32)
	local autoB = cell(rB, 2, "Авто-профиль", store.auto and C.on or C.off)
	local nowB = cell(rB, 2, "Применить сейчас", C.btn)
	for _, b in ipairs({saveB, resetB, autoB, nowB}) do b.TextSize = 11 end
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 50), Position = UDim2.fromOffset(12, 158), BackgroundTransparency = 1,
		Text = "При запуске скрипт узнаёт игру и подставляет её профиль: сохранённый тобой или готовый под жанр (шутер, паркур, симулятор). «Сохранить» запоминает скорость, прыжок, FOV, ESP и настройки аима именно для этой игры. Аим сам не включается.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c23,
	})

	local function describe(src)
		infoL.Text = "Жанр: " .. genre .. "  ·  профиль: " .. src
	end
	local function presetFor()
		return KNOWN[tostring(game.PlaceId)] or KNOWN[gid] or PRESETS[genre]
	end

	saveB.MouseButton1Click:Connect(function()
		store.games[gid] = snapshot()
		persist(); describe("сохранён тобой")
		saveB.Text = "Сохранено ✓"
		task.delay(1.2, function() saveB.Text = "Сохранить для игры" end)
	end)
	resetB.MouseButton1Click:Connect(function()
		store.games[gid] = nil
		persist(); describe(presetFor() and "готовый под жанр" or "нет")
	end)
	autoB.MouseButton1Click:Connect(function()
		store.auto = not store.auto
		paint(autoB, store.auto)
		persist()
	end)
	nowB.MouseButton1Click:Connect(function()
		local p = store.games[gid] or presetFor()
		if p then applyProfile(p); describe(store.games[gid] and "сохранён тобой" or "готовый под жанр")
		else infoL.Text = "Жанр: " .. genre .. "  ·  для этой игры профиля нет, нажми «Сохранить»" end
	end)


	-- =============== ВЫБОР ИГРЫ ===============
	-- чтобы добавить игру: впиши {"Название", PlaceId, "жанр"}; PlaceId — число из ссылки на игру (roblox.com/games/ЧИСЛО/...)
	local GAMES = {
		{"Brookhaven RP", 4924922222, "ролевая"},
		{"Adopt Me!", 920587237, "ролевая"},
		{"Blox Fruits", 2753915549, "приключения"},
		{"Murder Mystery 2", 142823291, "детектив"},
		{"Arsenal", 286090429, "шутер"},
		{"Rivals", 17625359962, "шутер"},
		{"Phantom Forces", 292439477, "шутер"},
		{"Bad Business", 3233893879, "шутер"},
		{"Counter Blox", 301549746, "шутер"},
		{"Da Hood", 2788229376, "экшн"},
		{"Blade Ball", 13772394625, "экшн"},
		{"Jailbreak", 606849621, "экшн"},
		{"Doors", 6516141723, "хоррор"},
		{"Piggy", 4623386862, "хоррор"},
		{"Tower of Hell", 1962086868, "паркур"},
		{"Natural Disaster Survival", 189707, "выживание"},
		{"Pet Simulator 99", 8737899170, "симулятор"},
		{"Bee Swarm Simulator", 1537690962, "симулятор"},
		{"Tower Defense Simulator", 3260590327, "стратегия"},
	}
	local GAME_BY_ID = {}
	for _, g in ipairs(GAMES) do GAME_BY_ID[tostring(g[2])] = g end

	local TPS = game:GetService("TeleportService")
	local c24 = card("ВЫБОР ИГРЫ", 380, 0)
	local search = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 28), PlaceholderText = "Поиск игры по названию…", Text = "",
		ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text,
		PlaceholderColor3 = Color3.fromRGB(130, 124, 170), BackgroundColor3 = C.field, Parent = c24,
	}, {round(8)})
	local listF = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 0, 176), Position = UDim2.fromOffset(12, 64), BackgroundColor3 = C.field, BackgroundTransparency = 0.4,
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = c24,
	}, {
		round(8),
		new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
		new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)}),
	})
	local pickInfo = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 246), BackgroundTransparency = 1, Text = "Выбери игру из списка",
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c24,
	})
	local rP = row(c24, 284, 32)
	local joinB = cell(rP, 3, "Зайти в игру", C.on)
	local presB = cell(rP, 3, "Пресет жанра", C.btn)
	local favB = cell(rP, 3, "♥ Избранное", C.btn)
	local rI = row(c24, 322, 32)
	local idBox = cellBox(rI, 2, "PlaceId игры")
	local idB = cell(rI, 2, "Зайти по ID", C.btn)
	joinB.TextSize = 11; presB.TextSize = 11; favB.TextSize = 11; idB.TextSize = 12
	local picked
	local listBtns = {}
	local function rebuild()
		for _, b in ipairs(listBtns) do b:Destroy() end
		listBtns = {}
		local q = string.lower(search.Text or "")
		local ordered = {}
		for _, pass in ipairs({true, false}) do -- избранные сверху
			for _, g in ipairs(GAMES) do
				if (store.fav[g[1]] and true or false) == pass then table.insert(ordered, g) end
			end
		end
		for i, g in ipairs(ordered) do
			if q == "" or string.find(string.lower(g[1]), q, 1, true) or string.find(g[3], q, 1, true) then
				local here = tostring(game.PlaceId) == tostring(g[2])
				local b = new("TextButton", {
					Size = UDim2.new(1, 0, 0, 30), LayoutOrder = i, Text = (store.fav[g[1]] and "♥ " or "") .. (here and "★ " or "") .. g[1] .. "   ·   " .. g[3],
					Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
					BackgroundColor3 = (picked == g) and C.on or C.card, BorderSizePixel = 0, Parent = listF,
				}, {round(8), new("UIPadding", {PaddingLeft = UDim.new(0, 8)})})
				b.MouseButton1Click:Connect(function()
					picked = g
					if _G.SpeedMenuShowModules then pcall(_G.SpeedMenuShowModules, g[1]) end
					pickInfo.Text = g[1] .. "  ·  жанр: " .. g[3] .. "  ·  PlaceId " .. g[2]
					for _, o in ipairs(listBtns) do o.BackgroundColor3 = C.card end
					b.BackgroundColor3 = C.on
				end)
				table.insert(listBtns, b)
			end
		end
	end
	rebuild()
	search:GetPropertyChangedSignal("Text"):Connect(rebuild)
	local function joinId(id)
		id = tonumber(id)
		if not id then pickInfo.Text = "Введи число — PlaceId из ссылки на игру" return end
		pickInfo.Text = "Телепортирую в игру " .. id .. "…"
		local ok, err = pcall(function() TPS:Teleport(id, lp) end)
		if not ok then pickInfo.Text = "Не удалось: " .. tostring(err) end
	end
	joinB.MouseButton1Click:Connect(function()
		if not picked then pickInfo.Text = "Сначала выбери игру в списке" return end
		joinId(picked[2])
	end)
	idB.MouseButton1Click:Connect(function() joinId(idBox.Text) end)
	favB.MouseButton1Click:Connect(function()
		if not picked then pickInfo.Text = "Сначала выбери игру в списке" return end
		store.fav[picked[1]] = (not store.fav[picked[1]]) or nil
		persist(); rebuild()
		pickInfo.Text = picked[1] .. (store.fav[picked[1]] and " — добавлена в избранное" or " — убрана из избранного")
	end)
	presB.MouseButton1Click:Connect(function()
		if not picked then pickInfo.Text = "Сначала выбери игру в списке" return end
		local p = PRESETS[picked[3]]
		if p then
			genre = picked[3]
			applyProfile(p)
			describe("готовый под жанр «" .. picked[3] .. "» (применён)")
			pickInfo.Text = "Пресет «" .. picked[3] .. "» применён к текущей игре"
		else
			pickInfo.Text = "Для жанра «" .. picked[3] .. "» готового пресета нет"
		end
	end)


	-- =============== МОДУЛИ ИГР: свои функции для каждой игры из списка ===============
	-- все модули работают только с твоим клиентом: свет, подсветка объектов, настройки, свои скорость и телепорт.
	local function TL() return _G.SpeedMenuTools end
	local function toolOn(n) local t = TL() return t and t.get and t.get(n) or false end
	local function toolSet(n, v) local t = TL() if t and t.set then pcall(t.set, n, v) end end
	local function feat(name, get, set, isAction) return {name = name, get = get, set = set, action = isAction} end
	local F = {}
	F.light = feat("Яркий свет, без тумана", function() return toolOn("fullbright") end, function(v) toolSet("fullbright", v) toolSet("nofog", v) end)
	F.fps = feat("FPS-буст", function() return toolOn("fps") end, function(v) toolSet("fps", v) end)
	F.zoom = feat("Дальний зум камеры", function() return toolOn("zoom") end, function(v) toolSet("zoom", v) end)
	F.click = feat("Автокликер", function() return toolOn("autoclick") end, function(v) toolSet("autoclick", v) end)
	F.afk = feat("Анти-АФК", function() return antiAfk end, function(v) antiAfk = v refreshUI() end)
	F.esp = feat("ESP игроков", function() return esp end, function(v) esp = v pcall(refreshEsp) refreshUI() end)
	F.void = feat("Анти-падение в бездну", function() return voidOn end, function(v) voidOn = v pcall(paint, _G.SpeedMenuVoidBtn, v) end)
	local function obj(label, kw)
		return feat(label, function() return toolOn("objesp") end, function(v)
			local t = TL()
			if t and t.setKeyword then t.setKeyword(kw) end
			toolSet("objesp", v)
		end)
	end
	local function spd(n)
		return feat("Скорость " .. n, function() return enabled and speed == n end, function(v)
			if v then speed = n end
			enabled = v
			if not v then local h = getHum() if h then h.WalkSpeed = DEFAULT end end
			refreshUI()
		end)
	end
	local function aimF(preset)
		return feat("Аим под эту игру", function() local l = _G.SpeedMenuAimLib return l and l.getAim and l.getAim() or false end, function(v)
			local l = _G.SpeedMenuAimLib
			if not l then return end
			if v and l.apply then l.apply(preset) end
			if l.setAim then l.setAim(v) end
		end)
	end
	local function highest()
		local hrp = getHRP()
		if not hrp then return end
		local ok, list = pcall(function() return workspace:GetDescendants() end)
		if not ok then return end
		local best
		for i = 1, math.min(#list, 10000) do
			local d = list[i]
			if d:IsA("BasePart") and d.CanCollide and d.Size.X > 4 and d.Size.Z > 4
				and not (lp.Character and d:IsDescendantOf(lp.Character)) and not Players:GetPlayerFromCharacter(d.Parent) then
				local top = d.Position.Y + d.Size.Y / 2
				if not best or top > best.y then best = {y = top, p = d} end
			end
		end
		if best then safeTP(CFrame.new(best.p.Position.X, best.y + 4, best.p.Position.Z)) end
	end
	local F_high = feat("ТП на самую высокую точку", nil, highest, true)

	local SH = {aimFov = 150, aimSmooth = 4, wallCheck = true, teamCheck = true, predOn = true, sticky = true}
	local function shooter(extra)
		local p = {}
		for k, v in pairs(SH) do p[k] = v end
		for k, v in pairs(extra or {}) do p[k] = v end
		return p
	end
	local MODULES = {
		["Doors"] = {F.light, obj("Подсветка дверей, ключей, рычагов", "door,keyobtain,leverforgate,livehintbook,goldpile"), spd(22), F.fps},
		["Piggy"] = {F.light, obj("Подсветка предметов и ключей", "key,valve,crowbar,wrench,hammer,item"), spd(24), F.zoom},
		["Tower of Hell"] = {F.zoom, F.light, F.afk, F.fps},
		["Natural Disaster Survival"] = {F_high, F.void, spd(30), F.light},
		["Pet Simulator 99"] = {F.afk, F.click, obj("Подсветка монет и сундуков", "coin,chest,loot,orb,diamond"), F.fps},
		["Bee Swarm Simulator"] = {F.afk, F.click, obj("Подсветка токенов и пыльцы", "token,pollen,bubble,field"), F.fps},
		["Blox Fruits"] = {obj("Подсветка фруктов и сундуков", "fruit,chest"), F.afk, F.fps, F.light},
		["Adopt Me!"] = {F.afk, F.fps, F.zoom},
		["Brookhaven RP"] = {F.afk, F.fps, F.zoom, F.light},
		["Murder Mystery 2"] = {obj("Подсветка выпавшего оружия и монет", "gundrop,coin"), spd(24), F.afk, F.fps},
		["Arsenal"] = {F.esp, aimF(shooter({aimSmooth = 3})), F.fps},
		["Rivals"] = {F.esp, aimF(shooter({aimSmooth = 4})), F.fps},
		["Phantom Forces"] = {F.esp, aimF(shooter({aimSmooth = 5, predMs = 80})), F.fps},
		["Bad Business"] = {F.esp, aimF(shooter({aimSmooth = 5, predMs = 80})), F.fps},
		["Counter Blox"] = {F.esp, aimF(shooter({aimSmooth = 5, predMs = 80})), F.fps},
		["Da Hood"] = {F.esp, aimF(shooter({aimFov = 180, aimSmooth = 3, predMs = 120, teamCheck = false})), spd(30)},
		["Jailbreak"] = {F.esp, spd(30), F.afk, F.fps},
		["Blade Ball"] = {F.fps, F.afk, F.zoom},
		["Tower Defense Simulator"] = {F.afk, F.fps, F.zoom},
	}
	local GENERIC = {F.light, F.fps, F.afk, F.zoom, F.click}

	local c26 = card("МОДУЛИ ИГРЫ", 120, 1)
	local modTitle = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 26), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Parent = c26,
	})
	local modBtns = {}
	local function showModules(gname)
		for _, m in ipairs(modBtns) do m.b:Destroy() end
		modBtns = {}
		local list = MODULES[gname]
		modTitle.Text = list and ("Модули: " .. gname) or "Модули: общие (для этой игры нет отдельных)"
		list = list or GENERIC
		for i, f in ipairs(list) do
			local b = new("TextButton", {
				Size = UDim2.new(1, -24, 0, 32), Position = UDim2.fromOffset(12, 48 + (i - 1) * 38), Text = f.name,
				Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text, BackgroundColor3 = f.action and C.btn or C.off,
				BorderSizePixel = 0, Parent = c26,
			}, {round(8)})
			b.MouseButton1Click:Connect(function()
				if f.action then pcall(f.set) return end
				local cur = f.get() and true or false
				pcall(f.set, not cur)
				pcall(function() _G.SpeedMenuToast(f.name .. (cur and ": выключено" or ": включено")) end)
			end)
			table.insert(modBtns, {b = b, f = f})
		end
		c26.Size = UDim2.new(1, 0, 0, 56 + #list * 38)
	end
	showModules(GAME_BY_ID[tostring(game.PlaceId)] and GAME_BY_ID[tostring(game.PlaceId)][1] or "")
	local mAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		mAcc = mAcc + (dt or 0.016)
		if mAcc < 0.3 then return end
		mAcc = 0
		for _, m in ipairs(modBtns) do
			if not m.f.action then
				local ok, v = pcall(m.f.get)
				tween(m.b, {BackgroundColor3 = (ok and v) and C.on or C.off})
			end
		end
	end)
	-- выбор в списке игр показывает модули этой игры
	local oldRebuildHook = showModules
	_G.SpeedMenuShowModules = showModules
	-- определяем игру после загрузки (даём ей 3 секунды заполнить ReplicatedStorage)
	task.spawn(function()
		task.wait(3)
		local saved = store.games[gid]
		genre = (saved and saved.genre) or (KNOWN[tostring(game.PlaceId)] and KNOWN[tostring(game.PlaceId)].genre) or (GAME_BY_ID[tostring(game.PlaceId)] and GAME_BY_ID[tostring(game.PlaceId)][3]) or detect() or "обычная"
		nameL.Text = gameName
		local p = saved or presetFor()
		if p and store.auto then
			applyProfile(p)
			describe(saved and "сохранён тобой (применён)" or "готовый под жанр (применён)")
		else
			describe(p and "есть, авто-применение выключено" or "нет")
		end
	end)
end, function(e) __trk.report("игры", e) end)

-- =====================================================================
-- ===== ИНСТРУМЕНТЫ ДЛЯ ИГР: свет, FPS, зум, автокликер, поиск объектов по имени
-- =====================================================================
xpcall(function() --[[инструменты игр]]
	local Lighting = game:GetService("Lighting")
	local vu = game:GetService("VirtualUser")
	local c25 = card("ИНСТРУМЕНТЫ ДЛЯ ИГР", 306, 2)
	local r1 = row(c25, 28, 32)
	local r2 = row(c25, 66, 32)
	local r3 = row(c25, 104, 32)
	local bFull = cell(r1, 2, "Яркий свет", C.off)
	local bFog = cell(r1, 2, "Без тумана", C.off)
	local bFps = cell(r2, 2, "FPS-буст", C.off)
	local bZoom = cell(r2, 2, "Дальний зум", C.off)
	local bClick = cell(r3, 2, "Автокликер", C.off)
	local cpsBox = cellBox(r3, 2, "CPS 1–1000 (10)")
	label(c25, "Объекты по имени", 142)
	local r4 = row(c25, 170, 32)
	local kwBox = cellBox(r4, 1, "часть имени, напр. coin, key, door")
	local r5 = row(c25, 208, 32)
	local bObj = cell(r5, 2, "Подсветить", C.off)
	local bTp = cell(r5, 2, "ТП к ближайшему", C.btn)
	for _, b in ipairs({bFull, bFog, bFps, bZoom, bClick, bObj, bTp}) do b.TextSize = 11 end
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 50), Position = UDim2.fromOffset(12, 248), BackgroundTransparency = 1,
		Text = "Подходит для любых игр. «Подсветить» показывает до 25 объектов, в имени которых есть введённое слово; «ТП» переносит к ближайшему из них.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c25,
	})

	local st = {fullbright = false, nofog = false, fps = false, zoom = false, autoclick = false, objesp = false}
	local btnOf = {fullbright = bFull, nofog = bFog, fps = bFps, zoom = bZoom, autoclick = bClick, objesp = bObj}
	local saved = {}

	local function applyLight()
		if st.fullbright then
			Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false
			Lighting.Ambient = Color3.fromRGB(178, 178, 178); Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
		end
		if st.nofog then
			Lighting.FogEnd = 1e6
			for _, a in ipairs(Lighting:GetChildren()) do
				if a:IsA("Atmosphere") then a.Density = 0 end
			end
		end
	end
	local function setFullbright(v)
		if v and not saved.light then
			saved.light = {Lighting.Brightness, Lighting.ClockTime, Lighting.GlobalShadows, Lighting.Ambient, Lighting.OutdoorAmbient}
		end
		st.fullbright = v
		if v then applyLight()
		elseif saved.light then
			local l = saved.light
			Lighting.Brightness, Lighting.ClockTime, Lighting.GlobalShadows, Lighting.Ambient, Lighting.OutdoorAmbient = l[1], l[2], l[3], l[4], l[5]
			saved.light = nil
		end
	end
	local function setFog(v)
		if v and not saved.fog then
			saved.fog = {Lighting.FogEnd, {}}
			for _, a in ipairs(Lighting:GetChildren()) do
				if a:IsA("Atmosphere") then table.insert(saved.fog[2], {a, a.Density}) end
			end
		end
		st.nofog = v
		if v then applyLight()
		elseif saved.fog then
			Lighting.FogEnd = saved.fog[1]
			for _, p in ipairs(saved.fog[2]) do if p[1].Parent then p[1].Density = p[2] end end
			saved.fog = nil
		end
	end
	local function setFps(v)
		st.fps = v
		if v then
			saved.fps = {fx = {}}
			pcall(function() saved.fps.q = settings().Rendering.QualityLevel end)
			pcall(function() settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
			pcall(function() saved.fps.deco = workspace.Terrain.Decoration; workspace.Terrain.Decoration = false end)
			for _, e in ipairs(Lighting:GetChildren()) do
				if e:IsA("PostEffect") and e.Enabled then
					table.insert(saved.fps.fx, e); e.Enabled = false
				end
			end
			pcall(function() saved.fps.shadows = Lighting.GlobalShadows; Lighting.GlobalShadows = false end)
		elseif saved.fps then
			local f = saved.fps
			pcall(function() settings().Rendering.QualityLevel = f.q or Enum.QualityLevel.Automatic end)
			pcall(function() if f.deco ~= nil then workspace.Terrain.Decoration = f.deco end end)
			for _, e in ipairs(f.fx) do if e.Parent then e.Enabled = true end end
			pcall(function() if f.shadows ~= nil and not st.fullbright then Lighting.GlobalShadows = f.shadows end end)
			saved.fps = nil
		end
	end
	local function setZoom(v)
		st.zoom = v
		if v then
			saved.zoom = {lp.CameraMaxZoomDistance, lp.CameraMinZoomDistance}
			lp.CameraMaxZoomDistance = 2000; lp.CameraMinZoomDistance = 0.5
		elseif saved.zoom then
			lp.CameraMaxZoomDistance, lp.CameraMinZoomDistance = saved.zoom[1], saved.zoom[2]
			saved.zoom = nil
		end
	end

	-- ----- объекты по имени -----
	local hlFolder = new("Folder", {Name = "SpeedMenuObjects", Parent = gui})
	local marks = {}
	local function partOf(inst)
		if inst:IsA("BasePart") then return inst end
		if inst:IsA("Model") then return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true) end
	end
	local function scan(kw)
		local out = {}
		local kws = {}
		for w in string.gmatch(string.lower(kw or ""), "[^,%s]+") do
			if #w >= 2 then table.insert(kws, w) end
		end
		if #kws == 0 then return out end
		local function match(n)
			n = string.lower(n)
			for _, w in ipairs(kws) do
				if string.find(n, w, 1, true) then return true end
			end
			return false
		end
		local ok, list = pcall(function() return workspace:GetDescendants() end)
		if not ok then return out end
		local myChar = lp.Character
		for i = 1, math.min(#list, 8000) do
			local d = list[i]
			if (d:IsA("BasePart") or d:IsA("Model")) and match(d.Name) then
				if not (myChar and d:IsDescendantOf(myChar)) and not Players:GetPlayerFromCharacter(d) then
					local p = partOf(d)
					if p then table.insert(out, {inst = d, part = p}) end
				end
			end
		end
		local hrp = getHRP()
		if hrp then
			table.sort(out, function(a, b) return (a.part.Position - hrp.Position).Magnitude < (b.part.Position - hrp.Position).Magnitude end)
		end
		return out
	end
	local function clearMarks()
		for k, h in pairs(marks) do h:Destroy(); marks[k] = nil end
	end
	local function refreshMarks()
		local list = scan(kwBox.Text)
		local keep = {}
		for i = 1, math.min(#list, 25) do
			local d = list[i].inst
			keep[d] = true
			if not marks[d] then
				marks[d] = new("Highlight", {
					Adornee = d, FillColor = Color3.fromRGB(255, 220, 60), OutlineColor = Color3.new(1, 1, 1), FillTransparency = 0.5,
					DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = hlFolder,
				})
			end
		end
		for d, h in pairs(marks) do
			if not keep[d] or not d.Parent then h:Destroy(); marks[d] = nil end
		end
	end
	local function setObj(v)
		st.objesp = v
		if not v then clearMarks() else pcall(refreshMarks) end
	end

	local setters = {fullbright = setFullbright, nofog = setFog, fps = setFps, zoom = setZoom, autoclick = function(v) st.autoclick = v end, objesp = setObj}
	local function setTool(name, v)
		local f = setters[name]
		if not f then return end
		v = v and true or false
		f(v)
		local b = btnOf[name]
		if b then paint(b, v) end
	end
	for name, b in pairs(btnOf) do
		b.MouseButton1Click:Connect(function() setTool(name, not st[name]) end)
	end
	bTp.MouseButton1Click:Connect(function()
		local list = scan(kwBox.Text)
		local hrp = getHRP()
		if hrp and list[1] then
			safeTP(list[1].part.CFrame + Vector3.new(0, 4, 0))
			bTp.Text = "Телепорт ✓"
		else
			bTp.Text = "Не найдено"
		end
		task.delay(1.2, function() bTp.Text = "ТП к ближайшему" end)
	end)

	_G.SpeedMenuTools = {
		set = setTool,
		get = function(n) return st[n] and true or false end,
		setKeyword = function(t) kwBox.Text = t end,
		snapshot = function() return {fullbright = st.fullbright, nofog = st.nofog, fps = st.fps, zoom = st.zoom} end,
	}

	-- общий цикл: удержание света, автокликер, обновление подсветки
	local tL, tC, tO = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt)
		dt = dt or 0.016
		tL, tC, tO = tL + dt, tC + dt, tO + dt
		if tL > 1 then tL = 0; if st.fullbright or st.nofog then pcall(applyLight) end end
		if st.autoclick then
			-- очень быстрый режим: до 1000 кликов/сек, несколько кликов за кадр (не больше 25 за кадр, чтобы не вешать игру)
			local cps = math.clamp(tonumber(cpsBox.Text) or 10, 1, 1000)
			local n = math.min(math.floor(tC * cps), 25)
			if n >= 1 then
				tC = math.min(tC - n / cps, 0.05)
				local c = lp.Character
				local tool = c and c:FindFirstChildOfClass("Tool")
				local cf = workspace.CurrentCamera and workspace.CurrentCamera.CFrame or CFrame.new()
				for _ = 1, n do
					if tool then pcall(function() tool:Activate() end) end
					pcall(function() vu:ClickButton1(Vector2.new(), cf) end)
				end
			end
		end
		if st.objesp and tO > 2 then tO = 0; pcall(refreshMarks) end
	end)
end, function(e) __trk.report("инструменты игр", e) end)


-- =====================================================================
-- ===== ПОЗИЦИИ: у каждой игры свои 50 слотов с названиями
-- =====================================================================
xpcall(function() --[[слоты позиций]]
	local FILE = "SpeedMenu_slots.json"
	local N = 50
	local curG = tostring(game.GameId ~= 0 and game.GameId or game.PlaceId)
	local viewG = curG
	local detected = nil -- название текущей игры из Roblox
	local data = {games = {}}

	local function parseSlot(i, v)
		if type(v) == "table" and tonumber(v.x) and tonumber(v.y) and tonumber(v.z) then
			return {name = tostring(v.name or ("Поз. " .. i)), x = v.x, y = v.y, z = v.z, lx = tonumber(v.lx) or 0, lz = tonumber(v.lz) or -1}
		end
	end
	local function parseSlots(src)
		local out = {}
		for k, v in pairs(src) do
			local i = tonumber(k)
			if i and i >= 1 and i <= N then
				local sl = parseSlot(i, v)
				if sl then out[i] = sl end
			end
		end
		return out
	end
	if canSave then
		local ok, d = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
		if ok and type(d) == "table" then
			if type(d.games) == "table" then
				for gid, g in pairs(d.games) do
					if type(g) == "table" and type(g.slots) == "table" then
						data.games[tostring(gid)] = {name = tostring(g.name or ""), slots = parseSlots(g.slots)}
					end
				end
			elseif type(d.slots) == "table" then
				-- старый формат (общие слоты): переносим в текущую игру
				data.games[curG] = {name = "", slots = parseSlots(d.slots)}
			end
		end
	end
	local pq = false
	local function persist()
		if not canSave or pq then return end
		pq = true
		task.delay(0.6, function()
			pq = false
			local out = {games = {}}
			for gid, g in pairs(data.games) do
				local so = {}
				for i, v in pairs(g.slots) do so[tostring(i)] = v end
				if next(so) or g.name ~= "" then out.games[gid] = {name = g.name, slots = so} end
			end
			pcall(function() writefile(FILE, HttpService:JSONEncode(out)) end)
		end)
	end
	local function ensure(id)
		local g = data.games[id]
		if not g then g = {name = "", slots = {}}; data.games[id] = g end
		return g
	end
	local function gameLabel(id)
		local g = data.games[id]
		if g and g.name ~= "" then return g.name end
		if id == curG and detected then return detected end
		return "Игра " .. id
	end
	local function gameIds()
		local ids, seen = {curG}, {[curG] = true}
		for gid, g in pairs(data.games) do
			if not seen[gid] and next(g.slots) then table.insert(ids, gid); seen[gid] = true end
		end
		table.sort(ids, function(x, y)
			if x == curG then return true end
			if y == curG then return false end
			return gameLabel(x) < gameLabel(y)
		end)
		return ids
	end

	-- старая карточка на 3 слота заменяется этой (50 слотов с названиями)
	for _, f in ipairs(scroll:GetChildren()) do
		if f:IsA("Frame") then
			local t0 = f:FindFirstChildOfClass("TextLabel")
			if t0 and string.sub(t0.Text, 1, #"СОХРАНЁННЫЕ ПОЗИЦИИ") == "СОХРАНЁННЫЕ ПОЗИЦИИ" then f:Destroy() end
		end
	end
	local c27 = card("СОХРАНЁННЫЕ ПОЗИЦИИ · 50 СЛОТОВ ДЛЯ КАЖДОЙ ИГРЫ", 484, 15)
	local gRow = new("Frame", {Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 24), BackgroundTransparency = 1, Parent = c27})
	local prevG = new("TextButton", {Size = UDim2.fromOffset(30, 30), Text = "◀", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text, BackgroundColor3 = C.btn, BorderSizePixel = 0, Parent = gRow}, {round(8)})
	local nextG = new("TextButton", {Size = UDim2.fromOffset(30, 30), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Text = "▶", Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text, BackgroundColor3 = C.btn, BorderSizePixel = 0, Parent = gRow}, {round(8)})
	local gName = new("TextBox", {
		Size = UDim2.new(1, -68, 1, 0), Position = UDim2.fromOffset(34, 0), Text = "", PlaceholderText = "Название игры для этих позиций",
		ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text,
		PlaceholderColor3 = Color3.fromRGB(130, 124, 170), BackgroundColor3 = C.field, TextTruncate = Enum.TextTruncate.AtEnd, Parent = gRow,
	}, {round(8), new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)})})
	local counter = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 58), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c27,
	})
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 0, 378), Position = UDim2.fromOffset(12, 98), BackgroundColor3 = C.field, BackgroundTransparency = 0.5,
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = c27,
	}, {
		round(8),
		new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
		new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8)}),
	})
	local rows = {}
	local function viewSlots()
		local g = data.games[viewG]
		return g and g.slots or {}
	end
	local function paintSlot(i)
		local r, s = rows[i], viewSlots()[i]
		r.name.PlaceholderText = s and string.format("%d, %d, %d", s.x, s.y, s.z) or ("Слот " .. i)
		r.name.Text = s and s.name or ""
		local here = viewG == curG
		r.tp.BackgroundColor3 = (s and here) and C.on or C.off
		r.save.BackgroundColor3 = (s and C.btn) or C.accent
	end
	local function refreshAll()
		local n = 0
		for _ in pairs(viewSlots()) do n = n + 1 end
		gName.Text = gameLabel(viewG)
		local here = viewG == curG
		counter.Text = (here and "Это текущая игра. " or "Другая игра: телепорт отключён (координаты только для той игры). ")
			.. "Занято " .. n .. " из " .. N .. ". «Сохр.» запоминает место, «ТП» возвращает, «✕» очищает слот."
			.. (canSave and "" or " Файл не сохраняется: нет writefile.")
		for i = 1, N do paintSlot(i) end
	end
	local function flash(btn, txt)
		local old = btn.Text
		btn.Text = txt
		task.delay(0.9, function() btn.Text = old end)
	end
	local function mkBtn(parent, text, w, x)
		return new("TextButton", {
			Size = UDim2.fromOffset(w, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Text = text,
			Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text, BackgroundColor3 = C.btn, BorderSizePixel = 0, Parent = parent,
		}, {round(7)})
	end
	for i = 1, N do
		if i % 10 == 0 then task.wait() end -- отдаём кадр, чтобы запуск не подвисал
		local f = new("Frame", {Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i, BackgroundTransparency = 1, Parent = list})
		new("TextLabel", {
			Size = UDim2.fromOffset(24, 34), BackgroundTransparency = 1, Text = tostring(i), Font = Enum.Font.GothamBold,
			TextSize = 11, TextColor3 = C.sub, Parent = f,
		})
		local nameB = new("TextBox", {
			Size = UDim2.new(1, -26 - 122, 0, 30), Position = UDim2.new(0, 26, 0.5, -15), Text = "", PlaceholderText = "Слот " .. i,
			ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text,
			PlaceholderColor3 = Color3.fromRGB(130, 124, 170), BackgroundColor3 = C.card, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true, Parent = f,
		}, {round(7), new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 4)})})
		local clr = mkBtn(f, "✕", 26, 0)
		local tp = mkBtn(f, "ТП", 36, -30)
		local save = mkBtn(f, "Сохр.", 48, -70)
		rows[i] = {name = nameB, clr = clr, tp = tp, save = save}

		save.MouseButton1Click:Connect(function()
			if viewG ~= curG then flash(save, "др. игра") return end
			local hrp = getHRP()
			if not hrp then flash(save, "нет перса") return end
			local p, lv = hrp.Position, hrp.CFrame.LookVector
			local nm = (nameB.Text ~= "" and nameB.Text) or ("Поз. " .. i)
			ensure(curG).slots[i] = {name = nm, x = p.X, y = p.Y, z = p.Z, lx = lv.X, lz = lv.Z}
			persist(); refreshAll(); flash(save, "✓")
			pcall(function() _G.SpeedMenuToast("Позиция «" .. nm .. "» сохранена") end)
		end)
		tp.MouseButton1Click:Connect(function()
			if viewG ~= curG then flash(tp, "др. игра") return end
			local s, hrp = viewSlots()[i], getHRP()
			if not s then flash(tp, "пусто") return end
			if not hrp then return end
			local pos = Vector3.new(s.x, s.y, s.z)
			local dir = Vector3.new(s.lx, 0, s.lz)
			if dir.Magnitude < 0.01 then dir = Vector3.new(0, 0, -1) end
			hrp.AssemblyLinearVelocity = Vector3.zero
			safeTP(CFrame.lookAt(pos, pos + dir))
			flash(tp, "✓")
			pcall(function() _G.SpeedMenuToast("Телепорт: " .. s.name) end)
		end)
		clr.MouseButton1Click:Connect(function()
			local g = data.games[viewG]
			if g then g.slots[i] = nil end
			persist(); refreshAll()
		end)
		nameB.FocusLost:Connect(function()
			local s = viewSlots()[i]
			if s then
				s.name = (nameB.Text ~= "" and nameB.Text) or ("Поз. " .. i)
				nameB.Text = s.name
				persist()
			end
		end)
	end

	local function step(d)
		local ids = gameIds()
		local at = 1
		for k, id in ipairs(ids) do if id == viewG then at = k end end
		viewG = ids[((at - 1 + d) % #ids) + 1]
		refreshAll()
	end
	prevG.MouseButton1Click:Connect(function() step(-1) end)
	nextG.MouseButton1Click:Connect(function() step(1) end)
	gName.FocusLost:Connect(function()
		local t = (gName.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		ensure(viewG).name = t
		persist(); refreshAll()
	end)
	refreshAll()

	-- настоящее название текущей игры из Roblox (если не задано своё)
	task.spawn(function()
		local ok, info = pcall(function() return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId) end)
		if ok and info and info.Name then
			detected = tostring(info.Name)
			refreshAll()
		end
	end)
end, function(e) __trk.report("слоты позиций", e) end)

-- =====================================================================
-- ===== СЕРВЕРЫ: переход на людный / тихий / быстрый сервер этой же игры
-- =====================================================================
xpcall(function() --[[серверы]]
	local TPS = game:GetService("TeleportService")
	local c28 = card("СМЕНА СЕРВЕРА (эта игра)", 214, 2)
	local statusL = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 26), BackgroundTransparency = 1,
		Text = "Выбери тип сервера — скрипт найдёт подходящий публичный сервер этой игры и перенесёт тебя.",
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c28,
	})
	local r1 = row(c28, 62, 36)
	local bBusy = cell(r1, 2, "🔥 Людный", C.on)
	local bPing = cell(r1, 2, "⚡ Лучший пинг", C.btn)
	local r2 = row(c28, 104, 36)
	local bQuiet = cell(r2, 2, "🌙 Тихий", C.btn)
	local bRand = cell(r2, 2, "🎲 Случайный", C.btn)
	local r3 = row(c28, 146, 36)
	local bAgain = cell(r3, 1, "↻ Перезайти на этот же сервер", C.btn)
	for _, b in ipairs({bBusy, bPing, bQuiet, bRand, bAgain}) do b.TextSize = 12 end
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 186), BackgroundTransparency = 1,
		Text = "Нужен запускатель с функцией request. Работает для публичных серверов; в играх только с приватными серверами не сработает.",
		Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c28,
	})

	local busy = false
	local function setStatus(t) statusL.Text = t end
	local function fetch(order, pages)
		local req = (syn and syn.request) or http_request or request
		if not req then return nil, "в запускателе нет функции request" end
		local out, cursor = {}, nil
		for _ = 1, pages do
			local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=" .. order .. "&excludeFullGames=true&limit=100"
			if cursor then url = url .. "&cursor=" .. cursor end
			local ok, res = pcall(function() return req({Url = url, Method = "GET"}) end)
			if not ok or not res or not res.Body then return #out > 0 and out or nil, "сервер Roblox не ответил" end
			local okj, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
			if not okj or type(data) ~= "table" or type(data.data) ~= "table" then return #out > 0 and out or nil, "неверный ответ Roblox" end
			for _, sv in ipairs(data.data) do
				if sv.id ~= game.JobId and (sv.playing or 0) < (sv.maxPlayers or 0) then table.insert(out, sv) end
			end
			cursor = data.nextPageCursor
			if not cursor then break end
		end
		return out
	end
	local function hop(mode)
		if busy then return end
		busy = true
		task.delay(10, function() busy = false end)
		setStatus("Ищу сервер…")
		pcall(function() _G.SpeedMenuToast("Ищу сервер…") end)
		task.spawn(function()
			local list, err
			if mode == "busy" then list, err = fetch("Desc", 1)
			elseif mode == "quiet" then list, err = fetch("Asc", 1)
			else list, err = fetch("Desc", 3) end
			if not list or #list == 0 then setStatus("Не нашёл серверов: " .. tostring(err or "список пуст")) busy = false return end
			local pick
			if mode == "busy" then
				for _, sv in ipairs(list) do
					if (sv.playing or 0) < (sv.maxPlayers or 0) - 1 then pick = sv break end
				end
			elseif mode == "quiet" then
				for _, sv in ipairs(list) do
					if (sv.playing or 0) >= 1 then pick = sv break end
				end
			elseif mode == "ping" then
				for _, sv in ipairs(list) do
					if tonumber(sv.ping) and (sv.playing or 0) >= 2 and (not pick or sv.ping < pick.ping) then pick = sv end
				end
			end
			pick = pick or list[math.random(#list)]
			setStatus("Телепортирую: игроков " .. tostring(pick.playing) .. "/" .. tostring(pick.maxPlayers) .. (pick.ping and (", пинг " .. tostring(pick.ping)) or "") .. "…")
			local ok, e2 = pcall(function() TPS:TeleportToPlaceInstance(game.PlaceId, pick.id, lp) end)
			if not ok then setStatus("Не удалось: " .. tostring(e2)) end
			task.delay(6, function() busy = false end)
		end)
	end
	bBusy.MouseButton1Click:Connect(function() hop("busy") end)
	bPing.MouseButton1Click:Connect(function() hop("ping") end)
	bQuiet.MouseButton1Click:Connect(function() hop("quiet") end)
	bRand.MouseButton1Click:Connect(function() hop("random") end)
	bAgain.MouseButton1Click:Connect(function()
		setStatus("Перезахожу…")
		pcall(function()
			if #Players:GetPlayers() <= 1 then TPS:Teleport(game.PlaceId, lp) else TPS:TeleportToPlaceInstance(game.PlaceId, game.JobId, lp) end
		end)
	end)
end, function(e) __trk.report("серверы", e) end)

-- =====================================================================
-- ===== АВТОЗАПУСК: скрипт сам запускается заново (после захода в игру и после смены сервера)
-- =====================================================================
xpcall(function() --[[автозапуск]]
	local FILE = "SpeedMenu_auto.json"
	local AUTO_PATH = "autoexec/SpeedMenu_auto.lua"
	local st = {on = false, loader = ""}
	if canSave then
		local ok, d = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
		if ok and type(d) == "table" then
			if type(d.on) == "boolean" then st.on = d.on end
			if type(d.loader) == "string" then st.loader = d.loader end
		end
	end
	local queueFn = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	local closed = false
	table.insert(_G.SpeedMenuCleanup, function() closed = true end)

	local c29 = card("АВТОЗАПУСК", 292, 3)
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 26), BackgroundTransparency = 1,
		Text = "Вставь строку, которой ты запускаешь этот скрипт (loadstring…, вместе с ключом, если он нужен). Она хранится только у тебя в файле.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c29,
	})
	local box = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 78), Position = UDim2.fromOffset(12, 74), Text = st.loader, PlaceholderText = "loadstring(game:HttpGet(\"…\"))()",
		ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, Font = Enum.Font.Code, TextSize = 10, TextColor3 = C.text,
		PlaceholderColor3 = Color3.fromRGB(130, 124, 170), BackgroundColor3 = C.field, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, ClipsDescendants = true, Parent = c29,
	}, {round(8), new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)})})
	local tog = new("TextButton", {
		Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, 160), Text = "", Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = C.text, BackgroundColor3 = C.off, BorderSizePixel = 0, Parent = c29,
	}, {round(8)})
	local info = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 84), Position = UDim2.fromOffset(12, 200), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c29,
	})

	local function writeAuto()
		if not (type(writefile) == "function") then return false end
		pcall(function() if type(makefolder) == "function" and type(isfolder) == "function" and not isfolder("autoexec") then makefolder("autoexec") end end)
		return (pcall(function() writefile(AUTO_PATH, st.loader) end))
	end
	local function removeAuto()
		pcall(function()
			if type(isfile) == "function" and type(delfile) == "function" and isfile(AUTO_PATH) then delfile(AUTO_PATH) end
		end)
	end
	local function persist()
		if not canSave then return end
		pcall(function() writefile(FILE, HttpService:JSONEncode({on = st.on, loader = st.loader})) end)
	end
	local function refresh()
		tog.Text = st.on and "Автозапуск: ВКЛ" or "Автозапуск: ВЫКЛ"
		tog.BackgroundColor3 = st.on and C.on or C.off
		local lines = {}
		table.insert(lines, (type(writefile) == "function") and "• файл автозапуска (autoexec): доступен" or "• файл автозапуска (autoexec): нет writefile")
		table.insert(lines, queueFn and "• запуск после смены сервера: доступен" or "• запуск после смены сервера: нет queue_on_teleport")
		table.insert(lines, st.loader == "" and "• строка запуска пока не вставлена" or "• строка запуска сохранена")
		info.Text = table.concat(lines, "\n") .. "\nПосле включения скрипт запускается сам при входе в любую игру (если запускатель читает папку autoexec) и после смены сервера."
	end
	box.FocusLost:Connect(function()
		st.loader = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if st.on then
			if st.loader == "" then st.on = false; removeAuto() else writeAuto() end
		end
		persist(); refresh()
	end)
	tog.MouseButton1Click:Connect(function()
		st.loader = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if st.loader == "" and not st.on then
			info.Text = "Сначала вставь строку запуска в поле выше."
			return
		end
		st.on = not st.on
		if st.on then writeAuto() else removeAuto() end
		persist(); refresh()
	end)
	-- после телепорта (смена сервера, переход в другую игру) запускаем скрипт снова
	pcall(function()
		lp.OnTeleport:Connect(function(state)
			if closed or not st.on or st.loader == "" or not queueFn then return end
			if state == Enum.TeleportState.Started or state == Enum.TeleportState.InProgress then
				pcall(queueFn, st.loader)
			end
		end)
	end)
	refresh()
end, function(e) __trk.report("автозапуск", e) end)

-- =====================================================================
-- ===== АВТОКЛИКЕР-ВИДЖЕТ: панель ▶ ⚙ ✥ и кольцо-мишень на экране (как в приложениях-автокликерах)
-- =====================================================================
xpcall(function() --[[автокликер виджет]]
	local vu = game:GetService("VirtualUser")
	local okV, VIM = pcall(function() return game:GetService("VirtualInputManager") end)
	if not okV then VIM = nil end

	-- ----- карточка в меню -----
	local c30 = card("АВТОКЛИКЕР (виджет на экране)", 168, 3)
	local showB = new("TextButton", {
		Size = UDim2.new(1, -24, 0, 36), Position = UDim2.fromOffset(12, 28), Text = "Показать виджет автокликера",
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text, BackgroundColor3 = C.off, BorderSizePixel = 0, Parent = c30,
	}, {round(8)})
	local centerB = new("TextButton", {
		Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 70), Text = "Кольцо в центр экрана",
		Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text, BackgroundColor3 = C.btn, BorderSizePixel = 0, Parent = c30,
	}, {round(8)})
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 56), Position = UDim2.fromOffset(12, 106), BackgroundTransparency = 1,
		Text = "▶ — запуск и пауза, ⚙ — скорость и автостоп, ✥ — перетащить панель. Перетащи синее кольцо туда, куда нужно кликать (кнопка игры, монетка, моб), и нажми ▶.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c30,
	})

	-- ----- экранный виджет -----
	local cg = new("ScreenGui", {Name = "SpeedMenuClicker", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, Enabled = false, Parent = parent})
	local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(800, 400)

	-- кольцо-мишень
	local ring = new("TextButton", {
		Name = "Ring", Size = UDim2.fromOffset(74, 74), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(vp.X * 0.5, vp.Y * 0.5),
		Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(225, 240, 255), BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = cg,
	}, {
		new("UICorner", {CornerRadius = UDim.new(1, 0)}),
		new("UIStroke", {Color = Color3.fromRGB(0, 110, 220), Thickness = 6}),
	})
	local dot = new("Frame", {
		Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 110, 220), BorderSizePixel = 0, Active = false, Parent = ring,
	}, {new("UICorner", {CornerRadius = UDim.new(1, 0)})})

	-- панель управления
	local panel = new("Frame", {
		Name = "Panel", Size = UDim2.fromOffset(56, 176), Position = UDim2.fromOffset(vp.X * 0.5 - 150, vp.Y * 0.5 - 90),
		BackgroundColor3 = Color3.fromRGB(42, 42, 46), BorderSizePixel = 0, Parent = cg,
	}, {new("UICorner", {CornerRadius = UDim.new(0, 12)}), new("UIStroke", {Color = Color3.fromRGB(70, 70, 78), Thickness = 1})})
	local function pbtn(y, txt, col)
		return new("TextButton", {
			Size = UDim2.fromOffset(48, 52), Position = UDim2.fromOffset(4, y), Text = txt, Font = Enum.Font.GothamBlack, TextSize = 30,
			TextColor3 = col, BackgroundTransparency = 1, AutoButtonColor = false, Parent = panel,
		})
	end
	local playB = pbtn(4, "▶", Color3.fromRGB(40, 120, 255))
	local gearB = pbtn(62, "⚙", Color3.fromRGB(110, 150, 185))
	local moveB = pbtn(120, "✥", Color3.fromRGB(110, 110, 118))

	-- окно настроек
	local pop = new("Frame", {
		Size = UDim2.fromOffset(214, 232), Visible = false, BackgroundColor3 = Color3.fromRGB(42, 42, 46), BorderSizePixel = 0, Parent = cg,
	}, {new("UICorner", {CornerRadius = UDim.new(0, 12)}), new("UIStroke", {Color = Color3.fromRGB(70, 70, 78), Thickness = 1})})
	local function plabel(y, t)
		return new("TextLabel", {
			Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(10, y), BackgroundTransparency = 1, Text = t,
			Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = Color3.fromRGB(200, 205, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = pop,
		})
	end
	local function pbox(y, v)
		return new("TextBox", {
			Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, y), Text = v, ClearTextOnFocus = false,
			Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(62, 62, 68), Parent = pop,
		}, {new("UICorner", {CornerRadius = UDim.new(0, 8)})})
	end
	plabel(8, "Скорость, кликов в секунду (1–1000)")
	local cpsB = pbox(26, "20")
	plabel(60, "Автостоп через, сек (0 — без лимита)")
	local stopB = pbox(78, "0")
	plabel(112, "Режим клика")
	local modeB = new("TextButton", {
		Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 130), Text = "Касание (не мешает ходьбе)", Font = Enum.Font.GothamBold,
		TextSize = 12, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(62, 62, 68), Parent = pop,
	}, {new("UICorner", {CornerRadius = UDim.new(0, 8)})})
	local closeB = new("TextButton", {
		Size = UDim2.new(1, -20, 0, 28), Position = UDim2.fromOffset(10, 166), Text = "Готово", Font = Enum.Font.GothamBold, TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(40, 120, 255), Parent = pop,
	}, {new("UICorner", {CornerRadius = UDim.new(0, 8)})})

	-- перетаскивание
	local function draggable(handle, obj, onMove)
		local drag, st, sp = false, nil, nil
		handle.InputBegan:Connect(function(i)
			if isPress(i) then drag, st, sp = true, i.Position, obj.Position end
		end)
		UIS.InputChanged:Connect(function(i)
			if drag and isMove(i) then
				local d = i.Position - st
				obj.Position = UDim2.fromOffset(sp.X.Offset + d.X, sp.Y.Offset + d.Y)
				if onMove then onMove() end
			end
		end)
		UIS.InputEnded:Connect(function(i) if drag and isPress(i) then drag = false end end)
	end
	draggable(moveB, panel, function() pop.Visible = false end)
	draggable(ring, ring)

	-- работа
	local running, runStart, acc = false, 0, 0
	local function setRunning(v)
		running = v
		runStart = os.clock()
		acc = 0
		playB.Text = v and "⏸" or "▶"
		playB.TextColor3 = v and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(40, 120, 255)
		ring.Interactable = not v -- пока кликаем, кольцо не перехватывает клики
		ring.BackgroundTransparency = v and 0.7 or 0.35
		pcall(function() _G.SpeedMenuToast(v and "Автокликер запущен" or "Автокликер остановлен") end)
	end
	playB.MouseButton1Click:Connect(function() setRunning(not running) end)
	gearB.MouseButton1Click:Connect(function()
		pop.Visible = not pop.Visible
		if pop.Visible then
			local v = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(800, 400)
			local x = panel.AbsolutePosition.X + panel.AbsoluteSize.X + 8
			if x + 214 > v.X then x = panel.AbsolutePosition.X - 222 end
			pop.Position = UDim2.fromOffset(math.max(x, 4), math.clamp(panel.AbsolutePosition.Y, 4, math.max(v.Y - 238, 4)))
		end
	end)
	closeB.MouseButton1Click:Connect(function() pop.Visible = false end)

	-- «Умный» режим: жмёт кнопку интерфейса под кольцом, иначе бьёт предметом в руке. Не создаёт настоящее нажатие
	-- на экран, поэтому джойстик и ходьба продолжают работать.
	-- режимы: 1 = касание (имитация пальца, ходьба не блокируется), 2 = умный (нажатие кнопок интерфейса), 3 = мышь
	local mode = 1
	local MODE_TXT = {"Касание (не мешает ходьбе)", "Умный (кнопки и предмет)", "Мышь (может мешать ходьбе)"}
	local statusP = new("TextLabel", {
		Size = UDim2.new(1, -20, 0, 26), Position = UDim2.fromOffset(10, 198), BackgroundTransparency = 1,
		Text = "", Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = Color3.fromRGB(150, 155, 165), TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = pop,
	})
	local function setStatus(t) statusP.Text = t end
	setStatus("VirtualInputManager: " .. (VIM and "есть" or "нет") .. " · firesignal: " .. ((firesignal or getconnections) and "есть" or "нет"))
	modeB.MouseButton1Click:Connect(function()
		mode = mode % 3 + 1
		modeB.Text = MODE_TXT[mode]
	end)
	local touchOk, touchFails = 0, 0
	local function touchClick(x, y)
		if not VIM then return false end
		local ok = pcall(function()
			VIM:SendTouchEvent(97, 0, x, y)
			VIM:SendTouchEvent(97, 2, x, y)
		end)
		if ok then touchOk = touchOk + 1 else touchFails = touchFails + 1 end
		return ok
	end
	local GS = game:GetService("GuiService")
	local function fireBtn(o)
		local fired = false
		local fs = firesignal
		for _, n in ipairs({"MouseButton1Down", "MouseButton1Click", "Activated", "MouseButton1Up"}) do
			local sig = o[n]
			if fs then
				if pcall(fs, sig) then fired = true end
			elseif getconnections then
				local okc, conns = pcall(getconnections, sig)
				if okc and type(conns) == "table" then
					for _, c in ipairs(conns) do
						if pcall(function() c:Fire() end) then fired = true end
					end
				end
			end
		end
		return fired
	end
	local cacheT, cacheBtn = 0, nil
	local function findBtn(x, y)
		local pg = lp:FindFirstChildOfClass("PlayerGui")
		if not pg then return nil end
		local inset = 0
		pcall(function() inset = GS:GetGuiInset().Y end)
		for _, yy in ipairs({y, y - inset}) do
			local ok, objs = pcall(function() return pg:GetGuiObjectsAtPosition(x, yy) end)
			if ok and objs then
				for _, o in ipairs(objs) do
					if not o:IsDescendantOf(cg) and not o:IsDescendantOf(gui) and string.sub(o:FindFirstAncestorWhichIsA("ScreenGui") and o:FindFirstAncestorWhichIsA("ScreenGui").Name or "", 1, 9) ~= "SpeedMenu" then
						local b = o:IsA("GuiButton") and o or o:FindFirstAncestorWhichIsA("GuiButton")
						if b then return b end
					end
				end
			end
		end
		return nil
	end
	local function smartClick(x, y)
		local now = os.clock()
		if now - cacheT > 0.25 then cacheT = now; cacheBtn = findBtn(x, y) end
		if cacheBtn and cacheBtn.Parent and fireBtn(cacheBtn) then return end
		local c = lp.Character
		local tool = c and c:FindFirstChildOfClass("Tool")
		if tool then pcall(function() tool:Activate() end) end
		pcall(function() vu:ClickButton1(Vector2.new(x, y), workspace.CurrentCamera.CFrame) end)
	end

	local function clickAt(x, y)
		if mode == 1 then
			if touchClick(x, y) then return end
			setStatus("касание недоступно в запускателе — пробую «Умный»")
			smartClick(x, y)
			return
		elseif mode == 2 then
			smartClick(x, y)
			return
		end
		local ok = false
		if VIM then
			ok = pcall(function()
				VIM:SendMouseButtonEvent(x, y, 0, true, game, 1)
				VIM:SendMouseButtonEvent(x, y, 0, false, game, 1)
			end)
		end
		if not ok then
			pcall(function() vu:ClickButton1(Vector2.new(x, y), workspace.CurrentCamera.CFrame) end)
		end
	end
	RunService.Heartbeat:Connect(function(dt)
		if not running then return end
		dt = dt or 0.016
		acc = acc + dt
		local cps = math.clamp(tonumber(cpsB.Text) or 20, 1, 1000)
		local lim = tonumber(stopB.Text) or 0
		if lim > 0 and os.clock() - runStart >= lim then setRunning(false) return end
		local n = math.min(math.floor(acc * cps), 10) -- не больше 10 кликов за кадр
		if n >= 1 then
			acc = math.min(acc - n / cps, 0.05)
			local p = ring.AbsolutePosition + ring.AbsoluteSize / 2
			for _ = 1, n do clickAt(p.X, p.Y) end
		end
	end)

	-- кнопки карточки
	local shown = false
	local function setShown(v)
		shown = v
		cg.Enabled = v
		if not v then setRunning(false); pop.Visible = false end
		showB.Text = v and "Скрыть виджет автокликера" or "Показать виджет автокликера"
		showB.BackgroundColor3 = v and C.on or C.off
	end
	showB.MouseButton1Click:Connect(function() setShown(not shown) end)
	centerB.MouseButton1Click:Connect(function()
		local v = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(800, 400)
		ring.Position = UDim2.fromOffset(v.X / 2, v.Y / 2)
		if not shown then setShown(true) end
	end)
	table.insert(_G.SpeedMenuCleanup, function() running = false end)
end, function(e) __trk.report("автокликер-виджет", e) end)

-- =====================================================================
-- ===== КОНФИГИ НАСТРОЕК: 50 именных слотов (скорость, прыжок, FOV, ESP, аим, свет и т.д.)
-- =====================================================================
xpcall(function() --[[конфиги]]
	local FILE = "SpeedMenu_cfgs.json"
	local N = 50
	local cfgs = {}
	if canSave then
		local ok, d = pcall(function() return HttpService:JSONDecode(readfile(FILE)) end)
		if ok and type(d) == "table" and type(d.slots) == "table" then
			for k, v in pairs(d.slots) do
				local i = tonumber(k)
				if i and i >= 1 and i <= N and type(v) == "table" and type(v.data) == "table" then
					cfgs[i] = {name = tostring(v.name or ("Конфиг " .. i)), data = v.data}
				end
			end
		end
	end
	local pq = false
	local function persist()
		if not canSave or pq then return end
		pq = true
		task.delay(0.6, function()
			pq = false
			local out = {}
			for i, v in pairs(cfgs) do out[tostring(i)] = v end
			pcall(function() writefile(FILE, HttpService:JSONEncode({slots = out})) end)
		end)
	end

	local c31 = card("КОНФИГИ НАСТРОЕК · 50 СЛОТОВ", 440, 97)
	local counter = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 24), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c31,
	})
	local list = new("ScrollingFrame", {
		Size = UDim2.new(1, -24, 0, 378), Position = UDim2.fromOffset(12, 56), BackgroundColor3 = C.field, BackgroundTransparency = 0.5,
		BorderSizePixel = 0, ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = c31,
	}, {
		round(8),
		new("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
		new("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 8)}),
	})
	local rows = {}
	local function refresh()
		local n = 0
		for i = 1, N do
			local r, c = rows[i], cfgs[i]
			if c then n = n + 1 end
			r.name.Text = c and c.name or ""
			r.load.BackgroundColor3 = c and C.on or C.off
			r.save.BackgroundColor3 = c and C.btn or C.accent
		end
		counter.Text = "Занято " .. n .. " из " .. N .. ". «Сохр.» запоминает все текущие настройки меню под названием, «Загр.» применяет их, «✕» очищает слот." .. (canSave and "" or " Файл не сохраняется: нет writefile.")
	end
	local function flash(btn, txt)
		local old = btn.Text
		btn.Text = txt
		task.delay(0.9, function() btn.Text = old end)
	end
	local function mkBtn(parent, text, w, x)
		return new("TextButton", {
			Size = UDim2.fromOffset(w, 30), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, x, 0.5, 0), Text = text,
			Font = Enum.Font.GothamBold, TextSize = 11, TextColor3 = C.text, BackgroundColor3 = C.btn, BorderSizePixel = 0, Parent = parent,
		}, {round(7)})
	end
	for i = 1, N do
		if i % 10 == 0 then task.wait() end -- отдаём кадр, чтобы запуск не подвисал
		local f = new("Frame", {Size = UDim2.new(1, 0, 0, 34), LayoutOrder = i, BackgroundTransparency = 1, Parent = list})
		new("TextLabel", {
			Size = UDim2.fromOffset(24, 34), BackgroundTransparency = 1, Text = tostring(i), Font = Enum.Font.GothamBold,
			TextSize = 11, TextColor3 = C.sub, Parent = f,
		})
		local nameB = new("TextBox", {
			Size = UDim2.new(1, -26 - 132, 0, 30), Position = UDim2.new(0, 26, 0.5, -15), Text = "", PlaceholderText = "Конфиг " .. i,
			ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = C.text,
			PlaceholderColor3 = Color3.fromRGB(130, 124, 170), BackgroundColor3 = C.card, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true, Parent = f,
		}, {round(7), new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 4)})})
		local clr = mkBtn(f, "✕", 26, 0)
		local ld = mkBtn(f, "Загр.", 46, -30)
		local sv = mkBtn(f, "Сохр.", 48, -80)
		rows[i] = {name = nameB, load = ld, save = sv}
		sv.MouseButton1Click:Connect(function()
			local P = _G.SpeedMenuProfile
			if not (P and P.snapshot) then flash(sv, "нет данных") return end
			local ok, snap = pcall(P.snapshot)
			if not ok or type(snap) ~= "table" then flash(sv, "ошибка") return end
			cfgs[i] = {name = (nameB.Text ~= "" and nameB.Text) or ("Конфиг " .. i), data = snap}
			persist(); refresh(); flash(sv, "✓")
		end)
		ld.MouseButton1Click:Connect(function()
			local c, P = cfgs[i], _G.SpeedMenuProfile
			if not c then flash(ld, "пусто") return end
			if not (P and P.apply) then return end
			pcall(P.apply, c.data)
			flash(ld, "✓")
			pcall(function() _G.SpeedMenuToast("Конфиг «" .. c.name .. "» загружен") end)
		end)
		clr.MouseButton1Click:Connect(function()
			cfgs[i] = nil
			persist(); refresh()
		end)
		nameB.FocusLost:Connect(function()
			local c = cfgs[i]
			if c then
				c.name = (nameB.Text ~= "" and nameB.Text) or ("Конфиг " .. i)
				nameB.Text = c.name
				persist()
			end
		end)
	end
	refresh()
end, function(e) __trk.report("конфиги", e) end)

-- =====================================================================
-- ===== РАЗМЕР ПЕРСОНАЖА: уменьшить / увеличить себя (виден только тебе)
-- =====================================================================
xpcall(function() --[[размер]]
	local c32 = card("РАЗМЕР ПЕРСОНАЖА", 170, 17)
	label(c32, "Размер, %", 30)
	local sizeBox = numBox(c32, 30, 100)
	local rP = row(c32, 68, 32)
	local presets = {}
	for _, v in ipairs({25, 50, 100, 200}) do
		local b = cell(rP, 4, v .. "%")
		table.insert(presets, {b, v})
	end
	local onB = cell(row(c32, 106, 32), 1, "Размер: ВЫКЛ", C.off)
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(12, 142), BackgroundTransparency = 1,
		Text = "Меняет размер только на твоём экране: другие игроки видят тебя обычным.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c32,
	})

	local pct, on = 100, false
	local function apply()
		local c = lp.Character
		if not c then return end
		local k = on and (pct / 100) or 1
		pcall(function() c:ScaleTo(k) end)
	end
	local function setPct(v)
		pct = math.clamp(math.floor((tonumber(v) or pct) + 0.5), 10, 500)
		sizeBox.Text = tostring(pct)
		if on then apply() end
	end
	local function setOn(v)
		on = v
		onB.Text = v and "Размер: ВКЛ" or "Размер: ВЫКЛ"
		paint(onB, v)
		apply()
	end
	sizeBox.FocusLost:Connect(function() setPct(sizeBox.Text) end)
	for _, p in ipairs(presets) do
		p[1].MouseButton1Click:Connect(function()
			setPct(p[2])
			if not on then setOn(true) end
		end)
	end
	onB.MouseButton1Click:Connect(function() setOn(not on) end)
	-- после возрождения применяем размер заново
	lp.CharacterAdded:Connect(function()
		task.wait(1)
		if on then apply() end
	end)
	table.insert(_G.SpeedMenuCleanup, function() on = false; apply() end)
end, function(e) __trk.report("размер", e) end)

-- =====================================================================
-- ===== ИНФО-ПАНЕЛЬ: FPS, пинг, игроки, координаты и скорость поверх экрана
-- =====================================================================
xpcall(function() --[[инфо-панель]]
	local Stats = game:GetService("Stats")
	local c33 = card("ИНФО-ПАНЕЛЬ (FPS, пинг, координаты)", 120, 95)
	local rB = row(c33, 28, 36)
	local showB = cell(rB, 2, "Панель: ВЫКЛ", C.off)
	local coordB = cell(rB, 2, "Координаты: ВКЛ", C.on)
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 40), Position = UDim2.fromOffset(12, 70), BackgroundTransparency = 1,
		Text = "Маленькая панель поверх экрана: FPS, пинг, игроков на сервере, твои координаты и скорость. Её можно перетащить пальцем.",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = c33,
	})

	local hg = new("ScreenGui", {Name = "SpeedMenuHud", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 40, Enabled = false, Parent = parent})
	local hud = new("Frame", {
		Size = UDim2.fromOffset(176, 78), Position = UDim2.fromOffset(12, 80), BackgroundColor3 = Color3.fromRGB(18, 16, 28),
		BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = hg,
	}, {
		new("UICorner", {CornerRadius = UDim.new(0, 10)}),
		new("UIStroke", {Color = Color3.fromRGB(139, 92, 246), Thickness = 1.5, Transparency = 0.2}),
	})
	local txt = new("TextLabel", {
		Size = UDim2.new(1, -16, 1, -12), Position = UDim2.fromOffset(8, 6), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.Code, TextSize = 12, TextColor3 = Color3.fromRGB(235, 232, 255), TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, Parent = hud,
	})
	-- перетаскивание панели
	local drag, st0, p0 = false, nil, nil
	hud.InputBegan:Connect(function(i)
		if isPress(i) then drag, st0, p0 = true, i.Position, hud.Position end
	end)
	UIS.InputChanged:Connect(function(i)
		if drag and isMove(i) then
			local d = i.Position - st0
			hud.Position = UDim2.fromOffset(p0.X.Offset + d.X, p0.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i) if drag and isPress(i) then drag = false end end)

	local shown, coords = false, true
	local function setShown(v)
		shown = v
		hg.Enabled = v
		showB.Text = v and "Панель: ВКЛ" or "Панель: ВЫКЛ"
		paint(showB, v)
	end
	showB.MouseButton1Click:Connect(function() setShown(not shown) end)
	coordB.MouseButton1Click:Connect(function()
		coords = not coords
		coordB.Text = coords and "Координаты: ВКЛ" or "Координаты: ВЫКЛ"
		paint(coordB, coords)
		hud.Size = UDim2.fromOffset(176, coords and 78 or 44)
	end)

	local acc, frames, fps = 0, 0, 60
	RunService.Heartbeat:Connect(function(dt)
		if not shown then return end
		acc = acc + (dt or 0.016)
		frames = frames + 1
		if acc < 0.5 then return end
		fps = math.floor(frames / acc + 0.5)
		acc, frames = 0, 0
		local ping = 0
		pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
		local lines = {
			"FPS    " .. fps,
			"Пинг   " .. ping .. " мс",
			"Игроки " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers,
		}
		if coords then
			local hrp = getHRP()
			if hrp then
				local p, v = hrp.Position, hrp.AssemblyLinearVelocity
				table.insert(lines, string.format("XYZ %d %d %d", p.X, p.Y, p.Z))
				table.insert(lines, string.format("Скор. %d", math.sqrt(v.X * v.X + v.Z * v.Z)))
			end
		end
		txt.Text = table.concat(lines, "\n")
	end)
end, function(e) __trk.report("инфо-панель", e) end)

-- =====================================================================
-- ===== УВЕДОМЛЕНИЯ: короткие всплывающие подсказки при включении функций
-- =====================================================================
xpcall(function() --[[уведомления]]
	local TweenService = game:GetService("TweenService")
	local tg = new("ScreenGui", {Name = "SpeedMenuToast", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60, Parent = parent})
	local pill = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -60), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34),
		BackgroundColor3 = Color3.fromRGB(26, 22, 42), BackgroundTransparency = 0.1, BorderSizePixel = 0, Visible = false, Parent = tg,
	}, {
		new("UICorner", {CornerRadius = UDim.new(0, 12)}),
		new("UIStroke", {Color = Color3.fromRGB(167, 139, 250), Thickness = 1.5}),
		new("UIPadding", {PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16)}),
	})
	local lbl = new("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.fromRGB(240, 238, 255), Parent = pill,
	})
	local token = 0
	local function tw(o, p, t)
		pcall(function() TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p):Play() end)
	end
	_G.SpeedMenuToast = function(text)
		token = token + 1
		local my = token
		lbl.Text = tostring(text)
		pill.Visible = true
		tw(pill, {Position = UDim2.new(0.5, 0, 0, 14)}, 0.2)
		task.delay(2, function()
			if my == token then
				tw(pill, {Position = UDim2.new(0.5, 0, 0, -60)}, 0.25)
			end
		end)
	end
	table.insert(_G.SpeedMenuCleanup, function() _G.SpeedMenuToast = nil end)
end, function(e) __trk.report("уведомления", e) end)

-- =====================================================================
-- ===== ЖУРНАЛ ОШИБОК: что сломалось при запуске (можно скопировать и прислать разработчику)
-- =====================================================================
xpcall(function() --[[журнал]]
	local c34 = card("ЖУРНАЛ ОШИБОК", 238, 100)
	local rB = row(c34, 28, 32)
	local refB = cell(rB, 2, "Обновить", C.btn)
	local copyB = cell(rB, 2, "Копировать", C.btn)
	local box = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 166), Position = UDim2.fromOffset(12, 66), Text = "", ClearTextOnFocus = false, MultiLine = true,
		TextWrapped = true, Font = Enum.Font.Code, TextSize = 10, TextColor3 = C.text, BackgroundColor3 = C.field,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ClipsDescendants = true, Parent = c34,
	}, {round(8), new("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 6)})})
	local function build()
		local ex = "?"
		pcall(function() ex = tostring((identifyexecutor and identifyexecutor()) or "?") end)
		local name = "?"
		pcall(function() name = tostring(game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name) end)
		local lines = {
			"Запускатель: " .. ex,
			"Игра: " .. name .. " (PlaceId " .. tostring(game.PlaceId) .. ")",
			"writefile: " .. (type(writefile) == "function" and "да" or "нет") .. ", request: " .. (((syn and syn.request) or http_request or request) and "да" or "нет")
				.. ", firesignal: " .. ((firesignal or getconnections) and "да" or "нет"),
			"",
		}
		if #__trk.errlog == 0 then
			table.insert(lines, "Ошибок при запуске нет ✓")
		else
			for _, m in ipairs(__trk.errlog) do table.insert(lines, m) end
		end
		return table.concat(lines, "\n")
	end
	box.Text = build()
	refB.MouseButton1Click:Connect(function() box.Text = build() end)
	copyB.MouseButton1Click:Connect(function()
		local ok = false
		local fn = setclipboard or toclipboard
		if fn then ok = pcall(fn, box.Text) end
		copyB.Text = ok and "Скопировано ✓" or "Нет буфера"
		task.delay(1.2, function() copyB.Text = "Копировать" end)
	end)
end, function(e) warn("[SpeedMenu] ошибка в блоке «журнал»: " .. tostring(e)) end)


-- ===== ВЕСЕЛЬЕ: локальные эффекты (видишь только ты) =====
xpcall(function() --[[веселье]]
	local Lighting = game:GetService("Lighting")
	local cf = card("ВЕСЕЛЬЕ — эффекты только для тебя", 150, 60)
	local r1 = row(cf, 30, 34)
	local r2 = row(cf, 70, 34)
	local r3 = row(cf, 110, 34)
	local bRain = cell(r1, 2, "🌈 Радуга", C.btn)
	local bDisco = cell(r1, 2, "🪩 Дискотека", C.btn)
	local bMoon = cell(r2, 2, "🌙 Гравитация Луны", C.btn)
	local bTime = cell(r2, 2, "🕒 Время суток", C.btn)
	local bFish = cell(r3, 2, "🐟 Рыбий глаз", C.btn)
	local bOff = cell(r3, 2, "↺ Всё выключить", C.danger)

	local st = {rain = false, disco = false, moon = false, fish = false}
	local orig = {
		amb = Lighting.Ambient, out = Lighting.OutdoorAmbient, clock = Lighting.ClockTime, grav = workspace.Gravity,
		fov = workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView or 70,
	}
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SpeedMenuFun"; cc.Enabled = false; cc.Parent = Lighting
	local t = 0
	local function paintB(b, on) b.BackgroundColor3 = on and C.on or C.btn end
	local function restore()
		for k in pairs(st) do st[k] = false end
		cc.Enabled = false; cc.TintColor = Color3.new(1, 1, 1)
		pcall(function() Lighting.Ambient = orig.amb; Lighting.OutdoorAmbient = orig.out end)
		pcall(function() workspace.Gravity = orig.grav end)
		pcall(function() local cam = workspace.CurrentCamera; if cam then cam.FieldOfView = orig.fov end end)
		paintB(bRain, false); paintB(bDisco, false); paintB(bMoon, false); paintB(bFish, false)
	end
	bRain.MouseButton1Click:Connect(function() st.rain = not st.rain; paintB(bRain, st.rain); if not st.rain and not st.disco then cc.Enabled = false; cc.TintColor = Color3.new(1, 1, 1) end end)
	bDisco.MouseButton1Click:Connect(function()
		st.disco = not st.disco; paintB(bDisco, st.disco)
		if not st.disco then pcall(function() Lighting.Ambient = orig.amb; Lighting.OutdoorAmbient = orig.out end) end
	end)
	bMoon.MouseButton1Click:Connect(function()
		st.moon = not st.moon; paintB(bMoon, st.moon)
		workspace.Gravity = st.moon and orig.grav / 6 or orig.grav
	end)
	bFish.MouseButton1Click:Connect(function()
		st.fish = not st.fish; paintB(bFish, st.fish)
		local cam = workspace.CurrentCamera
		if cam then cam.FieldOfView = st.fish and 120 or orig.fov end
	end)
	local hours = {6, 12, 18, 0}
	local hi = 0
	bTime.MouseButton1Click:Connect(function()
		hi = hi % #hours + 1
		Lighting.ClockTime = hours[hi]
		bTime.Text = "🕒 " .. ({"Утро", "День", "Вечер", "Ночь"})[hi]
	end)
	bOff.MouseButton1Click:Connect(function()
		restore()
		pcall(function() Lighting.ClockTime = orig.clock end)
		bTime.Text = "🕒 Время суток"; hi = 0
	end)
	RunService.Heartbeat:Connect(function(dt)
		if not (st.rain or st.disco) then return end
		t = t + dt
		if st.rain then
			cc.Enabled = true
			cc.TintColor = Color3.fromHSV((t * 0.2) % 1, 0.35, 1)
		end
		if st.disco then
			local c = Color3.fromHSV((t * 0.9) % 1, 0.8, 0.9)
			Lighting.Ambient = c; Lighting.OutdoorAmbient = c
		end
	end)
	table.insert(_G.SpeedMenuCleanup, function() restore(); pcall(function() Lighting.ClockTime = orig.clock end); pcall(function() cc:Destroy() end) end)
end, function(e) __trk.report("веселье", e) end)


-- ===== ВЕСЕЛЬЕ 2: тело, камера, эмоции (локальные, безобидные) =====
xpcall(function() --[[веселье2]]
	local Lighting = game:GetService("Lighting")
	local StarterGui = game:GetService("StarterGui")

	-- ---- ТЕЛО ----
	local cb = card("ВЕСЕЛЬЕ — ТЕЛО", 150, 61)
	local b1 = row(cb, 30, 34)
	local b2 = row(cb, 70, 34)
	local b3 = row(cb, 110, 34)
	local bSpin = cell(b1, 2, "🌀 Вращение", C.btn)
	local bGlow = cell(b1, 2, "💡 Светящийся ореол", C.btn)
	local bTrail = cell(b2, 2, "✨ Шлейф", C.btn)
	local bBig = cell(b2, 2, "🔭 Свободный зум", C.btn)
	local bDance = cell(b3, 3, "💃 Танец", C.btn)
	local bWave = cell(b3, 3, "👋 Привет", C.btn)
	local bLaugh = cell(b3, 3, "😂 Смех", C.btn)
	local st = {spin = false, glow = false, trail = false, zoom = false}
	local light, trail, att0, att1
	local origZoom = lp.CameraMaxZoomDistance
	local function mark(b, on) b.BackgroundColor3 = on and C.on or C.btn end
	local function clearBody()
		pcall(function() if light then light:Destroy() end end)
		pcall(function() if trail then trail:Destroy() end end)
		pcall(function() if att0 then att0:Destroy() end end)
		pcall(function() if att1 then att1:Destroy() end end)
		light, trail, att0, att1 = nil, nil, nil, nil
	end
	local function setGlow(on)
		local hrp = getHRP()
		if light then pcall(function() light:Destroy() end) light = nil end
		if on and hrp then
			light = Instance.new("PointLight")
			light.Brightness = 3; light.Range = 24; light.Color = Color3.fromRGB(170, 120, 255); light.Parent = hrp
		end
	end
	local function setTrail(on)
		local hrp = getHRP()
		pcall(function() if trail then trail:Destroy() end end)
		pcall(function() if att0 then att0:Destroy() end end)
		pcall(function() if att1 then att1:Destroy() end end)
		trail, att0, att1 = nil, nil, nil
		if on and hrp then
			att0 = Instance.new("Attachment"); att0.Position = Vector3.new(0, 1, 0); att0.Parent = hrp
			att1 = Instance.new("Attachment"); att1.Position = Vector3.new(0, -1, 0); att1.Parent = hrp
			trail = Instance.new("Trail")
			trail.Attachment0 = att0; trail.Attachment1 = att1; trail.Lifetime = 0.8
			trail.LightEmission = 1
			trail.Color = ColorSequence.new(Color3.fromRGB(139, 92, 246), Color3.fromRGB(217, 70, 239))
			trail.Transparency = NumberSequence.new(0, 1)
			trail.Parent = hrp
		end
	end
	bSpin.MouseButton1Click:Connect(function() st.spin = not st.spin; mark(bSpin, st.spin) end)
	bGlow.MouseButton1Click:Connect(function() st.glow = not st.glow; mark(bGlow, st.glow); setGlow(st.glow) end)
	bTrail.MouseButton1Click:Connect(function() st.trail = not st.trail; mark(bTrail, st.trail); setTrail(st.trail) end)
	bBig.MouseButton1Click:Connect(function()
		st.zoom = not st.zoom; mark(bBig, st.zoom)
		pcall(function() lp.CameraMaxZoomDistance = st.zoom and 1000 or origZoom end)
	end)
	local function emote(name)
		local h = getHum()
		if h then pcall(function() h:PlayEmote(name) end) end
	end
	bDance.MouseButton1Click:Connect(function() emote("dance") end)
	bWave.MouseButton1Click:Connect(function() emote("wave") end)
	bLaugh.MouseButton1Click:Connect(function() emote("laugh") end)
	RunService.Heartbeat:Connect(function(dt)
		if st.spin then
			local hrp = getHRP()
			if hrp then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, dt * 10, 0) end
		end
	end)
	-- после респавна возвращаем ореол и шлейф
	lp.CharacterAdded:Connect(function()
		task.wait(1)
		if __trk.closed then return end
		if st.glow then setGlow(true) end
		if st.trail then setTrail(true) end
	end)

	-- ---- КАМЕРА ----
	local cc = card("ВЕСЕЛЬЕ — КАМЕРА", 110, 62)
	local c1 = row(cc, 30, 34)
	local c2 = row(cc, 70, 34)
	local bUi = cell(c1, 2, "🙈 Скрыть интерфейс игры", C.btn)
	local bBlur = cell(c1, 2, "🌫 Кино-размытие", C.btn)
	local bBw = cell(c2, 2, "🎞 Чёрно-белое", C.btn)
	local bWarm = cell(c2, 2, "🔥 Тёплый фильтр", C.btn)
	local cs = {ui = false, blur = false, bw = false, warm = false}
	local blur = Instance.new("BlurEffect"); blur.Name = "SpeedMenuBlur"; blur.Size = 0; blur.Enabled = false; blur.Parent = Lighting
	local grade = Instance.new("ColorCorrectionEffect"); grade.Name = "SpeedMenuGrade"; grade.Enabled = false; grade.Parent = Lighting
	local function regrade()
		grade.Enabled = cs.bw or cs.warm
		grade.Saturation = cs.bw and -1 or 0.15
		grade.TintColor = cs.warm and Color3.fromRGB(255, 220, 180) or Color3.new(1, 1, 1)
		grade.Contrast = cs.bw and 0.15 or 0.05
	end
	bUi.MouseButton1Click:Connect(function()
		cs.ui = not cs.ui; mark(bUi, cs.ui)
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, not cs.ui) end)
	end)
	bBlur.MouseButton1Click:Connect(function() cs.blur = not cs.blur; mark(bBlur, cs.blur); blur.Enabled = cs.blur; blur.Size = cs.blur and 8 or 0 end)
	bBw.MouseButton1Click:Connect(function() cs.bw = not cs.bw; mark(bBw, cs.bw); regrade() end)
	bWarm.MouseButton1Click:Connect(function() cs.warm = not cs.warm; mark(bWarm, cs.warm); regrade() end)

	table.insert(_G.SpeedMenuCleanup, function()
		st.spin = false; st.glow = false; st.trail = false; st.zoom = false
		clearBody()
		pcall(function() lp.CameraMaxZoomDistance = origZoom end)
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end)
		pcall(function() blur:Destroy() end)
		pcall(function() grade:Destroy() end)
	end)
end, function(e) __trk.report("веселье2", e) end)


-- ===== ПОЛЕЗНОЕ: движение, копирование, таймер, заметки =====
xpcall(function() --[[полезное]]
	local function toast(t) pcall(function() _G.SpeedMenuToast(t) end) end
	local function mark(b, on) b.BackgroundColor3 = on and C.on or C.btn end

	-- ---- ДВИЖЕНИЕ ----
	local cm = card("ПОЛЕЗНОЕ — ДВИЖЕНИЕ", 190, 63)
	local m1 = row(cm, 30, 34)
	local m2 = row(cm, 70, 34)
	local m3 = row(cm, 110, 34)
	local m4 = row(cm, 150, 34)
	local bAuto = cell(m1, 2, "🚶 Авто-ходьба вперёд", C.btn)
	local bDash = cell(m1, 2, "💨 Рывок вперёд", C.btn)
	local bTap = cell(m2, 2, "👆 ТП по касанию", C.btn)
	local bBack = cell(m2, 2, "⏪ Назад на 5 с", C.btn)
	local bDeath = cell(m3, 2, "💀 Туда, где умер", C.btn)
	local bReset = cell(m3, 2, "🔄 Сброс персонажа", C.btn)
	local bSit = cell(m4, 2, "🪑 Сесть / встать", C.btn)
	local bTop = cell(m4, 2, "⛰ На самую высокую точку", C.btn)
	for _, b in ipairs({bAuto, bDash, bTap, bBack, bDeath, bReset, bSit, bTop}) do b.TextSize = 11 end
	local autoW, tapTp = false, false

	-- история позиций (раз в 0.25 с, 10 секунд)
	local hist, hT = {}, 0
	local deathPos = nil
	RunService.Heartbeat:Connect(function(dt)
		hT = hT + dt
		if hT >= 0.25 then
			hT = 0
			local hrp = getHRP()
			if hrp then
				table.insert(hist, hrp.CFrame)
				if #hist > 40 then table.remove(hist, 1) end
			end
		end
		if autoW then
			local h = getHum()
			local cam = workspace.CurrentCamera
			if h and cam and h.MoveDirection.Magnitude < 0.1 then
				local look = cam.CFrame.LookVector
				h:Move(Vector3.new(look.X, 0, look.Z), false)
			end
		end
	end)
	local function watchDeath(char)
		local h = char:WaitForChild("Humanoid", 10)
		if h then
			h.Died:Connect(function()
				if #hist > 0 then deathPos = hist[math.max(1, #hist - 2)] end
			end)
		end
	end
	if lp.Character then task.spawn(watchDeath, lp.Character) end
	lp.CharacterAdded:Connect(function(c) hist = {}; task.spawn(watchDeath, c) end)

	bAuto.MouseButton1Click:Connect(function() autoW = not autoW; mark(bAuto, autoW) end)
	bDash.MouseButton1Click:Connect(function()
		local hrp = getHRP()
		if hrp then hrp.AssemblyLinearVelocity = hrp.CFrame.LookVector * 90 + Vector3.new(0, 15, 0) end
	end)
	bTap.Text = "🔒 ТП по касанию"
	__trk.premHooks = __trk.premHooks or {}
	table.insert(__trk.premHooks, function(prem)
		bTap.Text = prem and "👆 ТП по касанию" or "🔒 ТП по касанию"
		if not prem then tapTp = false; mark(bTap, false) end
	end)
	bTap.MouseButton1Click:Connect(function()
		if not __trk.prem then toast("🔒 ТП по касанию — только в премиуме (Настройки → ПРЕМИУМ)") return end
		tapTp = not tapTp; mark(bTap, tapTp); toast(tapTp and "ТП по касанию: коснись земли" or "ТП по касанию выключено")
	end)
	bBack.MouseButton1Click:Connect(function()
		local cf = hist[math.max(1, #hist - 20)]
		if cf then safeTP(cf) else toast("Истории позиций пока нет") end
	end)
	bDeath.MouseButton1Click:Connect(function()
		if deathPos then safeTP(deathPos) else toast("Ты ещё не умирал на этом запуске") end
	end)
	bReset.MouseButton1Click:Connect(function()
		local h = getHum()
		if h then h.Health = 0 end
	end)
	bSit.MouseButton1Click:Connect(function()
		local h = getHum()
		if h then h.Sit = not h.Sit end
	end)
	bTop.MouseButton1Click:Connect(function()
		local hrp = getHRP()
		if not hrp then return end
		local best = hrp.Position.Y
		local ok, list = pcall(function() return workspace:GetDescendants() end)
		local target
		if ok then
			for i = 1, math.min(#list, 8000) do
				local d = list[i]
				if d:IsA("BasePart") and d.CanCollide and not d:IsDescendantOf(lp.Character) and d.Position.Y + d.Size.Y / 2 > best and d.Position.Y < 5000 then
					best = d.Position.Y + d.Size.Y / 2; target = d
				end
			end
		end
		if target then safeTP(CFrame.new(target.Position.X, best + 4, target.Position.Z)) else toast("Выше ничего не нашёл") end
	end)
	-- ТП по касанию: короткий тап по земле
	local tapStart, tapT
	UIS.InputBegan:Connect(function(i, gp)
		if tapTp and __trk.prem and not gp and i.UserInputType == Enum.UserInputType.Touch then tapStart, tapT = i.Position, os.clock() end
	end)
	UIS.InputEnded:Connect(function(i)
		if tapTp and tapStart and i.UserInputType == Enum.UserInputType.Touch then
			local quick = os.clock() - tapT < 0.25 and (i.Position - tapStart).Magnitude < 10
			tapStart = nil
			if quick then
				local cam = workspace.CurrentCamera
				if cam then
					local ray = cam:ScreenPointToRay(i.Position.X, i.Position.Y)
					local rp = RaycastParams.new()
					rp.FilterType = Enum.RaycastFilterType.Exclude
					rp.FilterDescendantsInstances = {lp.Character}
					local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, rp)
					if res then safeTP(CFrame.new(res.Position + Vector3.new(0, 4, 0))) end
				end
			end
		end
	end)

	-- ---- КОПИРОВАНИЕ ----
	local ci = card("ПОЛЕЗНОЕ — КОПИРОВАТЬ", 110, 64)
	local i1 = row(ci, 30, 34)
	local i2 = row(ci, 70, 34)
	local bPos = cell(i1, 2, "📍 Мои координаты", C.btn)
	local bPlace = cell(i1, 2, "🆔 ID игры", C.btn)
	local bJob = cell(i2, 2, "🔗 ID сервера", C.btn)
	local bName = cell(i2, 2, "👤 Мой ник", C.btn)
	for _, b in ipairs({bPos, bPlace, bJob, bName}) do b.TextSize = 11 end
	local function copy(text, what)
		local fn = setclipboard or toclipboard
		if fn and pcall(fn, text) then toast("Скопировано: " .. what) else toast(what .. ": " .. text) end
	end
	bPos.MouseButton1Click:Connect(function()
		local hrp = getHRP()
		if hrp then local p = hrp.Position; copy(string.format("%d, %d, %d", p.X, p.Y, p.Z), "координаты") end
	end)
	bPlace.MouseButton1Click:Connect(function() copy(tostring(game.PlaceId), "ID игры") end)
	bJob.MouseButton1Click:Connect(function() copy(tostring(game.JobId), "ID сервера") end)
	bName.MouseButton1Click:Connect(function() copy(lp.Name, "ник") end)

	-- ---- ТАЙМЕР-НАПОМИНАНИЕ ----
	local ct = card("ТАЙМЕР-НАПОМИНАНИЕ", 76, 65)
	local t1 = row(ct, 30, 34)
	local tBox = cellBox(t1, 2, "минуты")
	local tBtn = cell(t1, 2, "⏱ Запустить", C.on)
	local tId = 0
	tBtn.MouseButton1Click:Connect(function()
		if tBtn.Text ~= "⏱ Запустить" then
			tId = tId + 1; tBtn.Text = "⏱ Запустить"; tBtn.BackgroundColor3 = C.on; toast("Таймер остановлен") return
		end
		local mins = tonumber(tBox.Text)
		if not mins or mins <= 0 then toast("Впиши минуты числом") return end
		tId = tId + 1
		local my = tId
		local endAt = os.clock() + mins * 60
		tBtn.BackgroundColor3 = C.danger
		toast("Таймер на " .. mins .. " мин запущен")
		task.spawn(function()
			while my == tId and os.clock() < endAt do
				local left = math.ceil(endAt - os.clock())
				tBtn.Text = string.format("⏹ %02d:%02d", math.floor(left / 60), left % 60)
				task.wait(0.5)
			end
			if my == tId then
				tBtn.Text = "⏱ Запустить"; tBtn.BackgroundColor3 = C.on
				toast("⏰ Время вышло!")
				pcall(function() game:GetService("StarterGui"):SetCore("SendNotification", {Title = "⏰ Таймер", Text = "Время вышло!", Duration = 10}) end)
			end
		end)
	end)
	table.insert(_G.SpeedMenuCleanup, function() tId = tId + 1 end)

	-- ---- ЗАМЕТКИ ----
	local cn = card("ЗАМЕТКИ (сохраняются сами)", 150, 66)
	local NOTES = "SpeedMenu_notes.txt"
	local notes = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 108), Position = UDim2.fromOffset(12, 30), Text = "", PlaceholderText = "Коды, подсказки, список дел…",
		ClearTextOnFocus = false, MultiLine = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = C.text, PlaceholderColor3 = Color3.fromRGB(120, 126, 160), BackgroundColor3 = C.field, Parent = cn,
	}, {round(6)})
	pcall(function()
		if isfile and readfile and isfile(NOTES) then notes.Text = readfile(NOTES) end
	end)
	notes.FocusLost:Connect(function()
		pcall(function() if writefile then writefile(NOTES, notes.Text) end end)
	end)
end, function(e) __trk.report("полезное", e) end)






-- ===== ФОН-КАРТИНКА (логотип W1NTEZ) =====
xpcall(function() --[[фон]]
	local BG_FILE, USER_FILE, CFG = "SpeedMenu_bg.jpg", "SpeedMenu_bg.png", "SpeedMenu_bgcfg.json"
	local B64 = [==[
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
]==]
	local cfg = {on = true, ti = 2}
	if canSave then
		local ok, d = pcall(function() return HttpService:JSONDecode(readfile(CFG)) end)
		if ok and type(d) == "table" then
			if type(d.on) == "boolean" then cfg.on = d.on end
			if tonumber(d.ti) then cfg.ti = math.clamp(math.floor(d.ti), 1, 3) end
		end
	end
	local function saveCfg() if canSave then pcall(function() writefile(CFG, HttpService:JSONEncode(cfg)) end) end end
	local dims = {0.25, 0.45, 0.65}
	local dimNames = {"слабое", "среднее", "сильное"}

	local img = new("ImageLabel", {
		Name = "SpeedMenuBg", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0, ScaleType = Enum.ScaleType.Crop,
		ImageTransparency = dims[cfg.ti], Visible = false, Parent = main,
	}, {round(14)})

	local function decode()
		local map = {}
		local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
		for i = 1, #chars do map[string.byte(chars, i)] = i - 1 end
		local out, acc, bits, n = {}, 0, 0, 0
		for i = 1, #B64 do
			local v = map[string.byte(B64, i)]
			if v then
				acc = acc * 64 + v; bits = bits + 6
				if bits >= 8 then
					bits = bits - 8
					local p = 2 ^ bits
					local byte = math.floor(acc / p)
					acc = acc - byte * p
					n = n + 1; out[n] = string.char(byte)
				end
			end
			if i % 4000 == 0 then task.wait() end
		end
		return table.concat(out)
	end

	local assetId
	local function loadAsset()
		if not (type(getcustomasset) == "function" and type(writefile) == "function" and type(isfile) == "function") then return nil end
		if isfile(USER_FILE) then return getcustomasset(USER_FILE) end -- своё фото в полном качестве
		if not isfile(BG_FILE) then writefile(BG_FILE, decode()) end
		return getcustomasset(BG_FILE)
	end

	local function soften(f)
		if f:IsA("Frame") and f.Parent == main:FindFirstChildOfClass("ScrollingFrame") then
			f.BackgroundTransparency = (cfg.on and assetId) and 0.3 or 0
		end
	end
	local function refreshBg()
		img.Visible = (cfg.on and assetId ~= nil)
		img.ImageTransparency = dims[cfg.ti]
		for _, f in ipairs(scroll:GetChildren()) do soften(f) end
	end
	scroll.ChildAdded:Connect(function(f) task.defer(function() pcall(soften, f) end) end)

	task.spawn(function()
		local ok, id = pcall(loadAsset)
		if ok and id then
			assetId = id
			img.Image = id
			refreshBg()
			-- то же фото — на плавающую кнопку (иконку) меню; кнопка создаётся чуть позже, ждём её
			task.spawn(function()
				local t0 = os.clock()
				local fb
				while os.clock() - t0 < 20 do
					fb = gui:FindFirstChild("SpeedMenuToggle")
					if fb then break end
					task.wait(0.3)
				end
				if fb and not fb:FindFirstChild("SpeedMenuIcon") then
					fb.Text = ""
					fb.Size = UDim2.fromOffset(54, 54)
					new("ImageLabel", {
						Name = "SpeedMenuIcon", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = id,
						ScaleType = Enum.ScaleType.Crop, Active = false, ZIndex = fb.ZIndex + 1, Parent = fb,
					}, {round(10)})
				end
			end)
		else
			warn("[SpeedMenu] фон не загружен: " .. tostring(id or "запускатель не поддерживает getcustomasset"))
		end
	end)

	local cb = card("ОФОРМЛЕНИЕ — ФОН (фото W1NTEZ)", 128, 78)
	local r1 = row(cb, 30, 34)
	local bOn = cell(r1, 2, cfg.on and "🖼 Фон: вкл" or "🖼 Фон: выкл", cfg.on and C.on or C.btn)
	local bDim = cell(r1, 2, "🌑 Затемнение: " .. dimNames[cfg.ti], C.btn)
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 44), Position = UDim2.fromOffset(12, 72), BackgroundTransparency = 1, TextWrapped = true,
		Text = "Своё фото в лучшем качестве: положи файл SpeedMenu_bg.png в папку workspace запускателя и перезапусти скрипт.",
		Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = cb,
	})
	bOn.MouseButton1Click:Connect(function()
		cfg.on = not cfg.on
		bOn.Text = cfg.on and "🖼 Фон: вкл" or "🖼 Фон: выкл"; bOn.BackgroundColor3 = cfg.on and C.on or C.btn
		refreshBg(); saveCfg()
		if cfg.on and not assetId then pcall(function() _G.SpeedMenuToast("Фон не поддерживается этим запускателем") end) end
	end)
	bDim.MouseButton1Click:Connect(function()
		cfg.ti = cfg.ti % 3 + 1
		bDim.Text = "🌑 Затемнение: " .. dimNames[cfg.ti]
		refreshBg(); saveCfg()
	end)
end, function(e) __trk.report("фон", e) end)


-- ===== ПРЕМИУМ: код доступа =====
xpcall(function() --[[премиум]]
	-- ВНИМАНИЕ: в скрипте хранятся только хэши кодов, сами коды здесь не записаны.
	local SALT = "W1NTEZ|prem|v1|"
	-- в скрипте нет самих кодов: только их хэши и зашифрованный ключ модуля под каждый код
	local OWNER_W = {["eadbdc3ada07fef5"] = "eae43e45b6f2c9df93dfb060730d5c31"}
	local BUYER_W = {
		["e7a2103b6cdb70ca"] = "c8d968acd1a76c9411cf523df6caebfa",
		["3f3f53d1aac1f02a"] = "a73c0c0d06644e3d07e0290cd58ecb64",
		["b9aef21477ffeeb0"] = "ae91cb0758b52f3c960d11c0271818d2",
		["24531dafcb2424bc"] = "c23519fd2fd3c6ece75eb608122b89a1",
		["abb2ade6197b2c3b"] = "94556ce961ccee7d6abb479a6ada0ee2",
	}
	-- премиум-функции лежат здесь в зашифрованном виде; расшифровать их можно только верным кодом
	local CIPHER = [=====[
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
]=====]
	-- необязательно: ссылка на твой текстовый файл со списком хэшей (по одному в строке) — так можно выдавать/отзывать коды без новой версии скрипта
	local PREMIUM_LIST_URL = ""
	local TG_LINK = "https://t.me/maks47808"
	local BUY_TEXT = "Купить премиум: Telegram " .. TG_LINK
	local PREM_FILE = "SpeedMenu_prem.txt"
	local LOCKED = {"ТЕЛЕПОРТ"}
	local FEATURES = "Премиум-функции зашифрованы и открываются только кодом. Премиум открывает: телепорт по координатам, ТП по касанию, радар, метку, «идти за игроком», запись маршрута, кино-камеру, горячие кнопки, темы, чат-лог, журнал игроков, статистику, сигнал «игрок рядом», авто-возврат после смерти, ускорение дня."

	local function toast(t) pcall(function() _G.SpeedMenuToast(t) end) end
	local function phash(code)
		local str = SALT .. string.upper((string.gsub(tostring(code), "%s", "")))
		local h1, h2 = 5381, 52711
		for i = 1, #str do
			local b = string.byte(str, i)
			h1 = (h1 * 33 + b) % 4294967291
			h2 = (h2 * 131 + b * (i % 7 + 1)) % 4294967279
		end
		return string.format("%08x%08x", h1, h2)
	end
	local remote = {}
	local function fetchRemote()
		if PREMIUM_LIST_URL == "" then return end
		local ok, body = pcall(function() return game:HttpGet(PREMIUM_LIST_URL) end)
		if ok and type(body) == "string" then
			for line in string.gmatch(body, "[^\r\n]+") do
				local h, w = string.match(string.lower((string.gsub(line, "%s", ""))), "^(%x+):(%x+)$")
				if h and w and #h == 16 and #w == 32 then remote[h] = w end
			end
		end
	end
	-- ---- шифр (RC4-drop768) и распаковка модуля ----
	local bxor = bit32 and bit32.bxor
	local function rc4(key, data)
		local S = {}
		for i = 0, 255 do S[i] = i end
		local j, kl = 0, #key
		for i = 0, 255 do
			j = (j + S[i] + string.byte(key, i % kl + 1)) % 256
			S[i], S[j] = S[j], S[i]
		end
		local i2, j2 = 0, 0
		for _ = 1, 768 do
			i2 = (i2 + 1) % 256; j2 = (j2 + S[i2]) % 256
			S[i2], S[j2] = S[j2], S[i2]
		end
		local out = {}
		for n = 1, #data do
			i2 = (i2 + 1) % 256; j2 = (j2 + S[i2]) % 256
			S[i2], S[j2] = S[j2], S[i2]
			out[n] = string.char(bxor(string.byte(data, n), S[(S[i2] + S[j2]) % 256]))
			if n % 25000 == 0 then task.wait() end
		end
		return table.concat(out)
	end
	local function norm(code) return string.upper((string.gsub(tostring(code), "%s", ""))) end
	local function hex2bin(h) return (string.gsub(h, "%x%x", function(x) return string.char(tonumber(x, 16)) end)) end
	local function bin2hex(b) return (string.gsub(b, ".", function(c) return string.format("%02x", string.byte(c)) end)) end
	local function keyFor(code, w) return rc4("W1NTEZ|kek|v1|" .. norm(code), hex2bin(w)) end
	local function b64(str)
		local map = {}
		local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
		for i = 1, #chars do map[string.byte(chars, i)] = i - 1 end
		local out, acc, bits, n = {}, 0, 0, 0
		for i = 1, #str do
			local v = map[string.byte(str, i)]
			if v then
				acc = acc * 64 + v; bits = bits + 6
				if bits >= 8 then
					bits = bits - 8
					local p = 2 ^ bits
					local byte = math.floor(acc / p)
					acc = acc - byte * p
					n = n + 1; out[n] = string.char(byte)
				end
			end
		end
		return table.concat(out)
	end
	local MARK = "--W1NTEZ-PREMIUM-MODULE\n"
	local function decrypt(K)
		if not bxor then return nil end
		local plain = rc4(K, b64(CIPHER))
		if string.sub(plain, 1, #MARK) ~= MARK then return nil end
		return plain
	end
	local function check(code)
		local h = phash(code)
		local w = OWNER_W[h] or BUYER_W[h] or remote[h]
		if not w then return nil end
		return (OWNER_W[h] and "owner" or "buyer"), keyFor(code, w)
	end

	-- мост: модуль видит нужные части меню и общие переключатели
	local GENV = (getfenv and getfenv(1)) or _G
	local VAL = {
		C = C, cell = cell, row = row, new = new, card = card, cellBox = cellBox, round = round, getHRP = getHRP, getHum = getHum,
		RunService = RunService, UIS = UIS, Players = Players, lp = lp, __trk = __trk, refreshUI = refreshUI, canSave = canSave,
		safeTP = safeTP, parent = parent, gui = gui, isPress = isPress, isMove = isMove, HttpService = HttpService,
		startFly = startFly, stopFly = stopFly, refreshEsp = refreshEsp, DEFAULT = DEFAULT,
	}
	local GET = {
		flying = function() return flying end, enabled = function() return enabled end, noclip = function() return noclip end,
		god = function() return god end, esp = function() return esp end, infJump = function() return infJump end,
	}
	local SET = {
		flying = function(v) flying = v end, enabled = function(v) enabled = v end, noclip = function(v) noclip = v end,
		god = function(v) god = v end, esp = function(v) esp = v end, infJump = function(v) infJump = v end,
	}
	local modEnv = setmetatable({}, {
		__index = function(_, k)
			local g = GET[k]
			if g then return g() end
			local v = VAL[k]
			if v ~= nil then return v end
			return GENV[k]
		end,
		__newindex = function(t, k, v)
			local f = SET[k]
			if f then f(v) else rawset(t, k, v) end
		end,
	})
	local moduleLoaded, ownerK = false, nil
	local function loadModule(K)
		if moduleLoaded then return true end
		local plain = decrypt(K)
		if not plain then toast("Не удалось расшифровать премиум-модуль"); return false end
		local fn, err = loadstring(plain, "=W1NTEZ-premium")
		if not fn then __trk.report("премиум-модуль", err); return false end
		if setfenv then setfenv(fn, modEnv) else toast("Запускатель не поддерживает премиум-модуль"); return false end
		local before = {}
		for _, f in ipairs(scroll:GetChildren()) do before[f] = true end
		local ok, e = pcall(fn)
		if not ok then __trk.report("премиум-модуль", e) end
		moduleLoaded = true
		-- если меню уже построено, добавляем новые карточки во вкладки
		if __trk.addCard then
			for _, f in ipairs(scroll:GetChildren()) do
				if f:IsA("Frame") and not before[f] then pcall(__trk.addCard, f) end
			end
		end
		return true
	end

	__trk.prem, __trk.owner = false, false
	local cardP = card("ПРЕМИУМ — КОД ДОСТУПА", 214, 79)
	local status = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 22), Position = UDim2.fromOffset(12, 28), BackgroundTransparency = 1, Text = "🔒 Премиум не активирован",
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Parent = cardP,
	})
	local pr = row(cardP, 54, 34)
	local codeBox = cellBox(pr, 2, "введи код")
	local actBtn = cell(pr, 2, "🔑 Активировать", C.on)
	actBtn.TextSize = 11
	local buyRow = row(cardP, 94, 34)
	local buyBtn = cell(buyRow, 1, "💬 Купить премиум — Telegram", C.accent)
	buyBtn.TextSize = 12
	buyBtn.MouseButton1Click:Connect(function()
		local cp = setclipboard or toclipboard
		if cp and pcall(cp, TG_LINK) then toast("Ссылка на Telegram скопирована — открой её в браузере") else toast("Telegram: " .. TG_LINK) end
	end)
	new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 76), Position = UDim2.fromOffset(12, 132), BackgroundTransparency = 1, TextWrapped = true,
		Text = FEATURES .. "\n" .. BUY_TEXT, Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = C.sub,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = cardP,
	})

	-- генератор кодов — виден только владельцу
	local genRow = row(cardP, 214, 34)
	local genBtn = cell(genRow, 2, "🎲 Новый код покупателя", C.accent)
	local hashBtn = cell(genRow, 2, "📋 Строка для списка", C.btn)
	genBtn.TextSize = 10; hashBtn.TextSize = 10
	local genInfo = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 252), BackgroundTransparency = 1, TextWrapped = true, Text = "",
		Font = Enum.Font.Code, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = cardP,
	})
	genRow.Visible = false; genInfo.Visible = false
	local lastHash
	local rnd = Random.new(math.floor(os.clock() * 1000) + os.time())
	local alpha = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	genBtn.MouseButton1Click:Connect(function()
		local parts = {}
		for g = 1, 4 do
			local p = ""
			for _ = 1, 4 do local k = rnd:NextInteger(1, #alpha); p = p .. string.sub(alpha, k, k) end
			parts[g] = p
		end
		local code = "W1-" .. table.concat(parts, "-")
		if not ownerK then toast("Сначала войди кодом владельца") return end
		lastHash = phash(code) .. ":" .. bin2hex(rc4("W1NTEZ|kek|v1|" .. norm(code), ownerK))
		genInfo.Text = "Код: " .. code .. "\nСтрока для списка: " .. lastHash
		local cp = setclipboard or toclipboard
		if cp then pcall(cp, code) end
		toast("Код создан" .. (cp and " и скопирован" or ""))
	end)
	hashBtn.MouseButton1Click:Connect(function()
		local cp = setclipboard or toclipboard
		if lastHash and cp then pcall(cp, lastHash); toast("Строка для списка скопирована") elseif not lastHash then toast("Сначала создай код") end
	end)

	local overlays = {}
	local function setState(kind)
		__trk.prem = kind ~= nil
		__trk.owner = kind == "owner"
		status.Text = kind == "owner" and "👑 Владелец: премиум открыт" or (kind and "✅ Премиум активен" or "🔒 Премиум не активирован")
		status.TextColor3 = kind and Color3.fromRGB(120, 255, 160) or C.text
		genRow.Visible = __trk.owner; genInfo.Visible = __trk.owner
		for _, hk in ipairs(__trk.premHooks or {}) do pcall(hk, __trk.prem) end
		cardP.Size = UDim2.new(1, 0, 0, __trk.owner and 290 or 214)
		for _, o in ipairs(overlays) do pcall(function() o.Visible = not __trk.prem end) end
		pcall(function()
			local h = parent:FindFirstChild("SpeedMenuHotkeys")
			if h then h.Enabled = __trk.prem end
		end)
	end
	local function lockCard(f)
		if f:FindFirstChild("PremLock") then return end
		local ov = new("TextButton", {
			Name = "PremLock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, Text = "",
			AutoButtonColor = false, ZIndex = 60, Visible = not __trk.prem, Parent = f,
		}, {round(10)})
		new("TextLabel", {
			Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "🔒 ПРЕМИУМ\nкод: Настройки → ПРЕМИУМ\nкупить: t.me/maks47808", Font = Enum.Font.GothamBold,
			TextSize = 13, TextColor3 = Color3.new(1, 1, 1), ZIndex = 61, Parent = ov,
		})
		ov.MouseButton1Click:Connect(function() toast("🔒 Нужен премиум-код (Настройки → ПРЕМИУМ)") end)
		table.insert(overlays, ov)
	end
	local function scanLocks()
		for _, f in ipairs(scroll:GetChildren()) do
			if f:IsA("Frame") then
				local t = f:FindFirstChildOfClass("TextLabel")
				local title = t and t.Text or ""
				for _, p in ipairs(LOCKED) do
					if string.sub(title, 1, #p) == p then lockCard(f) break end
				end
			end
		end
	end

	local tries, lastTry = 0, 0
	actBtn.MouseButton1Click:Connect(function()
		if os.clock() - lastTry < 1.5 then return end
		lastTry = os.clock()
		local kind, K = check(codeBox.Text)
		if kind and loadModule(K) then
			if kind == "owner" then ownerK = K end
			setState(kind)
			toast(kind == "owner" and "Добро пожаловать, владелец 👑" or "Премиум активирован ✅")
			if canSave then pcall(function() writefile(PREM_FILE, codeBox.Text) end) end
			codeBox.Text = ""
		else
			tries = tries + 1
			toast("Неверный код" .. (tries >= 3 and " (подожди немного)" or ""))
			if tries >= 3 then lastTry = os.clock() + 8 end
		end
	end)

	-- сохранённый код
	local saved
	if canSave then pcall(function() saved = readfile(PREM_FILE) end) end
	if saved then
		local k, K = check(saved)
		if k and loadModule(K) then if k == "owner" then ownerK = K end; setState(k) end
	end
	task.spawn(function()
		fetchRemote()
		if not __trk.prem and saved then
			local k, K = check(saved)
			if k and loadModule(K) then if k == "owner" then ownerK = K end; setState(k) end
		end
	end)
	local alive = true
	table.insert(_G.SpeedMenuCleanup, function() alive = false end)
	task.spawn(function()
		local n = 0
		while alive do
			task.wait(1)
			n = n + 1
			pcall(scanLocks)
			pcall(function()
				local h = parent:FindFirstChild("SpeedMenuHotkeys")
				if h and h.Enabled ~= __trk.prem then h.Enabled = __trk.prem end
			end)
			if n > 20 then task.wait(4) end
		end
	end)
end, function(e) __trk.report("премиум", e) end)



gui.Parent = parent
refreshUI()

-- сторож: если игра удалила окна меню — возвращаем их на место
task.spawn(function()
	local alive = true
	table.insert(_G.SpeedMenuCleanup, function() alive = false end)
	while alive and type(_G.SpeedMenuClose) == "function" do
		task.wait(1.5)
		for _, g in ipairs(__trk.guis or {}) do
			pcall(function()
				if g and not g.Parent and alive and type(_G.SpeedMenuClose) == "function" then
					local ok = pcall(function() g.Parent = parent end)
					if not ok or not g.Parent then
						pcall(function() g.Parent = lp:WaitForChild("PlayerGui", 5) end)
					end
				end
			end)
		end
	end
end)

-- ===== W1NTEZ YT: профиль создателя =====
xpcall(function() --[[профиль]]
local AVATAR_ID  = 0   -- вставь сюда число-ID картинки из Roblox
local AVATAR_URL = ""  -- запасной вариант: прямая ссылка на png (нужны getcustomasset и writefile)

local RED = Color3.fromRGB(225, 40, 50)

local c0 = card("СОЗДАТЕЛЬ СКРИПТА", 112, 0)

local avatar = new("ImageLabel", {
	Size = UDim2.fromOffset(80, 80), Position = UDim2.fromOffset(12, 26),
	BackgroundColor3 = C.field, BorderSizePixel = 0,
	ScaleType = Enum.ScaleType.Crop, Parent = c0,
}, {round(40), new("UIStroke", {Color = RED, Thickness = 2})})

if AVATAR_ID ~= 0 then
	avatar.Image = "rbxassetid://" .. AVATAR_ID
elseif AVATAR_URL ~= "" and type(getcustomasset) == "function" and type(writefile) == "function" then
	task.spawn(function()
		pcall(function()
			writefile("W1NTEZ_avatar.png", game:HttpGet(AVATAR_URL))
			avatar.Image = getcustomasset("W1NTEZ_avatar.png")
		end)
	end)
end

new("TextLabel", {
	Size = UDim2.new(1, -116, 0, 30), Position = UDim2.fromOffset(104, 32), BackgroundTransparency = 1,
	Text = "W1NTEZ YT", Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = C.text,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = c0,
})
new("TextLabel", {
	Size = UDim2.new(1, -116, 0, 20), Position = UDim2.fromOffset(104, 62), BackgroundTransparency = 1,
	Text = "№1 · Создатель скрипта", Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = RED,
	TextXAlignment = Enum.TextXAlignment.Left, Parent = c0,
})

-- заголовок окна
local title = header:FindFirstChildOfClass("TextLabel")
if title then title.Text = "⚡ Скрипт от W1NTEZ YT на любую игру" end
end, function(e) __trk.report("профиль", e) end)

-- =====================================================================
-- ===== НОВОЕ МЕНЮ: боковые вкладки (Главное / Игры / Аим / ESP / Функции / Настройки)
-- =====================================================================
local __tabStage = "start"
xpcall(function() --[[вкладки]]
	local SB = 118
	scroll.Size = UDim2.new(1, -SB, 1, -36)
	scroll.Position = UDim2.fromOffset(SB, 36)
	__tabStage = "scroll"

	local okQ, errQ = pcall(function()
		-- ----- быстрые переключатели (как на макете) -----
		local cq = card("БЫСТРЫЕ ПЕРЕКЛЮЧАТЕЛИ", 318, 0)
		local function aimLib() return _G.SpeedMenuAimLib end
		local QUICK = {
			{"👑", "Бессмертие", function() return god end, function()
				god = not god
				local h = getHum()
				if h then pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, not god) end) end
				refreshUI()
			end},
			{"⚡", "Ускорение", function() return enabled end, function()
				enabled = not enabled
				if not enabled then local h = getHum() if h then h.WalkSpeed = DEFAULT end end
				refreshUI()
			end},
			{"🎯", "Аим", function() local l = aimLib() return l and l.getAim and l.getAim() or false end, function()
				local l = aimLib()
				if l and l.setAim then l.setAim(not l.getAim()) end
			end},
			{"👁", "ESP игроков", function() return esp end, function()
				esp = not esp
				pcall(refreshEsp); refreshUI()
			end},
			{"🚪", "Ноклип", function() return noclip end, function() noclip = not noclip refreshUI() end},
			{"🦘", "Беск. прыжок", function() return infJump end, function() infJump = not infJump refreshUI() end},
		}
		local sw = {}
		for i, q in ipairs(QUICK) do
			local y = 28 + (i - 1) * 38
			local rowF = new("Frame", {Size = UDim2.new(1, -24, 0, 34), Position = UDim2.fromOffset(12, y), BackgroundColor3 = C.field, BackgroundTransparency = 0.35, BorderSizePixel = 0, Parent = cq}, {round(10)})
			new("TextLabel", {Size = UDim2.fromOffset(30, 34), Position = UDim2.fromOffset(6, 0), BackgroundTransparency = 1, Text = q[1], Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = C.text, Parent = rowF})
			new("TextLabel", {Size = UDim2.new(1, -110, 1, 0), Position = UDim2.fromOffset(40, 0), BackgroundTransparency = 1, Text = q[2], Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Parent = rowF})
			local pill = new("Frame", {Size = UDim2.fromOffset(46, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), BackgroundColor3 = C.off, BorderSizePixel = 0, Parent = rowF}, {round(11)})
			local knobF = new("Frame", {Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = pill}, {round(9)})
			local hit = new("TextButton", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", Parent = rowF})
			sw[i] = {pill = pill, knob = knobF, get = q[3], last = nil}
			hit.MouseButton1Click:Connect(function()
				pcall(q[4])
				task.defer(function()
					local ok, v = pcall(q[3])
					pcall(function() _G.SpeedMenuToast(q[2] .. ((ok and v) and ": включено" or ": выключено")) end)
				end)
			end)
		end
		local allBtn = new("TextButton", {
			Size = UDim2.new(1, -24, 0, 42), Position = UDim2.fromOffset(12, 28 + #QUICK * 38 + 4), Text = "▶  ВКЛЮЧИТЬ ВСЁ ОСНОВНОЕ",
			Font = Enum.Font.GothamBlack, TextSize = 13, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = C.on, Parent = cq,
		}, {round(12), new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(124, 58, 237), Color3.fromRGB(168, 85, 247))})})
		allBtn.MouseButton1Click:Connect(function()
			local anyOff = false
			for _, q in ipairs(QUICK) do if not q[3]() then anyOff = true end end
			for _, q in ipairs(QUICK) do
				if q[3]() ~= anyOff then pcall(q[4]) end
			end
		end)
		local acc = 0
		RunService.Heartbeat:Connect(function(dt)
			acc = acc + (dt or 0.016)
			if acc < 0.15 then return end
			acc = 0
			local anyOff = false
			for i, w in ipairs(sw) do
				local v = w.get() and true or false
				if not v then anyOff = true end
				if w.last ~= v then
					w.last = v
					tween(w.pill, {BackgroundColor3 = v and C.on or C.off})
					tween(w.knob, {Position = v and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)})
				end
			end
			allBtn.Text = anyOff and "▶  ВКЛЮЧИТЬ ВСЁ ОСНОВНОЕ" or "■  ВЫКЛЮЧИТЬ ВСЁ"
		end)

		-- ----- настройки: подсказка по кнопкам -----
		local cs = card("УПРАВЛЕНИЕ", 190, 99)
		new("TextLabel", {
			Size = UDim2.new(1, -24, 0, 110), Position = UDim2.fromOffset(12, 28), BackgroundTransparency = 1,
			Text = "RightShift — скрыть / показать меню\nRightAlt — аим вкл / выкл\n— в заголовке — свернуть окно\n✕ в заголовке (нажать дважды) — закрыть скрипт полностью\n◢ в углу — менять размер окна\nЗаголовок — перетаскивать",
			Font = Enum.Font.Gotham, TextSize = 12, TextColor3 = C.sub, TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = cs,
		})
		local rr = row(cs, 146, 34)
		local resetB = cell(rr, 1, "↺  Сбросить вид окна (размер, масштаб)", C.btn)
		local armed = false
		resetB.MouseButton1Click:Connect(function()
			if not armed then
				armed = true
				resetB.Text = "Нажми ещё раз для подтверждения"
				resetB.BackgroundColor3 = C.danger
				task.delay(3, function() armed = false; resetB.Text = "↺  Сбросить вид окна (размер, масштаб)"; resetB.BackgroundColor3 = C.btn end)
				return
			end
			armed = false
			pcall(function() if delfile and isfile and isfile("SpeedMenu_ui.json") then delfile("SpeedMenu_ui.json") end end)
			pcall(function() _G.SpeedMenuToast("Вид сброшен — перезапусти скрипт") end)
			resetB.Text = "Готово: перезапусти скрипт"
		end)

	end)

	__tabStage = "extras-done"
	-- ----- состояние окна: вкладка, размер, масштаб; плавающая кнопка для телефона -----
	local UI_FILE = "SpeedMenu_ui.json"
	local ui = {tab = 1, w = nil, h = nil, scale = 1, floatBtn = true}
	if canSave then
		local okU, d = pcall(function() return HttpService:JSONDecode(readfile(UI_FILE)) end)
		if okU and type(d) == "table" then
			ui.tab = math.clamp(tonumber(d.tab) or 1, 1, 8)
			ui.scale = math.clamp(tonumber(d.scale) or 1, 0.6, 1.5)
			-- кнопка меню всегда видна при запуске (раньше её можно было случайно выключить и потерять меню)
			if tonumber(d.w) and tonumber(d.h) then ui.w, ui.h = tonumber(d.w), tonumber(d.h) end
		end
	end
	local uiQ = false
	local function saveUi()
		if not canSave or uiQ then return end
		uiQ = true
		task.delay(1, function()
			uiQ = false
			pcall(function()
				local sz = main.Size
				writefile(UI_FILE, HttpService:JSONEncode({tab = ui.tab, scale = ui.scale, floatBtn = ui.floatBtn, w = sz.X.Offset, h = sz.Y.Offset}))
			end)
		end)
	end
	if ui.w and ui.h then
		main.Size = UDim2.fromOffset(math.clamp(ui.w, 340, 640), math.clamp(ui.h, 350, 720))
	end
	local uiScale = new("UIScale", {Scale = ui.scale, Parent = main})
	-- запоминаем размер окна после растягивания
	local lastW, lastH = 0, 0
	RunService.Heartbeat:Connect(function()
		local sz = main.Size
		if sz.Y.Offset > 40 and (sz.X.Offset ~= lastW or sz.Y.Offset ~= lastH) then
			lastW, lastH = sz.X.Offset, sz.Y.Offset
			saveUi()
		end
	end)

	-- карточка «Оформление»
	local c98 = card("ОФОРМЛЕНИЕ", 142, 98)
	local scaleL = label(c98, "Масштаб меню: " .. math.floor(ui.scale * 100) .. "%", 26, 12)
	local rS = row(c98, 58, 32)
	local sMin = cell(rS, 3, "Меньше", C.btn)
	local sMax = cell(rS, 3, "Больше", C.btn)
	local sRes = cell(rS, 3, "Сброс", C.btn)
	local rF = row(c98, 98, 32)
	local floatB = cell(rF, 1, ui.floatBtn and "Кнопка меню на экране: ВКЛ" or "Кнопка меню на экране: ВЫКЛ", ui.floatBtn and C.on or C.off)
	local function setScale(v)
		ui.scale = math.clamp(math.floor(v * 20 + 0.5) / 20, 0.6, 1.5)
		uiScale.Scale = ui.scale
		scaleL.Text = "Масштаб меню: " .. math.floor(ui.scale * 100 + 0.5) .. "%"
		saveUi()
	end
	sMin.MouseButton1Click:Connect(function() setScale(ui.scale - 0.1) end)
	sMax.MouseButton1Click:Connect(function() setScale(ui.scale + 0.1) end)
	sRes.MouseButton1Click:Connect(function() setScale(1) end)

	-- плавающая кнопка: открыть / скрыть меню пальцем (на телефоне нет RightShift)
	local fb = new("TextButton", {
		Name = "SpeedMenuToggle", Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 12, 0.5, -23), Text = "⚡",
		Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = C.on,
		AutoButtonColor = true, ZIndex = 20, Visible = ui.floatBtn, Parent = gui,
	}, {round(10), new("UIStroke", {Color = Color3.fromRGB(217, 70, 239), Thickness = 2})})
	local fDrag, fMoved, fStart, fPos = false, false, nil, nil
	fb.InputBegan:Connect(function(i)
		if isPress(i) then fDrag, fMoved, fStart, fPos = true, false, i.Position, fb.Position end
	end)
	UIS.InputChanged:Connect(function(i)
		if fDrag and isMove(i) then
			local d = i.Position - fStart
			if d.Magnitude > 8 then fMoved = true end
			if fMoved then fb.Position = UDim2.new(fPos.X.Scale, fPos.X.Offset + d.X, fPos.Y.Scale, fPos.Y.Offset + d.Y) end
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if fDrag and isPress(i) then
			fDrag = false
			if not fMoved then main.Visible = not main.Visible end
		end
	end)
	floatB.MouseButton1Click:Connect(function()
		ui.floatBtn = not ui.floatBtn
		fb.Visible = ui.floatBtn
		floatB.Text = ui.floatBtn and "Кнопка меню на экране: ВКЛ" or "Кнопка меню на экране: ВЫКЛ"
		paint(floatB, ui.floatBtn)
		saveUi()
	end)

	__tabStage = "ui-done"
	-- ----- вкладки (боковая панель на простых абсолютных позициях) -----
	local TABS = {
		{"🏠", "Главное"}, {"🎮", "Игры"}, {"🕹", "Моды игр"}, {"🎯", "Аим"}, {"👁", "ESP"}, {"⚙", "Функции"}, {"🎛", "Настройки"}, {"🎉", "Веселье"},
	}
	local RULES = {
		{"БЫСТРЫЕ", 1}, {"СОЗДАТЕЛЬ", 1}, {"СКОРОСТЬ ХОДЬБЫ", 1}, {"РЕЖИМЫ", 1}, {"ПРЫЖОК", 1}, {"ПРОЧЕЕ", 1},
		{"АВТОЗАПУСК", 7}, {"КОНФИГИ", 7}, {"ЖУРНАЛ", 7}, {"ИНФО-ПАНЕЛЬ", 7}, {"АВТОКЛИКЕР", 3}, {"СМЕНА СЕРВЕРА", 3}, {"ВЫБОР", 3}, {"МОДУЛИ", 3}, {"ИНСТРУМЕНТЫ", 3}, {"ИГРА И", 2}, {"БОТ", 2}, {"УБИТЬ", 2}, {"БЕСКОНЕЧНОЕ", 2}, {"САМОЛЁТ", 2}, {"ИГРОКИ", 2},
		{"АИМ", 4},
		{"ESP", 5},
		{"КАМЕРА", 7}, {"УПРАВЛЕНИЕ", 7}, {"ОФОРМЛЕНИЕ", 7}, {"ПРЕМИУМ", 7}, {"ВЕСЕЛЬЕ", 8},
	}
	local function tabOf(title)
		for _, r in ipairs(RULES) do
			if string.sub(title, 1, #r[1]) == r[1] then return r[2] end
		end
		return 6 -- всё остальное — «Функции»
	end

	local side = new("Frame", {
		Name = "Tabs", Size = UDim2.new(0, SB, 1, -36), Position = UDim2.fromOffset(0, 36),
		BackgroundColor3 = C.head, BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 4, Parent = main,
	})
	local tabBtns = {}
	local cards = {}
	local function select(n)
		for _, c in ipairs(cards) do c.f.Visible = (c.tab == n) end
		for i, b in ipairs(tabBtns) do
			b.BackgroundColor3 = (i == n) and C.on or C.card
			b.BackgroundTransparency = (i == n) and 0 or 0.2
		end
		scroll.CanvasPosition = Vector2.new(0, 0)
	end
	local searchBox
	for i, t in ipairs(TABS) do
		local b = new("TextButton", {
			Size = UDim2.new(1, -14, 0, 33), Position = UDim2.fromOffset(7, 8 + (i - 1) * 38), Text = t[1] .. " " .. t[2],
			Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text, BackgroundColor3 = C.card, BackgroundTransparency = 0.2,
			BorderSizePixel = 0, ZIndex = 5, Parent = side,
		}, {round(10)})
		b.MouseButton1Click:Connect(function()
			ui.tab = i
			if searchBox and searchBox.Text ~= "" then searchBox.Text = "" end
			select(i); saveUi()
		end)
		tabBtns[i] = b
	end

	__tabStage = "buttons-done"
	-- собираем карточки; прячем только те, что относятся к другим вкладкам
	local okC, errC = pcall(function()
		for _, f in ipairs(scroll:GetChildren()) do
			if f:IsA("Frame") then
				local t = f:FindFirstChildOfClass("TextLabel")
				local title = t and t.Text or ""
				table.insert(cards, {f = f, tab = tabOf(title)})
				if string.sub(title, 1, #"СОЗДАТЕЛЬ") == "СОЗДАТЕЛЬ" then f.LayoutOrder = -1 end
			end
		end
	end)
	if not okC then warn("[SpeedMenu] вкладки: " .. tostring(errC)) end
	if not okQ then warn("[SpeedMenu] быстрые переключатели: " .. tostring(errQ)) end
	-- видимые подсказки об ошибках прямо в окне
	local msg = (not okQ and ("перекл.: " .. tostring(errQ)) or "") .. (not okC and (" вкл.: " .. tostring(errC)) or "")
	if msg ~= "" then
		new("TextLabel", {
			Size = UDim2.new(1, -10, 0, 80), Position = UDim2.new(0, 5, 1, -85), BackgroundTransparency = 1, Text = msg,
			Font = Enum.Font.Gotham, TextSize = 9, TextColor3 = Color3.fromRGB(255, 120, 120), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5, Parent = side,
		})
	end
	select(math.clamp(ui.tab, 1, #TABS))

	__tabStage = "select-done"
	-- ----- поиск по всем функциям меню (по названиям карточек и кнопок) -----
	local function fold(str)
		local ok, res = pcall(function()
			local out = {}
			for _, cp in utf8.codes(str) do
				if cp >= 0x430 and cp <= 0x44F then cp = cp - 0x20
				elseif cp == 0x451 then cp = 0x401
				elseif cp >= 97 and cp <= 122 then cp = cp - 32 end
				table.insert(out, utf8.char(cp))
			end
			return table.concat(out)
		end)
		return ok and res or string.upper(str)
	end
	pcall(function()
		for _, c in ipairs(cards) do
			local parts = {}
			for _, d in ipairs(c.f:GetDescendants()) do
				if d:IsA("TextLabel") or d:IsA("TextButton") then table.insert(parts, d.Text) end
			end
			c.hay = fold(table.concat(parts, " "))
		end
	end)
	__trk.addCard = function(f)
		local t = f:FindFirstChildOfClass("TextLabel")
		local c = {f = f, tab = tabOf(t and t.Text or "")}
		local parts = {}
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("TextLabel") or d:IsA("TextButton") then table.insert(parts, d.Text) end
		end
		c.hay = fold(table.concat(parts, " "))
		table.insert(cards, c)
		f.Visible = (c.tab == ui.tab)
	end
	local cSearch = card("ПОИСК ПО ФУНКЦИЯМ", 76, -5)
	searchBox = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 30), Position = UDim2.fromOffset(12, 26), Text = "", PlaceholderText = "Например: полёт, ESP, аим, свет…",
		ClearTextOnFocus = false, Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = C.text,
		PlaceholderColor3 = Color3.fromRGB(130, 124, 170), BackgroundColor3 = C.field, Parent = cSearch,
	}, {round(8)})
	local found = new("TextLabel", {
		Size = UDim2.new(1, -24, 0, 14), Position = UDim2.fromOffset(12, 58), BackgroundTransparency = 1, Text = "",
		Font = Enum.Font.Gotham, TextSize = 10, TextColor3 = C.sub, TextXAlignment = Enum.TextXAlignment.Left, Parent = cSearch,
	})
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local q = fold((searchBox.Text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
		if q == "" then
			found.Text = ""
			select(math.clamp(ui.tab, 1, #TABS))
			return
		end
		local n = 0
		for _, c in ipairs(cards) do
			local hit = c.hay ~= nil and string.find(c.hay, q, 1, true) ~= nil
			c.f.Visible = hit
			if hit then n = n + 1 end
		end
		found.Text = n > 0 and ("Найдено карточек: " .. n .. " (из всех вкладок)") or "Ничего не найдено"
	end)

	__tabStage = "ok"
	-- ----- полное закрытие скрипта -----
	local ORIG_GRAV = workspace.Gravity
	local closing = false
	local function closeAll()
		if closing then return end
		closing = true
		-- 1) вернуть всё как было
		pcall(function()
			enabled, flying, noclip, god, esp, antiAfk = false, false, false, false, false, false
			infJump, jumpOn, fuelOn, durOn, planeGhost, seeThrough, voidOn, sprintOn = false, false, false, false, false, false, false, false
		end)
		pcall(stopFly)
		pcall(function()
			local h = getHum()
			if h then
				h.WalkSpeed = DEFAULT
				h.JumpPower = 50
				h:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			end
			local cam = workspace.CurrentCamera
			if cam then
				cam.FieldOfView = 70
				cam.CameraType = Enum.CameraType.Custom
				if h then cam.CameraSubject = h end
			end
			workspace.Gravity = ORIG_GRAV
		end)
		pcall(function()
			local l = _G.SpeedMenuAimLib
			if l and l.setAim then l.setAim(false) end
		end)
		pcall(function()
			local t = _G.SpeedMenuTools
			if t and t.set then
				for _, n in ipairs({"fullbright", "nofog", "fps", "zoom", "autoclick", "objesp"}) do pcall(t.set, n, false) end
			end
		end)
		for _, fn in ipairs(_G.SpeedMenuCleanup or {}) do pcall(fn) end
		-- 2) отключить все события и привязки кадров
		for _, c in ipairs(__trk.conns) do pcall(function() c:Disconnect() end) end
		for _, n in ipairs({"SpeedMenuAim", "SpeedMenuBot", "SpeedMenuEsp", "SpeedMenuCandy"}) do
			pcall(function() RunService:UnbindFromRenderStep(n) end)
		end
		-- 3) убрать весь интерфейс
		pcall(function()
			for _, g in ipairs(parent:GetChildren()) do
				if string.sub(g.Name, 1, 9) == "SpeedMenu" then g:Destroy() end
			end
		end)
		pcall(function() gui:Destroy() end)
		_G.SpeedMenuAimLib, _G.SpeedMenuTools, _G.SpeedMenuShowModules, _G.SpeedMenuClose, _G.SpeedMenuCleanup, _G.SpeedMenuVoidBtn, _G.SpeedMenuProfile = nil, nil, nil, nil, nil, nil, nil
		print("[SpeedMenu] скрипт закрыт")
	end
	_G.SpeedMenuClose = closeAll
	local closeBtn = new("TextButton", {
		Size = UDim2.fromOffset(28, 24), Position = UDim2.new(1, -70, 0, 6), Text = "✕", Font = Enum.Font.GothamBold, TextSize = 14,
		TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = C.danger, Parent = header,
	}, {round(6)})
	local confirmT = 0
	closeBtn.MouseButton1Click:Connect(function()
		if os.clock() - confirmT < 2.5 then closeAll() return end
		confirmT = os.clock()
		closeBtn.Text = "?"
		task.delay(2.5, function() if not closing then closeBtn.Text = "✕" end end)
	end)

	-- сворачивание окна прячет и боковую панель
	minBtn.MouseButton1Click:Connect(function() side.Visible = not folded end)
end, function(e)
	__trk.report("вкладки [" .. __tabStage .. "]", e)
	pcall(function()
		local t = header:FindFirstChildOfClass("TextLabel")
		if t then
			t.Text = "ОШИБКА вкладок [" .. __tabStage .. "]: " .. tostring(e)
			t.TextSize = 9; t.TextWrapped = true; t.TextColor3 = Color3.fromRGB(255, 120, 120)
		end
	end)
end)

-- =====================================================================
-- ===== КРАСОТА: градиенты, свечение, анимации нажатий для всех кнопок и карточек
-- =====================================================================
xpcall(function() --[[оформление]]
	local TweenService = game:GetService("TweenService")
	local function tw(o, p, t)
		pcall(function() TweenService:Create(o, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), p):Play() end)
	end
	local ACC = Color3.fromRGB(167, 139, 250)
	local PINK = Color3.fromRGB(240, 171, 252)

	local function styleButton(b)
		if b:GetAttribute("smStyled") then return end
		b:SetAttribute("smStyled", true)
		if b.BackgroundTransparency >= 0.9 then return end -- невидимые зоны (ползунки) не трогаем
		if not b:FindFirstChildOfClass("UICorner") then new("UICorner", {CornerRadius = UDim.new(0, 9), Parent = b}) end
		if not b:FindFirstChildOfClass("UIGradient") then
			new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 184, 212)), Rotation = 90, Parent = b})
		end
		if not b:FindFirstChildOfClass("UIStroke") then
			new("UIStroke", {Color = Color3.fromRGB(205, 180, 255), Transparency = 0.8, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = b})
		end
		local sc = new("UIScale", {Scale = 1, Parent = b})
		b.MouseEnter:Connect(function() tw(sc, {Scale = 1.03}) end)
		b.MouseLeave:Connect(function() tw(sc, {Scale = 1}) end)
		b.MouseButton1Down:Connect(function() tw(sc, {Scale = 0.94}, 0.08) end)
		b.MouseButton1Up:Connect(function() tw(sc, {Scale = 1}, 0.14) end)
	end
	local function styleBox(t)
		if t:GetAttribute("smStyled") then return end
		t:SetAttribute("smStyled", true)
		if not t:FindFirstChildOfClass("UICorner") then new("UICorner", {CornerRadius = UDim.new(0, 8), Parent = t}) end
		local st = t:FindFirstChildOfClass("UIStroke")
		if not st then st = new("UIStroke", {Color = ACC, Transparency = 0.75, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = t}) end
		t.Focused:Connect(function() tw(st, {Transparency = 0, Thickness = 1.6}) end)
		t.FocusLost:Connect(function() tw(st, {Transparency = 0.75, Thickness = 1}) end)
	end
	local function styleCard(f)
		if f:GetAttribute("smStyled") then return end
		f:SetAttribute("smStyled", true)
		local title = f:FindFirstChildOfClass("TextLabel")
		if not title then return end
		new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 192, 235)), Rotation = 90, Parent = f})
		if not f:FindFirstChildOfClass("UIStroke") then
			new("UIStroke", {Color = ACC, Transparency = 0.78, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = f})
		end
		local bar = new("Frame", {
			Size = UDim2.new(0, 3, 1, -18), Position = UDim2.fromOffset(0, 9), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = f,
		}, {
			new("UICorner", {CornerRadius = UDim.new(1, 0)}),
			new("UIGradient", {Color = ColorSequence.new(ACC, PINK), Rotation = 90}),
		})
		title.Font = Enum.Font.GothamBlack
		title.TextColor3 = Color3.new(1, 1, 1)
		new("UIGradient", {Color = ColorSequence.new(ACC, PINK), Parent = title})
	end

	-- 1) окно: мягкий градиент фона и переливающаяся рамка
	pcall(function()
		new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(185, 172, 220)), Rotation = 120, Parent = main})
	end)
	local strokeGrad
	pcall(function()
		local st = main:FindFirstChildOfClass("UIStroke")
		if st then
			st.Thickness = 2.5
			strokeGrad = new("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 80, 255)),
					ColorSequenceKeypoint.new(0.33, Color3.fromRGB(236, 72, 200)),
					ColorSequenceKeypoint.new(0.66, Color3.fromRGB(80, 130, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 80, 255)),
				}), Parent = st,
			})
		end
	end)
	-- 2) заголовок: бегущий блик
	local titleGrad
	pcall(function()
		local t = header:FindFirstChildOfClass("TextLabel")
		if t then
			t.TextColor3 = Color3.new(1, 1, 1)
			titleGrad = new("UIGradient", {
				Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 160, 255)),
					ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 160, 255)),
				}), Parent = t,
			})
		end
	end)
	-- 3) полоса прокрутки и боковая панель
	pcall(function()
		scroll.ScrollBarImageColor3 = ACC
		scroll.ScrollBarThickness = 4
	end)
	pcall(function()
		local side = main:FindFirstChild("Tabs")
		if side then
			new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(165, 148, 205)), Rotation = 90, Parent = side})
			new("Frame", {
				Size = UDim2.new(0, 1, 1, -16), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 8),
				BackgroundColor3 = ACC, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 6, Parent = side,
			})
		end
	end)
	-- 4) карточки, кнопки, поля ввода (в том числе созданные позже)
	for _, f in ipairs(scroll:GetChildren()) do
		if f:IsA("Frame") then pcall(styleCard, f) end
	end
	local function styleAny(d)
		if d:IsA("TextButton") then styleButton(d) elseif d:IsA("TextBox") then styleBox(d) end
	end
	local nStyled = 0
	for _, d in ipairs(gui:GetDescendants()) do
		pcall(styleAny, d)
		nStyled = nStyled + 1
		if nStyled % 80 == 0 then task.wait() end
	end
	gui.DescendantAdded:Connect(function(d)
		task.defer(function() pcall(styleAny, d) end)
	end)

	-- 5) анимация: вращение рамки и блик заголовка
	local rot = 0
	RunService.Heartbeat:Connect(function(dt)
		dt = dt or 0.016
		rot = (rot + dt * 40) % 360
		if strokeGrad then strokeGrad.Rotation = rot end
		if titleGrad then titleGrad.Offset = Vector2.new(math.sin(os.clock() * 1.2) * 0.8, 0) end
	end)
end, function(e) __trk.report("оформление", e) end)
end, function(e) return tostring(e) end)
if __smOk then
	print("[SpeedMenu] запущен")
	pcall(function() if type(writefile) == "function" then writefile("SpeedMenu_boot.flag", "ok") end end)
	pcall(function()
		local g = (gethui and gethui() or game:GetService("CoreGui")):FindFirstChild("SpeedMenu") or game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("SpeedMenu")
		if g then g.Enabled = true; local m = g:FindFirstChildWhichIsA("Frame"); if m then m.Visible = true end end
		game:GetService("StarterGui"):SetCore("SendNotification",{Title="W1NTEZ YT",Text="Меню готово. Фиолетовая кнопка ⚡ слева на экране — открыть/скрыть.",Duration=8})
	end)
else
	warn("[SpeedMenu] ОШИБКА ЗАПУСКА: " .. tostring(__smErr))
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "Скрипт W1NTEZ YT: ошибка", Text = tostring(__smErr):sub(1, 190), Duration = 30,
		})
	end)
end
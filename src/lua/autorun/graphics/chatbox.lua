local syntax_process
do
	local lex_setup = require("lang.lexer")
	local reader = require("lang.reader")

	local colors = {
		default = ColorBytes(255, 255, 255),
		keyword = ColorBytes(127, 159, 191),
		identifier = ColorBytes(223, 223, 223),
		string = ColorBytes(191, 127, 127),
		number = ColorBytes(127, 191, 127),
		operator = ColorBytes(191, 191, 159),
		ccomment = ColorBytes(159, 159, 159),
		cmulticomment = ColorBytes(159, 159, 159),

		comment = ColorBytes(159, 159, 159),
		multicomment = ColorBytes(159, 159, 159),
	}

	local translate = {
		TK_ge = colors.operator,
		TK_le = colors.operator,
		TK_concat = colors.operator,
		TK_eq = colors.operator,
		TK_label = colors.operator,
		["#"] = colors.operator,
		["]"] = colors.operator,
		[">"] = colors.operator,
		["/"] = colors.operator,
		["{"] = colors.operator,
		["}"] = colors.operator,
		[":"] = colors.operator,
		["*"] = colors.operator,
		["["] = colors.operator,
		["("] = colors.operator,
		[")"] = colors.operator,
		["+"] = colors.operator,
		[","] = colors.operator,
		["="] = colors.operator,
		["."] = colors.operator,
		["<"] = colors.operator,
		["-"] = colors.operator,
		[""] = colors.operator,
		TK_dots = colors.operator,


		TK_else = colors.keyword,
		TK_goto = colors.keyword,
		TK_if = colors.keyword,
		TK_nil = colors.keyword,
		TK_end = colors.keyword,
		TK_or = colors.keyword,
		TK_return = colors.keyword,
		TK_true = colors.keyword,
		TK_elseif = colors.keyword,
		TK_function = colors.keyword,
		TK_while = colors.keyword,
		TK_and = colors.keyword,
		TK_then = colors.keyword,
		TK_in = colors.keyword,
		TK_for = colors.keyword,
		TK_do = colors.keyword,
		TK_for = colors.keyword,
		TK_false = colors.keyword,
		TK_break = colors.keyword,
		TK_not = colors.keyword,

		TK_local = colors.keyword,

		TK_ne = colors.keyword,
		["/37"] = colors.keyword,

		TK_number = colors.number,
		TK_string = colors.string,
		TK_name = colors.default,
	}


	function syntax_process(str, markup)
		local ls = lex_setup(reader.string(str), str)

		local last_pos = 1
		local last_color

		for _ = 1, 1000 do
			if not pcall(ls.next, ls) then
				markup:AddString(str)
				return
			end

			if #ls.token == 1 then
				local color = colors.operator
				if color ~= last_color then
					markup:AddColor(color)
					last_color = color
				end
			else
				local color = translate[ls.token] or colors.comment
				if color ~= last_color then
					markup:AddColor(color)
					last_color = color
				end
			end


			if not ls.p then break end

			markup:AddString(str:sub(last_pos-1, ls.p-2))

			last_pos = ls.p

			if ls.token == "TK_eof" then break end
		end

		markup:AddString(str:sub(last_pos-1, last_pos-2))
	end
end


chat.panel = chat.panel or NULL

function chat.IsVisible()
	return chat.panel:IsValid() and chat.panel:IsVisible()
end

function chat.SetInputText(str)
	if not chat.panel:IsValid() then return end
	chat.panel:SetText(str)
end

function chat.GetInputText()
	if not chat.panel:IsValid() then return "" end
	return chat.panel:GetText()
end

function chat.GetInputPosition()
	if not chat.panel:IsValid() then return 0, 0 end
	return chat.panel:GetPosition()
end

function chat.GetPanel()
	if chat.panel:IsValid() then return chat.panel end

	chat.console_font = fonts.CreateFont({path = "Roboto", size = 12})

	local frame = gui.CreatePanel("frame")
	frame:SetTitle("chatbox")
	frame:SetSize(Vec2(400, 250))
	frame:SetPosition(Vec2(20, render.GetHeight()-frame:GetHeight()-20))

	frame:CallOnRemove(chat.Close)

	local S = gui.skin:GetScale()

	local emotes = frame:CreatePanel("button")
	emotes:SetSize(Vec2()+16)
	emotes:SetupLayout("bottom", "right")
	emotes.OnPress = function()
		local frame = gui.CreatePanel("frame")
		frame:SetSize(Vec2()+256)
		frame:SetPosition(emotes:GetWorldPosition())
		frame:SetTitle(L"smileys")

		local edit = frame:CreatePanel("text_edit")
		edit:SetMargin(Rect()+3)
		--edit:SetHeight(16)
		edit:SetupLayout("top", "fill_x")
		edit:RequestFocus()

		local scroll = frame:CreatePanel("scroll")
		scroll:SetupLayout("top", "fill")
		scroll:SetXScrollBar(false)

		local grid = scroll:SetPanel(gui.CreatePanel("base"))
		grid:SetStack(true)
		grid:SetNoDraw(true)

		edit.OnTextChanged = function(_, str)
			grid:RemoveChildren()

			local i = 0

			for name, path in pairs(chathud.emote_shortucts) do
				if name:find(str) then
					local url = path:match("<texture=(.+)>")
					local icon = grid:CreatePanel("button")
					icon:SetImagePath(url)
					icon:SetSize(Vec2()+32)
					if i > 100 then break end
					i = i + 1
				end
			end

			grid:Layout()
		end

		grid.OnLayout = function()
			grid:SetWidth(scroll:GetWidth())
			grid:SizeToChildrenHeight()
		end
	end

	local image = emotes:CreatePanel("image")
	image:SetSize(Vec2()+16)
	image:SetIgnoreMouse(true)
	image:SetPath("textures/silkicons/emoticon_smile.png")

	frame.emotes = emotes

	local edit = frame:CreatePanel("text_edit")
	edit:SetMargin(Rect()+3)
	--edit:SetHeight(18)
	edit:SetupLayout("bottom", "fill_x")
	edit:AddEvent("PostDrawGUI")
	frame.edit = edit

	local tab = frame:CreatePanel("tab")
	tab:SetSize(Vec2())
	tab:SetupLayout("bottom", "fill")
	frame.tab = tab

	local page = tab:AddTab("chat")

	local scroll = page:CreatePanel("scroll")
	scroll:SetXScrollBar(false)
	scroll:SetupLayout("fill")
	page.scroll = scroll

	local text = scroll:SetPanel(gui.CreatePanel("text"))
	text:SetPadding(Rect() + S * 2)
	text.markup:SetLineWrap(true)
	text:AddEvent("ChatAddText")

	function text:OnTextChanged()
		scroll:Layout()
		scroll:ScrollToFraction(Vec2(0,1))
	end

	function text:OnChatAddText(args)
		self.markup:AddFont(gui.skin.default_font)
		self.markup:AddTable(args, true)
		self.markup:AddTagStopper()
		self.markup:AddString("\n")
	end

	local old = scroll.OnLayout
	function scroll:OnLayout(...)
		text.markup:SetMaxWidth(self:GetAreaSize().x - text:GetPadding().x - text:GetPadding().w)
		return old(self, ...)
	end

	runfile("lua/examples/2d/markup.lua", text.markup)

	edit:RequestFocus()
	--edit:SetMultiline(true)

	local i = 1
	local last_history
	local found_autocomplete

	-- autocomplete should be done after keys like space and backspace are pressed
	-- so we can use the string after modifications
	edit.OnPostKeyInput = function(self, key, press)
		if not press then return end

		local str = self:GetText():trim()

		if not str:find("\n") and edit:GetCaretPosition().x == #self:GetText() then

			local scroll = 0

			if key == "tab" then
				scroll = input.IsKeyDown("left_shift") and -1 or 1
			end

			found_autocomplete = autocomplete.Query("chatsounds", str, scroll)

			if key == "tab" and found_autocomplete[1] then
				edit:SetText(found_autocomplete[1])
				edit:SetCaretPosition(Vec2(math.huge, 0))
				return false
			end
		end
	end

	edit.OnPreKeyInput = function(self, key, press)
		if not press then return end

		local ctrl = input.IsKeyDown("left_shift") or input.IsKeyDown("right_shift")
		local str = self:GetText()

		if key == "`" then
			if chat.panel.tab:IsTabSelected("chat") then
				chat.Close()
				chat.Open("console")
			else
				chat.Close()
			end

			return
		end

		if str ~= "" and ctrl then
			return
		end

		local command_history = serializer.ReadFile("luadata", "data/cmd_history.txt") or {}

		if str == last_history or str == "" or not str:find("\n") then
			local browse = false

			if key == "up" then
				i = math.clamp(i + 1, 1, #command_history)
				browse = true
			elseif key == "down" then
				i = math.clamp(i - 1, 1, #command_history)
				browse = true
			end

			local found = command_history[i]
			if browse and found then
				edit:SetText(found)
				edit:SetCaretPosition(Vec2(#found, 0))
				last_history = found
			end
		end

		if key == "escape" then
			chat.Close()
		elseif key == "enter" or key == "keypad_enter" then
			i = 0

			if #str > 0 then
				if command_history[1] ~= str then
					table.insert(command_history, 1, str)
					serializer.WriteFile("luadata", "data/cmd_history.txt", command_history)
				end

				if chat.panel.tab:IsTabSelected("chat") then
					chat.Say(str)
					chat.Close()
				elseif chat.panel.tab:IsTabSelected("console") then
					logn("> ", str)
					commands.RunString(str, nil, true, true)
					edit:SetText("")
					chat.panel:Layout(true)
					return false
				else
					print("!?")
				end
			else
				chat.Close()
				return false
			end

			return
		end

		event.Call("ChatTextChanged", str)
	end

	edit.OnTextChanged = function(_, str)
		event.Call("ChatTextChanged", str)
		edit:SizeToText()
		edit:SetupLayout("bottom", "fill_x")
	end

	edit.OnPostDrawGUI = function()
		if not chat.IsVisible() then return end
		if found_autocomplete and #found_autocomplete > 0 then
			local pos = edit:GetWorldPosition()
			autocomplete.DrawFound(pos.x, pos.y + edit:GetHeight(), found_autocomplete, nil, 2)
		end
	end

	function tab:OnSelectTab()
		page.scroll:SetScrollFraction(Vec2(0,1))
	end

	local page = tab:AddTab("console")
	page:SetColor(gui.skin.font_edit_background)

	local scroll = page:CreatePanel("scroll")
	scroll:SetupLayout("fill")
	page.scroll = scroll

	local text = scroll:SetPanel(gui.CreatePanel("text"))
	text:SetPadding(Rect() + S * 2)
	text:SetLightMode(true)
	text:SetCopyTags(false)
	text.markup:SetSuperLightMode(true)
	text:SetTextWrap(false)
	text.markup:AddFont(chat.console_font)
	text:AddEvent("ReplPrint")
	text:AddEvent("ReplClear")
	--text:AddEvent("LogSection")

	text.OnTextChanged = function()
		scroll:ScrollToFraction(Vec2(0,1))
	end

	chat.markup = text.markup

	--[[function text:OnLogSection(type, b)
		if type == "lua error" then
			if b then
				self.markup:AddString("<texture=textures/silkicons/error.png> ", true)
				self.capture = ""
			else
				local error = self.capture:match("ERROR:%s-(%b{})")
				if error then
					self.markup:AddColor(Color(1,0,0,1))
					self.markup:AddString(error:sub(2, -2):trim())
					self.markup:AddString("\n")
				end
				self.capture = nil
			end
		end
	end]]

	function text:OnReplClear()
		self.markup:Clear()
	end

	function text:OnReplPrint(str)
		--if self.capture then
		--	self.capture = self.capture .. str
		--	return
		--end
		syntax_process(str, self.markup)
		--self.markup:AddTagStopper()
		self.markup:AddString("\n")
	end

	for _, line in ipairs(vfs.Read("logs/console_" .. jit.os:lower() .. ".txt"):split("\n")) do
		text:OnReplPrint(line:gsub("\r", ""))
	end

	if commands.history then
		for _, v in pairs(commands.history) do
			text:OnReplPrint(v)
		end
	end

	frame:SetSize(Vec2(400, 250))
	frame:SetPosition(Vec2(50, window.GetSize().y - frame:GetHeight() - 50))

	chat.panel = frame

	return frame
end

local old_mouse_trap

function chat.Open(tab)
	tab = tab or "chat"
	old_mouse_trap = window.GetMouseTrapped()

	local panel = chat.GetPanel()

	local page = panel.tab:SelectTab(tab)

	if tab == "console" then
		panel:SetPosition(Vec2(0, 0))
		panel:SetHeight(300)
		panel:CenterSimple()
		panel:MoveUp()
		panel:FillX()
	end

	panel:Minimize(true)
	panel.edit:RequestFocus()

	page.scroll:SetScrollFraction(Vec2(0,1))

	input.DisableFocus = true
	window.SetMouseTrapped(false)
end

function chat.Close()
	local panel = chat.GetPanel()

	panel:Minimize(false)
	panel.edit:SetText("")
	panel.edit:Unfocus()

	input.DisableFocus = false
	window.SetMouseTrapped(old_mouse_trap)
end

input.Bind("y", "show_chat", function()
	chat.Open()
end)

input.Bind("|", "show_chat_console", function()
	chat.Open("console")
end)
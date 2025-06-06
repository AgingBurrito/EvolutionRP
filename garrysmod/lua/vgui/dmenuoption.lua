
local PANEL = {}

AccessorFunc( PANEL, "m_pMenu", "Menu" )
AccessorFunc( PANEL, "m_bChecked", "Checked" )
AccessorFunc( PANEL, "m_bCheckable", "IsCheckable" )
AccessorFunc( PANEL, "m_bRadio", "Radio" )

function PANEL:Init()

	self:SetContentAlignment( 4 )
	self:SetTextInset( 32, 0 ) -- Room for icon on left
	self:SetChecked( false )

end

function PANEL:SetSubMenu( menu )

	self.SubMenu = menu

	if ( !IsValid( self.SubMenuArrow ) ) then

		self.SubMenuArrow = vgui.Create( "DPanel", self )
		self.SubMenuArrow.Paint = function( panel, w, h ) derma.SkinHook( "Paint", "MenuRightArrow", panel, w, h ) end

	end

end

function PANEL:AddSubMenu()

	local SubMenu = DermaMenu( true, self )
	SubMenu:SetVisible( false )
	SubMenu:SetParent( self )

	self:SetSubMenu( SubMenu )

	return SubMenu

end

function PANEL:OnCursorEntered()

	if ( IsValid( self.ParentMenu ) ) then
		self.ParentMenu:OpenSubMenu( self, self.SubMenu )
		return
	end

	self:GetParent():OpenSubMenu( self, self.SubMenu )

end

function PANEL:OnCursorExited()
end

function PANEL:Paint( w, h )

	derma.SkinHook( "Paint", "MenuOption", self, w, h )

	--
	-- Draw the button text
	--
	return false

end

function PANEL:OnMousePressed( mousecode )

	self.m_MenuClicking = true

	DButton.OnMousePressed( self, mousecode )

end

function PANEL:OnMouseReleased( mousecode )

	DButton.OnMouseReleased( self, mousecode )

	if ( self.m_MenuClicking && mousecode == MOUSE_LEFT ) then

		self.m_MenuClicking = false
		CloseDermaMenus()

	end

end

function PANEL:DoRightClick()

	if ( self:GetIsCheckable() ) then
		self:ToggleCheck()
	end

end

function PANEL:DoClickInternal()

	if ( self:GetIsCheckable() ) then
		self:ToggleCheck()
	end

	if ( self.m_pMenu ) then

		self.m_pMenu:OptionSelectedInternal( self )

	end

end

function PANEL:ToggleCheck()

	if ( self:GetRadio() ) then
		if ( self:GetChecked() ) then return end

		local menu = self:GetMenu():GetCanvas()

		for k, pnl in pairs( menu:GetChildren() ) do
			pnl:SetChecked( false )
		end
	end

	self:SetChecked( !self:GetChecked() )

end

function PANEL:SetChecked( b )
	if ( self:GetChecked() != b ) then
		self:OnChecked( b )
	end

	self.m_bChecked = b
end

function PANEL:OnChecked( b )
end

function PANEL:PerformLayout( w, h )

	self:SizeToContents()
	self:SetWide( self:GetWide() + 30 )

	w = math.max( self:GetParent():GetWide(), self:GetWide() )

	self:SetSize( w, 22 )

	if ( IsValid( self.SubMenuArrow ) ) then

		self.SubMenuArrow:SetSize( 15, 15 )
		self.SubMenuArrow:CenterVertical()
		self.SubMenuArrow:AlignRight( 4 )

	end

	DButton.PerformLayout( self, w, h )

end

function PANEL:UpdateColours( skin )

	-- If not hovered, but pressed down, choose a different color from the background!
	if ( !self.Hovered && ( self:IsDown() || self.m_bSelected ) ) then return self:SetTextStyleColor( skin.Colours.Button.Hover ) end

	-- Call the default action
	return DButton.UpdateColours( self, skin )

end

function PANEL:GenerateExample()

	-- Do nothing!

end

derma.DefineControl( "DMenuOption", "Menu Option Line", PANEL, "DButton" )

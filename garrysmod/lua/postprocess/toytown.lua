
local matToytown = Material( "pp/toytown-top" )
//matToytown:SetTexture( "$fbtexture", render.GetScreenEffectTexture() )

--[[---------------------------------------------------------
	Register the convars that will control this effect
-----------------------------------------------------------]]
local pp_toytown = CreateClientConVar( "pp_toytown", "0", false, false )
local pp_toytown_passes = CreateClientConVar( "pp_toytown_passes", "3", true, false )
local pp_toytown_size = CreateClientConVar( "pp_toytown_size", "0.4", true, false )

function DrawToyTown( NumPasses, H )
	cam.Start2D()

	surface.SetMaterial( matToytown )
	surface.SetDrawColor( 255, 255, 255, 255 )

	for i = 1, NumPasses do

		render.CopyRenderTargetToTexture( render.GetScreenEffectTexture() )

		surface.DrawTexturedRect( 0, 0, ScrW(), H )
		surface.DrawTexturedRectUV( 0, ScrH() - H, ScrW(), H, 0, 1, 1, 0 )

	end

	cam.End2D()
end

hook.Add( "RenderScreenspaceEffects", "RenderToyTown", function()

	if ( !pp_toytown:GetBool() ) then return end
	if ( !GAMEMODE:PostProcessPermitted( "toytown" ) ) then return end
	if ( !render.SupportsPixelShaders_2_0() ) then return end

	local NumPasses = pp_toytown_passes:GetInt()
	local H = math.floor( ScrH() * pp_toytown_size:GetFloat() )

	DrawToyTown( NumPasses, H )

end )

list.Set( "PostProcess", "#toytown_pp", {

	icon = "gui/postprocess/toytown.png",
	convar = "pp_toytown",
	category = "#shaders_pp",

	cpanel = function( CPanel )

		CPanel:Help( "#toytown_pp.desc" )
		CPanel:CheckBox( "#toytown_pp.enable", "pp_toytown" )

		CPanel:ToolPresets( "toytown", { pp_toytown_passes = "3", pp_toytown_size = "0.5" } )

		CPanel:NumSlider( "#toytown_pp.passes", "pp_toytown_passes", 1, 100, 0 )
		CPanel:NumSlider( "#toytown_pp.height", "pp_toytown_size", 0, 1 )

	end

} )

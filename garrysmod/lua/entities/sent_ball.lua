
AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.PrintName = "#sent_ball"
ENT.Author = "Garry Newman"
ENT.Information = "An edible bouncy ball. Press USE on the bouncy ball to eat it."
ENT.Category = "#spawnmenu.category.fun_games"

ENT.Editable = true
ENT.Spawnable = true
ENT.AdminOnly = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

ENT.MinSize = 4
ENT.MaxSize = 128

function ENT:SetupDataTables()

	self:NetworkVar( "Float", 0, "BallSize", { KeyName = "ballsize", Edit = { type = "Float", min = self.MinSize, max = self.MaxSize, order = 1 } } )
	self:NetworkVar( "Vector", 0, "BallColor", { KeyName = "ballcolor", Edit = { type = "VectorColor", order = 2 } } )

	if ( SERVER ) then
		self:NetworkVarNotify( "BallSize", self.OnBallSizeChanged )
	end

end

-- This is the spawn function. It's called when a client calls the entity to be spawned.
-- If you want to make your SENT spawnable you need one of these functions to properly create the entity
--
-- ply is the name of the player that is spawning it
-- tr is the trace from the player's eyes
--
function ENT:SpawnFunction( ply, tr, ClassName )

	if ( !tr.Hit ) then return end

	local size = math.random( 16, 48 )
	local SpawnPos = tr.HitPos + tr.HitNormal * size

	-- Make sure the spawn position is not out of bounds
	local oobTr = util.TraceLine( {
		start = tr.HitPos,
		endpos = SpawnPos,
		mask = MASK_SOLID_BRUSHONLY
	} )

	if ( oobTr.Hit ) then
		SpawnPos = oobTr.HitPos + oobTr.HitNormal * ( tr.HitPos:Distance( oobTr.HitPos ) / 2 )
	end

	local ent = ents.Create( ClassName )
	ent:SetPos( SpawnPos )
	ent:SetBallSize( size )
	ent:Spawn()
	ent:Activate()

	return ent

end

function ENT:Initialize()

	-- We do NOT want to execute anything below in this FUNCTION on CLIENT
	if ( CLIENT ) then return end

	-- Use the helibomb model just for the shadow (because it's about the same size)
	self:SetModel( "models/Combine_Helicopter/helicopter_bomb01.mdl" )

	-- We will put this here just in case, even though it should be called from OnBallSizeChanged in any case
	self:RebuildPhysics()

	-- Set the size if it wasn't set already..
	if ( self:GetBallSize() == 0 ) then self:SetBallSize( 32 ) end

	-- Select a random color for the ball, if one wasn't set.
	if ( !self:GetBallColor():IsZero() ) then return end

	self:SetBallColor( table.Random( {
		Vector( 1, 0.3, 0.3 ),
		Vector( 0.3, 1, 0.3 ),
		Vector( 1, 1, 0.3 ),
		Vector( 0.2, 0.3, 1 ),
	} ) )

end

function ENT:RebuildPhysics( value )

	-- This is necessary so that the vphysics.dll will not crash when attaching constraints to the new PhysObj after old one was destroyed
	-- TODO: Somehow figure out why it happens and/or move this code/fix to the constraint library
	self.ConstraintSystem = nil

	local size = math.Clamp( value or self:GetBallSize(), self.MinSize, self.MaxSize ) / 2.1
	self:PhysicsInitSphere( size, "metal_bouncy" )
	self:SetCollisionBounds( Vector( -size, -size, -size ), Vector( size, size, size ) )

	self:PhysWake()

end

if ( SERVER ) then

	function ENT:OnBallSizeChanged( varname, oldvalue, newvalue )

		-- Do not rebuild if the size wasn't changed
		if ( oldvalue == newvalue ) then return end

		self:RebuildPhysics( newvalue )

	end

	function ENT:KeyValue( key, val )
		if ( key == "ball_size" ) then self:SetBallSize( val ) end
		if ( key == "rendercolor" ) then self:SetBallColor( Vector( val ) / 255 ) end
	end

end

local BounceSound = Sound( "garrysmod/balloon_pop_cute.wav" )

function ENT:PhysicsCollide( data, physobj )

	-- Play sound on bounce
	if ( data.Speed > 60 && data.DeltaTime > 0.2 ) then

		local pitch = 32 + 128 - math.Clamp( self:GetBallSize(), self.MinSize, self.MaxSize )
		sound.Play( BounceSound, self:GetPos(), 75, math.random( pitch - 10, pitch + 10 ), math.Clamp( data.Speed / 150, 0, 1 ) )

	end

	-- Bounce like a crazy bitch
	local LastSpeed = math.max( data.OurOldVelocity:Length(), data.Speed )
	local NewVelocity = physobj:GetVelocity()
	NewVelocity:Normalize()

	LastSpeed = math.max( NewVelocity:Length(), LastSpeed )

	local TargetVelocity = NewVelocity * LastSpeed * 0.9

	physobj:SetVelocity( TargetVelocity )

end

function ENT:OnTakeDamage( dmginfo )

	-- React physically when shot/getting blown
	self:TakePhysicsDamage( dmginfo )

end

function ENT:Use( activator, caller )

	self:Remove()

	if ( activator:IsPlayer() ) then

		-- Give the collecting player some free health
		local health = activator:Health()
		activator:SetHealth( health + 5 )
		activator:SendLua( "achievements.EatBall()" )

	end

end

if ( SERVER ) then return end -- We do NOT want to execute anything below in this FILE on SERVER

local matBall = Material( "sprites/sent_ball" )

function ENT:Draw()

	render.SetMaterial( matBall )

	local pos = self:GetPos()
	local lcolor = render.ComputeLighting( pos, Vector( 0, 0, 1 ) )
	local c = self:GetBallColor()

	lcolor.x = c.r * ( math.Clamp( lcolor.x, 0, 1 ) + 0.5 ) * 255
	lcolor.y = c.g * ( math.Clamp( lcolor.y, 0, 1 ) + 0.5 ) * 255
	lcolor.z = c.b * ( math.Clamp( lcolor.z, 0, 1 ) + 0.5 ) * 255

	local size = math.Clamp( self:GetBallSize(), self.MinSize, self.MaxSize )
	render.DrawSprite( pos, size, size, Color( lcolor.x, lcolor.y, lcolor.z, 255 ) )

end

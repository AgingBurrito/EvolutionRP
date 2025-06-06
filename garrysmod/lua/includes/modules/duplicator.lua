

--[[---------------------------------------------------------
   Duplicator module,
   to add new constraints or entity classes use...

   duplicator.RegisterConstraint( "name", funct, ... )
   duplicator.RegisterEntityClass( "class", funct, ... )

-----------------------------------------------------------]]

module( "duplicator", package.seeall )

--
-- When saving or loading all coordinates are saved relative to these
--
local LocalPos = Vector( 0, 0, 0 )
local LocalAng = Angle( 0, 0, 0 )

--
-- Should be set to the player that is creating/copying stuff. Can be nil.
--
local ActionPlayer = nil

--
-- The physics object Saver/Loader
--
local PhysicsObject =
{
	Save = function( data, phys )

		data.Pos = phys:GetPos()
		data.Angle = phys:GetAngles()
		data.Frozen = !phys:IsMoveable()
		if ( !phys:IsGravityEnabled() ) then data.NoGrav = true end
		if ( phys:IsAsleep() ) then data.Sleep = true end

		data.Pos, data.Angle = WorldToLocal( data.Pos, data.Angle, LocalPos, LocalAng )

	end,

	Load = function( data, phys )

		if ( isvector( data.Pos ) and isangle( data.Angle ) ) then

			local pos, ang = LocalToWorld( data.Pos, data.Angle, LocalPos, LocalAng )
			phys:SetPos( pos )
			phys:SetAngles( ang )

		end

		-- Let's not Wake or put anything to sleep for now
		--[[
		if ( data.Sleep ) then
			if ( IsValid( phys ) ) then phys:Sleep() end
		else
			phys:Wake()
		end
		]]

		if ( data.Frozen ) then

			phys:EnableMotion( false )

			-- If we're being created by a player then add these to their frozen list so they can unfreeze them all
			if ( IsValid( ActionPlayer ) ) then
				ActionPlayer:AddFrozenPhysicsObject( phys:GetEntity(), phys )
			end

		end

		if ( data.NoGrav ) then phys:EnableGravity( false ) end

	end,
}

--
-- Entity physics saver
--
local EntityPhysics =
{
	--
	-- Loop each bone, calling PhysicsObject.Save
	--
	Save = function( data, Entity )

		local num = Entity:GetPhysicsObjectCount()

		for objectid = 0, num-1 do

			local obj = Entity:GetPhysicsObjectNum( objectid )
			if ( !IsValid( obj ) ) then continue end

			data[ objectid ] = {}
			PhysicsObject.Save( data[ objectid ], obj )

		end

	end,

	--
	-- Loop each bone, calling PhysicsObject.Load
	--
	Load = function( data, Entity )

		if ( !istable( data ) ) then return end

		for objectid, objectdata in pairs( data ) do

			local Phys = Entity:GetPhysicsObjectNum( objectid )
			if ( !IsValid( Phys ) ) then continue end

			PhysicsObject.Load( objectdata, Phys )

		end

	end,
}

--
-- Entity saver
--
local EntitySaver =
{
	--
	-- Called on each entity when saving
	--
	Save = function( data, ent )

		--
		-- Merge the entities actual table with the table we're saving
		-- this is terrible behaviour - but it's what we've always done.
		--
		if ( ent.PreEntityCopy ) then ent:PreEntityCopy() end
		table.Merge( data, ent:GetTable() )
		if ( ent.PostEntityCopy ) then ent:PostEntityCopy() end

		--
		-- Set so me generic variables that pretty much all entities
		-- would like to save.
		--
		data.Pos				= ent:GetPos()
		data.Angle				= ent:GetAngles()
		data.Class				= ent:GetClass()
		data.Model				= ent:GetModel()
		data.Skin				= ent:GetSkin()
		data.Mins, data.Maxs	= ent:GetCollisionBounds()
		data.ColGroup			= ent:GetCollisionGroup()
		data.Name				= ent:GetName()
		data.WorkshopID			= ent:GetWorkshopID()
		data.CurHealth			= ent:Health()
		data.MaxHealth			= ent:GetMaxHealth()
		data.Persistent			= ent:GetPersistent()

		data.Pos, data.Angle	= WorldToLocal( data.Pos, data.Angle, LocalPos, LocalAng )

		data.ModelScale			= ent:GetModelScale()
		if ( data.ModelScale == 1 ) then data.ModelScale = nil end

		-- This is useful for addons to determine if the entity was map spawned or not
		if ( ent:CreatedByMap() ) then
			data.MapCreationID = ent:MapCreationID()
		end

		-- Allow the entity to override the class
		-- (this is a hack for the jeep, since it's real class is different from the one it reports as)
		if ( ent.ClassOverride ) then data.Class = ent.ClassOverride end

		-- Save the physics
		data.PhysicsObjects = data.PhysicsObjects or {}
		EntityPhysics.Save( data.PhysicsObjects, ent )


		-- Flexes
		data.FlexScale = ent:GetFlexScale()
		for i = 0, ent:GetFlexNum() do

			local w = ent:GetFlexWeight( i )
			if ( w != 0 ) then
				data.Flex = data.Flex or {}
				data.Flex[ i ] = w
			end

		end

		-- Body Groups
		local bg = ent:GetBodyGroups()
		if ( bg ) then

			for k, v in pairs( bg ) do

				--
				-- If it has a non default setting, save it.
				--
				if ( ent:GetBodygroup( v.id ) > 0 ) then

					data.BodyG = data.BodyG or {}
					data.BodyG[ v.id ] = ent:GetBodygroup( v.id )

				end

			end

		end

		-- Non Sandbox tool set color and materials
		if ( ent:GetColor() != color_white ) then data._DuplicatedColor = ent:GetColor() end
		if ( ent:GetMaterial() != "" ) then data._DuplicatedMaterial = ent:GetMaterial() end

		-- Sub materials
		local subMaterials = {}

		for i = 0, 31 do

			local mat = ent:GetSubMaterial( i )

			if ( mat:len() > 0 ) then
				subMaterials[ i ] = mat
			end

		end

		if ( !table.IsEmpty( subMaterials ) ) then data._DuplicatedSubMaterials = subMaterials end

		-- Bone Manipulations
		if ( ent:HasBoneManipulations() ) then

			data.BoneManip = {}

			for i = 0, ent:GetBoneCount() do

				local t = {}

				local s = ent:GetManipulateBoneScale( i )
				local a = ent:GetManipulateBoneAngles( i )
				local p = ent:GetManipulateBonePosition( i )

				if ( s != Vector( 1, 1, 1 ) ) then t[ 's' ] = s end -- scale
				if ( a != angle_zero ) then t[ 'a' ] = a end -- angle
				if ( p != vector_origin ) then t[ 'p' ] = p end -- position

				if ( !table.IsEmpty( t ) ) then
					data.BoneManip[ i ] = t
				end

			end

		end

		--
		-- Store networks vars/DT vars (assigned using SetupDataTables)
		--
		if ( ent.GetNetworkVars ) then
			data.DT = ent:GetNetworkVars()
		end

		-- Make this function on your SENT if you want to modify the
		-- returned table specifically for your entity.
		if ( ent.OnEntityCopyTableFinish ) then
			ent:OnEntityCopyTableFinish( data )
		end

		--
		-- Exclude this crap
		--
		for k, v in pairs( data ) do

			if ( isfunction( v ) ) then
				data[k] = nil
			end

		end

		data.OnDieFunctions = nil
		data.AutomaticFrameAdvance = nil
		data.BaseClass = nil

	end,

	--
	-- Fill in the data!
	--
	Load = function( data, ent )

		if ( !data ) then return end

		-- We do the second check for models because apparently setting the model on an NPC causes some position changes
		-- And to prevent NPCs going into T-pose briefly upon duplicating
		if ( data.Model and data.Model != ent:GetModel() ) then ent:SetModel( data.Model ) end
		if ( data.Angle ) then ent:SetAngles( data.Angle ) end
		if ( data.Pos ) then ent:SetPos( data.Pos ) end
		if ( data.Skin ) then ent:SetSkin( data.Skin ) end
		if ( data.Flex ) then DoFlex( ent, data.Flex, data.FlexScale ) end
		if ( data.BoneManip ) then DoBoneManipulator( ent, data.BoneManip ) end
		if ( data.ModelScale ) then ent:SetModelScale( data.ModelScale, 0 ) end
		if ( data.ColGroup ) then ent:SetCollisionGroup( data.ColGroup ) end
		if ( data.Name ) then ent:SetName( data.Name ) end
		if ( data.Persistent ) then ent:SetPersistent( data.Persistent ) end
		if ( data._DuplicatedColor ) then ent:SetColor( data._DuplicatedColor ) end
		if ( data._DuplicatedMaterial ) then ent:SetMaterial( data._DuplicatedMaterial ) end

		-- Sub materials
		if ( data._DuplicatedSubMaterials ) then

			for id, mat in pairs( data._DuplicatedSubMaterials ) do

				ent:SetSubMaterial( id, mat )

			end

		end

		-- Body Groups
		if ( data.BodyG ) then
			for k, v in pairs( data.BodyG ) do
				ent:SetBodygroup( k, v )
			end
		end

		--
		-- Restore NetworkVars/DataTable variables (the SetupDataTables values)
		--
		if ( ent.RestoreNetworkVars ) then
			ent:RestoreNetworkVars( data.DT )
		end

	end,
}

local DuplicateAllowed = {}

--
-- Allow this entity to be duplicated
--
function Allow( classname )

	DuplicateAllowed[ classname ] = true

end

--
-- Disallow this entity to be duplicated
--
function Disallow( classname )

	DuplicateAllowed[ classname ] = false

end

--
-- Returns true if we can copy/paste this entity
--
function IsAllowed( classname )

	return DuplicateAllowed[ classname ]

end

ConstraintType 	= ConstraintType or {}

--
-- When a copy is copied it will be translated according to these
-- If you set them - make sure to set them back to 0 0 0!
--
function SetLocalPos( v ) LocalPos = v * 1 end
function SetLocalAng( v ) LocalAng = v * 1 end

--[[---------------------------------------------------------
	Register a constraint to be duplicated
-----------------------------------------------------------]]
function RegisterConstraint( _name_, _function_, ... )

	ConstraintType[ _name_ ] = {}

	ConstraintType[ _name_ ].Func = _function_
	ConstraintType[ _name_ ].Args = { ... }

end

EntityClasses = EntityClasses or {}

--[[---------------------------------------------------------
	Register an entity's class, to allow it to be duplicated
-----------------------------------------------------------]]
function RegisterEntityClass( _name_, _function_, ... )

	EntityClasses[ _name_ ] = {}

	EntityClasses[ _name_ ].Func = _function_
	EntityClasses[ _name_ ].Args = {...}

	Allow( _name_ )

end

--[[---------------------------------------------------------
   Returns an entity class factory
-----------------------------------------------------------]]
function FindEntityClass( _name_ )

	if ( !_name_ ) then return end
	return EntityClasses[ _name_ ]

end

BoneModifiers = BoneModifiers or {}
EntityModifiers = EntityModifiers or {}

function RegisterBoneModifier( _name_, _function_ ) BoneModifiers[ _name_ ] = _function_ end
function RegisterEntityModifier( _name_, _function_ ) EntityModifiers[ _name_ ] = _function_ end

--
-- Try to work out which workshop addons are used by this dupe. This is far from perfect.
--
function FigureOutRequiredAddons( Dupe )

	local addons = {}
	for _, ent in pairs( Dupe.Entities ) do
		for id, addon in pairs( engine.GetAddons() ) do
			-- Model
			if ( ent.Model and file.Exists( ent.Model, addon.title ) ) then
				addons[ addon.wsid ] = true
			end

			-- Material override
			if ( ent._DuplicatedMaterial and file.Exists( "materials/" .. ent._DuplicatedMaterial .. ".vmt", addon.title ) ) then
				addons[ addon.wsid ] = true
			end
		end
	end
	Dupe.RequiredAddons = table.GetKeys( addons )

end

if ( CLIENT ) then return end

--[[---------------------------------------------------------
   Restore's the flex data
-----------------------------------------------------------]]
function DoFlex( ent, Flex, Scale )

	if ( !Flex ) then return end
	if ( !IsValid( ent ) ) then return end

	for k, v in pairs( Flex ) do
		ent:SetFlexWeight( k, v )
	end

	if ( Scale ) then
		ent:SetFlexScale( Scale )
	end

end

--[[---------------------------------------------------------
   Restore's the bone's data
-----------------------------------------------------------]]
function DoBoneManipulator( ent, Bones )

	if ( !Bones ) then return end
	if ( !IsValid( ent ) ) then return end

	for k, v in pairs( Bones ) do

		if ( v.s ) then ent:ManipulateBoneScale( k, v.s ) end
		if ( v.a ) then ent:ManipulateBoneAngles( k, v.a ) end
		if ( v.p ) then ent:ManipulateBonePosition( k, v.p ) end

	end

end

--[[---------------------------------------------------------
   Generic function for duplicating stuff
-----------------------------------------------------------]]
function GenericDuplicatorFunction( Player, data )

	if ( !IsAllowed( data.Class ) ) then
		-- MsgN( "duplicator: ", data.Class, " isn't allowed to be duplicated!" )
		return
	end

	--
	-- Is this entity 'admin only'?
	--
	if ( IsValid( Player ) and !Player:IsAdmin() ) then

		if ( !scripted_ents.GetMember( data.Class, "Spawnable" ) ) then return end
		if ( scripted_ents.GetMember( data.Class, "AdminOnly" ) ) then return end

	end

	local Entity = ents.Create( data.Class )
	if ( !IsValid( Entity ) ) then return end

	-- TODO: Entity not found - maybe spawn a prop_physics with their model?

	DoGeneric( Entity, data )

	Entity:Spawn()
	Entity:Activate()

	EntityPhysics.Load( data.PhysicsObjects, Entity )

	table.Merge( Entity:GetTable(), data )

	return Entity

end

--[[---------------------------------------------------------
	Automates the process of adding crap the EntityMods table
-----------------------------------------------------------]]
function StoreEntityModifier( Entity, Type, Data )

	if ( !IsValid( Entity ) ) then return end

	Entity.EntityMods = Entity.EntityMods or {}

	-- Copy the data
	local NewData = Entity.EntityMods[ Type ] or {}
	table.Merge( NewData, Data )

	Entity.EntityMods[ Type ] = NewData

end

--[[---------------------------------------------------------
	Clear entity modification
-----------------------------------------------------------]]
function ClearEntityModifier( Entity, Type )

	if ( !IsValid( Entity ) ) then return end

	Entity.EntityMods = Entity.EntityMods or {}
	Entity.EntityMods[ Type ] = nil

end

--[[---------------------------------------------------------
	Automates the process of adding crap the BoneMods table
-----------------------------------------------------------]]
function StoreBoneModifier( Entity, BoneID, Type, Data )

	if ( !IsValid( Entity ) ) then return end

	-- Copy the data
	NewData = {}
	table.Merge( NewData, Data )

	-- Add it to the entity
	Entity.BoneMods = Entity.BoneMods or {}
	Entity.BoneMods[ BoneID ] = Entity.BoneMods[ BoneID ] or {}

	Entity.BoneMods[ BoneID ][ Type ] = NewData

end

--[[---------------------------------------------------------
	Returns a copy of the passed entity's table
-----------------------------------------------------------]]
function CopyEntTable( Ent )

	local output = {}
	EntitySaver.Save( output, Ent )
	return output

end

--
-- Work out the AABB size
--
function WorkoutSize( Ents )

	local mins = Vector( -1, -1, -1 )
	local maxs = Vector( 1, 1, 1 )


	for k, v in pairs( Ents ) do

		if ( !v.Mins or !v.Maxs ) then continue end
		if ( !v.Angle or !v.Pos ) then continue end

		--
		-- Rotate according to the entity!
		--
		local mi = v.Mins
		local ma = v.Maxs

		-- There has to be a better way
		local t1 = LocalToWorld( Vector( mi.x, mi.y, mi.z ), Angle( 0, 0, 0 ), v.Pos, v.Angle )
		local t2 = LocalToWorld( Vector( ma.x, mi.y, mi.z ), Angle( 0, 0, 0 ), v.Pos, v.Angle )
		local t3 = LocalToWorld( Vector( mi.x, ma.y, mi.z ), Angle( 0, 0, 0 ), v.Pos, v.Angle )
		local t4 = LocalToWorld( Vector( ma.x, ma.y, mi.z ), Angle( 0, 0, 0 ), v.Pos, v.Angle )

		local b1 = LocalToWorld( Vector( mi.x, mi.y, ma.z ), Angle( 0, 0, 0 ), v.Pos, v.Angle )
		local b2 = LocalToWorld( Vector( ma.x, mi.y, ma.z ), Angle( 0, 0, 0 ), v.Pos, v.Angle )
		local b3 = LocalToWorld( Vector( mi.x, ma.y, ma.z ), Angle( 0, 0, 0 ), v.Pos, v.Angle )
		local b4 = LocalToWorld( Vector( ma.x, ma.y, ma.z ), Angle( 0, 0, 0 ), v.Pos, v.Angle )

		mins.x = math.min( mins.x, t1.x, t2.x, t3.x, t4.x, b1.x, b2.x, b3.x, b4.x )
		mins.y = math.min( mins.y, t1.y, t2.y, t3.y, t4.y, b1.y, b2.y, b3.y, b4.y )
		mins.z = math.min( mins.z, t1.z, t2.z, t3.z, t4.z, b1.z, b2.z, b3.z, b4.z )

		maxs.x = math.max( maxs.x, t1.x, t2.x, t3.x, t4.x, b1.x, b2.x, b3.x, b4.x )
		maxs.y = math.max( maxs.y, t1.y, t2.y, t3.y, t4.y, b1.y, b2.y, b3.y, b4.y )
		maxs.z = math.max( maxs.z, t1.z, t2.z, t3.z, t4.z, b1.z, b2.z, b3.z, b4.z )

	end

	return mins, maxs

end

--[[---------------------------------------------------------
   Copy this entity, and all of its constraints and entities
   and put them in a table.
-----------------------------------------------------------]]
function Copy( Ent, AddToTable )

	local Ents = {}
	local Constraints = {}

	GetAllConstrainedEntitiesAndConstraints( Ent, Ents, Constraints )

	local EntTables = {}
	if ( AddToTable != nil ) then EntTables = AddToTable.Entities or {} end

	for k, v in pairs( Ents ) do
		EntTables[ k ] = CopyEntTable( v )
	end

	local ConstraintTables = {}
	if ( AddToTable != nil ) then ConstraintTables = AddToTable.Constraints or {} end

	for k, v in pairs( Constraints ) do
		ConstraintTables[ k ] = v
	end

	local mins, maxs = WorkoutSize( EntTables )

	return {
		Entities = EntTables,
		Constraints = ConstraintTables,
		Mins = mins,
		Maxs = maxs
	}

end

function CopyEnts( Ents )

	local Ret = { Entities = {}, Constraints = {} }

	for k, v in pairs( Ents ) do

		Ret = Copy( v, Ret )

	end

	return Ret

end

--[[---------------------------------------------------------
   Create an entity from a table.
-----------------------------------------------------------]]
function CreateEntityFromTable( Player, EntTable )

	-- Get rid of stored outputs, they are being abused
	-- Do it here, so that entities can store new ones on creation
	EntTable.m_tOutputs = nil

	--
	-- Convert position/angle to `local`
	--
	if ( EntTable.Pos and EntTable.Angle ) then

		EntTable.Pos, EntTable.Angle = LocalToWorld( EntTable.Pos, EntTable.Angle, LocalPos, LocalAng )

	end

	local EntityClass = FindEntityClass( EntTable.Class )

	-- This class is unregistered. Instead of failing try using a generic
	-- Duplication function to make a new copy..
	if ( !EntityClass ) then

		return GenericDuplicatorFunction( Player, EntTable )

	end

	-- Build the argument list
	local ArgList = {}

	for iNumber, Key in pairs( EntityClass.Args ) do

		local Arg = nil

		-- Translate keys from old system
		if ( Key == "pos" or Key == "position" ) then Key = "Pos" end
		if ( Key == "ang" or Key == "Ang" or Key == "angle" ) then Key = "Angle" end
		if ( Key == "model" ) then Key = "Model" end

		Arg = EntTable[ Key ]

		-- Special keys
		if ( Key == "Data" ) then Arg = EntTable end

		-- If there's a missing argument then unpack will stop sending at that argument so send it as `false`
		if ( Arg == nil ) then Arg = false end

		ArgList[ iNumber ] = Arg

	end

	-- Create and return the entity
	return EntityClass.Func( Player, unpack( ArgList ) )

end


--[[---------------------------------------------------------
  Make a constraint from a constraint table
-----------------------------------------------------------]]
function CreateConstraintFromTable( Constraint, EntityList, ply )

	local Factory = ConstraintType[ Constraint.Type ]
	if ( !Factory ) then return end

	-- Unfortunately we cannot distinguish here if this is a ropeconstraint or not
	if ( ply and !ply:CheckLimit( "constraints" ) ) then return end
	if ( ply and !ply:CheckLimit( "ropeconstraints" ) ) then return end

	local args = {}
	for k, key in pairs( Factory.Args ) do

		local val = Constraint[ key ]

		for i = 1, 6 do

			if ( Constraint.Entity[ i ] ) then

				if ( key == "Ent" .. i ) then
					val = EntityList[ Constraint.Entity[ i ].Index ]
					if ( Constraint.Entity[ i ].World ) then
						val = game.GetWorld()
					end
				end

				if ( key == "Bone" .. i ) then val = Constraint.Entity[ i ].Bone or 0 end
				if ( key == "LPos" .. i ) then val = Constraint.Entity[ i ].LPos end
				if ( key == "WPos" .. i ) then val = Constraint.Entity[ i ].WPos end
				if ( key == "Length" .. i ) then val = Constraint.Entity[ i ].Length or 0 end

			end
		end

		-- A little hack to give the duped constraints the correct player object
		if ( key:lower() == "pl" or key:lower() == "ply" or key:lower() == "player" ) then val = ply end

		-- If there's a missing argument then unpack will stop sending at that argument
		if ( val == nil ) then val = false end

		table.insert( args, val )

	end

	-- Pulley, Hydraulic can return up to 4 ents
	local const1, const2, const3, const4 = Factory.Func( unpack( args ) )

	-- Hacky way to determine if the constraint is a rope one, since we have no better way
	local function IsRopeConstraint( ent ) return ent and ent:GetClass() == "keyframe_rope" end
	local isRope = IsRopeConstraint( const1 ) || IsRopeConstraint( const2 ) || IsRopeConstraint( const3 ) || IsRopeConstraint( const4 )
	local constraintType = isRope and "ropeconstraints" or "constraints"

	-- If in Sandbox, keep track of this.
	if ( ply and ply.AddCleanup and IsValid( const1 ) ) then
		ply:AddCount( constraintType, const1 )

		-- Hack: special case for nocollide
		if ( const1:GetClass() == "logic_collision_pair" ) then constraintType = "nocollide" end
		ply:AddCleanup( constraintType, const1 )
		ply:AddCleanup( constraintType, const2 )
		ply:AddCleanup( constraintType, const3 )
		ply:AddCleanup( constraintType, const4 )
	end

	return const1, const2, const3, const4

end

--[[---------------------------------------------------------
   Given entity list and constranit list, create all entities
   and return their tables
-----------------------------------------------------------]]
function Paste( Player, entityList, constraintList )

	--
	-- Store the player
	--
	local oldplayer = ActionPlayer
	ActionPlayer = Player

	--
	-- Copy the table - because we're gonna be changing some stuff on it.
	--
	local EntityList = table.Copy( entityList )
	local ConstraintList = table.Copy( constraintList )

	local CreatedEntities = {}

	--
	-- Create the Entities
	--
	for k, v in pairs( EntityList ) do

		local e = nil
		local b = ProtectedCall( function() e = CreateEntityFromTable( Player, v ) end )
		if ( !b ) then continue end

		if ( IsValid( e ) ) then

			--
			-- Call this here ( as well as before :Spawn) because Spawn/Init might have stomped the values
			--
			if ( e.RestoreNetworkVars ) then
				e:RestoreNetworkVars( v.DT )
			end

			if ( e.OnDuplicated ) then
				e:OnDuplicated( v )
			end

		end

		CreatedEntities[ k ] = e

		if ( CreatedEntities[ k ] ) then

			CreatedEntities[ k ].BoneMods = table.Copy( v.BoneMods )
			CreatedEntities[ k ].EntityMods = table.Copy( v.EntityMods )
			CreatedEntities[ k ].PhysicsObjects = table.Copy( v.PhysicsObjects )

		else

			CreatedEntities[ k ] = nil

		end

	end

	--
	-- Apply modifiers to the created entities
	--
	for EntID, Ent in pairs( CreatedEntities ) do

		ApplyEntityModifiers( Player, Ent )
		ApplyBoneModifiers( Player, Ent )

		if ( Ent.PostEntityPaste ) then
			Ent:PostEntityPaste( Player or NULL, Ent, CreatedEntities )
		end

	end

	local CreatedConstraints = {}

	--
	-- Create constraints
	--
	for k, Constraint in pairs( ConstraintList ) do

		local Entity = nil
		ProtectedCall( function() Entity = CreateConstraintFromTable( Constraint, CreatedEntities, Player ) end )

		if ( IsValid( Entity ) ) then
			table.insert( CreatedConstraints, Entity )
		end

	end

	ActionPlayer = oldplayer

	return CreatedEntities, CreatedConstraints

end


--[[---------------------------------------------------------
  Applies entity modifiers
-----------------------------------------------------------]]
function ApplyEntityModifiers( Player, Ent )

	if ( !Ent ) then return end
	if ( !Ent.EntityMods ) then return end

	for Type, ModFunction in pairs( EntityModifiers ) do

		if ( Ent.EntityMods[ Type ] ) then

			ModFunction( Player, Ent, Ent.EntityMods[ Type ] )

		end
	end

end


--[[---------------------------------------------------------
  Applies Bone Modifiers
-----------------------------------------------------------]]
function ApplyBoneModifiers( Player, Ent )

	if ( !Ent ) then return end
	if ( !Ent.PhysicsObjects ) then return end
	if ( !Ent.BoneMods ) then return end

	--
	-- Loop every Bone on the entity
	--
	for Bone, Types in pairs( Ent.BoneMods ) do

		-- The physics object isn't valid, skip it.
		if ( !Ent.PhysicsObjects[ Bone ] ) then continue end

		-- Loop through each modifier on this bone
		for Type, Data in pairs( Types ) do

			-- Find and all the function
			local ModFunction = BoneModifiers[ Type ]
			if ( ModFunction ) then
				ModFunction( Player, Ent, Bone, Ent:GetPhysicsObjectNum( Bone ), Data )
			end

		end

	end

end


--
-- Returns all constrained Entities and constraints
-- This is kind of in the wrong place.
--
-- This function will accept the world entity to save constrains, but will not actually save the world entity itself
--
function GetAllConstrainedEntitiesAndConstraints( ent, EntTable, ConstraintTable )

	if ( !IsValid( ent ) and !ent:IsWorld() ) then return end

	-- Translate the class name
	local classname = ent:GetClass()
	if ( ent.ClassOverride ) then classname = ent.ClassOverride end

	-- Is the entity in the dupe whitelist?
	if ( !IsAllowed( classname ) and !ent:IsWorld() ) then
		-- MsgN( "duplicator: ", classname, " isn't allowed to be duplicated!" )
		return
	end

	-- Entity doesn't want to be duplicated.
	if ( ent.DoNotDuplicate ) then return end

	if ( !ent:IsWorld() ) then EntTable[ ent:EntIndex() ] = ent end

	if ( !constraint.HasConstraints( ent ) ) then return end

	local ConTable = constraint.GetTable( ent )

	for key, constr in pairs( ConTable ) do

		local index = constr.Constraint:GetCreationID()

		if ( !ConstraintTable[ index ] ) then

			-- Add constraint to the constraints table
			ConstraintTable[ index ] = constr

			-- Run the Function for any ents attached to this constraint
			for _, ConstrainedEnt in pairs( constr.Entity ) do

				if ( !ConstrainedEnt.Entity:IsWorld() ) then

					GetAllConstrainedEntitiesAndConstraints( ConstrainedEnt.Entity, EntTable, ConstraintTable )

				end

			end

		end
	end

	return EntTable, ConstraintTable

end


--
-- Return true if this entity should be removed when RemoveMapCreatedEntities is called
-- We don't want to remove all entities.
--
local function ShouldMapEntityBeRemoved( ent, classname )

	if ( classname == "prop_physics" ) then return true end
	if ( classname == "prop_physics_multiplayer" ) then return true end
	if ( classname == "prop_ragdoll" ) then return true end
	if ( ent:IsNPC() ) then return true end
	if ( IsAllowed( classname ) ) then return true end

	return false

end

--
-- Help to remove certain map created entities before creating the saved entities
-- This is obviously so we don't get duplicate props everywhere. It should be called
-- before calling Paste.
--
function RemoveMapCreatedEntities()

	for k, v in ipairs( ents.GetAll() ) do

		if ( v:CreatedByMap() and ShouldMapEntityBeRemoved( v, v:GetClass() ) ) then
			v:Remove()
		end

	end

end

--
-- BACKWARDS COMPATIBILITY - PHASE OUT, RENAME?
--
function DoGenericPhysics( Entity, Player, data )

	if ( !data or !data.PhysicsObjects ) then return end

	EntityPhysics.Load( data.PhysicsObjects, Entity )

end

function DoGeneric( ent, data )

	EntitySaver.Load( data, ent )

end

// Behaviour states
#define NPC_IDLE	(1<<0)	// Stay still
#define NPC_ROAM	(1<<1)	// Walking around
#define NPC_RETURN	(1<<2)	// Return to reference marker

#define COMSIG_NPC_UPDATE "npc_update"
#define COMSIG_NPC_RETURN "npc_return"
#define COMSIG_NPC_RETURN_FINISHED "npc_return_finished"
#define COMSIG_NPC_WANDER "npc_wander"



/mob/living/simple_animal/trader_npc
	name = "npc"
	desc = "placeholder!"
	icon_state = "axolotl"
	icon_living = "axolotl"
	icon_dead = "axolotl_dead"
	maxHealth = 10
	health = 10
	attack_verb_continuous = "gremibbles" //their teeth are just for gripping food, not used for self defense nor even chewing
	attack_verb_simple = "gremibble"
	guaranteed_butcher_results = list(/obj/item/reagent_containers/food/snacks/meat/slab = 1)
	// response_help_continuous = "pets"
	// response_help_simple = "pet"
	// response_disarm_continuous = "gently pushes aside"
	// response_disarm_simple = "gently push aside"
	// response_harm_continuous = "splats"
	// response_harm_simple = "splat"
	// pass_flags = PASSTABLE | PASSGRILLE | PASSMOB
	mob_size = MOB_SIZE_HUMAN
	//move_resist = MOVE_FORCE_VERY_STRONG
	can_be_z_moved = FALSE

	// location refs, safe to modify in mapping if you want to change their starting point, otherwise, the place spawned is it's starting position
	var/start_pos_x
	var/start_pos_y

	// try to avoid changing this, might mess up in future.
	var/area_ref
	var/turf_ref

	var/roam_area = FALSE // if true, will only wander in the area it's spawned in.

/mob/living/simple_animal/trader_npc/Initialize()
	. = ..()
	


/mob/living/simple_animal/trader_npc/ComponentInitialize()
	if(isnull(start_pos_x) || isnull(start_pos_y))
		start_pos_x = loc.x
		start_pos_y = loc.y
		turf_ref = get_turf(loc)
	
	area_ref = get_area(get_turf(loc))
	if(!turf_ref)
		var/turf/T = locate(start_pos_x, start_pos_y, loc.z)

		if(isnull(T))
			WARNING("Cannot find turf located at [start_pos_x], [start_pos_y] for NPC: [name], deleting them..") // check appropriate error warning, might be using wrong one
			return INITIALIZE_HINT_QDEL
		
		turf_ref = T
	
	AddComponent(/datum/component/trader_npc, turf_ref, roam_area ? area_ref : null, roam_area)
	. = ..()

/mob/living/simple_animal/trader_npc/handle_automated_action()
	SEND_SIGNAL(src, COMSIG_NPC_UPDATE)
	. = ..()


/mob/living/simple_animal/trader_npc/handle_automated_movement() // Who asked you to WALK? >:(
	return

/mob/living/simple_animal/trader_npc/handle_automated_speech(override) // Silence, vermin.
	return

/datum/component/trader_npc
	// configuration vars
	var/roam_area = FALSE // if true, will only wander in the area it's spawned in.
	var/roam_range = -1 // range from where it's reference tile is located, will only wander in those bounds
	var/npc_move_speed = 0.4 SECONDS
	var/timer_new_customer = 2 MINUTES
	
	// stuff you shouldn't configure..
	var/npc_status = NPC_IDLE
	var/seen_people = FALSE

	var/datum/move_loop/move/return_loop
	var/datum/move_loop/move/random_loop

	var/turf_ref
	var/area_ref

	var/mob/living/parent_ref

/datum/component/trader_npc/Initialize(source_turf, allowed_areas, roam_in_areas = FALSE, wander_range = -1)
	if(!ismovable(parent))
		return COMPONENT_INCOMPATIBLE
	
	. = ..()

	parent_ref = parent

	turf_ref = source_turf
	area_ref = allowed_areas
	roam_area = roam_in_areas
	roam_range = wander_range

	RegisterSignal(parent, COMSIG_NPC_RETURN, PROC_REF(return_to_position), turf_ref)

/datum/component/trader_npc/RegisterWithParent()
	. = ..()
	RegisterSignal(parent_ref, COMSIG_NPC_UPDATE, PROC_REF(process_ai))

/datum/component/trader_npc/UnregisterFromParent()
	. = ..()
	UnregisterSignal(parent_ref, COMSIG_NPC_UPDATE)

/datum/component/trader_npc/proc/process_ai()
	if(npc_status == NPC_IDLE)
		face_closest_carbon()
		
		if(!seen_people)
			npc_status = NPC_ROAM
	
	if(npc_status == NPC_ROAM)
		// wander
		// chance to emote?
		// listen for customer
		// return if customer present
	

	if(!return_loop)
		var/returnCheck = FALSE

		if(roam_range > 0)
			if(get_dist(turf_ref, parent) > roam_range)
				returnCheck = TRUE

		if(roam_area)
			if(get_area(parent_ref.loc) != area_ref)
				returnCheck = TRUE

		if(returnCheck)
			return_to_position(turf_ref)

/datum/component/trader_npc/proc/notice_people(mob/living/L as mob)
	// , TIMER_UNIQUE|TIMER_OVERRIDE
	seen_people = TRUE

	INVOKE_ASYNC(parent_ref,TYPE_PROC_REF(/mob/living, emote), "me", EMOTE_VISIBLE, "waves at [L].")
	addtimer(CALLBACK(parent_ref,TYPE_PROC_REF(/atom/movable, say), "Welcome, customer!"), rand(0.3 SECONDS, 1.2 SECONDS)) // Hate this, but I wanted to add a short delay after the emote.

/datum/component/trader_npc/proc/reset_noticed_people()
	seen_people = FALSE

/datum/component/trader_npc/proc/face_closest_carbon()
	var/mob/M = parent

	var/mob/living/closest_person = get_closest_atom(/mob/living, oviewers(5, M), M)

	if(closest_person)
		addtimer(CALLBACK(src,PROC_REF(reset_noticed_people)), timer_new_customer, TIMER_UNIQUE|TIMER_OVERRIDE)
		if(!seen_people)
			notice_people(closest_person)

		M.face_atom(closest_person)

// Return back to spot!
/datum/component/trader_npc/proc/return_to_position()
	var/atom/movable/AM = parent
	
	return_loop = SSmove_manager.jps_move(moving = AM, chasing = turf_ref, delay = npc_return_speed, repath_delay = 10 SECONDS, timeout = 1 MINUTES, flags = MOVEMENT_LOOP_START_FAST)

	if(!return_loop)
		return

	RegisterSignal(return_loop, COMSIG_MOVELOOP_START,PROC_REF(return_onstart))
	RegisterSignal(return_loop, COMSIG_MOVELOOP_STOP,PROC_REF(return_onstop))
	RegisterSignal(return_loop, COMSIG_PARENT_QDELETING,PROC_REF(return_ondeath))

	if(return_loop.running)
		return_onstart(return_loop) // There's a good chance it'll autostart, gotta catch that
	
	npc_status = NPC_RETURN

/datum/component/trader_npc/proc/return_onstart()
	SIGNAL_HANDLER
	RegisterSignal(parent, COMSIG_MOVABLE_MOVED,PROC_REF(return_handle_move))

/datum/component/trader_npc/proc/return_onstop()
	SIGNAL_HANDLER
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED))

/datum/component/trader_npc/proc/return_ondeath(datum/source)
	SIGNAL_HANDLER
	return_loop = null
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED))


/datum/component/trader_npc/proc/return_handle_move(datum/source, old_loc)
	SIGNAL_HANDLER

	// This can happen, because signals once sent cannot be stopped
	if(QDELETED(src))
		return
	
	if(return_loop)
		if(get_turf(parent) == turf_ref)
			qdel(return_loop)
			npc_status = NPC_IDLE
			SEND_SIGNAL(parent, COMSIG_NPC_RETURN_FINISHED)


	// to do: maybe make idle chatter?

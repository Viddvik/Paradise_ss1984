/datum/map_generator/cave_generator
	var/name = "Cave Generator"
	///Weighted list of the types that spawns if the turf is simulated
	var/weighted_simulated_turf_types = list(/turf/simulated/floor/plating/asteroid/airless = 1)
	///Expanded list of the types that spawns if the turf is open
	var/simulated_turf_types
	///Weighted list of the types that spawns if the turf is a wall
	var/weighted_wall_turf_types = list(/turf/simulated/mineral/random = 1)
	///Expanded list of the types that spawns if the turf is closed
	var/wall_turf_types


	///Weighted list of mobs that can spawn in the area.
	var/list/weighted_mob_spawn_list
	///Expanded list of mobs that can spawn in the area. Reads from the weighted list
	var/list/mob_spawn_list
	// Weighted list of Megafauna that can spawn in the caves
	///The mob spawn list but with no megafauna markers. autogenerated
	var/list/mob_spawn_no_mega_list
	// Weighted list of Megafauna that can spawn in the area
	var/list/weighted_megafauna_spawn_list
	///Expanded list of Megafauna that can spawn in the area. Reads from the weighted list
	var/list/megafauna_spawn_list
	///Weighted list of flora that can spawn in the area.
	var/list/weighted_flora_spawn_list
	///Expanded list of flora that can spawn in the area. Reads from the weighted list
	var/list/flora_spawn_list
	///Weighted list of extra features that can spawn in the area, such as geysers.
	var/list/weighted_feature_spawn_list
	///Expanded list of extra features that can spawn in the area. Reads from the weighted list
	var/list/feature_spawn_list



	///Base chance of spawning a mob
	var/mob_spawn_chance = 3
	///Base chance of spawning flora
	var/flora_spawn_chance = 2
	///Base chance of spawning features
	var/feature_spawn_chance = 0.1
	///Unique ID for this spawner
	var/string_gen

	///Chance of cells starting closed
	var/initial_closed_chance = 45
	///Amount of smoothing iterations
	var/smoothing_iterations = 20
	///How much neighbours does a dead cell need to become alive
	var/birth_limit = 4
	///How little neighbours does a alive cell need to die
	var/death_limit = 3

/datum/map_generator/cave_generator/New()
	. = ..()
	if(!weighted_mob_spawn_list)
		weighted_mob_spawn_list = list(/mob/living/simple_animal/hostile/asteroid/goldgrub = 1, /mob/living/simple_animal/hostile/asteroid/goliath = 5, /mob/living/simple_animal/hostile/asteroid/basilisk = 4, /mob/living/simple_animal/hostile/asteroid/hivelord = 3)
	mob_spawn_list = expand_weights(weighted_mob_spawn_list)
	mob_spawn_no_mega_list = expand_weights(weighted_mob_spawn_list - SPAWN_MEGAFAUNA)
	if(!weighted_megafauna_spawn_list)
		weighted_megafauna_spawn_list = GLOB.megafauna_spawn_list
	megafauna_spawn_list = expand_weights(weighted_megafauna_spawn_list)
	if(!weighted_flora_spawn_list)
		weighted_flora_spawn_list = list(/obj/structure/flora/ash/leaf_shroom = 2 , /obj/structure/flora/ash/cap_shroom = 2 , /obj/structure/flora/ash/stem_shroom = 2 , /obj/structure/flora/ash/cacti = 1, /obj/structure/flora/ash/tall_shroom = 2)
	flora_spawn_list = expand_weights(weighted_flora_spawn_list)
	if(!weighted_feature_spawn_list)
		weighted_feature_spawn_list = list(/obj/structure/spawner/lavaland/legion = 1) //this is bad, but we don't have geysers
	feature_spawn_list = expand_weights(weighted_feature_spawn_list)
	simulated_turf_types = expand_weights(weighted_simulated_turf_types)
	wall_turf_types = expand_weights(weighted_wall_turf_types)

/datum/map_generator/cave_generator/generate_terrain(list/turfs, area/generate_in)

	if(!(generate_in.area_flags & CAVES_ALLOWED))
		return
	var/start_time = REALTIMEOFDAY
	string_gen = rustg_cnoise_generate("[initial_closed_chance]", "[smoothing_iterations]", "[birth_limit]", "[death_limit]", "[world.maxx]", "[world.maxy]") //Generate the raw CA data

	for(var/turf/gen_turf as anything in turfs) //Go through all the turfs and generate them

		var/closed = string_gen[world.maxx * (gen_turf.y - 1) + gen_turf.x] != "0"
		var/turf/new_turf = pick(closed ? wall_turf_types : simulated_turf_types)
		// The assumption is this will be faster then changeturf, and changeturf isn't required since by this point
		// The old tile hasn't got the chance to init yet
		new_turf = new new_turf(gen_turf)

	var/message = "[name] terrain generation finished in [(REALTIMEOFDAY - start_time)/10]s!"
	log_startup_progress_global("Mapping", message)
	log_world(message)

/datum/map_generator/cave_generator/populate_terrain(list/turfs, area/generate_in)

	// Area var pullouts to make accessing in the loop faster
	var/flora_allowed = (generate_in.area_flags & FLORA_ALLOWED) && length(flora_spawn_list)
	var/feature_allowed = (generate_in.area_flags & FLORA_ALLOWED) && length(feature_spawn_list)
	var/mobs_allowed = (generate_in.area_flags & MOB_SPAWN_ALLOWED) && length(mob_spawn_list)
	var/megas_allowed = (generate_in.area_flags & MEGAFAUNA_SPAWN_ALLOWED) && length(megafauna_spawn_list)

	var/start_time = REALTIMEOFDAY

	for(var/turf/turf as anything in turfs)
		if(!(turf.type in simulated_turf_types)) //only put stuff on open turfs we generated, so closed walls and rivers and stuff are skipped
			continue

		// If we've spawned something yet
		var/spawned_something = FALSE

		///Spawning isn't done in procs to save on overhead on the 60k turfs we're going through.
		//FLORA SPAWNING HERE
		if(flora_allowed && prob(flora_spawn_chance))
			var/flora_type = pick(flora_spawn_list)
			new flora_type(turf)
			spawned_something = TRUE
		//FEATURE SPAWNING HERE
		if(feature_allowed && prob(feature_spawn_chance))
			var/can_spawn = TRUE
			var/atom/picked_feature = pick(feature_spawn_list)
			for(var/obj/structure/existing_feature in range(7, turf))
				if(istype(existing_feature, picked_feature))
					can_spawn = FALSE
					break
			if(can_spawn)
				new picked_feature(turf)
				spawned_something = TRUE
		//MOB SPAWNING HERE
		if(mobs_allowed && !spawned_something && prob(mob_spawn_chance))
			var/atom/picked_mob = pick(mob_spawn_list)
			if(picked_mob == SPAWN_MEGAFAUNA)
				if(megas_allowed) //this is danger. it's boss time.
					picked_mob = pick(megafauna_spawn_list)
				else //this is not danger, don't spawn a boss, spawn something else
					picked_mob = pick(mob_spawn_no_mega_list) //What if we used 100% of the brain...and did something (slightly) less shit than a while loop?
			var/can_spawn = TRUE
			// prevents tendrils spawning in each other's collapse range
			if(ispath(picked_mob, /obj/structure/spawner/lavaland))
				for(var/obj/structure/spawner/lavaland/spawn_blocker in range(4, turf))
					can_spawn = FALSE
					break
			//if the random is a standard mob, avoid spawning if there's another one within 12 tiles
			else if(ispath(picked_mob, /mob/living/simple_animal/hostile/asteroid))
				for(var/mob/living/simple_animal/hostile/asteroid/mob_blocker in urange(12, turf))
					can_spawn = FALSE
					break
			//if there's a megafauna within standard view don't spawn anything at all (This isn't really consistent, I don't know why we do this. you do you tho)
			if(can_spawn)
				for(var/mob/living/simple_animal/hostile/megafauna/found_fauna in range(7, turf))
					can_spawn = FALSE
					break
			if(can_spawn)
				if(ispath(picked_mob, /mob/living/simple_animal/hostile/megafauna/bubblegum)) //there can be only one bubblegum, so don't waste spawns on it
					weighted_megafauna_spawn_list.Remove(picked_mob)
					megafauna_spawn_list = expand_weights(weighted_megafauna_spawn_list)
					megas_allowed = megas_allowed && length(megafauna_spawn_list)
				if(ispath(picked_mob, /mob/living/simple_animal/hostile/megafauna/ancient_robot)) //same as above, we do not want multiple of these robots
					weighted_megafauna_spawn_list.Remove(picked_mob)
					megafauna_spawn_list = expand_weights(weighted_megafauna_spawn_list)
					megas_allowed = megas_allowed && length(megafauna_spawn_list)
				new picked_mob(turf)
				spawned_something = TRUE

	var/message = "[name] terrain population finished in [(REALTIMEOFDAY - start_time)/10]s!"
	log_startup_progress_global("Mapping", message)

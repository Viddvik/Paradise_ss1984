// Wires for modsuits

/datum/wires/modsuits/secure
	randomize = TRUE

/datum/wires/modsuits
	holder_type = /obj/item/mod/control
	wire_count = 6 // 4 actual, 2 duds
	proper_name = "MOD control unit"
	window_x = 345
	window_y = 90

/datum/wires/modsuits/New(atom/_holder)
	wires = list(WIRE_HACK, WIRE_DISABLE, WIRE_ELECTRIFY, WIRE_INTERFACE)
	return ..()

/datum/wires/modsuits/interactable(mob/user)
	var/obj/item/mod/control/mod = holder
	if(mod.seconds_electrified && mod.shock(user, 100)))
		return FALSE
	return FALSE

/datum/wires/modsuits/get_status()
. = ..()
	var/obj/item/mod/control/mod = holder
	+= "The orange light is [mod.seconds_electrified ? "on" : "off"]."
	+= "The red light is [mod.malfunctioning ? "off" : "blinking"]."
	+= "The green light is [mod.locked ? "on" : "off"]."
	+= "The yellow light is [mod.interface_break ? "off" : "on"]."

/datum/wires/modsuits/on_pulse(wire)
	var/obj/item/mod/control/mod = holder
	switch(wire)
		if(WIRE_HACK)
			mod.locked = !mod.locked
		if(WIRE_DISABLE)
			mod.malfunctioning = TRUE
		if(WIRE_ELECTRIFY)
			mod.seconds_electrified = 30
		if(WIRE_INTERFACE)
			mod.interface_break = !mod.interface_break

/datum/wires/modsuits/on_cut(wire, mend)
	var/obj/item/mod/control/mod = holder
	switch(wire)
		if(WIRE_HACK)
			if(!mend)
				mod.req_access = list()
		if(WIRE_DISABLE)
			mod.malfunctioning = !mend
		if(WIRE_ELECTRIFY)
			if(mend)
				mod.seconds_electrified = 0
			else
				mod.seconds_electrified = -1
		if(WIRE_INTERFACE)
			mod.interface_break = !mend

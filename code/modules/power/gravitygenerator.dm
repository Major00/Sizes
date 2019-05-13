//
// Gravity Generator
//
GLOBAL_DATUM(active_gravity_generator, /obj/machinery/gravity_generator/main)
var/const/POWER_IDLE = 0
var/const/POWER_UP = 1
var/const/POWER_DOWN = 2

var/const/GRAV_NEEDS_SCREWDRIVER = 0
var/const/GRAV_NEEDS_WELDING = 1
var/const/GRAV_NEEDS_PLASTEEL = 2
var/const/GRAV_NEEDS_WRENCH = 3

//
// Abstract Generator
//

/obj/machinery/gravity_generator
	name = "gravitational generator"
	desc = "A device which produces a gravaton field when set up."
	icon = 'icons/obj/machines/gravity_generator.dmi'
	anchored = 1
	density = 1
	use_power = 0
	unacidable = 1
	var/sprite_number = 0

/obj/machinery/gravity_generator/ex_act(severity, target)
	if(severity == 1) // Very sturdy.
		set_broken()

/obj/machinery/gravity_generator/update_icon()
	..()
	icon_state = "[get_status()]_[sprite_number]"

/obj/machinery/gravity_generator/proc/get_status()
	return "off"

// You aren't allowed to move.
/obj/machinery/gravity_generator/Move(NewLoc, Dir = 0, step_x = 0, step_y = 0, var/glide_size_override = 0)
	. = ..()
	qdel(src)

/obj/machinery/gravity_generator/proc/set_broken()
	stat |= BROKEN

/obj/machinery/gravity_generator/proc/set_fix()
	stat &= ~BROKEN

/obj/machinery/gravity_generator/part/Destroy()
	set_broken()
	if(main_part)
		qdel(main_part)
	. = ..()

//
// Part generator which is mostly there for looks
//

/obj/machinery/gravity_generator/part
	var/obj/machinery/gravity_generator/main/main_part = null

/obj/machinery/gravity_generator/part/attackby(obj/item/I as obj, mob/user as mob, params)
	return main_part.attackby(I, user)

/obj/machinery/gravity_generator/part/get_status()
	return main_part.get_status()

/obj/machinery/gravity_generator/part/attack_hand(mob/user as mob)
	return main_part.attack_hand(user)

/obj/machinery/gravity_generator/part/set_broken()
	..()
	if(main_part && !(main_part.stat & BROKEN))
		main_part.set_broken()

//
// Generator which spawns with the station.
//

/obj/machinery/gravity_generator/main/station/Initialize()
	. = ..()
	setup_parts()
	middle.overlays += "activated"
	//Set ourselves in the global var
	if (!GLOB.active_gravity_generator)
		GLOB.active_gravity_generator = src

//
// Generator an admin can spawn
//

/obj/machinery/gravity_generator/main/station/admin/Initialize()
	. = ..()
	grav_on()

//
// Main Generator with the main code
//

/obj/machinery/gravity_generator/main
	icon_state = "on_8"
	idle_power_usage = 0
	active_power_usage = 3000
	power_channel = ENVIRON
	sprite_number = 8
	use_power = 1
	interact_offline = 1
	var/on = 1
	var/breaker = 1
	var/list/parts = list()
	var/obj/middle = null
	var/charging_state = POWER_IDLE
	var/charge_count = 100
	var/current_overlay = null
	var/broken_state = 0

/obj/machinery/gravity_generator/main/Destroy() // If we somehow get deleted, remove all of our other parts.
	investigate_log("was destroyed!", "gravity")
	on = 0
	grav_off()
	for(var/obj/machinery/gravity_generator/part/O in parts)
		O.main_part = null
		qdel(O)
	. = ..()

/obj/machinery/gravity_generator/main/proc/setup_parts()
	var/turf/our_turf = get_turf(src)
	// 9x9 block obtained from the bottom middle of the block
	var/list/spawn_turfs = block(locate(our_turf.x - 1, our_turf.y + 2, our_turf.z), locate(our_turf.x + 1, our_turf.y, our_turf.z))
	var/count = 10
	for(var/turf/T in spawn_turfs)
		count--
		if(T == our_turf) // Skip our turf.
			continue
		var/obj/machinery/gravity_generator/part/part = new(T)
		if(count == 5) // Middle
			middle = part
		if(count <= 3) // Their sprite is the top part of the generator
			part.density = 0
			part.layer = WALL_OBJ_LAYER
		part.sprite_number = count
		part.main_part = src
		parts += part
		part.update_icon()

/obj/machinery/gravity_generator/main/proc/connected_parts()
	return parts.len == 8

/obj/machinery/gravity_generator/main/set_broken()
	..()
	for(var/obj/machinery/gravity_generator/M in parts)
		if(!(M.stat & BROKEN))
			M.set_broken()
	middle.overlays.Cut()
	charge_count = 0
	breaker = 0
	grav_off()
	set_power()
	set_state(0)
	investigate_log("has broken down.", "gravity")

/obj/machinery/gravity_generator/main/set_fix()
	..()
	for(var/obj/machinery/gravity_generator/M in parts)
		if(M.stat & BROKEN)
			M.set_fix()
	broken_state = 0
	update_icon()
	set_power()

// Interaction

// Fixing the gravity generator.
/obj/machinery/gravity_generator/main/attackby(obj/item/I, mob/user, params)
	var/old_broken_state = broken_state

	var/list/usable_qualities = list()
	if(GRAV_NEEDS_WRENCH)
		usable_qualities.Add(QUALITY_BOLT_TURNING)
	if(GRAV_NEEDS_WELDING)
		usable_qualities.Add(QUALITY_WELDING)
	if(GRAV_NEEDS_SCREWDRIVER)
		usable_qualities.Add(QUALITY_SCREW_DRIVING)

	var/tool_type = I.get_tool_type(user, usable_qualities, src)
	switch(tool_type)

		if(QUALITY_BOLT_TURNING)
			if(GRAV_NEEDS_WRENCH)
				if(I.use_tool(user, src, WORKTIME_FAST, tool_type, FAILCHANCE_NORMAL, required_stat = STAT_MEC))
					user << SPAN_NOTICE("You secure the plating to the framework.")
					set_fix()
					return
			return

		if(QUALITY_WELDING)
			if(GRAV_NEEDS_WELDING)
				if(I.use_tool(user, src, WORKTIME_FAST, tool_type, FAILCHANCE_NORMAL, required_stat = STAT_MEC))
					user << SPAN_NOTICE("You mend the damaged framework.")
					broken_state++
					return
			return

		if(QUALITY_SCREW_DRIVING)
			if(GRAV_NEEDS_SCREWDRIVER)
				if(I.use_tool(user, src, WORKTIME_FAST, tool_type, FAILCHANCE_NORMAL, required_stat = STAT_MEC))
					user << SPAN_NOTICE("You secure the screws of the framework.")
					broken_state++
					return
			return

		if(ABORT_CHECK)
			return

	if(GRAV_NEEDS_PLASTEEL)
		if(istype(I, /obj/item/stack/material/plasteel))
			var/obj/item/stack/material/plasteel/PS = I
			if(PS.amount >= 10)
				PS.use(10)
				user << SPAN_NOTICE("You add the plating to the framework.")
				playsound(src.loc, 'sound/machines/click.ogg', 75, 1)
				broken_state++
			else
				user << SPAN_WARNING("You need 10 sheets of plasteel!")
	if(old_broken_state != broken_state)
		update_icon()
	else
		..()

/obj/machinery/gravity_generator/main/attack_hand(mob/user as mob)
	if(!..())
		return interact(user)

/obj/machinery/gravity_generator/main/interact(mob/user as mob)
	if(stat & BROKEN)
		return
	var/dat = "Gravity Generator Breaker: "
	if(breaker)
		dat += "<span class='linkOn'>ON</span> <A href='?src=\ref[src];gentoggle=1'>OFF</A>"
	else
		dat += "<A href='?src=\ref[src];gentoggle=1'>ON</A> <span class='linkOn'>OFF</span> "

	dat += "<br>Generator Status:<br><div class='statusDisplay'>"
	if(charging_state != POWER_IDLE)
		dat += "<font class='bad'>WARNING</font> Radiation Detected. <br>[charging_state == POWER_UP ? "Charging..." : "Discharging..."]"
	else if(on)
		dat += "Powered."
	else
		dat += "Unpowered."

	dat += "<br>Gravity Charge: [charge_count]%</div>"

	var/datum/browser/popup = new(user, "gravgen", name)
	popup.set_content(dat)
	popup.open()


/obj/machinery/gravity_generator/main/Topic(href, href_list)

	if(..())
		return

	if(href_list["gentoggle"])
		breaker = !breaker
		investigate_log("was toggled [breaker ? "<font color='green'>ON</font>" : "<font color='red'>OFF</font>"] by [usr.key].", "gravity")
		set_power()
		src.updateUsrDialog()

// Power and Icon States

/obj/machinery/gravity_generator/main/power_change()
	..()
	investigate_log("has [stat & NOPOWER ? "lost" : "regained"] power.", "gravity")
	set_power()

/obj/machinery/gravity_generator/main/get_status()
	if(stat & BROKEN)
		return "fix[min(broken_state, 3)]"
	return on || charging_state != POWER_IDLE ? "on" : "off"

/obj/machinery/gravity_generator/main/update_icon()
	..()
	for(var/obj/O in parts)
		O.update_icon()

// Set the charging state based on power/breaker.
/obj/machinery/gravity_generator/main/proc/set_power()
	var/new_state = 0
	if(stat & (NOPOWER|BROKEN) || !breaker)
		new_state = 0
	else if(breaker)
		new_state = 1

	charging_state = new_state ? POWER_UP : POWER_DOWN // Startup sequence animation.
	investigate_log("is now [charging_state == POWER_UP ? "charging" : "discharging"].", "gravity")
	update_icon()

// Set the state of the gravity.
/obj/machinery/gravity_generator/main/proc/set_state(var/new_state)
	if(new_state == on)
		return
	on = new_state
	charging_state = POWER_IDLE
	use_power = on ? 2 : 1
	if(new_state) // If we turned on
		grav_on()
	else
		grav_off()
	update_icon()
	src.updateUsrDialog()

/obj/machinery/gravity_generator/main/proc/grav_on()
	if(!maps_data.station_levels.len)
		message_admins("maps_data.station_levels is blank. Gravgen isn't properly established.")
		return

	gravity_is_on = 1
	update_gravity(gravity_is_on)
	priority_announcement.Announce("The gravity generator was brought fully operational.")
	investigate_log("was brought full online and is now producing gravity.", "gravity")
	var/area/area = get_area(src)
	message_admins("The gravity generator was brought fully online. (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>[area.name]</a>)")

/obj/machinery/gravity_generator/main/proc/grav_off()
	if(!maps_data.station_levels.len)
		message_admins("maps_data.station_levels is blank. Gravgen isn't properly established.")
		return

	gravity_is_on = 0
	update_gravity(gravity_is_on)
	priority_announcement.Announce("The gravity generator was brought offline.")
	investigate_log("was brought offline and there is now no gravity.", "gravity")
	var/area/area = get_area(src)
	message_admins("The gravity generator was brought offline with no backup generator. (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>[area.name]</a>)")
	shake_everyone()

/obj/machinery/gravity_generator/main/proc/update_gravity(var/is_on)
	for(var/area/A in world)
		if(isStationLevel(A.z))
			A.update_gravity()

// Charge/Discharge and turn on/off gravity when you reach 0/100 percent.
// Also emit radiation and handle the overlays.
/obj/machinery/gravity_generator/main/Process()
	if(stat & BROKEN)
		return
	if(charging_state != POWER_IDLE)
		if(charging_state == POWER_UP && charge_count >= 100)
			set_state(1)
		else if(charging_state == POWER_DOWN && charge_count <= 0)
			set_state(0)
		else
			if(charging_state == POWER_UP)
				charge_count += 2

			else if(charging_state == POWER_DOWN)
				charge_count -= 2

			if(charge_count % 4 == 0 && prob(75)) // Let them know it is charging/discharging.
				playsound(src.loc, 'sound/effects/EMPulse.ogg', 100, 1)

			updateDialog()
			if(prob(25)) // To help stop "Your clothes feel warm." spam.
				pulse_radiation()

			var/overlay_state = null
			switch(charge_count)
				if(0 to 20)
					overlay_state = null
				if(21 to 40)
					overlay_state = "startup"
				if(41 to 60)
					overlay_state = "idle"
				if(61 to 80)
					overlay_state = "activating"
				if(81 to 100)
					overlay_state = "activated"

			if(overlay_state != current_overlay)
				if(middle)
					middle.overlays.Cut()
					if(overlay_state)
						middle.overlays += overlay_state
					current_overlay = overlay_state


/obj/machinery/gravity_generator/main/proc/pulse_radiation()
	for(var/mob/living/L in view(7, src))
		L.irradiate(20)

// Shake everyone to let them know that gravity was enagaged/disenagaged.
/obj/machinery/gravity_generator/main/proc/shake_everyone()
	for(var/mob/M in SSmobs.mob_list)
		var/turf/our_turf = get_turf(src.loc)
		if(M.client)
			shake_camera(M, 15, 1)
			M.playsound_local(our_turf, 'sound/effects/alert.ogg', 100, 1, 0.5, is_global = TRUE)

// Misc
/obj/item/weapon/paper/gravity_gen
	name = "paper- 'Generate your own gravity!'"
	info = {"<h1>Gravity Generator Instructions For Dummies</h1>
	<p>Surprisingly, gravity isn't that hard to make! All you have to do is inject deadly radioactive minerals into a ball of
	energy and you have yourself gravity! You can turn the machine on or off when required but you must remember that the generator
	will EMIT RADIATION when charging or discharging, you can tell it is charging or discharging by the noise it makes, so please WEAR PROTECTIVE CLOTHING.</p>
	<br>
	<h3>It blew up!</h3>
	<p>Don't panic! The gravity generator was designed to be easily repaired. If, somehow, the sturdy framework did not survive then
	please proceed to panic; otherwise follow these steps.</p><ol>
	<li>Secure the screws of the framework with a screwdriver.</li>
	<li>Mend the damaged framework with a welding tool.</li>
	<li>Add additional plasteel plating.</li>
	<li>Secure the additional plating with a wrench.</li></ol>"}
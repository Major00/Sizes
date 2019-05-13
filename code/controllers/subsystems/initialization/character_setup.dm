SUBSYSTEM_DEF(character_setup)
	name = "Character Setup"
	init_order = INIT_ORDER_CHAR_SETUP
	flags = SS_NO_FIRE

	var/initialized = FALSE	//set to TRUE after it has been initialized, will obviously never be set if the subsystem doesn't initialize

	var/list/prefs_awaiting_setup = list()
	var/list/preferences_datums = list()

/datum/controller/subsystem/character_setup/Initialize()
	while(prefs_awaiting_setup.len)
		var/datum/preferences/prefs = prefs_awaiting_setup[prefs_awaiting_setup.len]
		prefs_awaiting_setup.len--
		prefs.setup()
	initialized = TRUE
	. = ..()
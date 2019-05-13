/datum/antagonist/marshal
	id = ROLE_MARSHAL
	role_text = "Ironhammer Marshal"
	role_text_plural = "Ironhammer Marshals"
	bantype = ROLE_BANTYPE_CREW_SIDED
	protected_jobs = list(JOBS_COMMAND, JOBS_SECURITY)
	antaghud_indicator = "huddeathsquad"

	possible_objectives = list(
	/datum/objective/assassinate/marshal = 100,
	)

	survive_objective = /datum/objective/escape
	welcome_text = "You are a freelance bounty hunter, contracted by Ironhammer to bring in a wanted fugitive, dead or alive.\n\
	Local Ironhammer forces may assist you if you introduce yourself and win their trust. Remember that you hold no official rank \
	and they are under no obligation to help or listen to you."

/datum/antagonist/marshal/can_become_antag(var/datum/mind/M)
	if(!..())
		return FALSE
	return TRUE

/datum/antagonist/marshal/equip()
	if(!owner.current)
		return FALSE

	spawn_uplink(owner.current)

	return TRUE
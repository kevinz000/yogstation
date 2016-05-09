#define LING_FAKEDEATH_TIME					400 //40 seconds
#define LING_DEAD_GENETICDAMAGE_HEAL_CAP	50	//The lowest value of geneticdamage handle_changeling() can take it to while dead.
#define LING_ABSORB_RECENT_SPEECH			8	//The amount of recent spoken lines to gain on absorbing a mob

var/list/possible_changeling_IDs = list("Alpha","Beta","Gamma","Delta","Epsilon","Zeta","Eta","Theta","Iota","Kappa","Lambda","Mu","Nu","Xi","Omicron","Pi","Rho","Sigma","Tau","Upsilon","Phi","Chi","Psi","Omega")
var/list/slots = list("head", "wear_mask", "back", "wear_suit", "w_uniform", "shoes", "belt", "gloves", "glasses", "ears", "wear_id", "s_store")
var/list/slot2slot = list("head" = slot_head, "wear_mask" = slot_wear_mask, "back" = slot_back, "wear_suit" = slot_wear_suit, "w_uniform" = slot_w_uniform, "shoes" = slot_shoes, "belt" = slot_belt, "gloves" = slot_gloves, "glasses" = slot_glasses, "ears" = slot_ears, "wear_id" = slot_wear_id, "s_store" = slot_s_store)
var/list/slot2type = list("head" = /obj/item/clothing/head/changeling, "wear_mask" = /obj/item/clothing/mask/changeling, "back" = /obj/item/changeling, "wear_suit" = /obj/item/clothing/suit/changeling, "w_uniform" = /obj/item/clothing/under/changeling, "shoes" = /obj/item/clothing/shoes/changeling, "belt" = /obj/item/changeling, "gloves" = /obj/item/clothing/gloves/changeling, "glasses" = /obj/item/clothing/glasses/changeling, "ears" = /obj/item/changeling, "wear_id" = /obj/item/changeling, "s_store" = /obj/item/changeling)


/datum/game_mode
	var/list/datum/mind/changelings = list()


/datum/game_mode/changeling
	name = "changeling"
	config_tag = "changeling"
	antag_flag = BE_CHANGELING
	restricted_jobs = list("AI", "Cyborg")
	protected_jobs = list("Security Officer", "Warden", "Detective", "Head of Security", "Captain", "Recovery Agent")
	required_players = 15
	required_enemies = 1
	recommended_enemies = 4
	reroll_friendly = 1


	var/const/prob_int_murder_target = 50 // intercept names the assassination target half the time
	var/const/prob_right_murder_target_l = 25 // lower bound on probability of naming right assassination target
	var/const/prob_right_murder_target_h = 50 // upper bound on probability of naimg the right assassination target

	var/const/prob_int_item = 50 // intercept names the theft target half the time
	var/const/prob_right_item_l = 25 // lower bound on probability of naming right theft target
	var/const/prob_right_item_h = 50 // upper bound on probability of naming the right theft target

	var/const/prob_int_sab_target = 50 // intercept names the sabotage target half the time
	var/const/prob_right_sab_target_l = 25 // lower bound on probability of naming right sabotage target
	var/const/prob_right_sab_target_h = 50 // upper bound on probability of naming right sabotage target

	var/const/prob_right_killer_l = 25 //lower bound on probability of naming the right operative
	var/const/prob_right_killer_h = 50 //upper bound on probability of naming the right operative
	var/const/prob_right_objective_l = 25 //lower bound on probability of determining the objective correctly
	var/const/prob_right_objective_h = 50 //upper bound on probability of determining the objective correctly

	var/const/changeling_amount = 4 //hard limit on changelings if scaling is turned off

	var/changeling_team_objective_type = null //If this is not null, we hand our this objective to all lings

/datum/game_mode/changeling/announce()
	world << "<b>The current game mode is - Changeling!</b>"
	world << "<b>There are alien changelings on the station. Do not let the changelings succeed!</b>"

/datum/game_mode/changeling/pre_setup()

	if(config.protect_roles_from_antagonist)
		restricted_jobs += protected_jobs

	if(config.protect_assistant_from_antagonist)
		restricted_jobs += "Assistant"

	var/num_changelings = 1

	if(config.changeling_scaling_coeff)
		num_changelings = max(1, min( round(num_players()/(config.changeling_scaling_coeff*2))+2, round(num_players()/config.changeling_scaling_coeff) ))
	else
		num_changelings = max(1, min(num_players(), changeling_amount))

	if(antag_candidates.len>0)
		for(var/i = 0, i < num_changelings, i++)
			if(!antag_candidates.len) break
			var/datum/mind/changeling = pick_candidate()
			antag_candidates -= changeling
			changelings += changeling
			changeling.restricted_roles = restricted_jobs
			modePlayer += changelings
		return 1
	else
		return 0

/datum/game_mode/changeling/post_setup()

	//Decide if it's ok for the lings to have a team objective
	//And then set it up to be handed out in forge_changeling_objectives
	var/list/team_objectives = typesof(/datum/objective/changeling_team_objective) - /datum/objective/changeling_team_objective
	var/list/possible_team_objectives = list()
	for(var/T in team_objectives)
		var/datum/objective/changeling_team_objective/CTO = T

		if(changelings.len >= initial(CTO.min_lings))
			possible_team_objectives += T

	if(possible_team_objectives.len && prob(20*changelings.len))
		changeling_team_objective_type = pick(possible_team_objectives)

	for(var/datum/mind/changeling in changelings)
		log_game("[changeling.key] (ckey) has been selected as a changeling")
		changeling.current.make_changeling()
		changeling.special_role = "Changeling"
		forge_changeling_objectives(changeling)
		greet_changeling(changeling)
	..()
	return

/datum/game_mode/changeling/make_antag_chance(mob/living/carbon/human/character) //Assigns changeling to latejoiners
	var/changelingcap = min( round(joined_player_list.len/(config.changeling_scaling_coeff*2))+2, round(joined_player_list.len/config.changeling_scaling_coeff) )
	if(ticker.mode.changelings.len >= changelingcap) //Caps number of latejoin antagonists
		return
	if(ticker.mode.changelings.len <= (changelingcap - 2) || prob(100 - (config.changeling_scaling_coeff*2)))
		if(character.client.prefs.hasSpecialRole(BE_CHANGELING))
			var/list/bans = jobban_list_for_mob(character.client)
			if(!jobban_job_in_list(bans, "changeling") && !jobban_job_in_list(bans, "Syndicate"))
				if(age_check(character.client))
					if(!(character.job in restricted_jobs))
						character.mind.make_Changling()

/datum/game_mode/proc/forge_changeling_objectives(datum/mind/changeling, var/team_mode = 0)
	//OBJECTIVES - random traitor objectives. Unique objectives "steal brain" and "identity theft".
	//No escape alone because changelings aren't suited for it and it'd probably just lead to rampant robusting
	//If it seems like they'd be able to do it in play, add a 10% chance to have to escape alone

	var/escape_objective_possible = TRUE

	//if there's a team objective, check if it's compatible with escape objectives
	for(var/datum/objective/changeling_team_objective/CTO in changeling.objectives)
		if(!CTO.escape_objective_compatible)
			escape_objective_possible = FALSE
			break

	var/datum/objective/absorb/absorb_objective = new
	absorb_objective.owner = changeling
	absorb_objective.gen_amount_goal(6, 8)
	changeling.objectives += absorb_objective

	if(prob(60))
		var/datum/objective/steal/steal_objective = new
		steal_objective.owner = changeling
		steal_objective.find_target()
		changeling.objectives += steal_objective

	var/list/active_ais = active_ais()
	if(active_ais.len && prob(100/joined_player_list.len))
		var/datum/objective/destroy/destroy_objective = new
		destroy_objective.owner = changeling
		destroy_objective.find_target()
		changeling.objectives += destroy_objective
	else
		if(prob(70))
			var/datum/objective/assassinate/kill_objective = new
			kill_objective.owner = changeling
			if(team_mode) //No backstabbing while in a team
				kill_objective.find_target_by_role(role = "Changeling", role_type = 1, invert = 1)
			else
				kill_objective.find_target()
			changeling.objectives += kill_objective
		else
			var/datum/objective/maroon/maroon_objective = new
			maroon_objective.owner = changeling
			if(team_mode)
				maroon_objective.find_target_by_role(role = "Changeling", role_type = 1, invert = 1)
			else
				maroon_objective.find_target()
			changeling.objectives += maroon_objective

			if (!(locate(/datum/objective/escape) in changeling.objectives) && escape_objective_possible)
				var/datum/objective/escape/escape_with_identity/identity_theft = new
				identity_theft.owner = changeling
				identity_theft.target = maroon_objective.target
				identity_theft.update_explanation_text()
				changeling.objectives += identity_theft
				escape_objective_possible = FALSE

	if (!(locate(/datum/objective/escape) in changeling.objectives) && escape_objective_possible)
		if(prob(50))
			var/datum/objective/escape/escape_objective = new
			escape_objective.owner = changeling
			changeling.objectives += escape_objective
		else
			var/datum/objective/escape/escape_with_identity/identity_theft = new
			identity_theft.owner = changeling
			if(team_mode)
				identity_theft.find_target_by_role(role = "Changeling", role_type = 1, invert = 1)
			else
				identity_theft.find_target()
			changeling.objectives += identity_theft
		escape_objective_possible = FALSE



/datum/game_mode/changeling/forge_changeling_objectives(datum/mind/changeling)
	if(changeling_team_objective_type)
		var/datum/objective/changeling_team_objective/team_objective = new changeling_team_objective_type
		team_objective.owner = changeling
		changeling.objectives += team_objective

		..(changeling,1)
	else
		..(changeling,0)


/datum/game_mode/proc/greet_changeling(datum/mind/changeling, you_are=1)
	if (you_are)
		changeling.current << "<span class='boldannounce'>You are [changeling.changeling.changelingID], a changeling! You have absorbed and taken the form of a human.</span>"
	changeling.current << "<span class='boldannounce'>Use say \":g message\" to communicate with your fellow changelings.</span>"
	changeling.current << "<b>You must complete the following tasks:</b>"

	if (changeling.current.mind)
		var/mob/living/carbon/human/H = changeling.current
		if(H.mind.assigned_role == "Clown")
			H << "You have evolved beyond your clownish nature, allowing you to wield weapons without harming yourself."
			H.dna.remove_mutation(CLOWNMUT)

	var/obj_count = 1
	for(var/datum/objective/objective in changeling.objectives)
		changeling.current << "<b>Objective #[obj_count]</b>: [objective.explanation_text]"
		obj_count++
	return

/*/datum/game_mode/changeling/check_finished()
	var/changelings_alive = 0
	for(var/datum/mind/changeling in changelings)
		if(!istype(changeling.current,/mob/living/carbon))
			continue
		if(changeling.current.stat==2)
			continue
		changelings_alive++

	if (changelings_alive)
		changelingdeath = 0
		return ..()
	else
		if (!changelingdeath)
			changelingdeathtime = world.time
			changelingdeath = 1
		if(world.time-changelingdeathtime > TIME_TO_GET_REVIVED)
			return 1
		else
			return ..()
	return 0*/

/datum/game_mode/proc/auto_declare_completion_changeling()
	if(changelings.len)
		var/text = "<br><font size=3><b>The changelings were:</b></font>"
		for(var/datum/mind/changeling in changelings)
			var/changelingwin = 1
			if(!changeling.current)
				changelingwin = 0

			text += printplayer(changeling)

			//Removed sanity if(changeling) because we -want- a runtime to inform us that the changelings list is incorrect and needs to be fixed.
			text += "<br><b>Changeling ID:</b> [changeling.changeling.changelingID]."
			text += "<br><b>Genomes Extracted:</b> [changeling.changeling.absorbedcount]"

			if(changeling.objectives.len)
				var/count = 1
				for(var/datum/objective/objective in changeling.objectives)
					if(objective.check_completion())
						text += "<br><b>Objective #[count]</b>: [objective.explanation_text] <font color='green'><b>Success!</b></font>"
						feedback_add_details("changeling_objective","[objective.type]|SUCCESS")
					else
						text += "<br><b>Objective #[count]</b>: [objective.explanation_text] <span class='danger'>Fail.</span>"
						feedback_add_details("changeling_objective","[objective.type]|FAIL")
						changelingwin = 0
					count++

			if(changelingwin)
				text += "<br><font color='green'><b>The changeling was successful!</b></font>"
				feedback_add_details("changeling_success","SUCCESS")
			else
				text += "<br><span class='boldannounce'>The changeling has failed.</span>"
				feedback_add_details("changeling_success","FAIL")
			text += "<br>"

		world << text


	return 1

/datum/changeling //stores changeling powers, changeling recharge thingie, changeling absorbed DNA and changeling ID (for changeling hivemind)
	var/list/stored_profiles = list() //list of datum/changelingprofile
	var/datum/changelingprofile/first_prof = null
	//var/list/absorbed_dna = list()
	//var/list/protected_dna = list() //dna that is not lost when capacity is otherwise full
	var/dna_max = 6 //How many extra DNA strands the changeling can store for transformation.
	var/absorbedcount = 0
	var/chem_charges = 20
	var/chem_storage = 75
	var/chem_recharge_rate = 1
	var/chem_recharge_slowdown = 0
	var/sting_range = 2
	var/changelingID = "Changeling"
	var/geneticdamage = 0
	var/isabsorbing = 0
	var/geneticpoints = 10
	var/purchasedpowers = list()
	var/mimicing = ""
	var/canrespec = 0
	var/changeling_speak = 0
	var/datum/dna/chosen_dna
	var/obj/effect/proc_holder/changeling/sting/chosen_sting

/datum/changeling/New(var/gender=FEMALE)
	..()
	var/honorific
	if(gender == FEMALE)	honorific = "Ms."
	else					honorific = "Mr."
	if(possible_changeling_IDs.len)
		changelingID = pick(possible_changeling_IDs)
		possible_changeling_IDs -= changelingID
		changelingID = "[honorific] [changelingID]"
	else
		changelingID = "[honorific] [rand(1,999)]"


/datum/changeling/proc/regenerate(var/mob/living/carbon/the_ling)
	if(istype(the_ling))
		if(the_ling.stat == DEAD)
			chem_charges = min(max(0, chem_charges + chem_recharge_rate - chem_recharge_slowdown), (chem_storage*0.5))
			geneticdamage = max(LING_DEAD_GENETICDAMAGE_HEAL_CAP,geneticdamage-1)
		else //not dead? no chem/geneticdamage caps.
			chem_charges = min(max(0, chem_charges + chem_recharge_rate - chem_recharge_slowdown), chem_storage)
			geneticdamage = max(0, geneticdamage-1)


/datum/changeling/proc/get_dna(dna_owner)
	for(var/datum/changelingprofile/prof in stored_profiles)
		if(dna_owner == prof.name)
			return prof

/datum/changeling/proc/has_dna(datum/dna/tDNA)
	for(var/datum/changelingprofile/prof in stored_profiles)
		if(tDNA.is_same_as(prof.dna))
			return 1
	return 0

/datum/changeling/proc/can_absorb_dna(mob/living/carbon/user, mob/living/carbon/human/target)
	var/datum/changelingprofile/prof = stored_profiles[1]
	if(prof.dna == user.dna && stored_profiles.len >= dna_max)//If our current DNA is the stalest, we gotta ditch it.
		user << "<span class='warning'>We have reached our capacity to store genetic information! We must transform before absorbing more.</span>"
		return
	if(!target)
		return
	if((target.disabilities & NOCLONE) || (target.disabilities & HUSK))
		user << "<span class='warning'>DNA of [target] is ruined beyond usability!</span>"
		return
	if(!ishuman(target))//Absorbing monkeys is entirely possible, but it can cause issues with transforming. That's what lesser form is for anyway!
		user << "<span class='warning'>We could gain no benefit from absorbing a lesser creature.</span>"
		return
	if(has_dna(target.dna))
		user << "<span class='warning'>We refresh this DNA with new information!</span>"
	if(!check_dna_integrity(target))
		user << "<span class='warning'>[target] is not compatible with our biology.</span>"
		return
	return 1

/datum/changeling/proc/add_profile(var/mob/living/carbon/human/H, var/mob/living/carbon/user, protect = 0)
	if(stored_profiles.len > dna_max)
		if(!push_out_profile())
			return

	var/datum/changelingprofile/prof = new()

	H.dna.real_name = H.real_name //Set this again, just to be sure that it's properly set.
	var/datum/dna/new_dna = new H.dna.type
	H.dna.copy_dna(new_dna)
	prof.dna = new_dna
	prof.name = H.real_name
	prof.protected = protect
	prof.gender = H.gender
	prof.skin_tone = H.skin_tone
	prof.hair_color = H.hair_color
	prof.hair_style = H.hair_style
	prof.facial_hair_color = H.facial_hair_color
	prof.facial_hair_style = H.facial_hair_style
	prof.eye_color = H.eye_color
	prof.features = H.features

	var/list/slots = list("head", "wear_mask", "back", "wear_suit", "w_uniform", "shoes", "belt", "gloves", "glasses", "ears", "wear_id", "s_store")
	for(var/slot in slots)
		var/obj/item/I = H.vars[slot]
		if(!I)
			continue
		prof.name_list[slot] = I.name
		prof.appearance_list[slot] = I.appearance
		prof.flags_cover_list[slot] = I.flags_cover
		prof.item_color_list[slot] = I.item_color
		prof.item_state_list[slot] = I.item_state
		prof.exists_list[slot] = 1

	stored_profiles += prof
	absorbedcount++

	return prof

/datum/changeling/proc/remove_profile(var/mob/living/carbon/human/H, force = 0)
	for(var/datum/changelingprofile/prof in stored_profiles)
		if(H.real_name == prof.name)
			if(prof.protected && !force)
				continue
			stored_profiles -= prof
			qdel(prof)

/datum/changeling/proc/get_profile_to_remove()
	for(var/datum/changelingprofile/prof in stored_profiles)
		if(!prof.protected)
			return prof

/datum/changeling/proc/push_out_profile()
	var/datum/changelingprofile/removeprofile = get_profile_to_remove()
	if(removeprofile)
		stored_profiles -= removeprofile
		return 1
	return 0

/proc/changeling_transform(var/mob/living/carbon/human/user, var/datum/changelingprofile/chosen_prof)
	var/datum/dna/chosen_dna = chosen_prof.dna

	//check for chameleon effect and revert it before the transform
	if (user.dna && user.dna.mutations)
		var/datum/mutation/human/HM = mutations_list[CHAMELEON]
		if (HM in user.dna.mutations)
			HM.force_lose(user)
			user.alpha = 255 //just to be safe

	user.real_name = chosen_prof.name
	user.dna = chosen_dna
	hardset_dna(user, null, null, null, null, chosen_dna.species.type, chosen_dna.features)
	user.gender = chosen_prof.gender
	user.skin_tone = chosen_prof.skin_tone
	user.hair_color = chosen_prof.hair_color
	user.hair_style = chosen_prof.hair_style
	user.facial_hair_color = chosen_prof.facial_hair_color
	user.facial_hair_style = chosen_prof.facial_hair_style
	user.eye_color = chosen_prof.eye_color
	user.features = chosen_prof.features

	domutcheck(user)
	user.update_body()
	user.update_hair()

	//vars hackery. not pretty, but better than the alternative.
	for(var/slot in slots)
		if(istype(user.vars[slot], slot2type[slot]) && !(chosen_prof.exists_list[slot])) //remove unnecessary flesh items
			qdel(user.vars[slot])
			continue

		if((user.vars[slot] && !istype(user.vars[slot], slot2type[slot])) || !(chosen_prof.exists_list[slot]))
			continue

		var/obj/item/C
		var/equip = 0
		if(!user.vars[slot])
			var/thetype = slot2type[slot]
			equip = 1
			C = new thetype(user)

		else if(istype(user.vars[slot], slot2type[slot]))
			C = user.vars[slot]

		C.appearance = chosen_prof.appearance_list[slot]
		C.name = chosen_prof.name_list[slot]
		C.flags_cover = chosen_prof.flags_cover_list[slot]
		C.item_color = chosen_prof.item_color_list[slot]
		C.item_state = chosen_prof.item_state_list[slot]
		if(equip)
			user.equip_to_slot_or_del(C, slot2slot[slot])

	user.regenerate_icons()

/datum/changelingprofile
	var/name = "a bug"

	var/protected = 0

	var/datum/dna/dna = null
	var/list/name_list = list() //associative list of slotname = itemname
	var/list/appearance_list = list()
	var/list/flags_cover_list = list()
	var/list/exists_list = list()
	var/list/item_color_list = list()
	var/list/item_state_list = list()

	var/gender = null
	var/skin_tone = null
	var/hair_color = null
	var/hair_style = null
	var/facial_hair_color = null
	var/facial_hair_style = null
	var/list/features = list()
	var/eye_color = null

/datum/changelingprofile/Destroy()
	qdel(dna)

//abomination stuff
/datum/species/abomination
	name = "???"
	id = "abomination"
	specflags = list(NOBREATH,COLDRES,NOGUNS,VIRUSIMMUNE,PIERCEIMMUNE,RADIMMUNE)
	speedmod = 4
	armor = 0
	punchmod = 25
	no_equip = list(slot_w_uniform,slot_glasses, slot_back, slot_ears)
	//var/has_fine_manipulation = 0
	attack_verb = "slash"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	heatmod = 1.5

/obj/item/clothing/suit/abomination
	name = "fleshy hide"
	desc = "A huge chunk of flesh. It seems to be shifting around itself."
	icon_state = "golem"
	item_state = "golem"
	body_parts_covered = CHEST|GROIN|LEGS|ARMS
	armor = list(melee = 80, bullet = 50, laser = 50,energy = 100, bomb = 30, bio = 100, rad = 0)
	unacidable = 1
	burn_state = -1
	flags_inv = HIDEGLOVES|HIDESHOES|HIDEJUMPSUIT
	flags = ABSTRACT | NODROP

/obj/item/clothing/shoes/abomination
	name = "spiked hooks"
	desc = "A fleshy membrane with spikes that dig into the ground below."
	icon_state = "golem"
	unacidable = 1
	burn_state = -1
	flags = NOSLIP | ABSTRACT | NODROP

/obj/item/clothing/mask/muzzle/abomination
	name = "distorted mouth"
	desc = "A disgusting mouth with multiple rows of teeth. There's no way someone with this on could talk normally."
	icon_state = "golem"
	item_state = "golem"
	flags = ABSTRACT | NODROP
	armor = list(melee = 30, bullet = 20, laser = 30, energy = 50, bomb = 20, bio = 50, rad = 0)
	unacidable = 1
	burn_state = -1
	flags_cover = MASKCOVERSEYES

/obj/item/clothing/head/abomination
	name = "hardened membrane"
	icon_state = "golem"
	item_state = "golem"
	desc = "Hardened resin of some sort."
	flags = ABSTRACT | NODROP
	armor = list(melee = 50, bullet = 25, laser = 20,energy = 50, bomb = 10, bio = 50, rad = 0)
	unacidable = 1
	burn_state = -1
	flags_cover = HEADCOVERSEYES | HEADCOVERSMOUTH

/obj/item/clothing/gloves/abomination
	name = "hardened membrane"
	desc = "A strange filament webbing that would fit around one's hands. They seem to be rather thick."
	icon_state = "golem"
	item_state = "golem"
	siemens_coefficient = 0
	permeability_coefficient = 0.9
	cold_protection = HANDS
	min_cold_protection_temperature = GLOVES_MIN_TEMP_PROTECT
	heat_protection = HANDS
	max_heat_protection_temperature = GLOVES_MAX_TEMP_PROTECT
	unacidable = 1
	burn_state = -1
	flags = ABSTRACT | NODROP


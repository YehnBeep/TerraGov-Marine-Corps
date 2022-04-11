#define BANDAGE (1<<0)
#define SALVE (1<<1)
#define DISINFECT (1<<2)

/obj/item/stack/medical
	name = "medical pack"
	singular_name = "medical pack"
	amount = 10
	max_amount = 10
	w_class = WEIGHT_CLASS_SMALL
	throw_speed = 4
	throw_range = 20
	///Medical skill level needed to not get a fumble delay
	var/skill_level_needed = SKILL_MEDICAL_UNTRAINED
	///Fumble delay applied without sufficient skill
	var/unskilled_delay = SKILL_TASK_TRIVIAL

/obj/item/stack/medical/attack(mob/living/carbon/M as mob, mob/user as mob)
	if(!istype(M))
		to_chat(user, span_warning("\The [src] cannot be applied to [M]!"))
		return TRUE

	if(M.status_flags & INCORPOREAL || user.status_flags & INCORPOREAL) //Incorporeal beings cannot attack or be attacked
		return TRUE

	if(!ishuman(user))
		to_chat(user, span_warning("You don't have the dexterity to do this!"))
		return TRUE

	var/mob/living/carbon/human/H = M
	var/datum/limb/affecting = user.client.prefs.toggles_gameplay & RADIAL_MEDICAL ? radial_medical(H, user) : H.get_limb(user.zone_selected)

	if(!affecting)
		return TRUE

	if(affecting.body_part == HEAD)
		if(H.head && istype(H.head,/obj/item/clothing/head/helmet/space))
			to_chat(user, span_warning("You can't apply [src] through [H.head]!"))
			return TRUE
	else
		if(H.wear_suit && istype(H.wear_suit,/obj/item/clothing/suit/space))
			to_chat(user, span_warning("You can't apply [src] through [H.wear_suit]!"))
			return TRUE

	if(affecting.limb_status & LIMB_ROBOT)
		to_chat(user, span_warning("This isn't useful at all on a robotic limb."))
		return TRUE

	H.UpdateDamageIcon()

	if(user.skills.getRating("medical") < skill_level_needed)
		if(user.do_actions)
			to_chat(user, span_warning("You're busy with something else right now!"))
		if(!do_mob(user, M, unskilled_delay, BUSY_ICON_UNSKILLED, BUSY_ICON_MEDICAL))
			return TRUE

	return affecting

/obj/item/stack/medical/heal_pack
	name = "platonic gauze"
	///How much brute damage this pack heals when applied to a limb
	var/heal_brute = 0
	///How much burn damage this pack heals when applied to a limb
	var/heal_burn = 0
	///Set of wound flags applied by use, including BANDAGE, SALVE, and DISINFECT
	var/heal_flags = NONE


/obj/item/stack/medical/heal_pack/attack(mob/living/carbon/M as mob, mob/user as mob)
	. = ..()
	if(. == TRUE)
		return

	var/datum/limb/affecting = .
	var/mob/living/carbon/human/patient = M //If we've got to this point, the parent proc already checked they're human
	if(affecting.surgery_open_stage) //Checks if mob is lying down on table for surgery
		if(patient.can_be_operated_on())
			do_surgery(patient, user, src)
		else
			to_chat(user, span_notice("\The [affecting.display_name] is cut open, you'll need more than a bandage!"))
		return

	var/affected = FALSE
	if(heal_flags & BANDAGE)
		affected |= affecting.bandage()
	if(heal_flags & SALVE)
		affected |= affecting.salve()
	if(heal_flags & DISINFECT)
		affected |= affecting.disinfect()

	generate_treatment_messages(user, patient, affecting, affected)
	if(affected)
		var/untrained_healing_penalty = (user.skills.getRating("medical") < skill_level_needed) ? 0.5 : 1
		affecting.heal_limb_damage(heal_brute * untrained_healing_penalty, heal_burn * untrained_healing_penalty, updating_health = TRUE)
		use(1)

///Purely visual, generates the success/failure messages for using a health pack
/obj/item/stack/medical/heal_pack/proc/generate_treatment_messages(mob/user, mob/patient, datum/limb/target_limb, success)
	if(!success)
		to_chat(user, span_warning("The wounds on [patient]'s [target_limb.display_name] have already been treated."))
		return
	user.visible_message(span_notice("[user] treats the wounds on [patient]'s [target_limb.display_name] with [src]."),
	span_notice("You treat the wounds on [patient]'s [target_limb.display_name] with [src].") )

/obj/item/stack/medical/heal_pack/gauze
	name = "roll of gauze"
	singular_name = "medical gauze"
	desc = "Some sterile gauze to wrap around bloody stumps."
	icon_state = "brutepack"
	heal_brute = 3
	heal_flags = BANDAGE

/obj/item/stack/medical/heal_pack/gauze/generate_treatment_messages(mob/user, mob/patient, datum/limb/target_limb, success)
	if(!success)
		to_chat(user, span_warning("The wounds on [patient]'s [target_limb.display_name] have already been treated."))
		return
	for (var/datum/wound/W AS in target_limb.wounds)
		if (W.internal)
			continue
		if (W.damage_type == CUT)
			user.visible_message(span_notice("[user] bandages [W.desc] on [patient]'s [target_limb.display_name]."),
			span_notice("You bandage \a [W.desc] on [patient]'s [target_limb.display_name].") )
		else if (istype(W,/datum/wound/bruise))
			user.visible_message(span_notice("[user] places bruise patch over [W.desc] on [patient]'s [target_limb.display_name]."),
			span_notice("You place a bruise patch over \a [W.desc] on [patient]'s [target_limb.display_name].") )

/obj/item/stack/medical/heal_pack/ointment
	name = "ointment"
	desc = "Used to treat burns, infected wounds, and relieve itching in unusual places."
	gender = PLURAL
	singular_name = "ointment"
	icon_state = "ointment"
	heal_burn = 3
	heal_flags = SALVE

/obj/item/stack/medical/heal_pack/ointment/generate_treatment_messages(mob/user, mob/patient, datum/limb/target_limb, success)
	if(!success)
		to_chat(user, span_warning("The wounds on [patient]'s [target_limb.display_name] have already been treated."))
		return
	user.visible_message(span_notice("[user] salves wounds on [patient]'s [target_limb.display_name]."),
	span_notice("You salve wounds on [patient]'s [target_limb.display_name]."))

/obj/item/stack/medical/heal_pack/gauze/tajaran
	name = "\improper S'rendarr's Hand leaf"
	singular_name = "S'rendarr's Hand leaf"
	desc = "A poultice made of soft leaves that is rubbed on bruises."
	icon = 'icons/obj/items/harvest.dmi'
	icon_state = "shandp"
	heal_brute = 7


/obj/item/stack/medical/heal_pack/ointment/tajaran
	name = "\improper Messa's Tear petals"
	singular_name = "Messa's Tear petal"
	desc = "A poultice made of cold, blue petals that is rubbed on burns."
	icon = 'icons/obj/items/harvest.dmi'
	icon_state = "mtearp"
	heal_burn = 7


/obj/item/stack/medical/heal_pack/gauze/sectoid
	name = "\improper healing resin pack"
	singular_name = "healing resin pack"
	desc = "A strange tool filled with a sticky, alien resin. It seems it is meant for covering wounds."
	icon = 'icons/obj/items/surgery_tools.dmi'
	icon_state = "predator_fixovein"
	heal_brute = 20
	heal_burn = 20
	heal_flags = BANDAGE | SALVE | DISINFECT


/obj/item/stack/medical/heal_pack/advanced
	dir = NORTH
	flags_atom = DIRLOCK
	skill_level_needed = SKILL_MEDICAL_PRACTICED
	unskilled_delay = SKILL_TASK_EASY

/obj/item/stack/medical/heal_pack/advanced/update_icon_state()
	if(max_amount < 1 || amount > max_amount)
		return
	var/percentage = round(amount / max_amount) * 100
	switch(percentage)
		if(1 to 20)
			setDir(SOUTH)
		if(21 to 40)
			setDir(EAST)
		if(41 to 60)
			setDir(SOUTHEAST)
		if(61 to 80)
			setDir(WEST)
		if(81 to INFINITY)
			setDir(NORTH)

/obj/item/stack/medical/heal_pack/advanced/bruise_pack
	name = "advanced trauma kit"
	singular_name = "advanced trauma kit"
	desc = "An advanced trauma kit for severe injuries."
	icon_state = "traumakit"
	heal_brute = 12
	heal_flags = BANDAGE | DISINFECT

/obj/item/stack/medical/heal_pack/advanced/bruise_pack/generate_treatment_messages(mob/user, mob/patient, datum/limb/target_limb, success)
	if(!success)
		to_chat(user, span_warning("The wounds on [patient]'s [target_limb.display_name] have already been treated."))
		return
	for(var/datum/wound/W AS in target_limb.wounds)
		if(W.internal)
			continue
		if(W.current_stage <= W.max_bleeding_stage)
			user.visible_message(span_notice("[user] cleans [W.desc] on [patient]'s [target_limb.display_name] and seals its edges with bioglue."),
			span_notice("You clean and seal [W.desc] on [patient]'s [target_limb.display_name]."))
		else if (istype(W,/datum/wound/bruise))
			user.visible_message(span_notice("[user] places a medicine patch over [W.desc] on [patient]'s [target_limb.display_name]."),
			span_notice("You place medicine patch over [W.desc] on [patient]'s [target_limb.display_name]."))
		else
			user.visible_message(span_notice("[user] smears some bioglue over [W.desc] on [patient]'s [target_limb.display_name]."),
			span_notice("You smear some bioglue over [W.desc] on [patient]'s [target_limb.display_name]."))

/obj/item/stack/medical/heal_pack/advanced/burn_pack
	name = "advanced burn kit"
	singular_name = "advanced burn kit"
	desc = "An advanced treatment kit for severe burns."
	icon_state = "burnkit"
	heal_burn = 12
	heal_flags = SALVE | DISINFECT

/obj/item/stack/medical/heal_pack/advanced/burn_pack/generate_treatment_messages(mob/user, mob/patient, datum/limb/target_limb, success)
	if(!success)
		to_chat(user, span_warning("The wounds on [patient]'s [target_limb.display_name] have already been treated."))
		return
	user.visible_message(span_notice("[user] covers the wounds on [patient]'s [target_limb.display_name] with regenerative membrane."),
	span_notice("You cover the wounds on [patient]'s [target_limb.display_name] with regenerative membrane."))

/obj/item/stack/medical/splint
	name = "medical splints"
	singular_name = "medical splint"
	icon_state = "splint"
	desc = "For holding broken bones in place, or as a tourniquet to treat missing limbs."
	amount = 5
	max_amount = 5
	skill_level_needed = SKILL_MEDICAL_PRACTICED
	unskilled_delay = SKILL_TASK_TOUGH
	///How much splint health per medical skill is applied
	var/applied_splint_health = 15


/obj/item/stack/medical/splint/attack(mob/living/carbon/M, mob/user)
	. = ..()
	if(. == TRUE)
		return TRUE

	if(user.do_actions)
		return

	if(ishuman(M))
		var/datum/limb/affecting = .
		var/limb = affecting.display_name

		if(!(affecting.name in list("l_arm", "r_arm", "l_leg", "r_leg", "r_hand", "l_hand", "r_foot", "l_foot", "chest", "groin", "head")))
			to_chat(user, span_warning("You can't apply a splint there!"))
			return

		if(affecting.limb_status & LIMB_DESTROYED)
			if(affecting.limb_status & LIMB_AMPUTATED)
				to_chat(user, span_warning("[user == M ? "Your" : "[M]'s"] missing [limb] is already sealed up!"))
				return
			to_chat(user, span_notice("You start to apply a makeshift tourniquet to the missing [limb]'s stump..."))
			if(!do_mob(user, M, SKILL_TASK_TOUGH * (user == M ? 2 : 1), BUSY_ICON_FRIENDLY, BUSY_ICON_MEDICAL))
				return
			to_chat(user, span_notice("You cut off the bloodflow to the severed [limb]."))
			affecting.add_limb_flags(LIMB_AMPUTATED) //Below this is so treating a severed arm or hand also catches the other
			if(affecting.parent && affecting.parent.limb_status & LIMB_DESTROYED)
				affecting.parent.add_limb_flags(LIMB_AMPUTATED) //It's only one stump, after all
			for(var/datum/limb/child AS in affecting.children)
				if(child.limb_status & LIMB_DESTROYED)
					child.add_limb_flags(LIMB_AMPUTATED)
			use(1)
			return

		if(affecting.limb_status & LIMB_SPLINTED)
			to_chat(user, span_warning("[user == M ? "Your" : "[M]'s"] [limb] is already splinted!"))
			return

		if(M != user)
			user.visible_message(span_warning("[user] starts to apply [src] to [M]'s [limb]."),
			span_notice("You start to apply [src] to [M]'s [limb], hold still."))
		else
			if((!user.hand && affecting.body_part == ARM_RIGHT) || (user.hand && affecting.body_part == ARM_LEFT))
				to_chat(user, span_warning("You can't apply a splint to the arm you're using!"))
				return
			user.visible_message(span_warning("[user] starts to apply [src] to [user.p_their()] [limb]."),
			span_notice("You start to apply [src] to your [limb], hold still."))

		if(affecting.apply_splints(src, user == M ? (applied_splint_health*max(user.skills.getRating("medical") - 1, 0)) : applied_splint_health*user.skills.getRating("medical"), user, M)) // Referenced in external organ helpers.
			use(1)

#undef BANDAGE
#undef SALVE
#undef DISINFECT

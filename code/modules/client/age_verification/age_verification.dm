/**
 * This datum essentially handles the UI for age verification, not very complicated at all.
 */
/datum/age_verification
	/// Soyjak that owns this datum
	var/client/owner
	/// Basically, if the age check hasn't succeeded and the owner closes the UI, we kick them out of the game
	var/kick_unruly_owner = TRUE

/datum/age_verification/New(user)
	owner = CLIENT_FROM_VAR(user)

/datum/age_verification/Destroy(force)
	. = ..()
	owner = null

/datum/age_verification/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AgeVerification")
		ui.open()

/datum/age_verification/ui_state(mob/user)
	return GLOB.always_state

/datum/age_verification/ui_act(action, list/params, datum/tgui/ui, datum/ui_state/state)
	. = ..()
	if(.)
		return

	switch(action)
		if("submit")
			INVOKE_ASYNC(src, PROC_REF(finalize_verification), params["month"], params["year"])

/datum/age_verification/ui_close(mob/user)
	. = ..()
	if(owner && kick_unruly_owner)
		log_admin("[owner.key] was kicked for closing the age gate UI without finalizing age verification.")
		QDEL_NULL(owner)
	qdel(src)

/datum/age_verification/proc/finalize_verification(month, year)
	var/validation_result = validate_submission(month, year)
	if(!validation_result)
		minor_detected(month, year)
		return FALSE

	var/datum/db_query/query_add_player = SSdbcore.NewQuery({"
		UPDATE [format_table_name("player")]
		SET month = :month, year = :year
		WHERE ckey = :ckey
	"}, list("month" = month, "year" = year, "ckey" = owner.ckey))
	if(query_add_player.Execute())
		log_admin("[owner.key] has successfully passed the age gate. (Month: [month] Year: [year])")
		send2adminchat("[owner.key] has successfully passed the age gate. (Month: [month] Year: [year])")
	else
		message_admins("WARNING! [owner.key] passed the age gate, but the database could not save it properly. (Month: [month] Year: [year])")
		send2adminchat("WARNING! [owner.key] passed the age gate, but the database could not save it properly. (Month: [month] Year: [year])")
	qdel(query_add_player)
	owner.update_flag_db(DB_FLAG_AGE_VETTED, TRUE)
	kick_unruly_owner = FALSE
	qdel(src)
	return TRUE

/datum/age_verification/proc/validate_submission(month, year)
	var/age_gate_result = FALSE

	var/player_year = text2num(year)
	var/player_month
	switch(uppertext(month))
		if("JANUARY")
			player_month = JANUARY
		if("FEBRUARY")
			player_month = FEBRUARY
		if("MARCH")
			player_month = MARCH
		if("APRIL")
			player_month = APRIL
		if("MAY")
			player_month = MAY
		if("JUNE")
			player_month = JUNE
		if("JULY")
			player_month = JULY
		if("AUGUST")
			player_month = AUGUST
		if("SEPTEMBER")
			player_month = SEPTEMBER
		if("OCTOBER")
			player_month = OCTOBER
		if("NOVEMBER")
			player_month = NOVEMBER
		if("DECEMBER")
			player_month = DECEMBER

	var/current_time = world.realtime
	var/current_month = text2num(time2text(current_time, "MM"))
	var/current_year = text2num(time2text(current_time, "YYYY"))

	var/player_total_months = (player_year * 12) + player_month

	var/current_total_months = (current_year * 12) + current_month

	var/months_in_eighteen_years = 18 * 12

	var/month_difference = current_total_months - player_total_months
	if(month_difference >= months_in_eighteen_years)
		age_gate_result = TRUE // they're fine
	return age_gate_result

/datum/age_verification/proc/minor_detected(month, year)
	owner.add_system_note("Automated-Age-Gate", "Failed automated age gate process.")
	var/given_reason = "SYSTEM BAN - Input date result during age verification was under 18 years of age. Contact administration for verification."
	if(!create_system_ban(player_key = owner.key, player_ip = owner.address, player_cid = owner.computer_id, applies_to_admins = FALSE, severity = "high", global_ban = TRUE, reason = given_reason, roles_to_ban = list("Server")))
		// this is the part where you should panic.
		message_admins("WARNING! Failed to ban [owner.key] for failing the automated age gate. (Month: [month] Year: [year])")
		send2adminchat("WARNING! Failed to ban [owner.key] for failing the automated age gate. (Month: [month] Year: [year])")
		qdel(owner)
		qdel(src)
		return

	// announce this
	message_admins("[owner.key] has been banned for failing the automated age gate. (Month: [month] Year: [year])")
	send2adminchat("[owner.key] has been banned for failing the automated age gate. (Month: [month] Year: [year])")

	// removing the client disconnects them
	kick_unruly_owner = FALSE
	qdel(owner)
	qdel(src)

/*
Doing my TODO here since i am offline
- add locking mechanism that blocks people from editing the assembly/pulsing the components
- add a list iterator components: if it receives a list, it will iterate over the contents sending them out
- add a component to store vars
- add a component that relays a signal and then sends one onFail or onSuccess
- dunno if this is already online, but add a timer
- fix the timer on prox_sensor
- ## DEBUG: Tue May 07 00:22:29 2019 MC restarted
what does that mean cause it triggered when i made an endless loop
- make setoutput cancellable
*/

obj
	var/datum/vgassembly/vga = null //component assembly

obj/variable_edited(var_name, old_value, new_value)
	. =..()

	switch(var_name)
		if("timestopped")
			if(vga)
				vga.setTimestop(new_value)

/*
Base Assembly
*/
datum/vgassembly
	var/name = "VGAssembly"
	var/obj/_parent
	var/list/_vgcs = list() //list of vgcs contained inside
	var/list/windows = list() //list of open uis, indexed with \ref[user]
	var/size = ARBITRARILY_LARGE_NUMBER
	//you can only use one or the other
	var/list/allowed_components = list() // keep list empty to disable
	var/list/banned_components = list() // keep list empty to disable
	var/list/output_queue = list() //list of outputs to fire, indexed by \ref[vgc]

datum/vgassembly/New()
	vg_assemblies += src

datum/vgassembly/Destroy()
	vg_assemblies -= src
	_parent = null
	_vgcs = null
	..()

datum/vgassembly/proc/rebuild()
	for(var/datum/vgcomponent/vgc in _vgcs)
		vgc.rebuildOutputs()

datum/vgassembly/proc/showCircuit(var/mob/user)
	//show the circuit via browser, manipulate components via topic
	var/uid = "\ref[user]"
	if(!windows[uid])
		var/datum/browser/W = new (user, "curcuitView", "[src]", nref = src)
		windows[uid] = W
	updateCurcuit(user)

datum/vgassembly/proc/updateCurcuit(var/mob/user)
	var/uid = "\ref[user]"
	if(!windows[uid])
		return

	var/datum/browser/W = windows[uid]
	var/content = "Components:<br><dl>"
	for(var/datum/vgcomponent/vgc in _vgcs)
		content += "<dt>[vgc] \ref[vgc]"
		if(vgc.has_settings)
			content += "<a HREF='?src=\ref[src];openC=\ref[vgc]'>\[Open Settings\]</a>"
		if(vgc.has_touch)
			content += "<a HREF='?src=\ref[src];touch=\ref[vgc]'>\[[vgc.touch_enabled ? "Disable" : "Enable"] Touch\]</a>"
		content += "<a HREF='?src=\ref[src];detach=\ref[vgc]'>\[Detach\]</a></dt><dd>" //add an ontouch toggle TODO

		content += "<dl>"
		if(vgc._input.len > 0)
			content += "<dt>Inputs:</dt>"
			for(var/vin in vgc._input)
				content += "<dd>[vin] <a HREF=?src=\ref[src];debug=\ref[vgc];input=[vin]>\[Pulse\]</a></dd>"
		else
			content += "<dt>No Inputs</dt>"

		if(vgc._output.len > 0)
			content += "<dt>Outputs:</dt>"
			for(var/out in vgc._output)
				content += "<dd>[out] "
				if(vgc._output[out])
					var/tar = vgc._output[out][2]
					var/tar_obj = vgc._output[out][1]
					content += "assigned to [tar] of \ref[tar_obj] <a HREF='?src=\ref[src];setO=\ref[vgc];output=[out]'>\[Reassign\]</a> <a HREF='?src=\ref[src];clear=\ref[vgc];output=[out]'>\[Clear\]</a>"
				else
					content += "<a HREF='?src=\ref[src];setO=\ref[vgc];output=[out]'>\[Assign\]</a>"
				content += "</dd>"
		else
			content += "No Outputs<br>"
		content += "</dl></dd>"

	content += "</dl>"
	if(_parent && !istype(_parent, /obj/item/vgc_assembly))
		content += "<a HREF='?src=\ref[src];detach=\ref[src]'>\[Detach From Object\]</a> "
	content += "<a HREF='?src=\ref[src];close=1'>\[Close\]</a>"
	W.set_content(content)
	W.open()

datum/vgassembly/Topic(href,href_list)
	if(href_list["close"]) //close curcuitview
		var/uid = "\ref[usr]"
		if(windows[uid])
			var/datum/browser/W = windows[uid]
			W.close()
			windows["\ref[usr]"] = null
		return
	else if(href_list["detach"]) //detach either obj or whole assembly
		var/target = locate(href_list["detach"])
		if(!target)
			return

		if(target == src) //detach assembly
			to_chat(usr, "You detach \the [src.name] from \the [_parent.name].")
			_parent.vga = null
			_parent = null
			var/obj/item/vgc_assembly/NewAss = new (src)
			usr.put_in_hands(NewAss)
			return
		else //uninstall component
			var/datum/vgcomponent/T = target
			to_chat(usr, "You uninstall \the [T.name] from \the [src.name].")
			var/obj/item/vgc_obj/NewObj = T.Uninstall()
			usr.put_in_hands(NewObj)
	else if(href_list["openC"]) //open settings of selected obj
		var/datum/vgcomponent/vgc = locate(href_list["openC"])
		if(!vgc)
			return
		to_chat(usr, "You open \the [vgc.name]'s settings.")
		vgc.openSettings(usr)
		return
	else if(href_list["setO"])
		var/datum/vgcomponent/out = locate(href_list["setO"])
		if(!out)
			return

		if(!(href_list["output"] in out._output))
			return

		var/list/refs = list()
		for(var/datum/vgcomponent/vgc in _vgcs)
			if(vgc == out)
				continue //dont wanna assign to ourself, or do we?
			var/i = 1
			while(1)
				if(!refs["[vgc.name]_[i]"])
					refs["[vgc.name]_[i]"] = "\ref[vgc]"
					break
				i++
		var/target = input(usr, "Select which component you want to output to.", "Select Target Component", 0) as null|anything in refs
		if(!target)
			return
		
		target = refs["[target]"]
		if(!locate(target))
			return
		
		var/input = input("Select which input you want to target.", "Select Target Input", "main") as null|anything in locate(target)._input

		var/datum/vgcomponent/vgc = locate(target)
		to_chat(usr, "You connect \the [out.name]'s [href_list["output"]] with \the [vgc.name]'s [input].")
		out.setOutput(href_list["output"], vgc, input)
	else if(href_list["touch"])
		var/datum/vgcomponent/vgc = locate(href_list["touch"])
		if(!vgc || !vgc.has_touch)
			return
		
		vgc.touch_enabled = !vgc.touch_enabled
	else if(href_list["debug"])
		var/datum/vgcomponent/vgc = locate(href_list["debug"])
		if(!vgc)
			return

		if(!href_list["input"] || !(href_list["input"] in vgc._input))
			return

		to_chat(usr, "You pulse [href_list["input"]] of [vgc.name].")
		call(vgc, vgc._input[href_list["input"]])(1)
		return
	else if(href_list["clear"])
		var/datum/vgcomponent/vgc = locate(href_list["clear"])
		if(!vgc)
			return

		if(!(href_list["output"] in vgc._output))
			return

		to_chat(usr, "You clear [href_list["output"]] of [vgc.name].")
		vgc._output[href_list["output"]] = null
	updateCurcuit(usr)


datum/vgassembly/proc/touched(var/obj/item/O, var/mob/user)
	//execute touch events for components if they are enabled
	for(var/datum/vgcomponent/vgc in _vgcs)
		if(!vgc.has_touch)
			continue
		
		vgc.onTouch(O, user)
	return

datum/vgassembly/proc/UI_Update()
	for(var/ref in windows)
		var/mob/user = locate(ref)
		if(!user)
			windows[ref] = null
			continue
		
		updateCurcuit(user)

datum/vgassembly/proc/hasSpace()
	return ((size - _vgcs.len) > 0)

datum/vgassembly/proc/canAdd(var/datum/vgcomponent/vgc)
	if(!hasSpace())
		return 0
	
	if(!vgc)
		return 0
	
	if(allowed_components.len > 0)
		for(var/c_type in allowed_components)
			if(c_type == vgc.type)
				return 1
		return 0
	else if(banned_components.len > 0)
		for(var/c_type in banned_components)
			if(c_type == vgc.type)
				return 0
	return 1

datum/vgassembly/proc/setTimestop(var/timestop)
	for(var/datum/vgcomponent/vgc in _vgcs)
		vgc.timestopped = timestop

datum/vgassembly/proc/fireOutputs()
	for(var/ref in output_queue)
		var/datum/vgcomponent/vgc = locate(ref)
		if(!vgc)
			output_queue["[ref]"] = null
			continue
		
		for(var/Q in output_queue["[ref]"])
			var/target = Q[1]
			var/signal = Q[2]
			if(vgc.timestopped)
				continue

			if(!vgc._output[target])
				output_queue["[ref]"]["[Q]"] = null

			if(vgc._output[target][1]._busy)
				output_queue["[ref]"]["[Q]"] = null
				continue

			if(!_vgcs.Find(vgc._output[target][1])) //component no longer in vga apparently
				output_queue["[ref]"]["[Q]"] = null
				vgc._output[target] = null
				continue

			var/proc_string = vgc._output[target][1]._input[_output[target][2]]
			call(vgc._output[target][1], proc_string)(signal) //oh boy what a line
			output_queue["[ref]"]["[Q]"] = null

/*
Base Component
*/
datum/vgcomponent
	var/name = "VGComponent" //used in the ui
	var/desc = "used to make logic happen"
	var/datum/vgassembly/_assembly //obj component is attached to
	var/list/_input = list( //can be called by multiple components, save all your procs you want to be accessed here
		"main" = "main"
	)
	var/list/_output = list( //can only point to one component: list(0 => ref to component, 1 => target), as can be seen in setOutput
		"main" = null
	)
	var/_busy = 0 //if machine is busy, for components who need time to properly function
	var/list/settings = list() //list of open uis, indexed with \ref[user]
	var/has_settings = 0 //enables openSettings button in assembly ui
	var/has_touch = 0
	var/touch_enabled = 0
	var/obj_path = /obj/item/vgc_obj
	var/timestopped = 0 //needed for processingobjs

datum/vgcomponent/Destroy()
	..()
	_assembly = null
	_input = null
	_output = null
	settings = null

datum/vgcomponent/proc/Install(var/datum/vgassembly/A)
	if(_assembly)
		return 0 //how
	
	if(!A || !A.canAdd(src))
		return 0 //more plausible

	_assembly = A
	_assembly._vgcs += src
	_assembly.UI_Update()
	return 1

datum/vgcomponent/proc/Uninstall() //don't override
	if(!_assembly)
		return

	
	var/datum/vgassembly/A = _assembly
	_assembly = null //needs to be null for rebuild to work for other components
	A.rebuild()
	A._vgcs -= src //now that we rebuilt, we can remove ourselves
	A.UI_Update()
	return new obj_path(src)

//basically removes all assigned outputs which aren't in the assembly anymore
datum/vgcomponent/proc/rebuildOutputs()
	for(var/O in _output)
		if(!_output[O])
			continue

		if(_output[O][1]._assembly != src._assembly)
			_output[O] = null

datum/vgcomponent/proc/handleOutput(var/target = "main", var/signal = 1)
	if(!_assembly)
		return
	
	_assembly.output_queue["\ref[src]"][++_assembly.output_queue["\ref[src]"].len] = list(target, signal)

datum/vgcomponent/proc/setOutput(var/out = "main", var/datum/vgcomponent/vgc, var/target = "main")
	if(!(out in _output))
		return 0

	if(!(target in vgc._input))
		return 0

	if(!_assembly || !_assembly._vgcs.Find(vgc))
		return //how

	_output[out] = list(vgc, target)

//opens window to configure settings
datum/vgcomponent/proc/openSettings(var/mob/user)
	return

//default input path
datum/vgcomponent/proc/main(var/signal)
	message_admins("somehow [src]'s default input got called, altough it was never set.'") //yes i know dont judge me, i am working with datums here
	return

datum/vgcomponent/proc/onTouch(var/obj/item/O, var/mob/user)
	return

/*
=============================================
COMPONENTS (the ones i made myself... kinda)
=============================================
*/
/*
Door control
-- maybe let this send out events sometime like ondooropen, ondoorclose
*/
datum/vgcomponent/doorController
	name = "Doorcontroller"
	desc="controls doors"
	var/list/saved_access = list() //ID.GetAccess()
	obj_path = /obj/item/vgc_obj/door_controller
	_input = list(
		"open" = "open",
		"close" = "close",
		"toggle" = "toggle"
	)
	_output = list()

datum/vgcomponent/doorController/proc/setAccess(var/obj/item/weapon/card/id/ID)
	saved_access = ID.GetAccess()

datum/vgcomponent/doorController/proc/open(var/signal)
	if(!signal) //we want a 1
		return 0

	if(!istype(_assembly._parent, /obj/machinery/door))
		return 0//no parent or not a door, however that happened

	var/obj/machinery/door/D = _assembly._parent
	if(D.check_access_list(saved_access))
		D.open()
		return 1
	else
		D.denied()
	return 0

datum/vgcomponent/doorController/proc/close(var/signal)
	if(!signal) //we want a 1
		return 0

	if(!istype(_assembly._parent, /obj/machinery/door))
		return 0//no parent or not a door, however that happened

	var/obj/machinery/door/D = _assembly._parent
	if(D.check_access_list(saved_access))
		D.close()
		return 1
	else
		D.denied()
	return 0

datum/vgcomponent/doorController/proc/toggle(var/signal)
	if(!signal) //we want a 1
		return 0

	if(!istype(_assembly._parent, /obj/machinery/door))
		return 0//no parent or not a door, however that happened

	var/obj/machinery/door/D = _assembly._parent
	if(D.check_access_list(saved_access))
		if(D.density)
			D.open()
		else
			D.close()
		return 1
	else
		D.denied()
	return 0

/*
Debugger
idea shamelessly copied from nexus - and modified
*/
/datum/vgcomponent/debugger
	name = "Debugger"
	desc="you should not have this"
	var/spam = 1
	obj_path = /obj/item/vgc_obj/debugger

/datum/vgcomponent/debugger/main(var/signal)
	if(spam)
		message_admins("received signal:[signal] | <a HREF='?src=\ref[src];pause=1'>\[Toggle Output/Passthrough\]</a>")
		handleOutput()
		return 1
	return 0

/datum/vgcomponent/debugger/Topic(href, href_list)
	. =..()
	if(href_list["pause"])
		spam = !spam

/*
Button
*/
/datum/vgcomponent/button
	name = "Button"
	desc="press to send a signal"
	var/toggle = 0
	var/state = 1
	obj_path = /obj/item/vgc_obj/button
	_input = list()
	has_touch = 1
	touch_enabled = 1

/datum/vgcomponent/button/onTouch(obj/item/O, mob/user)
	handleOutput(signal = state)
	if(toggle)
		state = !state

//togglebutton
/datum/vgcomponent/button/toggle
	name = "Togglebutton"
	toggle = 1

/*
Splitter
*/
/datum/vgcomponent/splitter
	name = "Splitter"
	desc = "splits signals"
	obj_path = /obj/item/vgc_obj/splitter
	_output = list(
		"channel1" = null,
		"channel2" = null
	)
	has_settings = 1

/datum/vgcomponent/splitter/main(var/signal)
	for(var/out in _output)
		handleOutput(out, signal)
	return 1

/datum/vgcomponent/splitter/openSettings(var/mob/user)
	to_chat(user, "here you will be able to add new channels, altough that is TODO")
	return

/*
Speaker
*/
/datum/vgcomponent/speaker
	name = "Speaker"
	desc = "speaks"
	obj_path = /obj/item/vgc_obj/speaker
	_output = list()

/datum/vgcomponent/speaker/main(var/signal)
	/*if(signal == 1)
		signal = pick("YEET","WAAAA","REEEEE","meep","hello","help","good evening","m'lady")*/
	_assembly._parent.say(signal)
	return 1

/*
Keyboard
*/
/datum/vgcomponent/keyboard
	name = "Keyboard"
	desc = "used to type stuff"
	obj_path = /obj/item/vgc_obj/keyboard
	_input = list()
	has_touch = 1
	touch_enabled = 1

/datum/vgcomponent/keyboard/onTouch(var/obj/item/O, var/mob/user)
	if(!user)
		return

	var/output = input("What do you want to type?", "Write Message", null) as null|text
	if(!output)
		return

	handleOutput("main", output)

/datum/vgcomponent/prox_sensor
	name = "Proximity Sensor"
	desc = "detects fast movement"
	obj_path = /obj/item/vgc_obj/prox_sensor
	_input = list(
		"activate" = "activate",
		"deactivate" = "deactivate",
		"toggle" = "toggle",
		"setRange" = "setRange",
		"setTimer" = "setTimer",
		"startTimer" = "start_process",
		"stopTimer" = "stop_process"
	)
	_output = list(
		"sense" = null
	)
	var/active = 0
	var/timer = 0
	var/range = 2
	has_settings = 1

/datum/vgcomponent/prox_sensor/proc/activate()
	active = 1
	start_process()
	return 1

/datum/vgcomponent/prox_sensor/proc/deactivate()
	active = 0
	stop_process()
	return 1

/datum/vgcomponent/prox_sensor/proc/toggle()
	if(active)
		deactivate()
	else
		activate()
	return 1

/datum/vgcomponent/prox_sensor/proc/setRange(var/signal)
	if(!isnum(signal))
		signal = text2num(signal)
		if(!signal) //wasn't a number
			return 0

	if(!(signal in (1 to 5)))
		return 0

	range = signal
	return 1

/datum/vgcomponent/prox_sensor/proc/setTimer(var/signal)
	if(!isnum(signal))
		signal = text2num(signal)
		if(!signal) //wasn't a number
			return 0
	
	timer = signal
	deactivate()
	return 1

/datum/vgcomponent/prox_sensor/proc/start_process()
	if(!(src in processing_objects))
		processing_objects.Add(src)
	return 1

/datum/vgcomponent/prox_sensor/proc/stop_process()
	if(src in processing_objects)
		processing_objects.Remove(src)
	return 1

/datum/vgcomponent/prox_sensor/proc/process()
	if(!_assembly)
		deactivate()
		return

	if(!active)
		if(--timer <= 0)
			activate()
		return
	
	//sense for people
	var/turf/loc = get_turf(_assembly._parent)
	for(var/mob/living/A in range(range,loc))
		if(A.move_speed < 12)
			handleOutput("sense")
			return //to prevent the spam

/*
===================================================================
ASSEMBLY WRAPPERS (just components that use the current assembly objs)
===================================================================
*/
/*
signaler
raw signaler
*/
/datum/vgcomponent/signaler
	name = "Signaler"
	desc="receives and sends signals"
	var/obj/item/device/assembly/signaler/_signaler
	has_touch = 1
	touch_enabled = 0
	obj_path = /obj/item/vgc_obj/signaler
	_input = list(
		"setFreq" = "setFreq", //receives freq
		"setCode" = "setCode", //receives code
		"send" = "send" //sends
	)
	_output = list(
		"signaled" = null
	)
	has_settings = 1

/datum/vgcomponent/signaler/onTouch(var/obj/item/O, var/mob/user)
	send()

datum/vgcomponent/signaler/New()
	_signaler = new ()
	_signaler.fingerprintslast = "VGAssembly" //for the investigation log TODO
	_signaler.vgc = src //so we can hook into receive_signal

/datum/vgcomponent/signaler/proc/setFreq(var/signal)
	if(!isnum(signal))
		signal = text2num(signal)
		if(!signal) //wasn't a number
			return 0

	if(!(signal in (MINIMUM_FREQUENCY to MAXIMUM_FREQUENCY)))
		return 0

	_signaler.set_frequency(signal)
	return 1

/datum/vgcomponent/signaler/proc/setCode(var/signal)
	if(!isnum(signal))
		signal = text2num(signal)
		if(!signal) //wasn't a number
			return 0

	if(!(signal in (1 to 100)))
		return 0

	_signaler.code = signal
	return 1

/datum/vgcomponent/signaler/proc/send()
	_signaler.signal()
	return 1


//signaled output
/datum/vgcomponent/signaler/proc/was_signaled()
	handleOutput("signaled", 1)
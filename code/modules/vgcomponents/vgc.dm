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
	var/timestopped = 0

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
		if(!vgc.has_touch && !vgc.touch_enabled)
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
	timestopped = timestop
	for(var/datum/vgcomponent/vgc in _vgcs)
		vgc.timestopped = timestop

datum/vgassembly/proc/fireOutputs()
	if(timestopped)
		return

	while(output_queue.len)
		var/list/Q = output_queue[output_queue.len]
		output_queue.len--
		var/ref = Q[1]
		var/target = Q[2]
		var/signal = Q[3]

		var/datum/vgcomponent/vgc = locate(ref)
		if(!vgc)
			continue

		if(vgc.timestopped)
			continue

		if(!vgc._output[target])
			continue

		if(vgc._output[target][1]._busy)
			continue

		if(!_vgcs.Find(vgc._output[target][1])) //component no longer in vga apparently
			vgc._output[target] = null
			continue

		var/proc_string = vgc._output[target][1]._input[vgc._output[target][2]]
		call(vgc._output[target][1], proc_string)(signal) //oh boy what a line

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
	var/has_touch = 0 //if the person has the ability to toggle touch behaviour
	var/touch_enabled = 0 //if touch will fire
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

	if(!_assembly.output_queue["\ref[src]"])
		_assembly.output_queue["\ref[src]"] = list()

	_assembly.output_queue[++_assembly.output_queue.len] = list("\ref[src]", target, signal)

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
	message_admins("somehow [src]'s default input got called, altough it was never set.'")
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
	touch_enabled = 1

/datum/vgcomponent/button/onTouch(obj/item/O, mob/user)
	handleOutput(signal = state)
	if(toggle)
		state = !state

//togglebutton
/datum/vgcomponent/button/toggle
	name = "Togglebutton"
	toggle = 1
	obj_path = /obj/item/vgc_obj/button/toggle

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
		"setRange" = "setRange"
	)
	_output = list(
		"sense" = null
	)
	var/active = 0
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
		return

	//sense for people
	var/turf/loc = get_turf(_assembly._parent)
	for(var/mob/living/A in range(range,loc))
		if(A.move_speed < 12)
			handleOutput("sense")
			return //to prevent the spam, only output once per process

/*
Algorithmic components
*/
/datum/vgcomponent/algorithmic
	_input = list(
		"setNum" = "setNum",
		"calculate" = "doCalc"
	)
	_output = list(
		"result"
	)
	var/num = 0

/datum/vgcomponent/proc/setNum(var/signal)
	if(!isnum(signal))
		signal = text2num(signal)
		if(!signal)
			return//wasn't a number

	num = signal

/datum/vgcomponent/proc/doCalc(var/signal)
	if(!isnum(signal))
		signal = text2num(signal)
		if(!signal)
			return//wasn't a number

	calc(signal)

/datum/vgcomponent/proc/calc(var/signal)
	return

// ADD
/datum/vgcomponent/algorithmic/add
	name = "Add"
	desc = "adds onto numbers"
	obj_path = /obj/item/vgc_obj/add

/datum/vgcomponent/algorithmic/add/calc(var/signal)
	handleOutput("result", signal+num)

//SUBTRACT
/datum/vgcomponent/algorithmic/sub
	name = "Subtract"
	desc = "subtracts of numbers"
	obj_path = /obj/item/vgc_obj/sub

/datum/vgcomponent/algorithmic/sub/calc(var/signal)
	handleOutput("result", signal-num)

//MULTIPLY
/datum/vgcomponent/algorithmic/mult
	name = "Multiply"
	desc = "multiply numbers"
	obj_path = /obj/item/vgc_obj/mult

/datum/vgcomponent/algorithmic/mult/calc(var/signal)
	handleOutput("result", signal*num)

//DIVIDE X/NUM
/datum/vgcomponent/algorithmic/div1
	name = "Divide 1"
	desc = "divide numbers with X/NUM"
	obj_path = /obj/item/vgc_obj/div1

/datum/vgcomponent/algorithmic/div1/calc(var/signal)
	if(!signal)
		return
	handleOutput("result", signal/num)

//DIVIDE NUM/X
/datum/vgcomponent/algorithmic/div2
	name = "Divide 2"
	desc = "divide numbers with NUM/X"
	obj_path = /obj/item/vgc_obj/div2

/datum/vgcomponent/algorithmic/div2/calc(var/signal)
	handleOutput("result", num/signal)

/*
String Appender
*/
/datum/vgcomponent/appender
	name = "Appender"
	desc = "appends to string"
	obj_path = /obj/item/vgc_obj/appender
	_input = list(
		"setPhrase" = "setPhrase",
		"append" = "append"
	)
	var/phrase = ""

/datum/vgcomponent/appender/proc/setPhrase(var/signal)
	if(!istext(signal))
		signal = "[signal]"

	phrase = signal

/datum/vgcomponent/appender/proc/append(var/signal)
	handleOutput(signal = "[signal][phrase]")

/*
LIST OPERATORS
*/
/*
Index getter
*/
/datum/vgcomponent/index_getter
	name = "List Index Grabber"
	desc = "grabs specified index from list"
	obj_path = /obj/item/vgc_obj/index_getter
	_input = list(
		"setIndex" = "setIndex",
		"grab" = "grab"
	)
	_output = list(
		"element" = null
	)
	var/index = 1

/datum/vgcomponent/index_getter/proc/setIndex(var/signal)
	if(!isnum(signal))
		signal = text2num(signal)
		if(!signal)
			return//wasn't a number
		
	index = signal

/datum/vgcomponent/index_getter/proc/grab(var/signal)
	if(!istype(signal, /list))
		return
	
	var/list/L = signal
	
	if(index > L.len)
		return

	handleOutput("element", L[index])

/*
List iterator
*/
/datum/vgcomponent/list_iterator
	name = "List iterator"
	desc = "iterates over the list given to it"
	obj_path = /obj/item/vgc_obj/list_iterator

datum/vgcomponent/list_iterator/main(var/signal)
	if(!istype(signal, /list))
		return

	for(var/E in signal)
		handleOutput(signal = E)

/*
Typecheck
*/
#define TYPE_NUM 1
#define TYPE_TEXT 2
#define TYPE_LIST 3
#define TYPE_MOB 4
#define TYPE_COSTUM 5

/datum/vgcomponent/typecheck
	name = "Typechecker"
	desc = "checks types"
	obj_path = /obj/item/vgc_obj/typecheck
	has_settings = 1 //type setting set over well... settings
	var/costum_type
	var/type_check = TYPE_NUM
	var/waitingForType = 0

/datum/vgcomponent/typecheck/main(var/signal)
	switch(type_check)
		if(TYPE_NUM)
			if(isnum(signal))
				handleOutput()
		if(TYPE_TEXT)
			if(istext(signal))
				handleOutput()
		if(TYPE_LIST)
			if(istype(signal, /list))
				handleOutput()
		if(TYPE_MOB)
			if(istype(signal, /mob))
				handleOutput()
		if(TYPE_COSTUM)
			if(!costum_type || waitingForType)
				return

			if(istype(signal, costum_type))
				handleOutput()


#undef TYPE_NUM
#undef TYPE_TEXT
#undef TYPE_LIST
#undef TYPE_MOB
#undef TYPE_COSTUM
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
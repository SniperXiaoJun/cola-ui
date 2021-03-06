#IMPORT_BEGIN
if exports?
	cola = require("./util")
	module?.exports = cola
else
	cola = @cola
#IMPORT_END

_$ = $()
_$.length = 1
this.$fly = (dom) ->
	_$[0] = dom
	return _$

cola.util.setText = (dom, text = "") ->
	if cola.browser.mozilla
		if typeof text is "string"
			text = text.replace(/&/g, "&amp;").replace(/>/g, "&gt;").replace(/</g, "&lt;").replace(/\n/g, "<br>")
		dom.innerHTML = text
	else
		dom.innerText = text
	return

doms = {}
cola.util.cacheDom = (ele) ->
	cola._ignoreNodeRemoved = true
	if not doms.hiddenDiv
		doms.hiddenDiv = $.xCreate(
			tagName: "div"
			id: "_hidden_div"
			style:
				display: "none"
		)
		doms.hiddenDiv.setAttribute(cola.constants.IGNORE_DIRECTIVE, "")
		document.body.appendChild(doms.hiddenDiv)
	doms.hiddenDiv.appendChild(ele)
	cola._ignoreNodeRemoved = false
	return

USER_DATA_KEY = cola.constants.DOM_USER_DATA_KEY

cola.util.userDataStore = {
	size: 0
}

cola.util.userData = (node, key, data) ->
	return if node.nodeType is 3
	userData = cola.util.userDataStore
	if node.nodeType is 8
		text = node.nodeValue
		i = text.indexOf("|")
		id = text.substring(i + 1) if i > -1
	else if node.getAttribute
		id = node.getAttribute(USER_DATA_KEY)

	if arguments.length is 3
		if not id
			id = cola.uniqueId()
			if node.nodeType is 8
				if i > -1
					node.nodeValue = text.substring(0, i + 1) + id
				else
					node.nodeValue = if text then text + "|" + id else "|" + id
			else if node.getAttribute
				node.setAttribute(USER_DATA_KEY, id)

			userData[id] = store = {
				__cleanStamp: cleanStamp
			}
			userData.size++
		else
			store = userData[id]
			if not store
				userData[id] = store = {
					__cleanStamp: cleanStamp
				}

		store[key] = data

	else if arguments.length is 2
		if typeof key is "string"
			if id
				store = userData[id]
				return store?[key]
		else if key and typeof key is "object"
			id = cola.uniqueId()
			if node.nodeType == 8
				if i > -1
					node.nodeValue = text.substring(0, i + 1) + id
				else
					node.nodeValue = if text then text + "|" + id else "|" + id
			else if node.getAttribute
				node.setAttribute(USER_DATA_KEY, id)

			userData[id] = store = {
				__cleanStamp: cleanStamp
			}
			for k, v of key
				store[k] = v
	else if arguments.length is 1
		if id
			return userData[id]
	return

cola.util.removeUserData = (node, key) ->
	if node.nodeType is 8
		text = node.nodeValue
		i = text.indexOf("|")
		id = text.substring(i + 1) if i > -1
	else if node.getAttribute
		id = node.getAttribute(USER_DATA_KEY)

	if id
		store = cola.util.userDataStore[id]
		if store
			if key
				value = store[key]
				delete store[key]
			else
				value = store
				delete cola.util.userDataStore[id]
				cola.util.userDataStore.size--
	return value

ON_NODE_DISPOSE_KEY = "__onNodeDispose"
ON_NODE_REMOVE_KEY = "__onNodeRemove"
ON_NODE_INSERT_KEY = "__onNodeInsert"

cola.detachNode = (node) ->
	return unless node.parentNode
	cola._ignoreNodeRemoved = true
	node.parentNode.removeChild(node)
	cola._ignoreNodeRemoved = false
	return

cola.util.onNodeRemove = (node, listener) ->
	oldListener = cola.util.userData(node, ON_NODE_REMOVE_KEY)
	if oldListener
		if oldListener instanceof Array
			oldListener.push(listener)
		else
			cola.util.userData(node, ON_NODE_REMOVE_KEY, [oldListener, listener])
	else
		cola.util.userData(node, ON_NODE_REMOVE_KEY, listener)
	return

cola.util.onNodeDispose = (node, listener) ->
	oldListener = cola.util.userData(node, ON_NODE_DISPOSE_KEY)
	if oldListener
		if oldListener instanceof Array
			oldListener.push(listener)
		else
			cola.util.userData(node, ON_NODE_DISPOSE_KEY, [oldListener, listener])
	else
		cola.util.userData(node, ON_NODE_DISPOSE_KEY, listener)
	return

cola.util.onNodeInsert = (node, listener) ->
	oldListener = cola.util.userData(node, ON_NODE_INSERT_KEY)
	if oldListener
		if oldListener instanceof Array
			oldListener.push(listener)
		else
			cola.util.userData(node, ON_NODE_INSERT_KEY, [oldListener, listener])
	else
		cola.util.userData(node, ON_NODE_INSERT_KEY, listener)
	return

_nodesToBeRemove = {}

_getNodeDataId = (node) ->
	return if node.nodeType is 3

	if node.nodeType is 8
		text = node.nodeValue
		i = text.indexOf("|")
		id = text.substring(i + 1) if i > -1
	else if node.getAttribute
		id = node.getAttribute(USER_DATA_KEY)
	return id

_DOMNodeInsertedListener = (evt) ->
	node = evt.target
	return unless node

	child = node.firstChild
	while child
		id = _getNodeDataId(child)
		if id
			store = cola.util.userDataStore[id]
			if store
				listeners = store[ON_NODE_INSERT_KEY]
				if listeners
					if listeners instanceof Array
						for listener in listeners
							listener(node, store)
					else
						listeners(node, store)
		child = child.nextSibling
	return

_DOMNodeRemovedListener = (evt) ->
	return if cola._ignoreNodeRemoved or window.closed

	node = evt.target
	return unless node

	child = node.firstChild
	while child
		id = _getNodeDataId(child)
		if id
			_nodesToBeRemove[id] = child
			store = cola.util.userDataStore[id]
			if store
				listeners = store[ON_NODE_REMOVE_KEY]
				if listeners
					if listeners instanceof Array
						for listener in listeners
							listener(node, store)
					else
						listeners(node, store)
		child = child.nextSibling

	id = _getNodeDataId(node)
	if id then _nodesToBeRemove[id] = node
	return

cleanStamp = 1

document.addEventListener("DOMNodeInserted", _DOMNodeInsertedListener)
document.addEventListener("DOMNodeRemoved", _DOMNodeRemovedListener)

$fly(window).on("unload", () ->
	document.removeEventListener("DOMNodeInserted", _DOMNodeInsertedListener)
	document.removeEventListener("DOMNodeRemoved", _DOMNodeRemovedListener)
	return
)

setInterval(() ->
	for id, node of _nodesToBeRemove
		store = cola.util.userDataStore[id]
		if store
			changed = true
			listeners = store[ON_NODE_DISPOSE_KEY]
			if listeners
				if listeners instanceof Array
					for listener in listeners
						listener(node, store)
				else
					listeners(node, store)
			delete cola.util.userDataStore[id]

	if changed then _nodesToBeRemove = {}
	return
, 5000)

cola.util.getGlobalTemplate = (name) ->
	template = document.getElementById(name)
	if template
		html = template.innerHTML
		if not template.hasAttribute("shared") then $fly(template).remove()
	return html

#if cola.device.mobile
#	$fly(window).on("load", () ->
#		FastClick.attach(document.body)
#		return
#	)

if cola.browser.webkit
	browser = "webkit"
	if cola.browser.chrome
		browser += " chrome"
	else if cola.browser.safari
		browser += " safari"
#	else if cola.browser.qqbrowser
#		browser += " qqbrowser"
else if cola.browser.ie
	browser = "ie"
else if cola.browser.mozilla
	browser = "mozilla"
else
	browser = ""

if cola.os.android
	os = " android"
else if cola.os.ios
	os = " ios"
else if cola.os.windows
	os = " windows"
else
	os = ""

if cola.device.mobile
	os += " mobile"
else if cola.device.desktop
	os += " desktop"

if browser or os
	$fly(document.documentElement).addClass(browser + os)

do ->
	factory = () ->
		toJSON = (node) ->
			obj = {}

			if node.tagName
				obj.tagName = node.tagName.toLowerCase()
			else if node.nodeName
				obj.nodeName = node.nodeName.toLowerCase()

			if node.attributes
				obj.attributes = {}

				for attribute in node.attributes
					obj.attributes[attribute.nodeName] = attribute.nodeValue

			if node.childNodes
				obj.childNodes = []

				for child in node.childNodes
					obj.childNodes.push(toJSON(child)) if child.nodeType is 1

			switch node.nodeName
				when "OPTION"
					obj.isOption = true
					obj.attributes["text"] = node.innerHTML
				when "OPTGROUP"
					obj.isGroup = true

			obj


		Parser =
			parse: (object) ->
				toJSON(object)

		Parser

	if typeof define is "function" and define.amd
		define(factory)
	else if typeof module isnt "undefined" and module.exports
		module.exports = factory()
	else
		window["parser"] = factory()
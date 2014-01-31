do ->
	factory = () ->
		templateCache = {}

		find = (name, stack, value = null) ->
			return stack[stack.length - 1] if name is "."

			[name, parts...] = name.split(/\./)

			for i in [stack.length - 1...-1]
				continue unless stack[i]?
				continue unless typeof stack[i] is "object" and name of (ctx = stack[i])

				value = ctx[name]
				break

			value = find(part, [value]) for part in parts

			if value instanceof Function
				value = do (value) ->
					->
						val = value.apply(ctx, arguments)

						return (val instanceof Function) and val.apply(null, arguments) or val

			value

		expand = (obj, tmpl, args...) ->
			(f.call(obj, args...)for f in tmpl).join("")

		parse = (template, delimiters = ["{{", "}}"], section = null) ->
			cache = (templateCache[delimiters.join(" ")] ||= {})
			return cache[template] if template of cache

			buffer = []

			buildRegex = ->
				[tagOpen, tagClose] = delimiters

				return ///
					([\s\S]*?)
					([#{' '}\t]*)
					(?: #{tagOpen} \s*
					(?:
						(!) 				 \s* ([\s\S]+?)		 |
						(=) 				 \s* ([\s\S]+?) \s* ? |
						({) 				 \s* (\w[\S]*?) \s* } |
						([^0-9a-zA-Z._!={]?) \s* ([\w.][\S]*?)
					)
					\s* #{tagClose} )
				///gm

			tagPattern = buildRegex()
			tagPattern.lastIndex = pos = (section or { start: 0 }).start

			parseError = (pos, msg) ->
				(endOfLine = /$/gm).lastIndex = pos
				endOfLine.exec(template)

				parsedLines = template.substr(0, pos).split("\n")
				lineNo 		= parsedLines.length
				lastLine 	= parsedLines[lineNo - 1]
				tagStart 	= contentEnd + whitespace.length
				lastTag 	= template.substr(tagStart + 1, pos - tagStart - 1)

				indent 		= new Array(lastLine.length - lastTag.length + 1).join(" ")
				carets 		= new Array(lastTag.length + 1).join("^")
				lastLine 	= lastLine + template.substr(pos, endOfLine.lastIndex - pos)

				error = new Error()
				error[key] = e[key] for key of e =
					"message": "#{msg}\n\nLine #{lineNo}:\n#{lastLine}\n#{indent}#{carets}"
					"error": msg, "line": lineNo, "char": indent.length, "tag": lastTag
				return error

			while match = tagPattern.exec(template)
				[content, whitespace] = match[1..2]
				type = match[3] or match[5] or match[7] or match[9]
				tag  = match[4] or match[6] or match[8] or match[10]

				contentEnd = (pos + content.length) - 1
				pos        = tagPattern.lastIndex

				isStandAlone = (contentEnd is -1 or template.charAt(contentEnd) is "\n") and template.charAt(pos) in [undefined, "", "\r", "\n"]

				buffer.push(do (content) ->
					->
						content
				) if content

				if isStandAlone and type not in ["", "&", "{"]
					pos += 1 if template.charAt(pos) is "\r"
					pos += 1 if template.charAt(pos) is "\n"
				else if whitespace
					buffer.push(do (whitespace) ->
						->
							whitespace
					)
					contentEnd += whitespace.length
					whitespace  = ""

				switch type
					when "!" then break
					when "", "&", "{"
						buildInterpolationTag = (name, is_unescaped) ->
							return (context) ->
								if (value = find(name, context) ? "") instanceof Function
									value = expand(this, parse("#{value()}"), arguments...)
								value = @escape("#{value}") unless is_unescaped
								return "#{value}"
						buffer.push(buildInterpolationTag(tag, type))
					when ">"
						buildPartialTag = (name, indentation) ->
							return (context, partials) ->
								partial = partials(name).toString()
								partial = partial.replace(/^(?=.)/gm, indentation) if indentation
								return expand(this, parse(partial), arguments...)
						buffer.push(buildPartialTag(tag, whitespace))
					when "#", "^"
						sectionInfo =
							name: tag, start: pos
							error: parseError(tagPattern.lastIndex, "Unclosed section '#{tag}'!")
						[tmpl, pos] = parse(template, delimiters, sectionInfo)

						sectionInfo["#"] = buildSectionTag = (name, delims, raw) ->
							return (context) ->
								value = find(name, context) or []
								tmpl  = if value instanceof Function then value(raw) else raw
								value = [value] unless value instanceof Array
								parsed = parse(tmpl or "", delims)

								context.push(value)
								result = for v in value
									context[context.length - 1] = v
									expand(this, parsed, arguments...)
								context.pop()

								return result.join("")

						sectionInfo["^"] = buildInvertedSectionTag = (name, delims, raw) ->
							return (context) ->
								value = find(name, context) or []
								value = [1] unless value instanceof Array
								value = if value.length is 0 then parse(raw, delims) else []
								return expand(this, value, arguments...)

						buffer.push(sectionInfo[type](tag, delimiters, tmpl))
					when "/"
						unless section?
							error = "End Section tag '#{tag}' found, but not in section!"
						else if tag != (name = section.name)
							error = "End Section tag closes '#{tag}'; expected '#{name}'!"
						throw parseError(tagPattern.lastIndex, error) if error

						template = template[section.start..contentEnd]
						cache[template] = buffer
						return [template, pos]
					when "="
						unless (delimiters = tag.split(/\s+/)).length is 2
							error = "Set Delimiters tag should have two and only two values!"
						throw parseError(tagPattern.lastIndex, error) if error

						escape 		= /[-[\]{}()*+?.,\\^$|#]/g
						delimiters 	= (d.replace(escape, "\\$&") for d in delimiters)
						tagPattern  = buildRegex()
					else
						throw parseError(tagPattern.lastIndex, "Unknown tag type -- #{type}")

				tagPattern.lastIndex = if pos? then pos else template.length

			throw section.error if section?

			buffer.push(-> template[pos..]) unless template.length is pos
			return cache[template] = buffer

		Renderer =
			escape: (value) ->
				entities = { "$": "amp", '"': "quot", "<": "lt", ">": "gt" }
				return value.replace(/[&"<>]/g, (ch) -> "&#{entities[ch]};")

			render: (template, data, partials = null) ->
				unless (partials ||= @partials or {}) instanceof Function
					partials = do (partials) ->
						(name) ->
							throw "Unknow partial '#{name}'!" unless name of partials
							return find(name, [partials])

				context = if @helpers instanceof Array then @helpers else [@helpers]
				return expand(this, parse(template), context.concat([data]), partials)

		Renderer
 
	if typeof define is "function" and define.amd
		define([], factory)
	else if typeof module isnt "undefined" and module.exports
		module.exports = factory()
	else
		window["renderer"] = factory()
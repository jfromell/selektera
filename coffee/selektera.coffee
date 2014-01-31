do ->
	factory = (renderer, parser, $) ->
		$.Selektera = (element, options) ->
			state = ''

			@settings = {}

			@$element = $ element

			@setState = (_state) -> state = _state

			@getState = -> state

			@init = ->
				@settings = $.extend({}, @defaults, options)

				# Parse the element to get the JSON ready for the renderer
				parsed = parser.parse(@$element.context)

				# Store the output html from the renderer
				html   = renderer.render(@settings.template, parsed)

				# Hide the original element and append the custom element
				@$element.hide().after($(html))

				# Attach events ###
				$(".selektera-control").on("click", (e) ->
					control = e.currentTarget

					# Find the input and toggle the dropdown-open class
					$(control).find(".selektera-input").toggleClass("dropdown-open")
					# Find the dropdown and toggle the open class
					$(control).find(".selektera-dropdown").toggleClass("open")
				)

				$(".selektera-option").on("click", (e) ->
					option = e.currentTarget

					# Reference to the control div
					$control = $(option).parents(".selektera-control")

					# Find out if any options are previously selected
					$selected = $control.find(".selektera-option.selected")

					# If so, remove the selected class from that option
					if $selected
						$selected.removeClass("selected")

					# Set the `selected` class on the option
					$(option).addClass("selected")

					# Trigger the `change` event on the input
					$control.find(".selektera-input").trigger("change", $(option).data("value"))
				)

				$(".selektera-input").on("change", (e, data) ->
					input = e.currentTarget

					# Find the input element inside the input div
					$element = $(input).find("input")

					# Set the element's value to the passed value
					$element.val(data)
				)

				# Remove the original element // This works as Selektera uses an input with the same name as the original element
				@$element.remove()

				# The plugin is now ready
				@setState "ready"

			@init()

			this

		$.Selektera::defaults =
			template: '<div class="selektera-control">' +
					'<div class="selektera-input">' +
						'<input name="{{attributes.name}}" {{#attributes.placeholder}}placeholder="{{attributes.placeholder}}"{{/attributes.placeholder}} disabled/>' +
					'</div>' +
					'<ul class="selektera-dropdown">' +
						'{{#childNodes}}' +
							'{{#isGroup}}' +
								'<li class="selektera-group">{{attributes.label}}' +
									'<ul>' +
										'{{#childNodes}}' +
											'<li class="selektera-option" data-value="{{attributes.value}}">{{attributes.text}}</li>' +
										'{{/childNodes}}' +
									'</ul>' +
								'</li>' +
							'{{/isGroup}}' +

							'{{#isOption}}' +
								'<li class="selektera-option" data-value="{{attributes.value}}">{{attributes.text}}</li>' +
							'{{/isOption}}' +
						'{{/childNodes}}' +
					'</ul>' +
				'</div>'

		$.fn.selektera = (option) ->
			@each ->
				if $(this).data("selektera") is undefined
					$(this).data("selektera", new $.Selektera(this, option))




	if typeof define is "function" and define.amd
		define(["renderer"], factory)
	else if typeof module isnt "undefined" and module.exports
		module.exports = factory(require("./renderer"))
	else
		window["selektera"] = factory(window["renderer"], window["parser"], window["jQuery"])
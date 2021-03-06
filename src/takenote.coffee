Editor = Function.inherit (area) ->
	throw new Error 'Missing area element' if !area
	@area = area
	@types =
		paragraph:
			tag: 'p'
		h1:
			tag: 'h1'
			NEXT: 'paragraph'
		h2:
			tag: 'h2'
			NEXT: 'paragraph'
		h3:
			tag: 'h3'
			NEXT: 'paragraph'
		standalone:
			tag: 'div'
			NEXT: 'paragraph'
	@DEFAULT_TYPE = 'paragraph'
	@ACTIVE_TYPE = @DEFAULT_TYPE
	return
,
	activate: ->
		@active = true
		@area.attr 'contenteditable', true
		@_addListeners()
		@erase() if !@area.html()
		return @

	deactivate: ->
		@active = false
		@area.attr 'contenteditable', false
		return @
	
	erase: ->
		@area.html ''
		@_addBlock @DEFAULT_TYPE
		return @

	setBlockType: (type_key) ->
		return false if !@active

		type = @types[type_key]
		throw new Error "Undefined block type '#{type_key}'" if not type
		caret = @_getCaret()

		old = @_getCaretBlock().firstChild
		node = new Element type.tag, type.attrs
		cnts = Array.prototype.slice.call old.childNodes
		cnts.forEach (cnt) -> node.appendChild cnt
		old.insert after: node
		node.parentNode.data 'type', type_key
		old.remove()

		@_setCaret caret
		do @_updateState
		return @
	
	indent: ->
		block = @_getCaretBlock()
		prev = block.previousSibling if block != null
		# prevent double indent
		return false if !prev

		caret = @_getCaret()

		sub = prev.lastChild
		sub = @_createSub(prev) if sub.tagName != 'UL'
		sub.appendChild block

		@_setCaret caret
		return @

	outdent: ->
		block = @_getCaretBlock()
		# prevent outdenting of root blocks
		return false if block.parentNode is @area

		caret = @_getCaret()

		# indent siblings (after)
		if block.nextSibling != null
			sub = block.lastChild
			sub = @_createSub(block) if sub.tagName != 'UL'
			sub.appendChild block.nextSibling while block.nextSibling != null

		parent_sub = block.parentNode
		parent_sub.parentNode.insert after: block
		parent_sub.remove() if parent_sub.childNodes.length is 0

		@_setCaret caret
		return @

	addBlock: (type_key) ->
		node = @_addBlock type_key, yes
		do @_fixAreaEnd

		return node.firstChild


	_createSub: (node) ->
		sub = new Element 'ul'
		node.appendChild sub
		return sub

	_getCaretNode: ->
		window.getSelection().focusNode

	_getCaretBlock: (old) ->
		old = @_getCaretNode() if old is undefined
		old = old.parentNode while old isnt null and old.tagName isnt 'LI' and old isnt document.body
		return null if old is null or old is document.body # outside of any possible block

		# check if we're in @area
		list = old
		area = @area
		while list isnt document.body
			list = list.parentNode
			return old if list is area
		return null
	
	_getCaret: ->
		sel = window.getSelection()
		if sel.focusNode then [sel.focusNode, sel.focusOffset, sel.anchorNode, sel.anchorOffset] else null;

	_setCaret: (caret) ->
		sel = window.getSelection()
		range = document.createRange()
		range.setStart caret[2], caret[3]
		range.setEnd caret[0], caret[1]
		sel.removeAllRanges()
		sel.addRange range

	_setCaretAt: (node) ->
		node = node.firstChild
		sel = window.getSelection()
		range = document.createRange()
		range.setStart node, 0
		range.setEnd node, 0
		sel.removeAllRanges()
		sel.addRange range

	_getNextTypeKey: ->
		active_type = @types[@ACTIVE_TYPE]
		unless active_type.NEXT is undefined then active_type.NEXT else @ACTIVE_TYPE

	_addBlock: (type_key, skip_right_fragment) ->
		block = @_getCaretBlock()
		orig_img_count = if block then block.find('img').length else 0

		frag = if skip_right_fragment then null else @_getRightFragment()
		frag_img_count = if frag then frag.find('img').length else 0

		type_key = @ACTIVE_TYPE if type_key is undefined and frag != null and frag.childNodes.length != 0
		type_key = @_getNextTypeKey() if type_key is undefined
		type = @types[type_key]

		node = new Element 'li'
		node.data 'type', type_key

		if orig_img_count
			imgs = block.find('img')
			if imgs.length > orig_img_count - frag_img_count
				block.find('img').last().remove()
		
		if block then block.insert after: node
		else @area.appendChild node

		cnt = new Element type.tag, type.attrs
		node.appendChild cnt
		cnt.appendChild frag unless frag is null
		return node

	_getRightFragment: ->
		sel = window.getSelection()
		return null if sel.focusNode is null
		range = sel.getRangeAt 0
		block = @_getCaretBlock sel.focusNode
		return document.createDocumentFragment() if !block
		cnt = block.firstChild.lastChild || block.firstChild || block
		range.setEnd cnt, cnt.length
		return range.extractContents()

	_addListeners: ->
		that = @

		@area.addEventListener 'keydown', ((e) ->
			switch e.keyCode
				when 13 # return
					e.preventDefault()
					that._setCaretAt that._addBlock()
				when 9 # tab
					e.preventDefault();
					if !e.shiftKey then that.indent()
					else that.outdent()
		), false

		@area.addEventListener 'keyup', ((e) ->
			switch e.keyCode
				when 8, 46 # backspace, delete
					sel = window.getSelection()
					apples = sel.focusNode.parentNode.find 'span.Apple-style-span'
					range = sel.getRangeAt 0
					apples.forEach (apple) ->
						cnts = Array.prototype.slice.call apple.childNodes
						cnts.forEach (cnt) -> apple.insert before: cnt
						apple.remove()
					range.reapply()

			do that._updateState
			do that._fixAreaEnd
		), false

		@area.addEventListener 'click', (->
			do that._fixAreaEnd
			do that._updateState
		), false

		return @

	_fixAreaEnd: ->
		if @area.lastChild.data('type') isnt 'paragraph'
			@area.insert @_addBlock('paragraph')
	
	_updateState: ->
		node = @_getCaretNode()
		if node isnt null
			node = node.parentNode while node.tagName != 'LI'
			@ACTIVE_TYPE = node.data('type') or @DEFAULT_TYPE
		else
			@ACTIVE_TYPE = @DEFAULT_TYPE

		do @_updateToolbar
	
	_updateToolbar: ->
		return false if not @toolbar
		do @toolbar.query


Toolbar = Function.inherit (element) ->
	throw new Error 'Missing toolbar element' if !element
	@element = element
	@_groups = []
	return
,
	activate: (editor) ->
		@active = true
		@element.addClassName 'active'
		@editor = editor
		return @
	deactivate: ->
		@active = false
		@element.removeClassName 'active'
		return @
	push: (group) ->
		throw new Error 'Invalid group' unless group instanceof ToolbarGroup
		@_groups.push group
		@element.appendChild group.element
		group.toolbar = this
	query: ->
		@_groups.forEach (group) -> do group.query


ToolbarGroup = Function.inherit (name) ->
	@name = name
	@_controls = []
	@element = new Element 'div',
		class: 'group'
	return
,
	push: (control) ->
		throw new Error 'Invalid control' unless control instanceof ToolbarControl
		@_controls.push control
		@element.appendChild control.element
		control.toolbar = @toolbar
	query: ->
		@_controls.forEach (control) ->
			active = no
			active = control.query.call null, this unless typeof control.query isnt 'function'
			control.element[if active then 'addClassName' else 'removeClassName'] 'active'
		, this.toolbar.editor


ToolbarControl = do Function.inherit

ToolbarButton = ToolbarControl.inherit (name, title, def) ->
	@name = name
	@title = title
	@def = def
	@handler = def.handler
	@query = def.query
	do @_build
	return
,
	_build: ->
		that = this
		@element = new Element 'a',
			href: 'javascript:void(0);'
			class: 'button ' + @name
			title: @title

		if @handler
			@element.addEventListener 'click', (e) ->
				do e.preventDefault
				that.handler.call that, that.toolbar.editor, e
				return false
			, false
		
		do @_addOverlay if @def.overlay
	
	_addOverlay: ->
		@overlay = @def.overlay
		@overlay.addClassName 'overlay'
		@element.insert @overlay


Toolbar.Group = ToolbarGroup
Toolbar.Control = ToolbarControl
Toolbar.Button = ToolbarButton
Editor.Toolbar = Toolbar

window.TakeNote = Editor
return
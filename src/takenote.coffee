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
	@DEFAULT_TYPE = 'h1'
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

	setBlockType: (type) ->
		return false if !@active

		type = @types[type]
		caret = @_getCaret()

		old = @_getCaretBlock().firstChild
		node = new Element type.tag, type.attrs
		cnts = Array.prototype.slice.call old.childNodes
		cnts.forEach (cnt) -> node.appendChild cnt
		old.insert after: node
		old.remove()

		@_setCaret caret
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


	_createSub: (node) ->
		sub = new Element 'ul'
		node.appendChild sub
		return sub

	_getCaretNode: ->
		window.getSelection().focusNode

	_getCaretBlock: (old) ->
		area = @area
		old = @_getCaretNode() if old is undefined
		old = old.parentNode while old.tagName != 'LI' if old != null and old != document.body
		if old != document.body then old else null
	
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

	_addBlock: (type_key) ->
		frag = @_getRightFragment()

		type_key = @ACTIVE_TYPE if type_key is undefined and frag != null and frag.childNodes.length != 0
		type_key = @_getNextTypeKey() if type_key is undefined
		type = @types[type_key]

		node = new Element 'li'
		node.data 'type', type_key
		block = @_getCaretBlock()
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

			node = that._getCaretNode()
			node = node.parentNode while node.tagName != 'LI'
			that.ACTIVE_TYPE = node.data('type') or that.DEFAULT_TYPE
		), false

		return @


window.TakeNote = Editor
return
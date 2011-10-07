buildToolbar = (toolbar) ->
	group = new TakeNote.Toolbar.Group 'block-type'
	toolbar.push group
	['paragraph', 'h1', 'h2'].forEach (type) ->
		control = new TakeNote.Toolbar.Button type,
			handler: (editor) -> editor.setBlockType type
			query: (editor) -> editor.ACTIVE_TYPE is type
		group.push control

window.editor = new TakeNote area
window.toolbar = new TakeNote.Toolbar controls
buildToolbar toolbar
do editor.activate
toolbar.activate editor
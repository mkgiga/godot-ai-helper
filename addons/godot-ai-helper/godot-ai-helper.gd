@tool
extends EditorPlugin
const PLUGIN_NAME = "AI Helper"
const ADDON_DIR = "res://addons/godot-ai-helper/"
const TAB_NAME = "AI Helper"
const CONTEXT_TAB_NAME = "Context"
const OUTPUT_TAB_NAME = "Output"
const ADD_SCRIPT_BUTTON_TEXT = "Include Current Script"
const ADD_SCENE_BUTTON_TEXT = "Include Current Scene Tree"
const REMOVE_BUTTON_TEXT = "Remove Selected"
const REFRESH_BUTTON_TEXT = "Refresh Output"
const TYPE_SCRIPT = "script"
const TYPE_SCENE_TREE = "scene_tree"
const HEAD_TEXT_LABEL = "Optional Header Text:"
const TAIL_TEXT_LABEL = "Optional Footer Text:"
const HEAD_PLACEHOLDER = "Enter text to appear BEFORE the included resources..."
const TAIL_PLACEHOLDER = "Enter text to appear AFTER the included resources..."
const SAVE_FILE_PATH = ADDON_DIR + "helper_state.json"

var code_highlighter: CodeHighlighter = preload(ADDON_DIR + "markdown_highlighter.tres")
var main_control: Control
var tab_container: TabContainer
var head_code_edit: CodeEdit
var context_list: ItemList
var tail_code_edit: CodeEdit
var output_code_edit: CodeEdit
var included_items: Array[Dictionary] = []
var first_run_completed: bool = false

func _enter_tree() -> void:
	main_control = VBoxContainer.new()
	main_control.name = TAB_NAME
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_control.add_child(tab_container)

	var context_vbox = VBoxContainer.new()
	context_vbox.name = CONTEXT_TAB_NAME
	tab_container.add_child(context_vbox)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, CONTEXT_TAB_NAME)

	var head_label = Label.new()
	head_label.text = HEAD_TEXT_LABEL
	context_vbox.add_child(head_label)
	
	head_code_edit = CodeEdit.new()
	head_code_edit.placeholder_text = HEAD_PLACEHOLDER
	head_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	head_code_edit.size_flags_stretch_ratio = 0.2
	head_code_edit.custom_minimum_size = Vector2(0, 60)
	head_code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	head_code_edit.gutters_draw_line_numbers = true
	head_code_edit.syntax_highlighter = null
	head_code_edit.focus_exited.connect(_save_state)
	
	context_vbox.add_child(head_code_edit)

	var context_buttons_hbox = HBoxContainer.new()
	context_vbox.add_child(context_buttons_hbox)
	
	var add_script_button = Button.new()
	add_script_button.text = ADD_SCRIPT_BUTTON_TEXT
	add_script_button.pressed.connect(_on_add_current_script_pressed)
	context_buttons_hbox.add_child(add_script_button)
	
	var add_scene_button = Button.new()
	add_scene_button.text = ADD_SCENE_BUTTON_TEXT
	add_scene_button.pressed.connect(_on_add_current_scene_pressed)
	context_buttons_hbox.add_child(add_scene_button)

	var list_label = Label.new()
	list_label.text = "Included Resources (Scenes first, then Scripts):"
	context_vbox.add_child(list_label)
	context_list = ItemList.new()
	context_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	context_list.size_flags_stretch_ratio = 0.6
	context_list.allow_reselect = true
	context_list.allow_search = false
	context_vbox.add_child(context_list)

	var tail_label = Label.new()
	tail_label.text = TAIL_TEXT_LABEL
	
	context_vbox.add_child(tail_label)
	
	tail_code_edit = CodeEdit.new()
	tail_code_edit.placeholder_text = TAIL_PLACEHOLDER
	tail_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tail_code_edit.size_flags_stretch_ratio = 0.2
	tail_code_edit.custom_minimum_size = Vector2(0, 60)
	tail_code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	tail_code_edit.gutters_draw_line_numbers = true
	tail_code_edit.syntax_highlighter = null
	tail_code_edit.focus_exited.connect(_save_state)
	
	context_vbox.add_child(tail_code_edit)

	var remove_button = Button.new()
	remove_button.text = REMOVE_BUTTON_TEXT
	remove_button.pressed.connect(_on_remove_selected_pressed)
	
	context_vbox.add_child(remove_button)

	var output_vbox = VBoxContainer.new()
	output_vbox.name = OUTPUT_TAB_NAME
	tab_container.add_child(output_vbox)
	tab_container.set_tab_title(tab_container.get_tab_count() - 1, OUTPUT_TAB_NAME)

	var refresh_button = Button.new()
	refresh_button.text = REFRESH_BUTTON_TEXT
	refresh_button.pressed.connect(_generate_output)
	output_vbox.add_child(refresh_button)

	output_code_edit = CodeEdit.new()
	output_code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_code_edit.editable = false
	output_code_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	output_code_edit.highlight_current_line = true
	output_code_edit.gutters_draw_line_numbers = true

	var highlighter = code_highlighter
	output_code_edit.syntax_highlighter = highlighter

	output_vbox.add_child(output_code_edit)
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_UL, main_control)
	set_control_dock_tab_title(main_control, TAB_NAME)
	
	_load_state()
	_update_context_list()
	_generate_output()
	
	if not first_run_completed:
		print("%s: First run detected. Focusing plugin tab '%s'." % [PLUGIN_NAME, TAB_NAME])
		call_deferred("_focus_plugin_tab")
		first_run_completed = true
		_save_state()

func _exit_tree() -> void:
	_save_state()
	
	if is_instance_valid(main_control):
		remove_control_from_docks(main_control)
		main_control.queue_free()
	
	included_items.clear()
	print("%s: Plugin UI removed and state saved." % PLUGIN_NAME)

func _focus_plugin_tab() -> void:
	if not is_instance_valid(main_control):
		return
		
	await get_tree().process_frame
	await get_tree().process_frame
	
	var parent = main_control.get_parent()
	var dock_tab_container: TabContainer = null
	var safety_count = 0
	
	while parent != null and safety_count < 20:
		if parent is TabContainer:
			for i in range(parent.get_tab_count()):
				if parent.get_tab_control(i) == main_control:
					dock_tab_container = parent
					break
			
			if is_instance_valid(dock_tab_container):
				break
		
		parent = parent.get_parent()
		safety_count += 1
		
	if is_instance_valid(dock_tab_container):
		for i in range(dock_tab_container.get_tab_count()):
			if dock_tab_container.get_tab_control(i) == main_control:
				if dock_tab_container.current_tab != i:
					dock_tab_container.current_tab = i
					print("%s: Focused dock tab '%s'." % [PLUGIN_NAME, TAB_NAME])
				if not dock_tab_container.is_visible_in_tree():
					dock_tab_container.show()
				break
	else:
		printerr("%s: Could not find parent Dock TabContainer for '%s'." % [PLUGIN_NAME, TAB_NAME])

func _save_state() -> void:
	if not is_instance_valid(head_code_edit) or not is_instance_valid(tail_code_edit):
		return
	
	var items_to_save: Array[Dictionary] = []
	
	for item in included_items:
		if item.has("type") and item.has("path"):
			items_to_save.append({"type": item.type, "path": item.path})
		else:
			printerr("%s: Skip invalid item save: %s" % [PLUGIN_NAME, str(item)])
	
	var state_data := {"head_text": head_code_edit.text, "tail_text": tail_code_edit.text, "items": items_to_save, "first_run_completed": first_run_completed}
	var json_string := JSON.stringify(state_data, "\t")
	var global_addon_dir = ProjectSettings.globalize_path(ADDON_DIR)

	if not DirAccess.dir_exists_absolute(global_addon_dir):
		var err = DirAccess.make_dir_recursive_absolute(global_addon_dir)
		if err != OK:
			printerr("%s: Failed create dir '%s'. Err: %s" % [PLUGIN_NAME, global_addon_dir, error_string(err)])
	
	var global_save_path = ProjectSettings.globalize_path(SAVE_FILE_PATH)
	var file := FileAccess.open(global_save_path, FileAccess.WRITE)

	if is_instance_valid(file):
		file.store_string(json_string)
		file.close()
	else:
		printerr("%s: Failed open save '%s'. Err: %s" % [PLUGIN_NAME, global_save_path, error_string(FileAccess.get_open_error())])

func _load_state() -> void:
	var global_save_path = ProjectSettings.globalize_path(SAVE_FILE_PATH)
	if not FileAccess.file_exists(global_save_path):
		print("%s: No save file." % PLUGIN_NAME)
		return
		
	var file := FileAccess.open(global_save_path, FileAccess.READ)
	if not is_instance_valid(file):
		printerr("%s: Failed open load '%s'." % [PLUGIN_NAME, global_save_path])
		return
		
	var json_string := file.get_as_text()
	
	file.close()
	
	var json_instance := JSON.new()
	var error := json_instance.parse(json_string)

	if error != OK:
		printerr("%s: Failed parse JSON '%s'." % [PLUGIN_NAME, global_save_path])
		return
		
	var parse_result: Variant = json_instance.get_data()
	
	if typeof(parse_result) != TYPE_DICTIONARY:
		printerr("%s: Invalid format '%s'." % [PLUGIN_NAME, global_save_path])
		return
		
	var state_data: Dictionary = parse_result
	
	if is_instance_valid(head_code_edit) and is_instance_valid(tail_code_edit):
		head_code_edit.text = state_data.get("head_text", "")
		tail_code_edit.text = state_data.get("tail_text", "")
	
	first_run_completed = state_data.get("first_run_completed", false)
	
	var loaded_items_simplified = state_data.get("items", [])
	included_items.clear()
	
	if typeof(loaded_items_simplified) == TYPE_ARRAY:
		for simple_item in loaded_items_simplified:
			if typeof(simple_item) == TYPE_DICTIONARY and simple_item.has("type") and simple_item.has("path"):
				var item_type = simple_item.type
				var item_path = simple_item.path
				var reconstructed_item : Dictionary = {"type": item_type, "path": item_path}

				if item_type == TYPE_SCENE_TREE:
					var global_item_path = ProjectSettings.globalize_path(item_path)
					
					if ResourceLoader.exists(global_item_path):
						var packed_scene: PackedScene = load(global_item_path)
						if is_instance_valid(packed_scene):
							var scene_instance : Node = packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
							if is_instance_valid(scene_instance):
								scene_instance.scene_file_path = item_path
								var tree_data: Dictionary = _generate_ascii_tree(scene_instance)
								reconstructed_item["ascii_tree"] = tree_data.get("tree", "Error: Regenerate fail")
								reconstructed_item["is_main"] = tree_data.get("is_main", false)
								scene_instance.queue_free()
							else:
								reconstructed_item["ascii_tree"] = "Error: Instantiate fail"
								reconstructed_item["is_main"] = false
						else:
							reconstructed_item["ascii_tree"] = "Error: Load fail"
							reconstructed_item["is_main"] = false
					else:
						reconstructed_item["ascii_tree"] = "Error: Not found"
						reconstructed_item["is_main"] = false
				included_items.append(reconstructed_item)
			else:
				printerr("%s: Skip invalid item load: %s" % [PLUGIN_NAME, str(simple_item)])
	else:
		printerr("%s: Invalid 'items' format." % PLUGIN_NAME)
		
	_sort_included_items()
	print("%s: State loaded." % PLUGIN_NAME)

func _compare_items(a: Dictionary, b: Dictionary) -> bool:
	if a.type == TYPE_SCENE_TREE and b.type == TYPE_SCRIPT:
		return true
		
	if a.type == TYPE_SCRIPT and b.type == TYPE_SCENE_TREE:
		return false
	return false

func _sort_included_items() -> void:
	included_items.sort_custom(_compare_items)

func _on_add_current_script_pressed() -> void:
	var script_editor := EditorInterface.get_script_editor()
	
	if not is_instance_valid(script_editor):
		return
		
	var script: Script = script_editor.get_current_script()
	if not is_instance_valid(script):
		_show_alert("No script open.")
		return
		
	var script_path: String = script.resource_path
	if script_path.is_empty():
		_show_alert("Cannot include built-in script.")
		return
		
	for item in included_items:
		if item.type == TYPE_SCRIPT and item.path == script_path:
			_select_item_by_path(script_path)
			return
			
	included_items.append({"type": TYPE_SCRIPT, "path": script_path})
	
	_sort_included_items()
	_update_context_list()
	_select_item_by_path(script_path)
	_save_state()
	
	print("%s: Added script '%s'." % [PLUGIN_NAME, script_path])

func _on_add_current_scene_pressed() -> void:
	var editor_scene_root: Node = EditorInterface.get_edited_scene_root()
	
	if not is_instance_valid(editor_scene_root):
		_show_alert("No scene open.")
		return
	
	var scene_path: String = editor_scene_root.scene_file_path
	
	if scene_path.is_empty():
		_show_alert("Scene must be saved.")
		return
	
	for item in included_items:
		if item.type == TYPE_SCENE_TREE and item.path == scene_path:
			_select_item_by_path(scene_path)
			return
	var tree_data: Dictionary = _generate_ascii_tree(editor_scene_root)
	
	if tree_data.is_empty() or not tree_data.has("tree") or tree_data.tree.is_empty():
		_show_alert("Could not generate tree data.")
		return
		
	included_items.append({"type": TYPE_SCENE_TREE, "path": scene_path, "ascii_tree": tree_data.tree, "is_main": tree_data.is_main})
	
	_sort_included_items()
	_update_context_list()
	_select_item_by_path(scene_path)
	_save_state()
	
	print("%s: Added scene '%s'." % [PLUGIN_NAME, scene_path])

func _on_remove_selected_pressed() -> void:
	var selected_indices: PackedInt32Array = context_list.get_selected_items()
	
	if selected_indices.is_empty():
		return
		
	selected_indices.sort()
	selected_indices.reverse()
	
	var items_removed = false
	
	for index_to_remove in selected_indices:
		if index_to_remove >= 0 and index_to_remove < included_items.size():
			included_items.pop_at(index_to_remove)
			items_removed = true
		else:
			printerr("%s: Invalid index %d" % [PLUGIN_NAME, index_to_remove])
			
	if items_removed:
		_update_context_list()
		_generate_output()
		_save_state()
		print("%s: Removed items." % PLUGIN_NAME)

func _update_context_list() -> void:
	if not is_instance_valid(context_list):
		return
		
	context_list.clear()
	
	var editor_icons := get_editor_interface().get_base_control()
	var script_icon: Texture2D = null
	var scene_icon: Texture2D = null

	if is_instance_valid(editor_icons):
		script_icon = editor_icons.get_theme_icon(&"GDScript", &"EditorIcons")
		scene_icon = editor_icons.get_theme_icon(&"PackedScene", &"EditorIcons")
	for i in range(included_items.size()):
		var item: Dictionary = included_items[i]
		var display_text: String = "Invalid"

		var icon_to_use: Texture2D = null
		var item_path = item.get("path", "[Missing]")

		if item.type == TYPE_SCRIPT:
			display_text = "Script: %s" % item_path.get_file()
			if is_instance_valid(script_icon):
				icon_to_use = script_icon
			else:
				display_text = "[S] " + display_text
		elif item.type == TYPE_SCENE_TREE:
			display_text = "Scene: %s" % item_path.get_file()
			if item.get("is_main", false):
				display_text += " (Main)"
			if is_instance_valid(scene_icon):
				icon_to_use = scene_icon
			else:
				display_text = "[T] " + display_text
		else:
			display_text = "Unknown: %s" % item_path.get_file()
		context_list.add_item(display_text, icon_to_use)
		context_list.set_item_tooltip(i, item_path)

func _generate_output() -> void:
	if not is_instance_valid(head_code_edit) or not is_instance_valid(tail_code_edit) or not is_instance_valid(output_code_edit):
		return
		
	var output_lines: Array[String] = []
	var error_messages: Array[String] = []

	var head_text = head_code_edit.text
	
	if not head_text.is_empty():
		output_lines.append(head_text)
		
		if not included_items.is_empty() or not tail_code_edit.text.is_empty():
			output_lines.append("")
			
	for item in included_items:
		if not item.has("type") or not item.has("path"):
			continue
			
		var item_path : String = item.path
		if item.type == TYPE_SCRIPT:
			var global_item_path = ProjectSettings.globalize_path(item_path)
			if not FileAccess.file_exists(global_item_path):
				error_messages.append("Script not found: %s" % item_path)
				output_lines.append("--- ERROR: Load fail %s ---" % item_path.get_file())
				output_lines.append("")
				continue
				
			var file_err = FileAccess.get_open_error()
			var file := FileAccess.open(global_item_path, FileAccess.READ)

			if not is_instance_valid(file):
				error_messages.append("Open fail %s (Err: %s)" % [item_path, error_string(file_err)])
				output_lines.append("--- ERROR: Open fail %s ---" % item_path.get_file())
				output_lines.append("")
				continue
				
			var content: String = file.get_as_text()
			file.close()
			output_lines.append("Script: %s" % item_path)
			output_lines.append("```gdscript")
			output_lines.append(content)
			output_lines.append("```")
			output_lines.append("")
			
		elif item.type == TYPE_SCENE_TREE:
			if not item.has("ascii_tree"):
				error_messages.append("Missing tree data: %s" % item_path)
				output_lines.append("--- ERROR: Missing tree %s ---" % item_path.get_file())
				output_lines.append("")
				continue
			var tree_content = item.ascii_tree
			var is_main = item.get("is_main", false)

			var title = "Scene Tree: %s" % item_path
			if is_main:
				title += " (PROJECT MAIN SCENE)"
			output_lines.append(title)
			output_lines.append("```text")
			output_lines.append(tree_content)
			output_lines.append("```")
			output_lines.append("")
			
	if not output_lines.is_empty() and output_lines[-1].is_empty():
		if not tail_code_edit.text.is_empty() or output_lines.size() == 1:
			output_lines.pop_back()
	var tail_text = tail_code_edit.text
	
	if not tail_text.is_empty():
		if not output_lines.is_empty():
			output_lines.append("")
		output_lines.append(tail_text)
		
	var final_output = "\n".join(output_lines)
	
	output_code_edit.text = final_output
	
	if not error_messages.is_empty():
		printerr("%s: Errors: %s" % [PLUGIN_NAME, ", ".join(error_messages)])

func _generate_ascii_tree(root_node: Node) -> Dictionary:
	var output_lines = []
	var main_scene_path = ProjectSettings.get_setting("application/run/main_scene", "")

	var is_main_scene = false
	var node_scene_path = root_node.scene_file_path

	if is_instance_valid(root_node) and not node_scene_path.is_empty():
		is_main_scene = (node_scene_path == main_scene_path)
		
	var autoloads: Dictionary = ProjectSettings.get_setting("autoload", {})
	var autoload_keys = autoloads.keys()

	var current_top_level_index = 0
	var root_indent = ""

	if is_main_scene:
		output_lines.append("root: Node/")
		root_indent = "  "
		
	for i in range(autoload_keys.size()):
		
		var autoload_name = autoload_keys[i]
		current_top_level_index += 1
		var is_last_root_item = (current_top_level_index == autoload_keys.size()) and not is_instance_valid(root_node)
		var prefix = root_indent + ("└─ " if is_last_root_item else "├─ ")
		var autoload_info = autoloads[autoload_name]
		var script_path = ""
		var node_type = "Node"

		if autoload_info.has("path") and typeof(autoload_info["path"]) == TYPE_STRING:
			var path_str : String = autoload_info["path"]
			
			if path_str.begins_with("*"):
				path_str = path_str.substr(1)
				node_type = "Script (Singleton)"
				script_path = path_str.get_file()
			elif path_str.ends_with(".tscn") or path_str.ends_with(".scn"):
				node_type = "PackedScene"
				script_path = path_str.get_file()
			elif path_str.ends_with(".gd"):
				node_type = "Script"
				script_path = path_str.get_file()
				
		var script_str = " (%s)" % script_path if not script_path.is_empty() else ""
		var node_info_str = "%s: %s%s [AUTOLOAD]" % [autoload_name, node_type, script_str]
		output_lines.append(prefix + node_info_str)
		
	if is_instance_valid(root_node):
		var root_prefix_str = root_indent + "└─ "
		_generate_ascii_tree_recursive(root_node, root_prefix_str, root_indent, true, output_lines)
	return { "tree": "\n".join(output_lines), "is_main": is_main_scene }

func _generate_ascii_tree_recursive(node: Node, node_prefix: String, children_prefix_base: String, is_last_sibling: bool, output_lines: Array) -> void:
	var node_name = _get_formatted_node_name(node.name)
	var node_type = node.get_class()

	var node_script = _get_script_info(node)
	var node_unique = " %" if node.is_unique_name_in_owner() else ""

	output_lines.append("%s%s: %s%s%s" % [node_prefix, node_name, node_type, node_unique, node_script])
	
	var children = node.get_children()
	
	if not children.is_empty():
		var new_children_prefix_base = children_prefix_base + ("  " if is_last_sibling else "│ ")
		
		for i in range(children.size()):
			var child = children[i]
			var child_is_last = (i == children.size() - 1)

			var child_node_prefix = new_children_prefix_base + ("└─ " if child_is_last else "├─ ")
			_generate_ascii_tree_recursive(child, child_node_prefix, new_children_prefix_base, child_is_last, output_lines)

func _get_formatted_node_name(node_name: String) -> String:
	if node_name.contains(" ") or node_name.begins_with("%") or node_name.begins_with("@") or node_name.contains(":"):
		return '"%s"' % node_name
	else:
		return node_name

func _get_script_info(node: Node) -> String:
	var script_resource = node.get_script()
	
	if is_instance_valid(script_resource) and script_resource is Script:
		var script_path: String = script_resource.resource_path
		if not script_path.is_empty():
			if script_path.begins_with("res://"):
				return " (%s)" % script_path.get_file()
			else:
				return " (Script: %s)" % script_path.get_file()
		else:
			return " (Built-In Script)"
	else:
		return ""

func _show_alert(message: String, title: String = PLUGIN_NAME) -> void:
	var base_control = get_editor_interface().get_base_control()
	
	if not is_instance_valid(base_control):
		printerr("Cannot show alert: Base control invalid.")
		return
		
	var dialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "OK"
	dialog.confirmed.connect(func(): dialog.queue_free())
	base_control.add_child(dialog)
	dialog.popup_centered()

func _select_item_by_path(resource_path: String) -> void:
	
	if not is_instance_valid(context_list):
		return
		
	for i in range(context_list.item_count):
		if context_list.get_item_tooltip(i) == resource_path:
			context_list.select(i)
			context_list.ensure_current_is_visible()
			break

func set_control_dock_tab_title(control: Control, title: String) -> void:
	if not is_instance_valid(control):
		return
	var parent = control.get_parent()
	var dock_tab_container: TabContainer = null

	var safety_count = 0
	
	while parent != null and safety_count < 20:
		if parent is TabContainer:
			for i in range(parent.get_tab_count()):
				if parent.get_tab_control(i) == control:
					dock_tab_container = parent
					break
			if is_instance_valid(dock_tab_container):
				break
		parent = parent.get_parent()
		safety_count += 1
		
	if is_instance_valid(dock_tab_container):
		for i in range(dock_tab_container.get_tab_count()):
			if dock_tab_container.get_tab_control(i) == control:
				dock_tab_container.set_tab_title(i, title)
				break
	else:
		printerr("%s: Could not find parent TabContainer to set title for '%s'." % [PLUGIN_NAME, control.name])

tool
extends EditorImportPlugin

func get_importer_name():
	return "ggj23.map_loader"

func get_visible_name():
	return "Map"

func get_recognized_extensions():
	return ["png"]

func get_save_extension():
	return "res"

func get_resource_type():
	return "Resource"

func get_preset_count():
	return 0

func get_import_options(preset):
	return {}

func import(source_file, save_path, options, platform_variants, gen_files):
	var res = Map.new()
	res.set_size(23, 23)
	return ResourceSaver.save("%s.%s" % [save_path, get_save_extension()], res)

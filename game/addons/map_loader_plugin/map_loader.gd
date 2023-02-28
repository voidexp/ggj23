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
	var image_file = File.new()
	var err = image_file.open(source_file, File.READ)
	if err:
		return err

	var image_data = image_file.get_buffer(image_file.get_len())
	image_file.close()

	var image = Image.new()
	err = image.load_png_from_buffer(image_data)
	if err:
		return err

	var map = Map.new()
	var size = image.get_size()
	map.set_size(size.x, size.y)

	image.lock()
	for r in range(map.rows):
		for c in range(map.cols):
			var coord = Vector2(c, r)
			var pixel: Color = image.get_pixel(c, r)
			if pixel.a == 0:
				map.set_tile(coord, Map.BLOCK_TYPE.NONE)
			elif pixel.v == 0:
				map.set_tile(coord, Map.BLOCK_TYPE.ROCK)
			elif pixel.r > 0.3:
				map.set_tile(coord, Map.BLOCK_TYPE.SOIL)

			if pixel.g > 0.3:
				map.gold_zones.append(coord)

	image.unlock()

	print("Loaded %dx%d map from %s" % [size.x, size.y, source_file])

	return ResourceSaver.save("%s.%s" % [save_path, get_save_extension()], map)

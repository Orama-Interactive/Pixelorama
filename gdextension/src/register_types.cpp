#include "register_types.hpp"

#include "algorithms/bucket.hpp"
#include "algorithms/drawing_algos.hpp"

#include <gdextension_interface.h>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

void initialize_pixelorama_lib(godot::ModuleInitializationLevel p_level)
{
    if (p_level != godot::MODULE_INITIALIZATION_LEVEL_SCENE)
		return;

	godot::ClassDB::register_class<DrawingAlgosCpp>();
}

void uninitialize_pixelorama_lib(godot::ModuleInitializationLevel p_level)
{
    if (p_level != godot::MODULE_INITIALIZATION_LEVEL_SCENE)
		return;
}

extern "C"
{
    GDExtensionBool GDE_EXPORT pixelorama_lib_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization)
    {
        godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

        init_obj.register_initializer(initialize_pixelorama_lib);
        init_obj.register_terminator(uninitialize_pixelorama_lib);
        init_obj.set_minimum_library_initialization_level(godot::MODULE_INITIALIZATION_LEVEL_SCENE);

        return init_obj.init();
    }
}

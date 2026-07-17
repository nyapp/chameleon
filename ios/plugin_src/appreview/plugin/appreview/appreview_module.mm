#ifdef VERSION_4_0
#include "core/config/engine.h"
#else
#include "core/engine.h"
#endif

#include "appreview_module.h"

AppReview *appreview;

void register_appreview_types() {
	appreview = memnew(AppReview);
	Engine::get_singleton()->add_singleton(Engine::Singleton("AppReview", appreview));
}

void unregister_appreview_types() {
	if (appreview) {
		memdelete(appreview);
		appreview = nullptr;
	}
}

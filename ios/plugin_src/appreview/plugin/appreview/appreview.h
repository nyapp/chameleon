#ifndef APPREVIEW_H
#define APPREVIEW_H

#ifdef VERSION_4_0
#include "core/object/object.h"
#include "core/string/ustring.h"
#endif

class AppReview : public Object {
	GDCLASS(AppReview, Object);

	static AppReview *instance;

public:
	void request_review();
	String get_app_version() const;

	static AppReview *get_singleton();

	AppReview();
	~AppReview();

protected:
	static void _bind_methods();
};

#endif

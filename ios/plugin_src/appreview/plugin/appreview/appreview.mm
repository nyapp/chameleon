#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>

#ifdef VERSION_4_0
#include "core/object/class_db.h"
#else
#include "core/class_db.h"
#endif

#include "appreview.h"

AppReview *AppReview::instance = nullptr;

AppReview::AppReview() {
	instance = this;
	NSLog(@"initialize AppReview");
}

AppReview::~AppReview() {
	if (instance == this) {
		instance = nullptr;
	}
	NSLog(@"deinitialize AppReview");
}

AppReview *AppReview::get_singleton() {
	return instance;
}

void AppReview::_bind_methods() {
	ClassDB::bind_method("request_review", &AppReview::request_review);
	ClassDB::bind_method("get_app_version", &AppReview::get_app_version);
}

String AppReview::get_app_version() const {
	NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	if (version == nil) {
		return String("1.0");
	}
	return String::utf8([version UTF8String]);
}

void AppReview::request_review() {
	if (@available(iOS 14.0, *)) {
		UIWindowScene *scene = nil;
		for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
			if (candidate.activationState == UISceneActivationStateForegroundActive &&
					[candidate isKindOfClass:[UIWindowScene class]]) {
				scene = (UIWindowScene *)candidate;
				break;
			}
		}
		if (scene == nil) {
			NSLog(@"AppReview: no foreground UIWindowScene");
			return;
		}
		[SKStoreReviewController requestReviewInScene:scene];
		return;
	}

	NSLog(@"AppReview: StoreKit review API unavailable");
}

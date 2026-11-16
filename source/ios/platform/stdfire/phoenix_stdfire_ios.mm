#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "phoenix_stdfire_ios.h"

/* UIKit objects below are only accessed on the main queue. */
static __weak UIView *phoenixCurrentToast = nil;

static UIWindow *phoenixStdFireWindow(void)
{
  UIApplication *application = [UIApplication sharedApplication];
  if (@available(iOS 13.0, *))
  {
    for (UIScene *scene in application.connectedScenes)
    {
      if (scene.activationState != UISceneActivationStateForegroundActive || ![scene isKindOfClass:[UIWindowScene class]])
        continue;
      for (UIWindow *window in ((UIWindowScene *)scene).windows)
        if (window.isKeyWindow) return window;
    }
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  return application.keyWindow;
#pragma clang diagnostic pop
}

bool phoenixStdFireSetTitle(const char *title)
{
  @autoreleasepool
  {
    @try
    {
      if (title == NULL) return false;
      NSString *value = [NSString stringWithUTF8String:title];
      if (value == nil) return false;
      dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool
        {
          @try
          {
            UIWindow *window = phoenixStdFireWindow();
            if (@available(iOS 13.0, *))
              window.windowScene.title = value;
            // Legacy, scene-less iOS applications still have a controller title.
            window.rootViewController.title = value;
          }
          @catch (NSException *exception)
          {
            NSLog(@"PhoenixStdFire: title update failed: %@", exception);
          }
        }
      });
      return true; /* Queued; a scene/window can disappear before execution. */
    }
    @catch (NSException *exception)
    {
      NSLog(@"PhoenixStdFire: title request failed: %@", exception);
      return false;
    }
  }
}

bool phoenixStdFireShowToast(const char *message)
{
  @autoreleasepool
  {
    @try
    {
      if (message == NULL) return false;
      NSString *value = [NSString stringWithUTF8String:message];
      if (value == nil || value.length == 0) return false;
      dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool
        {
          @try
          {
            UIWindow *window = phoenixStdFireWindow();
            if (window == nil) return;
            [phoenixCurrentToast removeFromSuperview];

            UIView *banner = [[UIView alloc] init];
            banner.translatesAutoresizingMaskIntoConstraints = NO;
            banner.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.94];
            banner.layer.cornerRadius = 8;
            banner.userInteractionEnabled = NO;
            banner.isAccessibilityElement = YES;
            banner.accessibilityLabel = value;

            UILabel *label = [[UILabel alloc] init];
            label.translatesAutoresizingMaskIntoConstraints = NO;
            label.text = value;
            label.textColor = [UIColor whiteColor];
            label.font = [UIFont systemFontOfSize:14];
            label.textAlignment = NSTextAlignmentCenter;
            label.numberOfLines = 2;
            label.lineBreakMode = NSLineBreakByTruncatingTail;
            [banner addSubview:label];
            [window addSubview:banner];
            phoenixCurrentToast = banner;

            NSLayoutYAxisAnchor *bottom = window.bottomAnchor;
            if (@available(iOS 11.0, *)) bottom = window.safeAreaLayoutGuide.bottomAnchor;
            [NSLayoutConstraint activateConstraints:@[
              [banner.centerXAnchor constraintEqualToAnchor:window.centerXAnchor],
              [banner.bottomAnchor constraintEqualToAnchor:bottom constant:-16],
              [banner.widthAnchor constraintLessThanOrEqualToAnchor:window.widthAnchor constant:-32],
              [label.leadingAnchor constraintEqualToAnchor:banner.leadingAnchor constant:16],
              [label.trailingAnchor constraintEqualToAnchor:banner.trailingAnchor constant:-16],
              [label.topAnchor constraintEqualToAnchor:banner.topAnchor constant:10],
              [label.bottomAnchor constraintEqualToAnchor:banner.bottomAnchor constant:-10]
            ]];
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, value);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
              [banner removeFromSuperview];
              if (phoenixCurrentToast == banner) phoenixCurrentToast = nil;
            });
          }
          @catch (NSException *exception)
          {
            NSLog(@"PhoenixStdFire: toast update failed: %@", exception);
          }
        }
      });
      return true; /* Queued, not a guarantee that a foreground window exists. */
    }
    @catch (NSException *exception)
    {
      NSLog(@"PhoenixStdFire: toast request failed: %@", exception);
      return false;
    }
  }
}

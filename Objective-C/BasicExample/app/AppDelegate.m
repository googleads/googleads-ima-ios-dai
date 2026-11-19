#import "AppDelegate.h"

static NSString *const kDefaultSceneConfigurationName = @"Default Configuration";
static NSString *const kIPadSceneConfigurationName = @"iPad Configuration";

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // Override point for customization after application launch.
  return YES;
}

#pragma mark - UISceneSession lifecycle

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                   options:(UISceneConnectionOptions *)options {
  // Called when a new scene session is being created.
  // Use this method to select a configuration to create the new scene with.
  NSString *configName = (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
                             ? kIPadSceneConfigurationName
                             : kDefaultSceneConfigurationName;
  return [[UISceneConfiguration alloc] initWithName:configName
                                        sessionRole:connectingSceneSession.role];
}

@end


#import "AppstaxInternals.h"
#import "AXJsonApiClient.h"
#import "AXDataStore.h"

@implementation Appstax

- (void)setupServicesWithAppKey:(NSString *)appKey {
    [self setupServicesWithAppKey:appKey baseUrl:@"https://appstax.com/api/latest/"];
}

- (void)setupServicesWithAppKey:(NSString *)appKey baseUrl:(NSString *)baseUrl {
    _appKey = appKey;
    _apiClient = [[AXJsonApiClient alloc] initWithAppKey:appKey baseUrl:baseUrl];
    [self setupServicesWithApiClient:_apiClient];
}

- (void)setupServicesWithApiClient:(AXJsonApiClient *)apiClient {
    _apiClient = apiClient;
    _dataStore = [[AXDataStore alloc] initWithApiClient:_apiClient];
    _userService = [[AXUserService alloc] initWithApiClient:_apiClient];
    _permissionsService = [[AXPermissionsService alloc] initWithApiClient:_apiClient];
    _fileService = [[AXFileService alloc] initWithApiClient:_apiClient];
}

#pragma mark - Class methods

+ (void)setAppKey:(NSString *)appKey {
    [[self defaultContext] setupServicesWithAppKey:appKey];
}

+ (void)setAppKey:(NSString *)appKey baseUrl:(NSString *)baseUrl {
    [[self defaultContext] setupServicesWithAppKey:appKey baseUrl:baseUrl];
}

+ (NSString *)appKey {
    return [[self defaultContext] appKey];
}

+ (void)setApiClient:(AXJsonApiClient *)apiClient {
    [[self defaultContext] setupServicesWithApiClient:apiClient];
}

+ (instancetype)defaultContext {
    static Appstax *defaultContext = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        defaultContext = [[self alloc] init];
    });
    return defaultContext;
}

+ (NSBundle *)frameworkBundle {
    static NSBundle* frameworkBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        frameworkBundle = [NSBundle bundleForClass:[Appstax class]];
    });
    return frameworkBundle;
}

+ (void)includeUnusedClasses {
    [AXImageView class];
}

@end

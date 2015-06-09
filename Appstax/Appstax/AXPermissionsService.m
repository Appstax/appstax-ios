
#import "AppstaxInternals.h"
#import "AXPermissionsService.h"
#import <Appstax/Appstax-Swift.h>

@interface AXPermissionsService ()
@property AXApiClient *apiClient;
@end

@implementation AXPermissionsService

- (instancetype)initWithApiClient:(AXApiClient *)apiClient {
    self = [super init];
    if(self) {
        _apiClient = apiClient;
    }
    return self;
}

- (void)grant:(NSArray *)grants revoke:(NSArray *)revokes objectID:(NSString *)objectID completion:(void(^)(NSError *))completion {
    NSURL *url = [_apiClient urlFromTemplate:@"/permissions" parameters:@{}];
    [_apiClient postDictionary:@{@"grants":[self fillPermissions:grants withObjectID:objectID],
                                 @"revokes":[self fillPermissions:revokes withObjectID:objectID]}
                         toUrl:url
                    completion:^(NSDictionary *dictionary, NSError *error) {
                        completion(error);
                    }];
}

- (NSArray *)fillPermissions:(NSArray *)permissions withObjectID:(NSString *)objectID {
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:permissions.count];
    for(NSUInteger i = 0; i < permissions.count; i++) {
        NSMutableDictionary *permission = [NSMutableDictionary dictionaryWithDictionary:permissions[i]];
        permission[@"sysObjectId"] = objectID;
        [result addObject:permission];
    }
    return result;
}

@end

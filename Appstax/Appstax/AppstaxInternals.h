
#import "Appstax.h"
#import "AXDataStore.h"
#import "AXJsonApiClient.h"
#import "AXObject.h"
#import "AXFile.h"
#import "AXFileService.h"
#import "AXQuery.h"
#import "AXUser.h"
#import "AXUserService.h"
#import "AXPermissionsService.h"
#import "AXKeychain.h"

@interface Appstax ()
@property NSString *appKey;
@property (readonly) AXJsonApiClient *apiClient;
@property (readonly) AXDataStore *dataStore;
@property (readonly) AXUserService *userService;
@property (readonly) AXPermissionsService *permissionsService;
@property (readonly) AXFileService *fileService;
+ (void)setApiClient:(AXJsonApiClient *)apiClient;
+ (void)setAppKey:(NSString *)appKey baseUrl:(NSString *)baseUrl;
+ (Appstax *)defaultContext;
+ (NSString *)appKey;
@end

@interface AXJsonApiClient ()
@property NSString *sessionID;
@end

@interface AXObject ()
@property (readonly) NSDictionary *allProperties;
@property (readonly) NSDictionary *allPropertiesForSaving;
@property AXObjectStatus status;
- (instancetype)initWithCollectionName:(NSString *)collectionName;
- (instancetype)initWithCollectionName:(NSString *)collectionName properties:(NSDictionary *)properties status:(AXObjectStatus)status;
- (void)overrideObjectID:(NSString *)objectID;
@end

typedef enum {
    AXFileStatusNew,
    AXFileStatusSaving,
    AXFileStatusSaved
} AXFileStatus;

@interface AXFile ()
@property (readonly) NSURL *url;
@property (readonly) AXFileStatus status;
+ (instancetype)fileWithUrl:(NSURL *)url name:(NSString *)name status:(AXFileStatus)status;
- (void)setUrl:(NSURL *)url;
- (void)setStatus:(AXFileStatus)status;
- (void)setData:(NSData *)data;
@end

@interface AXQuery ()
@property NSString *logicalOperator;
@end

@interface AXUser ()
@property NSString *objectID;
- (instancetype)initWithUsername:(NSString *)username properties:(NSDictionary *)properties;
@end

@interface AXUserService ()
- (void)setCurrentUser:(AXUser *)user;
- (AXKeychain *)keychain;
@end

@interface AXLoginViews ()
- (instancetype)initWithSize:(CGSize)size;
@end

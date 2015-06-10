
#import "AXFile.h"
#import "AXFileService.h"
#import "AXQuery.h"
#import "AXUser.h"
#import "AXUserService.h"
#import "AXPermissionsService.h"
#import "AXKeychain.h"


@interface AXFile ()
- (void)setData:(NSData *)data;
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

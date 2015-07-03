
#import "AXFile.h"
#import "AXFileService.h"
#import "AXQuery.h"
#import "AXUserService.h"
#import "AXPermissionsService.h"
#import "AXKeychain.h"
#import "AXLoginViews.h"


@interface AXFile ()
- (void)setData:(NSData *)data;
@end

@interface AXUserService ()
- (void)setCurrentUser:(AXUser *)user;
- (AXKeychain *)keychain;
@end

@interface AXLoginViews ()
- (instancetype)initWithSize:(CGSize)size;
@end

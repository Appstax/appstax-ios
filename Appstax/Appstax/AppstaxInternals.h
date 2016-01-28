
#import "AXFile.h"
#import "AXFileService.h"
#import "AXQuery.h"
#import "AXPermissionsService.h"
#import "AXKeychain.h"
#import "AXLoginViews.h"


@interface AXFile ()
- (void)setData:(NSData *)data;
@end

@interface AXLoginViews ()
- (instancetype)initWithSize:(CGSize)size;
@end

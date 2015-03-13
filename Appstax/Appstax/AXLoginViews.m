
#import "AXLoginViews.h"

@interface AXLoginViews ()
@property CGSize size;
@end

@implementation AXLoginViews

- (instancetype)initWithSize:(CGSize)size {
    self = [super init];
    if(self) {
        _size = size;
        [self setupBlankViews];
    }
    return self;
}

- (void)setupBlankViews {
    CGRect frame = CGRectMake(0, 0, _size.width, _size.height);
    _login  = [[UIView alloc] initWithFrame:frame];
    _signup = [[UIView alloc] initWithFrame:frame];
}

@end

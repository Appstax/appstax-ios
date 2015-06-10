
#import <Foundation/Foundation.h>

@interface AXQuery : NSObject

// TODO: Make internal when converting to Swift
@property NSString *logicalOperator;

@property (readonly) NSString *queryString;

+ (instancetype)query;
- (instancetype)initWithQueryString:(NSString *)queryString;
- (void)string:(NSString *)property equals:(NSString *)value;
- (void)string:(NSString *)property contains:(NSString *)value;

@end

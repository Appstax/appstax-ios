
#import <Foundation/Foundation.h>

@interface AXQuery : NSObject

@property (readonly) NSString *queryString;

+ (instancetype)query;
- (instancetype)initWithQueryString:(NSString *)queryString;
- (void)string:(NSString *)property equals:(NSString *)value;
- (void)string:(NSString *)property contains:(NSString *)value;

@end

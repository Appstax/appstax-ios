
#import "AXQuery.h"

@interface AXQuery ()
@property NSString *initialQueryString;
@property NSMutableArray *predicates;
@property NSString *logicalOperator;
@end

@implementation AXQuery

+ (instancetype)query {
    return [[AXQuery alloc] init];
}

- (instancetype)init {
    self = [super init];
    if(self) {
        _logicalOperator = @"and";
        _predicates = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithQueryString:(NSString *)queryString {
    self = [self init];
    [self addPredicate:queryString];
    return self;
}

- (NSString *)queryString {
    NSString *queryString = @"";
    if(_predicates.count > 0) {
        queryString = [_predicates componentsJoinedByString:[self predicateJoinString]];
    }
    return queryString;
}

- (NSString *)predicateJoinString {
    return [NSString stringWithFormat:@" %@ ", _logicalOperator];
}

- (void)addPredicate:(NSString *)predicate {
    [_predicates addObject:predicate];
}

#pragma mark - String properties

- (void)string:(NSString *)property equals:(NSString *)value {
    [self addPredicate:[NSString stringWithFormat:@"%@='%@'", property, value]];
}

- (void)string:(NSString *)property contains:(NSString *)value {
    [self addPredicate:[NSString stringWithFormat:@"%@ like '%%%@%%'", property, value]];
}

@end


#import <Foundation/Foundation.h>

@class AXObject;
@class AXQuery;
@class AXJsonApiClient;

@interface AXDataStore : NSObject

- (instancetype)initWithApiClient:(AXJsonApiClient *)apiClient;
- (AXObject *)create:(NSString *)collectionName;
- (AXObject *)create:(NSString *)collectionName properties:(NSDictionary *)properties;
- (void)save:(AXObject *)object completion:(void(^)(AXObject *object, NSError *error))completion;
- (void)delete:(AXObject *)object completion:(void(^)(NSError *error))completion;
- (void)saveObjects:(NSArray *)objects completion:(void(^)(NSError *error))completion;
- (void)findAll:(NSString *)collectionName completion:(void(^)(NSArray *objects, NSError *error))completion;
- (void)find:(NSString *)collectionName withId:(NSString *)objectID completion:(void(^)(AXObject *object, NSError *error))completion;
- (void)find:(NSString *)collectionName with:(NSDictionary *)propertyValues completion:(void(^)(NSArray *objects, NSError *error))completion;
- (void)find:(NSString *)collectionName search:(NSDictionary *)propertyValues completion:(void(^)(NSArray *objects, NSError *error))completion;
- (void)find:(NSString *)collectionName search:(NSString *)searchString properties:(NSArray *)searchProperties completion:(void(^)(NSArray *objects, NSError *error))completion;
- (void)find:(NSString *)collectionName query:(void(^)(AXQuery *query))queryBlock completion:(void(^)(NSArray *objects, NSError *error))completion;
- (void)find:(NSString *)collectionName queryString:(NSString *)queryString completion:(void(^)(NSArray *objects, NSError *error))completion;
@end

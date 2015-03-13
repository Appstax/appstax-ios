
#import <Foundation/Foundation.h>

@interface AXJsonApiClient : NSObject<NSURLSessionDelegate>

@property (readonly) NSString *sessionID;

- (instancetype)initWithAppKey:(NSString *)appKey baseUrl:(NSString *)baseUrl;
- (void)postDictionary:(NSDictionary *)dictionary toUrl:(NSURL *)url completion:(void(^)(NSDictionary *dictionary, NSError *error))completion;
- (void)putDictionary:(NSDictionary *)dictionary toUrl:(NSURL *)url completion:(void(^)(NSDictionary *dictionary, NSError *error))completion;
- (void)sendMultipartFormData:(NSDictionary *)dataParts toUrl:(NSURL *)url method:(NSString *)method completion:(void(^)(NSDictionary *dictionary, NSError *error))completion;
- (void)arrayFromUrl:(NSURL *)url completion:(void(^)(NSArray *array, NSError *error))completion;
- (void)dictionaryFromUrl:(NSURL *)url completion:(void(^)(NSDictionary *dictionary, NSError *error))completion;
- (void)dataFromUrl:(NSURL *)url completion:(void(^)(NSData *data, NSError *error))completion;
- (void)deleteUrl:(NSURL *)url completion:(void(^)(NSError *error))completion;
- (NSURL *)urlByConcatenatingStrings:(NSArray *)strings;
- (NSURL *)urlFromTemplate:(NSString *)template parameters:(NSDictionary *)parameters;

@end

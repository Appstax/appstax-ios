
#import <Foundation/Foundation.h>
#import "AXJsonApiClient.h"
#import "AXFile.h"
#import "AXObject.h"

@interface AXFileService : NSObject

- (instancetype)initWithApiClient:(AXJsonApiClient *)apiClient;

- (void)saveFilesForObject:(AXObject *)object completion:(void(^)(NSError *error))completion;
- (void)loadDataForFile:(AXFile *)file completion:(void(^)(AXFile *file, NSData *data, NSError *error))completion;
- (void)loadImageDataForFile:(AXFile *)file size:(CGSize)size crop:(BOOL)crop completion:(void(^)(AXFile *file, NSData *data, NSError *error))completion;
- (NSURL *)urlForFileName:(NSString *)filename objectID:(NSString *)objectID propertyName:(NSString *)propertyName collectionName:(NSString *)collectionName;

@end

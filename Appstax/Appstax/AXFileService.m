
#import "AXFileService.h"
#import "AppstaxInternals.h"

@interface AXFileService()
@property AXJsonApiClient *apiClient;
@end

@implementation AXFileService

- (instancetype)initWithApiClient:(AXJsonApiClient *)apiClient {
    self = [super init];
    if(self != nil) {
        _apiClient = apiClient;
    }
    return self;
}

- (void)saveFilesForObject:(AXObject *)object completion:(void(^)(NSError *error))completion {
    __block NSUInteger fileCount = 0;
    __block NSUInteger completeCount = 0;
    id completionHandler = ^(NSError *error) {
        completeCount++;
        if(completion && completeCount == fileCount) {
            completion(error);
        }
    };
    for(NSString *key in object.allProperties.keyEnumerator) {
        id value = object[key];
        if([value isKindOfClass:[AXFile class]]) {
            AXFile *file = (AXFile *)value;
            if(file.status == AXFileStatusNew) {
                fileCount++;
                [self saveFile:file forObjectID:object.objectID
                  propertyName:key collectionName:object.collectionName
                    completion:completionHandler];
            }
        }
    }
    if(fileCount == 0 && completion != nil) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
    }
}

- (void)saveFile:(AXFile *)file forObjectID:(NSString *)objectID propertyName:(NSString *)propertyName collectionName:(NSString *)collectionName completion:(void(^)(NSError *error))completion {
    NSURL *url = [self urlForFileName:file.filename objectID:objectID
                     propertyName:propertyName collectionName:collectionName];
    [file setUrl:url];
    [file setStatus:AXFileStatusSaving];
    [_apiClient sendMultipartFormData:@{@"file":@{@"data":[self dataForFile:file],
                                                  @"mimeType":file.mimeType,
                                                  @"filename":file.filename}}
                                toUrl:url
                               method:@"PUT"
                           completion:^(NSDictionary *dictionary, NSError *error) {
                               if(completion) {
                                   [file setStatus:AXFileStatusSaved];
                                   completion(error);
                               }
                           }];
}

- (void)loadDataForFile:(AXFile *)file completion:(void(^)(AXFile *file, NSData *data, NSError *error))completion {
    [_apiClient dataFromUrl:file.url completion:^(NSData *data, NSError *error) {
        if(completion) {
            completion(file, data, error);
        }
    }];
}

- (void)loadImageDataForFile:(AXFile *)file size:(CGSize)size crop:(BOOL)crop completion:(void(^)(AXFile *file, NSData *data, NSError *error))completion {
    NSURL *url = [self imageUrlForFile:file size:size crop:crop];
    [_apiClient dataFromUrl:url completion:^(NSData *data, NSError *error) {
        if(completion) {
            completion(file, data, error);
        }
    }];
}

- (NSData *)dataForFile:(AXFile *)file {
    NSData *data = file.data;
    if(data == nil && file.dataPath != nil) {
        data = [NSData dataWithContentsOfFile:file.dataPath];
    }
    if(data == nil) {
        data = [NSData data];
    }
    return data;
}

- (NSURL *)urlForFileName:(NSString *)filename objectID:(NSString *)objectID propertyName:(NSString *)propertyName collectionName:(NSString *)collectionName {
    return [_apiClient urlFromTemplate:@"/files/:collectionName/:objectID/:propertyName/:fileName"
                            parameters:@{@"collectionName":collectionName,
                                         @"objectID":objectID,
                                         @"propertyName":propertyName,
                                         @"fileName":filename}];
}

- (NSURL *)imageUrlForFile:(AXFile *)file size:(CGSize)size crop:(BOOL)crop {
    NSString *path = [NSString stringWithFormat:@"/images/%@/%@/%@/",
                      crop ? @"crop" : @"resize",
                      size.width  > 0 ? @(size.width ).stringValue : @"-",
                      size.height > 0 ? @(size.height).stringValue : @"-"];
    return [NSURL URLWithString:[file.url.absoluteString stringByReplacingOccurrencesOfString:@"/files/" withString:path]];
}

@end

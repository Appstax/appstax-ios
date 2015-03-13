
#import "AXFile.h"
#import "AppstaxInternals.h"

@implementation AXFile

+ (instancetype)fileWithData:(NSData *)data name:(NSString *)name {
    return [[AXFile alloc] initWithData:data dataPath:nil name:name url:nil status:AXFileStatusNew];
}

+ (instancetype)fileWithImage:(UIImage *)image name:(NSString *)name {
    NSData *data = UIImagePNGRepresentation(image);
    return [[AXFile alloc] initWithData:data dataPath:nil name:name url:nil status:AXFileStatusNew];
}

+ (instancetype)fileWithUrl:(NSURL *)url name:(NSString *)name status:(AXFileStatus)status {
    return [[AXFile alloc] initWithData:nil dataPath:nil name:name url:url status:status];
}

+ (instancetype)fileWithPath:(NSString *)path {
    return [[AXFile alloc] initWithData:nil dataPath:path name:[path lastPathComponent] url:nil status:AXFileStatusNew];
}

- (instancetype)initWithData:(NSData *)data dataPath:(NSString *)dataPath name:(NSString *)name url:(NSURL *)url status:(AXFileStatus)status {
    self = [super init];
    if(self != nil) {
        _url = url;
        _status = status;
        _filename = name;
        _data = data;
        _dataPath = dataPath;
        _mimeType = [AXFile mimeTypeFromFilename:_filename];
    }
    return self;
}

- (void)setUrl:(NSURL *)url {
    _url = url;
}

- (void)setStatus:(AXFileStatus)status {
    _status = status;
}

- (void)setData:(NSData *)data {
    _data = data;
}

- (void)load:(void(^)(NSError *error))completion {
    [[[Appstax defaultContext] fileService] loadDataForFile:self completion:^(AXFile *file, NSData *data, NSError *error) {
        if(!error) {
            _data = data;
        }
        if(completion) {
            completion(error);
        }
    }];
}

- (void)loadImageSize:(CGSize)size crop:(BOOL)crop completion:(void(^)(NSError *error))completion {
    [[[Appstax defaultContext] fileService] loadImageDataForFile:self size:size crop:crop completion:^(AXFile *file, NSData *data, NSError *error) {
        if(!error) {
            _data = data;
        }
        if(completion) {
            completion(error);
        }
    }];
}

- (void)unload {
    _data = nil;
}

+ (NSString *)mimeTypeFromFilename:(NSString *)filename {
    NSString *type = @{@"txt":@"text/plain",
                       @"png":@"image/png",
                       @"gif":@"image/gif",
                       @"jpg":@"image/jpeg",
                       @"jpeg":@"image/jpeg",
                       @"html":@"text/html",
                       @"htm":@"text/html"
                       }[filename.pathExtension];
    if(type == nil) {
        type = @"application/octet-stream";
    }
    return type;
}



@end

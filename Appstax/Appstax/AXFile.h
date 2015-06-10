
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef enum {
    AXFileStatusNew,
    AXFileStatusSaving,
    AXFileStatusSaved
} AXFileStatus;

@interface AXFile : NSObject

// TODO: Make internal when converting to Swift
@property AXFileStatus status;
@property NSURL *url;

@property (readonly) NSString *filename;
@property (readonly) NSData *data;
@property (readonly) NSString *dataPath;
@property (readonly) NSString *mimeType;

+ (instancetype)fileWithData:(NSData *)data name:(NSString *)name;
+ (instancetype)fileWithImage:(UIImage *)image name:(NSString *)name;
+ (instancetype)fileWithPath:(NSString *)path;
+ (instancetype)fileWithUrl:(NSURL *)url name:(NSString *)name status:(AXFileStatus)status;

- (void)load:(void(^)(NSError *error))completion;
- (void)loadImageSize:(CGSize)size crop:(BOOL)crop completion:(void(^)(NSError *error))completion;
- (void)unload;

@end

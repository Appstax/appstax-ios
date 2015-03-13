

#import "AXImageView.h"
#import "AppstaxInternals.h"

@interface AXImageView()
@property AXFile *file;
@end

@implementation AXImageView

+ (instancetype)viewWithFile:(AXFile *)file {
    AXImageView *view = [[AXImageView alloc] init];
    [view loadFile:file];
    return view;
}

+ (instancetype)viewWithFile:(AXFile *)file size:(CGSize)size crop:(BOOL)crop {
    AXImageView *view = [[AXImageView alloc] init];
    [view loadFile:file size:size crop:crop];
    return view;
}

- (void)loadFile:(AXFile *)file {
    _file = file;
    [[[Appstax defaultContext] fileService] loadDataForFile:file completion:^(AXFile *file, NSData *data, NSError *error) {
        if(!error && file == _file) {
            self.image = [UIImage imageWithData:data];
        }
    }];
}

- (void)loadFile:(AXFile *)file size:(CGSize)size crop:(BOOL)crop {
    _file = file;
    [[[Appstax defaultContext] fileService] loadImageDataForFile:file size:size crop:crop completion:^(AXFile *file, NSData *data, NSError *error) {
        if(!error && file == _file) {
            self.image = [UIImage imageWithData:data];
        }
    }];
}

@end

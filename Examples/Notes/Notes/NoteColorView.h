
#import <UIKit/UIKit.h>

@class NoteColorView;

@protocol NoteColorViewDelegate
- (void)colorView:(NoteColorView *)view didSelectIndex:(NSUInteger)index color:(UIColor *)color;
@end

@interface NoteColorView : UIView

@property (weak) id<NoteColorViewDelegate> IBOutlet delegate;

- (void)show;

@end

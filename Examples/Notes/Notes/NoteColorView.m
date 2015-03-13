
#import "NoteColorView.h"
#import "NoteColors.h"

@interface NoteColorView ()
@property NSLayoutConstraint *heightConstraint;
@end

@implementation NoteColorView

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setClipsToBounds:YES];
        [self setupHeightConstraint];
        [self setupButtons];
    }
    return self;
}

- (void)setupHeightConstraint {
    _heightConstraint = [NSLayoutConstraint constraintWithItem:self
                                                     attribute:NSLayoutAttributeHeight
                                                     relatedBy:NSLayoutRelationEqual
                                                        toItem:nil
                                                     attribute:NSLayoutAttributeNotAnAttribute
                                                    multiplier:1
                                                      constant:0];
    [self addConstraint:_heightConstraint];
}

- (void)setupButtons {
    NSArray *colors = [NoteColors allColors];
    CGSize container = self.frame.size;
    CGFloat height = container.height;
    CGFloat width = container.width / colors.count;
    for(int i = 0; i < colors.count; i++) {
        CGFloat x = i * width;
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(x, 0, width, height);
        button.backgroundColor = colors[i];
        button.tag = i;
        [button addTarget:self action:@selector(selected:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
    }
}

- (void)selected:(UIButton *)sender {
    UIColor *color = [NoteColors allColors][sender.tag];
    if(_delegate) {
        [_delegate colorView:self didSelectIndex:sender.tag color:color];
    }
}

- (void)show {
    [self.superview layoutIfNeeded];
    [UIView animateWithDuration:0.4 animations:^{
        [_heightConstraint setConstant:44];
        [self.superview layoutIfNeeded];
    }];
}

@end

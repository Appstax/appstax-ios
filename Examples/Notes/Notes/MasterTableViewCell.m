
#import "MasterTableViewCell.h"
#import "NoteColors.h"

@interface MasterTableViewCell ()
@property CAGradientLayer *gradientLayer;
@property CAGradientLayer *selectedGradientLayer;
@end

@implementation MasterTableViewCell

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if(self) {
        [self setupBackground];
        [self addObserver:self
               forKeyPath:@"self.note.status"
                  options:NSKeyValueObservingOptionNew
                  context:NULL];
    }
    return self;
}

- (void)setupBackground {
    _gradientLayer = [CAGradientLayer layer];
    _gradientLayer.colors = @[(id)[UIColor colorWithWhite:0 alpha:0].CGColor,
                              (id)[UIColor colorWithWhite:0 alpha:0.08].CGColor];
    _gradientLayer.frame = self.bounds;
    _selectedGradientLayer = [CAGradientLayer layer];
    _selectedGradientLayer.colors = @[(id)[UIColor colorWithWhite:0 alpha:0.3].CGColor,
                                      (id)[UIColor colorWithWhite:0 alpha:0.4].CGColor];
    _selectedGradientLayer.frame = self.bounds;
    [self setBackgroundColor:[UIColor clearColor]];
    [self setBackgroundView:[[UIView alloc] init]];
    [self.backgroundView.layer addSublayer:_gradientLayer];
    [self setSelectedBackgroundView:[[UIView alloc] init]];
    [self.selectedBackgroundView.layer addSublayer:_selectedGradientLayer];
}

- (void)setNote:(AXObject *)note {
    _note = note;
    ((UILabel *)[self viewWithTag:1001]).text = self.note[@"Title"];
    ((UILabel *)[self viewWithTag:1002]).text = [self trimAndRemoveNewlines:self.note[@"Content"]];
    _gradientLayer.backgroundColor = [[NoteColors allColors][[_note[@"ColorIndex"] intValue]] CGColor];
    _selectedGradientLayer.backgroundColor = _gradientLayer.backgroundColor;
}

- (NSString *)trimAndRemoveNewlines:(NSString *)string {
    return [[string stringByReplacingOccurrencesOfString:@"\n" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    UIActivityIndicatorView *activity = (UIActivityIndicatorView *)[self viewWithTag:1003];
    if(self.note.status == AXObjectStatusSaving) {
        [activity startAnimating];
    } else {
        [activity stopAnimating];
    }
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"self.note.status"];
}

@end

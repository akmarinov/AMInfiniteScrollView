//
//  AMInfiniteScrollView.m
//  AMInfiniteScrollView
//
//  Created by Andrew Marinov on 02.09.2013.
//  Copyright (c) 2013 Andrew Marinov. All rights reserved.
//

#import "AMInfiniteScrollView.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

NSString * const AMInfiniteScrollViewDirectionChanged = @"AMInfiniteScrollViewDirectionChanged";
NSInteger const kDefaultAutomaticScrollingSpeed = 1.0f;
CGFloat const kDefaultTimerFireRate = 1.0f;

static char const * const AMObjectIndexKey = "AMObjectIndexKey";

@interface AMInfiniteScrollView () <UIScrollViewDelegate>

@property (strong, nonatomic) NSMutableArray *visibleViews;
@property (strong, nonatomic) NSMutableSet *recycledViews;
@property (strong, nonatomic) UIView *containerView;

@property (strong, nonatomic) UINib *prototypeNib;
@property (assign, nonatomic) Class prototypeClass;

@property (assign, nonatomic) NSInteger numberOfCells;
@property (assign, nonatomic) NSInteger currentlyVisibleIndex;

@property (assign, nonatomic) BOOL firstLayout;

@property (strong, nonatomic) CADisplayLink *scrollTimer;

@end

@implementation AMInfiniteScrollView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        [self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self setup];
    }
    return self;
}

- (void)setShouldScrollAutomatically:(BOOL)shouldScrollAutomatically {
    _shouldScrollAutomatically = shouldScrollAutomatically;
    
    if (shouldScrollAutomatically) {
        if (!self.scrollTimer) {
            self.scrollTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(automaticScroll:)];
            self.scrollTimer.frameInterval = kDefaultTimerFireRate;
            self.scrollTimer.paused = NO;
            
            [self.scrollTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        } else {
            self.scrollTimer.paused = NO;
        }
    } else {
        self.scrollTimer.paused = YES;
    }
}

- (void)automaticScroll:(CADisplayLink *) timer {
    [self setContentOffset:CGPointMake((self.contentOffset.x + (kDefaultAutomaticScrollingSpeed  * self.scrollDirection)),
                                       self.contentOffset.y)];
}

- (void)setScrollDirection:(AMInfiniteScrollViewDirection)scrollDirection {
    if (scrollDirection != _scrollDirection && self.visibleViews.count > 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:AMInfiniteScrollViewDirectionChanged object:@(scrollDirection)];
        
        switch (_scrollDirection) {
            case AMInfiniteScrollViewDirectionLeft: {
                UIView *firstView = [self.visibleViews firstObject];
                self.currentlyVisibleIndex = [self getIndexFromObject:firstView];
            }
                break;
            case AMInfiniteScrollViewDirectionRight: {
                UIView *lastView = [self.visibleViews lastObject];
                self.currentlyVisibleIndex = [self getIndexFromObject:lastView];
            }
                break;
        }
    }
    
    _scrollDirection = scrollDirection;
}

- (void)handleContentSizeChange {
    self.contentSize = [self.dataSource contentSizeForScrollView:self];
    for (UIView *view in self.visibleViews) {
        [self.dataSource infiniteScroll:self willDisplayView:view atIndex:[self getIndexFromObject:view]];
    }
}

- (void)setup
{
    self.recycledViews = [[NSMutableSet alloc] init];
    self.visibleViews = [[NSMutableArray alloc] init];
    self.scrollDirection = AMInfiniteScrollViewDirectionLeft;
    
    self.numberOfCells = NSIntegerMax;
    
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    
    self.containerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, self.frame.size.height)];
    self.containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
    self.containerView.clipsToBounds = NO;
    [self addSubview:self.containerView];
    
    self.containerView.backgroundColor = [UIColor clearColor];
    
    self.delegate = self;
    
    self.backgroundColor = [UIColor clearColor];
    // hide horizontal scroll indicator so our recentering trick is not revealed
    [self setShowsHorizontalScrollIndicator:NO];
    [self setShowsVerticalScrollIndicator:NO];
}

- (void)setContentSize:(CGSize)contentSize {
    [super setContentSize:contentSize];
    self.containerView.frame = CGRectMake(0, 0, contentSize.width, contentSize.height);
}

- (void)reloadData {
    [self.containerView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.recycledViews addObjectsFromArray:self.visibleViews];
    [self.visibleViews removeAllObjects];
    
    self.contentSize = [self.dataSource contentSizeForScrollView:self];
    self.shouldScrollAutomatically = [self.dataSource infiniteScrollViewShouldScrollAutomatically:self];
    self.numberOfCells = [self.dataSource infiniteScrollViewNumberOfCells:self];
    [self layoutSubviews];
}

- (void)registerPrototypeViewClass:(Class)viewClass {
    self.prototypeClass = viewClass;
}

- (void)registerPrototypeNib:(UINib *)nib {
    self.prototypeNib = nib;
}

- (void)prepareToRotate {
    NSInteger middleIndex = self.visibleViews.count / 2;
    UIView *view = nil;
    
    if (middleIndex == 0) {
        view = self.visibleViews[middleIndex];
    } else {
        view = [self.visibleViews lastObject];
    }
    
    self.currentlyVisibleIndex = [self getIndexFromObject:view];
}

- (void)handleOrientationChange {
    if (self.visibleViews.count > 0) {
        [self prepareToRotate];
        [self reloadData];
    }
}

#pragma mark - Layout

// recenter content periodically to achieve impression of infinite scrolling
- (void)recenterIfNecessary
{
    CGPoint currentOffset = [self contentOffset];
    CGFloat contentWidth = [self contentSize].width;
    CGFloat centerOffsetX = (contentWidth - [self bounds].size.width) / 2.0;
    CGFloat distanceFromCenter = fabs(currentOffset.x - centerOffsetX);
    
    if (distanceFromCenter > (contentWidth / 4.0)) {
        self.contentOffset = CGPointMake(centerOffsetX, currentOffset.y);
        
        // move content by the same amount so it appears to stay still
        for (UIView *view in self.visibleViews) {
            CGPoint center = [self.containerView convertPoint:view.center toView:self];
            center.x += floorf((centerOffsetX - currentOffset.x));
            view.center = [self convertPoint:center toView:self.containerView];
        }
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.numberOfCells == NSIntegerMax) {
        self.numberOfCells = [self.dataSource infiniteScrollViewNumberOfCells:self];
    } else {
        
        [self recenterIfNecessary];
        
        // tile content in visible bounds
        CGRect visibleBounds = [self convertRect:[self bounds] toView:self.containerView];
        CGFloat minimumVisibleX = CGRectGetMinX(visibleBounds);
        CGFloat maximumVisibleX = CGRectGetMaxX(visibleBounds);
        
        [self tileViewsFromMinX:floorf(minimumVisibleX) toMaxX:ceilf(maximumVisibleX)];
    }
}


#pragma mark - Tiling

- (UIView *)dequeueCell {
    UIView *view = [self.recycledViews anyObject];
    if (view) {
        [self.recycledViews removeObject:view];
    } else {
        view = [[self.prototypeNib instantiateWithOwner:self options:nil] lastObject];
        
        if (!view) {
            view = [[self.prototypeClass alloc] init];
        }
    }
    NSAssert(view, @"There must be a valid view after the dequeue process.");
    
    if (view.gestureRecognizers.count == 0 && self.isUserInteractionEnabled) {
        UITapGestureRecognizer *tapGR = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewWasTappedWithGR:)];
        [view addGestureRecognizer:tapGR];
    }
    
    return view;
}

- (UIView *)insertViewAtIndex:(NSInteger) index
{
    UIView *view = [self.dataSource infiniteScrollView:self cellForRowAtIndex:index];
    [self setObjectIndex:index toObject:view];
    
    NSAssert(view, @"There must be a view.");
    
    [self.containerView addSubview:view];
    
    [self.dataSource infiniteScroll:self willDisplayView:view atIndex:index];
    
    return view;
}

- (CGFloat)placeNewViewOnRight:(CGFloat)rightEdge
{
    NSInteger index = 0;
    if (self.numberOfCells > 0 && self.numberOfCells != NSIntegerMax) {
        index = ((self.currentlyVisibleIndex % self.numberOfCells) + self.numberOfCells) % self.numberOfCells;
    } else {
        return -1;
    }
    
    UIView *view = [self insertViewAtIndex:index];
    [self.visibleViews addObject:view]; // add rightmost label at the end of the array
    
    CGRect frame = [view frame];
    frame.origin.x = ceilf(rightEdge);
    [view setFrame:frame];
    
    return CGRectGetMaxX(frame);
}

- (CGFloat)placeNewViewOnLeft:(CGFloat)leftEdge
{
    NSInteger index = 0;
    if (self.numberOfCells > 0 && self.numberOfCells != NSIntegerMax) {
        index = ((self.currentlyVisibleIndex % self.numberOfCells) + self.numberOfCells) % self.numberOfCells;
    } else {
        return 0;
    }
    
   
    
    UIView *view = [self insertViewAtIndex:index];
    [self.visibleViews insertObject:view atIndex:0]; // add leftmost label at the beginning of the array
    
    CGRect frame = [view frame];
    frame.origin.x = floorf(leftEdge - frame.size.width);
    [view setFrame:frame];
    
    return CGRectGetMinX(frame);
}

- (void)tileViewsFromMinX:(CGFloat)minimumVisibleX toMaxX:(CGFloat)maximumVisibleX
{
    // the upcoming tiling logic depends on there already being at least one view in the visibleLabels array, so
    // to kick off the tiling we need to make sure there's at least one label
    if ([self.visibleViews count] == 0)
    {
        if ([self placeNewViewOnRight:minimumVisibleX] < 0) {
            return;
        }
    }
    
    CGFloat spacing = [self.dataSource infiniteScrollView:self spacingAfterIndex:self.currentlyVisibleIndex + 1];
    
    // add views that are missing on right side
    UIView *lastView = [self.visibleViews lastObject];
    CGFloat rightEdge = ceilf(CGRectGetMaxX([lastView frame]) + spacing);
    while (rightEdge < maximumVisibleX)
    {
        UIView *lastView = [self.visibleViews lastObject];
        self.currentlyVisibleIndex = [self getIndexFromObject:lastView] + 1;
        
        rightEdge = [self placeNewViewOnRight:rightEdge] + spacing;
    }
    
    if (self.firstLayout == NO) {
        self.firstLayout = YES;
        self.currentlyVisibleIndex = 0;
    }
    
    // add views that are missing on left side
    UIView *firstView = self.visibleViews[0];
    CGFloat leftEdge = floorf(CGRectGetMinX([firstView frame]) - spacing);
    while (leftEdge > minimumVisibleX)
    {
        UIView *firstView = [self.visibleViews firstObject];
        self.currentlyVisibleIndex = [self getIndexFromObject:firstView] - 1;
        leftEdge = [self placeNewViewOnLeft:leftEdge] - spacing;
    }
    
    // remove labels that have fallen off right edge
    lastView = [self.visibleViews lastObject];
    while ([lastView frame].origin.x > maximumVisibleX + spacing)
    {
        [lastView removeFromSuperview];
        [self setObjectIndex:-1 toObject:lastView];
        [self.recycledViews addObject:lastView];
        [self.visibleViews removeLastObject];
        lastView = [self.visibleViews lastObject];
    }
    
    // remove labels that have fallen off left edge
    firstView = self.visibleViews[0];
    while (CGRectGetMaxX([firstView frame]) < minimumVisibleX - spacing)
    {
        [firstView removeFromSuperview];
        [self setObjectIndex:-1 toObject:firstView];
        [self.recycledViews addObject:firstView];
        [self.visibleViews removeObjectAtIndex:0];
        firstView = self.visibleViews[0];
    }
}

#pragma mark - Custom Object Index Setters/Getters


-(void)setObjectIndex:(NSInteger) index toObject:(id) object {
    objc_setAssociatedObject(object, AMObjectIndexKey, @(index), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)getIndexFromObject:(id) object {
    return [objc_getAssociatedObject(object, AMObjectIndexKey) integerValue];
}

#pragma mark - Gesture Recognizer

- (void)viewWasTappedWithGR:(UITapGestureRecognizer *) tapGR {
    [self.infiniteScrollDelegate infiniteScroll:self viewDidTapOnViewWithIndex:[self getIndexFromObject:tapGR.view]];
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    self.shouldScrollAutomatically = NO;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
        self.shouldScrollAutomatically = YES;
}

@end

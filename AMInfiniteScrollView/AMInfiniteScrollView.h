//
//  AMInfiniteScrollView.h
//  AMInfiniteScrollView
//
//  Created by Andrew Marinov on 02.09.2013.
//  Copyright (c) 2013 Andrew Marinov. All rights reserved.
//

#import <UIKit/UIKit.h>

UIKIT_EXTERN NSString* const AMInfiniteScrollViewDirectionChanged;


typedef NS_ENUM(NSInteger, AMInfiniteScrollViewDirection){
    AMInfiniteScrollViewDirectionRight = -1,
    AMInfiniteScrollViewDirectionLeft  =  1
};


@class AMInfiniteScrollView;

@protocol AMInfiniteScrollViewDelegate

@optional

- (void)infiniteScroll:(AMInfiniteScrollView *) infiniteScrollView viewDidTapOnViewWithIndex:(NSInteger) viewIndex;

@end

@protocol AMInfiniteScrollViewDataSource

@required

- (NSUInteger)infiniteScrollViewNumberOfCells:(AMInfiniteScrollView *)infiniteScrollView;
- (UIView *)infiniteScrollView:(AMInfiniteScrollView *)infiniteScrollView cellForRowAtIndex:(NSInteger)index;
- (CGSize)contentSizeForScrollView:(AMInfiniteScrollView *) scrollView;

@optional
- (CGFloat)infiniteScrollView:(AMInfiniteScrollView *)infiniteScrollView spacingAfterIndex:(NSInteger)index;
- (BOOL)infiniteScrollViewShouldScrollAutomatically:(AMInfiniteScrollView *)infiniteScrollView;
- (void)infiniteScroll:(AMInfiniteScrollView *) infiniteScrollView willDisplayView:(UIView *) view atIndex:(NSInteger) index;

@end


@interface AMInfiniteScrollView : UIScrollView

@property (weak, nonatomic) id<AMInfiniteScrollViewDataSource> dataSource;
@property (weak, nonatomic) id<AMInfiniteScrollViewDelegate> infiniteScrollDelegate;
@property (assign, nonatomic) AMInfiniteScrollViewDirection scrollDirection;
@property (assign, nonatomic) BOOL shouldScrollAutomatically;

- (void)reloadData;
- (void)registerPrototypeViewClass:(Class)viewClass;
- (void)registerPrototypeNib:(UINib *)nib;
- (UIView *)dequeueCell;
- (void)handleOrientationChange;
- (void)handleContentSizeChange;
@end

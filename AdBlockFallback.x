#import <UIKit/UIKit.h>
#import <math.h>

#import "AdBlockFallback.h"
#import "LogHelper.h"


@interface MANativeAdLoader : NSObject
- (void)loadAdIntoAdView:(id)view;
@end


@interface _TtC6Legacy26AdContainingViewController : UIViewController
- (UIView *)adContainerView;
- (UIView *)adBackgroundView;
- (NSLayoutConstraint *)adContainerViewHeightConstraint;
- (NSLayoutConstraint *)adBackgroundViewHeightConstraint;
- (void)updateAdVisibility;
@end


@class _TtC6Legacy33TableViewModelTableViewController;


@interface _TtC3Ads24RectangleAdTableViewCell : UITableViewCell
@end


#pragma mark - Settings

static BOOL pxQoLShouldEnableAdBlockFallback(void)
{
    NSUserDefaults *defaults =
        [NSUserDefaults standardUserDefaults];

    /*
     * 主広告ブロック。
     *
     * 未設定時はデフォルトYES。
     */
    id blockAdsValue =
        [defaults objectForKey:@"pxQoL_BlockAds"];

    BOOL blockAdsEnabled =
        blockAdsValue
            ? [blockAdsValue boolValue]
            : YES;

    if (!blockAdsEnabled) {
        return NO;
    }


    /*
     * Fallback。
     *
     * 未設定時はデフォルトNO。
     */
    id fallbackValue =
        [defaults objectForKey:@"pxQoL_AdBlockFallback"];

    BOOL fallbackEnabled =
        fallbackValue
            ? [fallbackValue boolValue]
            : NO;

    return fallbackEnabled;
}


#pragma mark - AdContainingViewController

static void pxQoLNeutralizeAdContainingViewController(
    _TtC6Legacy26AdContainingViewController *viewController)
{
    UIView *adContainerView =
        [viewController adContainerView];

    UIView *adBackgroundView =
        [viewController adBackgroundView];

    NSLayoutConstraint *adContainerViewHeightConstraint =
        [viewController adContainerViewHeightConstraint];

    NSLayoutConstraint *adBackgroundViewHeightConstraint =
        [viewController adBackgroundViewHeightConstraint];

    if (adContainerView) {
        adContainerView.hidden = YES;
        adContainerView.clipsToBounds = YES;
        adContainerView.userInteractionEnabled = NO;
    }

    if (adBackgroundView) {
        adBackgroundView.hidden = YES;
        adBackgroundView.clipsToBounds = YES;
        adBackgroundView.userInteractionEnabled = NO;
    }

    if (adContainerViewHeightConstraint) {
        adContainerViewHeightConstraint.constant = 0.0;
    }

    if (adBackgroundViewHeightConstraint) {
        adBackgroundViewHeightConstraint.constant = 0.0;
    }

    UIEdgeInsets additionalSafeAreaInsets =
        viewController.additionalSafeAreaInsets;

    if (additionalSafeAreaInsets.bottom != 0.0) {
        additionalSafeAreaInsets.bottom = 0.0;
        viewController.additionalSafeAreaInsets = additionalSafeAreaInsets;
    }
}


#pragma mark - Fallback Hooks

%group pxQoLAdBlockFallback


#pragma mark AppLovin

%hook MANativeAdLoader

- (void)loadAdIntoAdView:(id)view
{
    pxQoLLog(
        @"[AppLovinNativeAd/Fallback] blocked loadAdIntoAdView: %@",
        view
    );
}

%end


#pragma mark AdContainingViewController

%hook _TtC6Legacy26AdContainingViewController

- (void)viewDidLoad
{
    %orig;
    pxQoLNeutralizeAdContainingViewController(self);
}

- (void)viewWillAppear:(BOOL)animated
{
    %orig(animated);
    pxQoLNeutralizeAdContainingViewController(self);
}

- (void)updateAdVisibility
{
    %orig;
    pxQoLNeutralizeAdContainingViewController(self);
}

- (void)viewWillLayoutSubviews
{
    %orig;
    pxQoLNeutralizeAdContainingViewController(self);
}

%end


#pragma mark RectangleAdTableViewCell

%hook _TtC6Legacy33TableViewModelTableViewController

- (CGFloat)tableView:(UITableView *)tableView
heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat originalHeight = %orig;

    /*
     * Rectangle広告rowの純正height:
     *
     *   width * 5/6 + 38
     *
     * 実機観測:
     *   width 414 -> 383
     *   width   0 -> 38
     *
     * indexPathの位置には依存しない。
     */
    CGFloat rectangleHeight =
        CGRectGetWidth(tableView.bounds) * (5.0 / 6.0) + 38.0;

    if (fabs(originalHeight - rectangleHeight) < 0.001) {
        return 0.0;
    }

    return originalHeight;
}

%end


%hook _TtC3Ads24RectangleAdTableViewCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
{
    id cell =
        %orig(style, reuseIdentifier);

    if (cell) {
        [cell setHidden:YES];
        [cell setClipsToBounds:YES];
        [cell setUserInteractionEnabled:NO];
    }

    return cell;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    id cell =
        %orig(coder);

    if (cell) {
        [cell setHidden:YES];
        [cell setClipsToBounds:YES];
        [cell setUserInteractionEnabled:NO];
    }

    return cell;
}

- (void)prepareForReuse
{
    %orig;

    [self setHidden:YES];
    [self setClipsToBounds:YES];
    [self setUserInteractionEnabled:NO];
}

%end


%end // pxQoLAdBlockFallback


#pragma mark - Init

void pxQoLInitAdBlockFallback(void)
{
    if (!pxQoLShouldEnableAdBlockFallback()) {
        return;
    }

    pxQoLLog(
        @"[AdBlockFallback] enabled"
    );

    %init(pxQoLAdBlockFallback);
}
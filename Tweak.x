#import <UIKit/UIKit.h>
#import "BinaryPatch/Legacy/AdContainingViewController/Patch.h"

#import "LogHelper.h"

@interface UIImageAsset (pxQoL)
- (NSString *)assetName;
@end

@interface _TtC6Legacy20RootTabBarController : UITabBarController
@end

%ctor {
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        @"pxQoL_ShowHome": @YES,
        @"pxQoL_ShowSearch": @YES,
        @"pxQoL_ShowNew": @YES,
        @"pxQoL_ShowNotifications": @YES,
        @"pxQoL_ShowMypage": @YES,

        @"pxQoL_TabOrder": @[
            @"icon-tabbar-mypage",
            @"icon-tabbar-home",
            @"icon-tabbar-search",
            @"icon-tabbar-new",
            @"icon-tabbar-notifications"
        ]
    }];

    BOOL result = pxQoLPatchAdContainingViewController();

    NSLog(@"[pxQoL] ad patch result = %@", result ? @"YES" : @"NO");
}

%hook _TtC6Legacy20RootTabBarController

- (void)setViewControllers:(NSArray<UIViewController *> *)viewControllers
{
    NSMutableArray<UIViewController *> *visibleViewControllers =
        [NSMutableArray arrayWithCapacity:viewControllers.count];

    for (UIViewController *viewController in viewControllers) {
        UITabBarItem *tabBarItem = viewController.tabBarItem;
        UIImage *image = tabBarItem.image;
        UIImageAsset *asset = image.imageAsset;
        NSString *assetName = asset.assetName;

        // ホーム
        if ([assetName isEqualToString:@"icon-tabbar-home"] &&
            ![[NSUserDefaults standardUserDefaults]
                boolForKey:@"pxQoL_ShowHome"]) {

            NSLog(@"[pxQoL] REMOVE icon-tabbar-home");
            continue;
        }

        // みつける
        if ([assetName isEqualToString:@"icon-tabbar-search"] &&
            ![[NSUserDefaults standardUserDefaults]
                boolForKey:@"pxQoL_ShowSearch"]) {

            NSLog(@"[pxQoL] REMOVE icon-tabbar-search");
            continue;
        }

        // 新着
        if ([assetName isEqualToString:@"icon-tabbar-new"] &&
            ![[NSUserDefaults standardUserDefaults]
                boolForKey:@"pxQoL_ShowNew"]) {

            NSLog(@"[pxQoL] REMOVE icon-tabbar-new");
            continue;
        }

        // 通知
        if ([assetName isEqualToString:@"icon-tabbar-notifications"] &&
            ![[NSUserDefaults standardUserDefaults]
                boolForKey:@"pxQoL_ShowNotifications"]) {

            NSLog(@"[pxQoL] REMOVE icon-tabbar-notifications");
            continue;
        }

        /* ロックアウト対策のためコメントアウトしているが念のため消さない
        // マイページ
        if ([assetName isEqualToString:@"icon-tabbar-mypage"] &&
            ![[NSUserDefaults standardUserDefaults]
                boolForKey:@"pxQoL_ShowMypage"]) {

            NSLog(@"[pxQoL] REMOVE icon-tabbar-mypage");
            continue;
        }
        */

        [visibleViewControllers addObject:viewController];
    }

    /*
     * タブを assetName -> UIViewController にする
     */
    NSMutableDictionary<NSString *, UIViewController *> *tabs =
        [NSMutableDictionary dictionaryWithCapacity:visibleViewControllers.count];

    for (UIViewController *viewController in visibleViewControllers) {
        UITabBarItem *tabBarItem = viewController.tabBarItem;
        UIImage *image = tabBarItem.image;
        UIImageAsset *asset = image.imageAsset;
        NSString *assetName = asset.assetName;

        if (assetName.length > 0) {
            tabs[assetName] = viewController;
        }
    }

    /*
     * 設定に保存されている任意順を取得。
     */
    NSArray<NSString *> *wantedOrder =
        [[NSUserDefaults standardUserDefaults]
            arrayForKey:@"pxQoL_TabOrder"];

    /*
     * 保存値が不正・空の場合は安全なデフォルト順を使用。
     */
    if (wantedOrder.count == 0) {
        wantedOrder = @[
            @"icon-tabbar-mypage",
            @"icon-tabbar-home",
            @"icon-tabbar-search",
            @"icon-tabbar-new",
            @"icon-tabbar-notifications"
        ];
    }

    NSMutableArray<UIViewController *> *reordered =
        [NSMutableArray arrayWithCapacity:visibleViewControllers.count];

    /*
     * 保存順に表示中のタブを追加。
     *
     * seen により、保存値に重複があっても
     * 同じ UIViewController を二重追加しない。
     */
    NSMutableSet<NSString *> *seen =
        [NSMutableSet setWithCapacity:wantedOrder.count];

    for (NSString *assetName in wantedOrder) {
        if (![assetName isKindOfClass:[NSString class]]) {
            continue;
        }

        if ([seen containsObject:assetName]) {
            continue;
        }

        UIViewController *viewController = tabs[assetName];

        if (viewController) {
            [reordered addObject:viewController];
            [seen addObject:assetName];
        }
    }

    /*
     * 保存順に存在しなかった既知/未知のタブを残す。
     *
     * これにより、新しいタブがPixiv側に追加された場合でも
     * そのタブを消失させず末尾に残す。
     */
    for (UIViewController *viewController in visibleViewControllers) {
        UITabBarItem *tabBarItem = viewController.tabBarItem;
        UIImage *image = tabBarItem.image;
        UIImageAsset *asset = image.imageAsset;
        NSString *assetName = asset.assetName;

        if (assetName.length == 0 ||
            ![seen containsObject:assetName]) {

            [reordered addObject:viewController];

            if (assetName.length > 0) {
                [seen addObject:assetName];
            }
        }
    }

    NSLog(
        @"[pxQoL] setViewControllers: %lu -> %lu",
        (unsigned long)viewControllers.count,
        (unsigned long)reordered.count
    );

    %orig(reordered);
}

%end
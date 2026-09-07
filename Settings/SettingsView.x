#import "SettingsView.h"

#pragma mark - pxQoL Settings ViewController

@interface PXQoLSettingsViewController ()
    <UITableViewDragDelegate, UITableViewDropDelegate>
@end

@implementation PXQoLSettingsViewController

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];

    if (self) {
        self.title = @"pxQoL";
    }

    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.navigationItem.title = @"pxQoL";

    UIColor *tableBackgroundColor;

    if (@available(iOS 13.0, *)) {
        tableBackgroundColor =
            [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
                if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithRed:0.0
                                           green:0.0
                                            blue:0.0
                                           alpha:1.0];
                } else {
                    return [UIColor colorWithRed:245.0 / 255.0
                                           green:245.0 / 255.0
                                            blue:245.0 / 255.0
                                           alpha:1.0];
                }
            }];
    } else {
        tableBackgroundColor =
            [UIColor colorWithRed:245.0 / 255.0
                            green:245.0 / 255.0
                             blue:245.0 / 255.0
                            alpha:1.0];
    }

    self.tableView.backgroundColor = tableBackgroundColor;

    /*
     * 標準 editing mode は使用しない。
     *
     * UISwitch を表示したまま、
     * UITableView の Drag & Drop で並べ替える。
     */
    self.tableView.dragDelegate = self;
    self.tableView.dropDelegate = self;
    self.tableView.dragInteractionEnabled = YES;
}

#pragma mark - Sections

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {

    if (section == 0) {
        return 5;
    }

    /*
     * その他
     */
    if (section == 1) {
        return 2;
    }

    return 0;
}

- (NSString *)tableView:(UITableView *)tableView
titleForHeaderInSection:(NSInteger)section {

    if (section == 0) {
        return @"タブバー";
    }

    if (section == 1) {
        return @"その他";
    }

    return nil;
}

- (NSString *)tableView:(UITableView *)tableView
titleForFooterInSection:(NSInteger)section
{
    if (section == 1) {
        return @"変更はpixivの再起動後に反映されます。";
    }

    return nil;
}

- (void)tableView:(UITableView *)tableView
willDisplayHeaderView:(UIView *)view
       forSection:(NSInteger)section {

    if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
        UITableViewHeaderFooterView *header =
            (UITableViewHeaderFooterView *)view;

        header.textLabel.font =
            [UIFont systemFontOfSize:12.0
                              weight:UIFontWeightRegular];
    }
}

#pragma mark - Tab Information

- (NSArray<NSString *> *)pxQoLDefaultTabOrder {
    return @[
        @"icon-tabbar-mypage",
        @"icon-tabbar-home",
        @"icon-tabbar-search",
        @"icon-tabbar-new",
        @"icon-tabbar-notifications"
    ];
}

- (NSArray<NSString *> *)pxQoLTabOrder {

    NSArray<NSString *> *order =
        [[NSUserDefaults standardUserDefaults]
            arrayForKey:@"pxQoL_TabOrder"];

    if (order.count != 5) {
        return [self pxQoLDefaultTabOrder];
    }

    return order;
}

- (NSString *)pxQoLTitleForAssetName:(NSString *)assetName {

    NSDictionary<NSString *, NSString *> *titles = @{
        @"icon-tabbar-home": @"ホーム",
        @"icon-tabbar-search": @"みつける",
        @"icon-tabbar-new": @"新着",
        @"icon-tabbar-notifications": @"通知",
        @"icon-tabbar-mypage": @"マイページ"
    };

    return titles[assetName];
}

- (NSString *)pxQoLKeyForAssetName:(NSString *)assetName {

    NSDictionary<NSString *, NSString *> *keys = @{
        @"icon-tabbar-home": @"pxQoL_ShowHome",
        @"icon-tabbar-search": @"pxQoL_ShowSearch",
        @"icon-tabbar-new": @"pxQoL_ShowNew",
        @"icon-tabbar-notifications": @"pxQoL_ShowNotifications",
        @"icon-tabbar-mypage": @"pxQoL_ShowMypage"
    };

    return keys[assetName];
}

#pragma mark - Cell

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    static NSString *identifier = @"pxQoLTabSettingCell";

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:identifier];

    if (!cell) {
        cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:identifier];
    }

    /*
     * section 0 = タブバー
     */
    if (indexPath.section == 0) {

        NSArray<NSString *> *order = [self pxQoLTabOrder];

        if (indexPath.row < (NSInteger)order.count) {

            NSString *assetName = order[indexPath.row];
            NSString *title =
                [self pxQoLTitleForAssetName:assetName];
            NSString *key =
                [self pxQoLKeyForAssetName:assetName];

            cell.textLabel.text = title;
            cell.textLabel.numberOfLines = 0;

            UISwitch *toggle = [[UISwitch alloc] init];

            /*
             * 行番号ではなく assetName で識別。
             */
            toggle.accessibilityIdentifier = assetName;

            BOOL isMypage =
                [assetName isEqualToString:@"icon-tabbar-mypage"];

            if (isMypage) {

                /*
                 * マイページは常に表示。
                 * ただし位置は自由に変更可能。
                 */
                toggle.on = YES;
                toggle.enabled = NO;

            } else {

                toggle.on =
                    [[NSUserDefaults standardUserDefaults]
                        boolForKey:key];

                [toggle addTarget:self
                           action:@selector(pxQoL_toggleChanged:)
                 forControlEvents:UIControlEventValueChanged];
            }

            cell.accessoryView = toggle;
        }

    } else if (indexPath.section == 1) {

        /*
         * section 1 = その他
         *
         * row 0 = 広告ブロック
         * row 1 = Fallback広告ブロック
         */

        if (indexPath.row == 0) {

            cell.textLabel.text = @"広告ブロック";
            cell.textLabel.numberOfLines = 0;

            UISwitch *toggle =
                [[UISwitch alloc] init];

            toggle.on =
                [[NSUserDefaults standardUserDefaults]
                    boolForKey:@"pxQoL_BlockAds"];

            [toggle addTarget:self
                       action:@selector(pxQoL_adBlockToggleChanged:)
             forControlEvents:UIControlEventValueChanged];

            cell.accessoryView = toggle;

        } else if (indexPath.row == 1) {

            cell.textLabel.text = @"広告ブロック(Fallback)";
            cell.textLabel.numberOfLines = 0;

            UISwitch *toggle =
                [[UISwitch alloc] init];

            toggle.on =
                [[NSUserDefaults standardUserDefaults]
                    boolForKey:@"pxQoL_AdBlockFallback"];

            /*
             * 主広告ブロックがOFFならFallbackも実行されないため、
             * UI上も操作不可にする。
             */
            toggle.enabled =
                [[NSUserDefaults standardUserDefaults]
                    boolForKey:@"pxQoL_BlockAds"];

            [toggle addTarget:self
                       action:@selector(pxQoL_adBlockFallbackToggleChanged:)
             forControlEvents:UIControlEventValueChanged];

            cell.accessoryView = toggle;
        }

    } else {

        cell.textLabel.text = nil;
        cell.accessoryView = nil;
    }

    UIColor *cellColor;

    if (@available(iOS 13.0, *)) {
        cellColor =
            [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
                if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithRed:31.0 / 255.0
                                           green:31.0 / 255.0
                                            blue:31.0 / 255.0
                                           alpha:1.0];
                } else {
                    return [UIColor whiteColor];
                }
            }];
    } else {
        cellColor = [UIColor whiteColor];
    }

    cell.backgroundColor = cellColor;
    cell.contentView.backgroundColor = cellColor;

    cell.layoutMargins =
        UIEdgeInsetsMake(0.0, 20.0, 0.0, 20.0);

    return cell;
}

#pragma mark - Toggle

- (void)pxQoL_toggleChanged:(UISwitch *)sender {

    NSString *assetName =
        sender.accessibilityIdentifier;

    if (assetName.length == 0) {
        return;
    }

    /*
     * マイページは常に表示。
     */
    if ([assetName isEqualToString:@"icon-tabbar-mypage"]) {
        return;
    }

    NSString *key =
        [self pxQoLKeyForAssetName:assetName];

    if (key.length == 0) {
        return;
    }

    [[NSUserDefaults standardUserDefaults]
        setBool:sender.isOn
         forKey:key];

    NSLog(@"[pxQoL] %@ = %@",
          key,
          sender.isOn ? @"YES" : @"NO");
}


- (void)pxQoL_adBlockToggleChanged:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults]
        setBool:sender.isOn
         forKey:@"pxQoL_BlockAds"];

    NSLog(
        @"[pxQoL] pxQoL_BlockAds = %@",
        sender.isOn ? @"YES" : @"NO"
    );

    /*
     * Fallbackセルのenabled状態を更新。
     */
    [self.tableView reloadSections:
        [NSIndexSet indexSetWithIndex:1]
              withRowAnimation:UITableViewRowAnimationNone];
}

- (void)pxQoL_adBlockFallbackToggleChanged:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults]
        setBool:sender.isOn
         forKey:@"pxQoL_AdBlockFallback"];

    NSLog(
        @"[pxQoL] pxQoL_AdBlockFallback = %@",
        sender.isOn ? @"YES" : @"NO"
    );
}

#pragma mark - Drag

- (NSArray<UIDragItem *> *)
tableView:(UITableView *)tableView
itemsForBeginningDragSession:(id<UIDragSession>)session
       atIndexPath:(NSIndexPath *)indexPath {

    /*
     * タブバー section だけドラッグ可能。
     */
    if (indexPath.section != 0) {
        return @[];
    }

    NSArray<NSString *> *order =
        [self pxQoLTabOrder];

    if (indexPath.row >= (NSInteger)order.count) {
        return @[];
    }

    NSString *assetName = order[indexPath.row];

    NSItemProvider *itemProvider =
        [[NSItemProvider alloc]
            initWithObject:assetName];

    UIDragItem *dragItem =
        [[UIDragItem alloc]
            initWithItemProvider:itemProvider];

    /*
     * ドロップ時に assetName を直接取得できるようにする。
     */
    dragItem.localObject = assetName;

    return @[dragItem];
}

#pragma mark - Drop

- (UITableViewDropProposal *)
tableView:(UITableView *)tableView
dropSessionDidUpdate:(id<UIDropSession>)session
withDestinationIndexPath:(NSIndexPath *)destinationIndexPath {

    /*
     * タブバー section 内への移動だけ許可。
     */
    if (destinationIndexPath.section == 0 &&
        [session localDragSession] != nil) {

        return [[UITableViewDropProposal alloc]
            initWithDropOperation:UIDropOperationMove
            intent:UITableViewDropIntentInsertAtDestinationIndexPath];
    }

    /*
     * その他 section への移動は禁止。
     */
    return [[UITableViewDropProposal alloc]
        initWithDropOperation:UIDropOperationCancel];
}

- (void)tableView:(UITableView *)tableView
performDropWithCoordinator:
    (id<UITableViewDropCoordinator>)coordinator {

    NSIndexPath *destinationIndexPath =
        coordinator.destinationIndexPath;

    /*
     * section 0 以外にはドロップさせない。
     */
    if (destinationIndexPath.section != 0) {
        return;
    }

    for (id<UITableViewDropItem> dropItem in coordinator.items) {

        UIDragItem *dragItem = dropItem.dragItem;

        NSString *assetName =
            (NSString *)dragItem.localObject;

        if (![assetName isKindOfClass:[NSString class]]) {
            continue;
        }

        NSArray<NSString *> *currentOrder =
            [self pxQoLTabOrder];

        NSMutableArray<NSString *> *order =
            [currentOrder mutableCopy];

        NSInteger sourceIndex =
            [order indexOfObject:assetName];

        if (sourceIndex == NSNotFound) {
            continue;
        }

        NSInteger destinationIndex =
            destinationIndexPath.row;

        if (destinationIndex < 0 ||
            destinationIndex >= (NSInteger)order.count) {
            continue;
        }

        /*
         * 移動元を削除。
         */
        [order removeObjectAtIndex:sourceIndex];

        if (destinationIndex < 0) {
            destinationIndex = 0;
        }

        if (destinationIndex > (NSInteger)order.count) {
            destinationIndex = order.count;
        }

        [order insertObject:assetName
                    atIndex:destinationIndex];

        /*
         * 新しい順序を保存。
         */
        [[NSUserDefaults standardUserDefaults]
            setObject:order
             forKey:@"pxQoL_TabOrder"];

        NSLog(@"[pxQoL] TabOrder = %@", order);

        /*
         * 設定画面の表示も新しい順序に更新。
         */
        [tableView reloadSections:
            [NSIndexSet indexSetWithIndex:0]
                  withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - Selection

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
}

@end
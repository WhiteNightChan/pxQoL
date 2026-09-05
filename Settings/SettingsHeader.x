#import "SettingsView.h"

#pragma mark - pxQoL Settings Header

@interface PXQoLSettingsHeaderView : UIControl
@property (nonatomic, weak) UIViewController *viewController;
@property (nonatomic, strong) UITableViewCell *settingsCell;
@property (nonatomic, strong) UIColor *normalCellColor;
@property (nonatomic, strong) UIColor *highlightedCellColor;
@end

@implementation PXQoLSettingsHeaderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];

    if (self) {
        UIColor *backgroundColor;
        UIColor *cellColor;
        UIColor *highlightedCellColor;

        if (@available(iOS 13.0, *)) {
            backgroundColor =
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

            highlightedCellColor =
                [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *trait) {
                    if (trait.userInterfaceStyle == UIUserInterfaceStyleDark) {
                        return [UIColor colorWithRed:58.0 / 255.0
                                               green:58.0 / 255.0
                                                blue:60.0 / 255.0
                                               alpha:1.0];
                    } else {
                        return [UIColor colorWithRed:209.0 / 255.0
                                               green:209.0 / 255.0
                                                blue:213.0 / 255.0
                                               alpha:1.0];
                    }
                }];
        } else {
            backgroundColor =
                [UIColor colorWithRed:245.0 / 255.0
                               green:245.0 / 255.0
                                blue:245.0 / 255.0
                               alpha:1.0];

            cellColor = [UIColor whiteColor];

            highlightedCellColor =
                [UIColor colorWithRed:209.0 / 255.0
                               green:209.0 / 255.0
                                blue:213.0 / 255.0
                               alpha:1.0];
        }

        self.backgroundColor = backgroundColor;
        self.accessibilityLabel = @"Tweak設定";

        self.normalCellColor = cellColor;
        self.highlightedCellColor = highlightedCellColor;

        /*
         * カテゴリー名
         */
        UILabel *categoryLabel =
            [[UILabel alloc] initWithFrame:CGRectZero];

        categoryLabel.text = @"pxQoL";
        categoryLabel.font =
            [UIFont systemFontOfSize:12.0
                              weight:UIFontWeightRegular];
        categoryLabel.textColor =
            [UIColor secondaryLabelColor];

        categoryLabel.translatesAutoresizingMaskIntoConstraints = NO;

        [self addSubview:categoryLabel];

        /*
         * 設定セル
         */
        UITableViewCell *cell =
            [[UITableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:nil];

        cell.textLabel.text = @"タブ表示設定";
        cell.textLabel.numberOfLines = 0;
        cell.accessoryType =
            UITableViewCellAccessoryDisclosureIndicator;

        cell.backgroundColor = cellColor;
        cell.contentView.backgroundColor = cellColor;

        cell.layoutMargins =
            UIEdgeInsetsMake(0.0, 20.0, 0.0, 20.0);

        cell.userInteractionEnabled = NO;

        cell.translatesAutoresizingMaskIntoConstraints = NO;

        self.settingsCell = cell;

        [self addSubview:cell];

        /*
         * 上端・下端のseparator
         */
        UIView *topSeparator =
            [[UIView alloc] initWithFrame:CGRectZero];

        UIView *bottomSeparator =
            [[UIView alloc] initWithFrame:CGRectZero];

        UIColor *separatorColor =
            [UIColor separatorColor];

        topSeparator.backgroundColor =
            separatorColor;

        bottomSeparator.backgroundColor =
            separatorColor;

        topSeparator.translatesAutoresizingMaskIntoConstraints = NO;
        bottomSeparator.translatesAutoresizingMaskIntoConstraints = NO;

        [cell addSubview:topSeparator];
        [cell addSubview:bottomSeparator];

        /*
         * レイアウト
         */
        CGFloat separatorHeight =
            1.0 / UIScreen.mainScreen.scale;

        [NSLayoutConstraint activateConstraints:@[
            // カテゴリー名
            [categoryLabel.leadingAnchor
                constraintEqualToAnchor:self.leadingAnchor
                               constant:20.0],

            [categoryLabel.trailingAnchor
                constraintEqualToAnchor:self.trailingAnchor
                               constant:-16.0],

            [categoryLabel.topAnchor
                constraintEqualToAnchor:self.topAnchor
                               constant:8.0],

            [categoryLabel.heightAnchor
                constraintEqualToConstant:18.0],

            // セル
            [cell.leadingAnchor
                constraintEqualToAnchor:self.leadingAnchor],

            [cell.trailingAnchor
                constraintEqualToAnchor:self.trailingAnchor],

            [cell.topAnchor
                constraintEqualToAnchor:categoryLabel.bottomAnchor
                               constant:4.0],

            [cell.heightAnchor
                constraintEqualToConstant:44.0],

            // 上端 separator
            [topSeparator.leadingAnchor
                constraintEqualToAnchor:cell.leadingAnchor],

            [topSeparator.trailingAnchor
                constraintEqualToAnchor:cell.trailingAnchor],

            [topSeparator.topAnchor
                constraintEqualToAnchor:cell.topAnchor],

            [topSeparator.heightAnchor
                constraintEqualToConstant:separatorHeight],

            // 下端 separator
            [bottomSeparator.leadingAnchor
                constraintEqualToAnchor:cell.leadingAnchor],

            [bottomSeparator.trailingAnchor
                constraintEqualToAnchor:cell.trailingAnchor],

            [bottomSeparator.bottomAnchor
                constraintEqualToAnchor:cell.bottomAnchor],

            [bottomSeparator.heightAnchor
                constraintEqualToConstant:separatorHeight]
        ]];

        /*
         * タッチ開始
         */
        [self addTarget:self
                 action:@selector(pxQoL_touchDown:)
       forControlEvents:UIControlEventTouchDown];

        /*
         * タッチ終了・キャンセル
         */
        [self addTarget:self
                 action:@selector(pxQoL_touchUp:)
        forControlEvents:UIControlEventTouchUpInside];

        [self addTarget:self
                 action:@selector(pxQoL_touchUp:)
        forControlEvents:UIControlEventTouchUpOutside];

        [self addTarget:self
                 action:@selector(pxQoL_touchUp:)
        forControlEvents:UIControlEventTouchCancel];

        [self addTarget:self
                 action:@selector(pxQoL_touchUp:)
        forControlEvents:UIControlEventTouchDragExit];

        /*
         * タップ処理
         */
        [self addTarget:self
                 action:@selector(pxQoL_didTap:)
        forControlEvents:UIControlEventTouchUpInside];
    }

    return self;
}

- (void)pxQoL_touchDown:(id)sender {
    if (self.settingsCell) {
        self.settingsCell.backgroundColor =
            self.highlightedCellColor;

        self.settingsCell.contentView.backgroundColor =
            self.highlightedCellColor;
    }
}

- (void)pxQoL_touchUp:(id)sender {
    if (self.settingsCell) {
        self.settingsCell.backgroundColor =
            self.normalCellColor;

        self.settingsCell.contentView.backgroundColor =
            self.normalCellColor;
    }
}

- (void)pxQoL_didTap:(id)sender {
    UIViewController *baseViewController = self.viewController;

    if (!baseViewController) {
        return;
    }

    /*
     * タップ時のハイライトを確実に表示
     */
    self.settingsCell.backgroundColor =
        self.highlightedCellColor;

    self.settingsCell.contentView.backgroundColor =
        self.highlightedCellColor;

    PXQoLSettingsViewController *settings =
        [[PXQoLSettingsViewController alloc]
            initWithStyle:UITableViewStylePlain];

    UINavigationController *navigationController =
        baseViewController.navigationController;

    if (navigationController) {
        [navigationController pushViewController:settings
                                         animated:YES];
    } else {
        [baseViewController presentViewController:settings
                                          animated:YES
                                        completion:nil];
    }

    /*
     * 遷移開始後に通常色へ戻す
     */
    dispatch_async(dispatch_get_main_queue(), ^{
        self.settingsCell.backgroundColor =
            self.normalCellColor;

        self.settingsCell.contentView.backgroundColor =
            self.normalCellColor;
    });
}

@end


#pragma mark - Pixiv SettingsViewController

@interface _TtC6Legacy22SettingsViewController : UITableViewController
@end

%hook _TtC6Legacy22SettingsViewController

- (void)viewDidLoad {
    %orig;

    UITableView *tableView = self.tableView;

    if (!tableView) {
        return;
    }

    /*
     * Pixiv本来の
     *
     *   section 0
     *   section 1
     *   section 2
     *
     * は一切変更しない。
     *
     * filteredSettingSections の section index も
     * 元のまま維持する。
     *
     * pxQoLはtableHeaderViewとして最上部に配置する。
     */

    PXQoLSettingsHeaderView *header =
        [[PXQoLSettingsHeaderView alloc]
            initWithFrame:CGRectMake(
                0.0,
                0.0,
                tableView.bounds.size.width,
                74.0)];

    header.viewController = self;

    header.autoresizingMask =
        UIViewAutoresizingFlexibleWidth;

    tableView.tableHeaderView = header;
}

%end
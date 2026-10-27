# pxQoL

A QoL tweak for pixiv for iOS.

pxQoL adds features such as tab bar customization, home content visibility controls, and ad blocking while preserving pixiv's native behavior as much as possible.

## Features

### Tab Bar Customization

Customize the visibility and order of the following tabs:

- Home
- Discover
- New
- Notifications
- My Page

Home, Discover, New, and Notifications can be individually hidden.

My Page is always kept visible to preserve access to the settings screen, but it can still be reordered.

### Home Tab Customization

The following elements on the Home tab can be hidden individually:

- Ranking
- Pixivision

Elements outside the supported targets are left unchanged.

### Ad Blocking

Suppresses ad presentation in pixiv.

This does not grant server-side Premium entitlement. pxQoL only intervenes in client-side behavior to the extent required for its ad-blocking functionality.

### Settings

pxQoL adds the following entry to pixiv's settings screen:

`pxQoL` → `Tweak Settings`

Settings are divided into three categories:

- Tab Bar
- Element Visibility
- Debug

Changes are saved immediately, but take effect **the next time pixiv is launched**.

## Tested Environments

Currently tested environments:

| Environment | Status |
| --- | --- |
| iOS 16.4.1 / Dopamine Rootless | Tested and working |
| iOS 18.3.2 / LiveContainer + JIT | Launch confirmed |
| iOS 18.3.2 / LiveContainer JIT-less | Cannot complete launch when Binary Patch features are enabled |

When using LiveContainer, JIT is required for features that rely on Binary Patching:

- Hide Ranking
- Hide Pixivision
- Ad Blocking

pxQoL can be loaded without JIT when all of these features are disabled.

Direct installation through SideStore is currently outside the scope of tested configurations.

## Educational Purpose

pxQoL is developed primarily for educational and research purposes, including learning about iOS application behavior, reverse engineering, runtime analysis, and tweak development.

## Disclaimer

Use pxQoL at your own risk.

The author is not responsible for any damage, data loss, account issues, application instability, device problems, or other consequences resulting from the installation or use of this software.

Users are responsible for ensuring that their use of pxQoL complies with any applicable laws, platform rules, and terms of service.
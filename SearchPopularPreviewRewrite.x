#import <Foundation/Foundation.h>

#import "SearchPopularPreviewRewrite.h"
#import "LogHelper.h"


#pragma mark - Helpers

static BOOL pxQoLIsPremiumSearchSort(NSString *sort)
{
    if (sort == nil) {
        return NO;
    }

    return
        [sort isEqualToString:@"popular_desc"] ||
        [sort isEqualToString:@"popular_male_desc"] ||
        [sort isEqualToString:@"popular_female_desc"];
}


static NSURLRequest *pxQoLRewritePopularSearchRequest(
    NSURLRequest *request
)
{
    if (request == nil) {
        return request;
    }


    /*
     * ------------------------------------------------------------
     * Method
     * ------------------------------------------------------------
     */

    NSString *method =
        request.HTTPMethod;

    if (![method isEqualToString:@"GET"]) {
        return request;
    }


    /*
     * ------------------------------------------------------------
     * URL
     * ------------------------------------------------------------
     */

    NSURL *url =
        request.URL;

    if (url == nil) {
        return request;
    }

    if (![[url.scheme lowercaseString]
            isEqualToString:@"https"]) {

        return request;
    }

    if (![[url.host lowercaseString]
            isEqualToString:@"app-api.pixiv.net"]) {

        return request;
    }

    if (![url.path
            isEqualToString:@"/v1/search/illust"]) {

        return request;
    }


    /*
     * ------------------------------------------------------------
     * Parse URL
     * ------------------------------------------------------------
     */

    NSURLComponents *components =
        [NSURLComponents
            componentsWithURL:url
            resolvingAgainstBaseURL:NO];

    if (components == nil) {
        return request;
    }

    NSArray<NSURLQueryItem *> *queryItems =
        components.queryItems;

    if (queryItems == nil) {
        return request;
    }


    /*
     * ------------------------------------------------------------
     * Find sort
     *
     * premium sortが正確に1個だけ存在する場合のみ対象。
     * ------------------------------------------------------------
     */

    NSString *sortValue = nil;
    NSUInteger sortCount = 0;

    for (NSURLQueryItem *item in queryItems) {

        if (![item.name isEqualToString:@"sort"]) {
            continue;
        }

        sortCount++;

        if (sortCount > 1) {
            return request;
        }

        sortValue =
            item.value;
    }

    if (sortCount != 1) {
        return request;
    }

    if (!pxQoLIsPremiumSearchSort(sortValue)) {
        return request;
    }


    /*
     * ------------------------------------------------------------
     * Build new query
     *
     * 削除:
     *   sort
     *   content_type
     *   include_potential_violation_works
     *   filter
     *
     * filterは最後に
     *
     *   filter=for_ios
     *
     * を1個だけ追加する。
     *
     * それ以外の未知query itemはそのまま維持。
     * ------------------------------------------------------------
     */

    NSMutableArray<NSURLQueryItem *> *newQueryItems =
        [NSMutableArray arrayWithCapacity:
            queryItems.count];

    for (NSURLQueryItem *item in queryItems) {

        NSString *name =
            item.name;

        if ([name isEqualToString:@"sort"] ||
            [name isEqualToString:@"content_type"] ||
            [name isEqualToString:
                @"include_potential_violation_works"] ||
            [name isEqualToString:@"filter"]) {

            continue;
        }

        [newQueryItems addObject:item];
    }

    [newQueryItems addObject:
        [NSURLQueryItem
            queryItemWithName:@"filter"
            value:@"for_ios"]
    ];


    /*
     * ------------------------------------------------------------
     * Change endpoint
     * ------------------------------------------------------------
     */

    components.path =
        @"/v1/search/popular-preview/illust";

    components.queryItems =
        newQueryItems;

    NSURL *rewrittenURL =
        components.URL;

    if (rewrittenURL == nil) {
        pxQoLLog(
            @"[PopularPreviewRewrite] failed to build rewritten URL"
        );

        return request;
    }


    /*
     * ------------------------------------------------------------
     * Copy request
     *
     * 元NSMutableURLRequestは直接変更しない。
     * headers / HTTPBody / timeout / cache policy等は保持する。
     * ------------------------------------------------------------
     */

    NSMutableURLRequest *rewrittenRequest =
        [request mutableCopy];

    if (rewrittenRequest == nil) {
        return request;
    }

    rewrittenRequest.URL =
        rewrittenURL;


    pxQoLLog(
        @"[PopularPreviewRewrite] sort=%@",
        sortValue
    );

    pxQoLLog(
        @"[PopularPreviewRewrite] before=%@",
        url.absoluteString
    );

    pxQoLLog(
        @"[PopularPreviewRewrite] after=%@",
        rewrittenURL.absoluteString
    );


    return rewrittenRequest;
}


#pragma mark - Hook

%group pxQoLSearchPopularPreviewRewrite


%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:
    (NSURLRequest *)request
{
    NSURLRequest *rewrittenRequest =
        pxQoLRewritePopularSearchRequest(
            request
        );

    return %orig(rewrittenRequest);
}

%end


%end // pxQoLSearchPopularPreviewRewrite


#pragma mark - Init

void pxQoLInitSearchPopularPreviewRewrite(void)
{
    static BOOL initialized = NO;

    if (initialized) {
        return;
    }

    initialized = YES;

    pxQoLLog(
        @"[PopularPreviewRewrite] enabled"
    );

    %init(pxQoLSearchPopularPreviewRewrite);
}
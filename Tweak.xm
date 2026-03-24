#import <Foundation/Foundation.h>

static NSURL *PF7RewriteURL(NSURL *url) {
    if (!url) return nil;

    NSString *scheme = [[url scheme] lowercaseString] ?: @"";
    NSString *host   = [[url host] lowercaseString] ?: @"";
    NSString *path   = [url path] ?: @"";

    // 只处理和播客/itunes目录明显相关的请求
    BOOL looksRelevantHost =
        [host isEqualToString:@"itunes.apple.com"] ||
        [host isEqualToString:@"ax.itunes.apple.com"] ||
        [host hasSuffix:@".itunes.apple.com"] ||
        [host hasSuffix:@".mzstatic.com"] ||
        [host hasSuffix:@".apple.com"];

    if (!looksRelevantHost) {
        return nil;
    }

    NSURLComponents *comp = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if (!comp) return nil;

    BOOL changed = NO;

    // 1) 修 itunes 旧 host
    if ([host isEqualToString:@"ax.itunes.apple.com"] ||
        [host hasSuffix:@".itunes.apple.com"]) {
        comp.host = @"itunes.apple.com";
        changed = YES;
    }

    // 2) http -> https
    if ([scheme isEqualToString:@"http"]) {
        comp.scheme = @"https";
        changed = YES;
    }

    // 3) 对常见可用接口优先修正
    if ([path isEqualToString:@"/search"] || [path isEqualToString:@"/lookup"]) {
        if (![comp.host.lowercaseString isEqualToString:@"itunes.apple.com"]) {
            comp.host = @"itunes.apple.com";
            changed = YES;
        }
        if (![comp.scheme.lowercaseString isEqualToString:@"https"]) {
            comp.scheme = @"https";
            changed = YES;
        }
    }

    // 4) 一些老客户端可能会访问 podcast 相关页面或 feed 跳转
    // 不强改 path，只做 host/scheme 级别修复，避免把请求修坏
    if (!changed) return nil;

    NSURL *newURL = [comp URL];
    return newURL;
}

static NSURLRequest *PF7RewriteRequest(NSURLRequest *req) {
    if (!req) return req;

    NSURL *newURL = PF7RewriteURL(req.URL);
    if (!newURL || [newURL isEqual:req.URL]) {
        return req;
    }

    NSMutableURLRequest *mutable = [req mutableCopy];
    [mutable setURL:newURL];
    [mutable setValue:nil forHTTPHeaderField:@"Host"];
    NSLog(@"[PodcastsFix7] %@ -> %@", req.URL.absoluteString, newURL.absoluteString);
    return mutable;
}

%hook NSURLRequest

+ (id)requestWithURL:(NSURL *)URL {
    NSURL *newURL = PF7RewriteURL(URL);
    if (newURL) {
        NSLog(@"[PodcastsFix7] requestWithURL rewrite: %@ -> %@", URL.absoluteString, newURL.absoluteString);
        return %orig(newURL);
    }
    return %orig(URL);
}

+ (id)requestWithURL:(NSURL *)URL
         cachePolicy:(NSURLRequestCachePolicy)cachePolicy
     timeoutInterval:(NSTimeInterval)timeoutInterval {
    NSURL *newURL = PF7RewriteURL(URL);
    if (newURL) {
        NSLog(@"[PodcastsFix7] requestWithURL:cachePolicy:timeout rewrite: %@ -> %@", URL.absoluteString, newURL.absoluteString);
        return %orig(newURL, cachePolicy, timeoutInterval);
    }
    return %orig(URL, cachePolicy, timeoutInterval);
}

- (NSURL *)URL {
    NSURL *orig = %orig;
    NSURL *newURL = PF7RewriteURL(orig);
    return newURL ?: orig;
}

- (id)mutableCopyWithZone:(struct _NSZone *)zone {
    id copy = %orig(zone);
    if ([copy isKindOfClass:%c(NSMutableURLRequest)]) {
        NSMutableURLRequest *m = (NSMutableURLRequest *)copy;
        NSURL *newURL = PF7RewriteURL(m.URL);
        if (newURL) {
            [m setURL:newURL];
        }
    }
    return copy;
}

%end

%hook NSMutableURLRequest

- (void)setURL:(NSURL *)URL {
    NSURL *newURL = PF7RewriteURL(URL);
    if (newURL) {
        NSLog(@"[PodcastsFix7] setURL rewrite: %@ -> %@", URL.absoluteString, newURL.absoluteString);
        %orig(newURL);
        return;
    }
    %orig(URL);
}

%end

%ctor {
    @autoreleasepool {
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        NSLog(@"[PodcastsFix7] loaded into %@", bundleID);
    }
}

#import <Foundation/Foundation.h>

static NSURL *PF7RewriteURL(NSURL *url) {
    if (!url) return nil;

    NSString *scheme = [[url scheme] lowercaseString] ?: @"";
    NSString *host   = [[url host] lowercaseString] ?: @"";
    NSString *path   = [url path] ?: @"";

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

    if ([host isEqualToString:@"ax.itunes.apple.com"] ||
        [host hasSuffix:@".itunes.apple.com"]) {
        comp.host = @"itunes.apple.com";
        changed = YES;
    }

    if ([scheme isEqualToString:@"http"]) {
        comp.scheme = @"https";
        changed = YES;
    }

    if ([path isEqualToString:@"/search"] || [path isEqualToString:@"/lookup"]) {
        if (![[[comp host] lowercaseString] isEqualToString:@"itunes.apple.com"]) {
            comp.host = @"itunes.apple.com";
            changed = YES;
        }
        if (![[[comp scheme] lowercaseString] isEqualToString:@"https"]) {
            comp.scheme = @"https";
            changed = YES;
        }
    }

    if (!changed) return nil;

    return [comp URL];
}

%hook NSURLRequest

+ (id)requestWithURL:(NSURL *)URL {
    NSURL *newURL = PF7RewriteURL(URL);
    if (newURL) {
        NSLog(@"[PodcastsFix7] requestWithURL rewrite: %@ -> %@", [URL absoluteString], [newURL absoluteString]);
        return %orig(newURL);
    }
    return %orig(URL);
}

+ (id)requestWithURL:(NSURL *)URL
         cachePolicy:(NSURLRequestCachePolicy)cachePolicy
     timeoutInterval:(NSTimeInterval)timeoutInterval {
    NSURL *newURL = PF7RewriteURL(URL);
    if (newURL) {
        NSLog(@"[PodcastsFix7] requestWithURL:cachePolicy:timeout rewrite: %@ -> %@", [URL absoluteString], [newURL absoluteString]);
        return %orig(newURL, cachePolicy, timeoutInterval);
    }
    return %orig(URL, cachePolicy, timeoutInterval);
}

- (NSURL *)URL {
    NSURL *origURL = %orig;
    NSURL *newURL = PF7RewriteURL(origURL);
    return newURL ?: origURL;
}

- (id)mutableCopyWithZone:(struct _NSZone *)zone {
    id copyObj = %orig(zone);
    if ([copyObj isKindOfClass:%c(NSMutableURLRequest)]) {
        NSMutableURLRequest *reqCopy = (NSMutableURLRequest *)copyObj;
        NSURL *newURL = PF7RewriteURL([reqCopy URL]);
        if (newURL) {
            [reqCopy setURL:newURL];
        }
    }
    return copyObj;
}

%end

%hook NSMutableURLRequest

- (void)setURL:(NSURL *)URL {
    NSURL *newURL = PF7RewriteURL(URL);
    if (newURL) {
        NSLog(@"[PodcastsFix7] setURL rewrite: %@ -> %@", [URL absoluteString], [newURL absoluteString]);
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

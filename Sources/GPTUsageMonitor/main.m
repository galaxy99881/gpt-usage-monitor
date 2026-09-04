#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>

@interface AppDelegate : NSObject <NSApplicationDelegate, UNUserNotificationCenterDelegate>
@property NSStatusItem *statusItem;
@property NSMenu *menu;
@property NSMenuItem *updatedItem;
@property BOOL refreshing;
@property NSArray<NSDictionary *> *usageWindows;
@property NSString *usageError;
@property NSDictionary *tokenSummary;
@property NSArray<NSDictionary *> *dailyUsage;
@property NSDate *lastUsageUpdate;
@property NSArray<NSDictionary *> *latestTweets;
@property NSString *tweetError;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"gauge.with.dots.needle.50percent" accessibilityDescription:@"GPT 剩余用量"];
    self.statusItem.button.title = @" GPT";

    self.menu = [[NSMenu alloc] initWithTitle:@"GPT 剩余用量"];
    self.statusItem.menu = self.menu;
    [self rebuildMenuWithWindows:nil error:nil];
    [self refresh:nil];
    [self configureNotifications];
    [self refreshTweets];

    [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(refresh:) userInfo:nil repeats:YES];
    [NSTimer scheduledTimerWithTimeInterval:180 target:self selector:@selector(refreshTweets) userInfo:nil repeats:YES];
}

- (void)rebuildMenuWithWindows:(NSArray<NSDictionary *> *)windows error:(NSString *)error {
    if (windows != nil) { self.usageWindows = windows; self.usageError = nil; }
    if (error != nil) self.usageError = error;
    NSArray *visibleWindows = self.usageWindows;
    NSString *visibleError = self.usageError;
    [self.menu removeAllItems];

    NSMenuItem *title = [[NSMenuItem alloc] initWithTitle:@"GPT 剩余用量" action:nil keyEquivalent:@""];
    title.attributedTitle = [[NSAttributedString alloc] initWithString:@"GPT 剩余用量" attributes:@{NSFontAttributeName: [NSFont boldSystemFontOfSize:14]}];
    [self.menu addItem:title];
    [self.menu addItem:[NSMenuItem separatorItem]];

    if (self.refreshing && visibleWindows == nil && visibleError == nil) {
        [self.menu addItem:[[NSMenuItem alloc] initWithTitle:@"正在读取…" action:nil keyEquivalent:@""]];
    } else if (visibleError != nil) {
        NSMenuItem *errorItem = [[NSMenuItem alloc] initWithTitle:[@"⚠︎ " stringByAppendingString:visibleError] action:nil keyEquivalent:@""];
        [self.menu addItem:errorItem];
    } else {
        for (NSDictionary *window in visibleWindows) {
            double remaining = [window[@"remaining"] doubleValue];
            NSString *name = window[@"name"] ?: @"额度";
            NSString *line = [NSString stringWithFormat:@"%@    %.0f%% 剩余", name, remaining];
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:line action:nil keyEquivalent:@""];
            [self.menu addItem:item];

            NSNumber *duration = window[@"duration"];
            NSDate *reset = window[@"reset"];
            NSMutableArray<NSString *> *details = [NSMutableArray array];
            if (duration != nil) {
                NSInteger mins = duration.integerValue;
                if (mins >= 1440) [details addObject:[NSString stringWithFormat:@"%ld 天周期", mins / 1440]];
                else if (mins >= 60) [details addObject:[NSString stringWithFormat:@"%ld 小时周期", mins / 60]];
                else [details addObject:[NSString stringWithFormat:@"%ld 分钟周期", mins]];
            }
            if (reset != nil) {
                NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
                formatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
                formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
                formatter.maximumUnitCount = 2;
                NSString *remainingTime = [formatter stringFromTimeInterval:MAX(0, reset.timeIntervalSinceNow)];
                if (remainingTime) [details addObject:[NSString stringWithFormat:@"%@ 后刷新", remainingTime]];
            }
            if (details.count > 0) {
                NSMenuItem *detail = [[NSMenuItem alloc] initWithTitle:[@"    " stringByAppendingString:[details componentsJoinedByString:@" · "]] action:nil keyEquivalent:@""];
                detail.attributedTitle = [[NSAttributedString alloc] initWithString:detail.title attributes:@{NSForegroundColorAttributeName: NSColor.secondaryLabelColor, NSFontAttributeName: [NSFont systemFontOfSize:11]}];
                [self.menu addItem:detail];
            }
            [self.menu addItem:[NSMenuItem separatorItem]];
        }
    }

    if (self.tokenSummary != nil) {
        [self.menu addItem:[[NSMenuItem alloc] initWithTitle:@"Token 统计（官方）" action:nil keyEquivalent:@""]];
        NSNumber *lifetime = self.tokenSummary[@"lifetimeTokens"];
        if ([lifetime isKindOfClass:NSNumber.class]) {
            [self.menu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"累计使用：%@ tokens", [self compactNumber:lifetime.longLongValue]] action:nil keyEquivalent:@""]];
        }
        long long sevenDays = [self recentTokensForDays:7];
        if (sevenDays > 0) {
            [self.menu addItem:[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"最近 7 个使用日：%@", [self compactNumber:sevenDays]] action:nil keyEquivalent:@""]];
            NSInteger start = MAX(0, (NSInteger)self.dailyUsage.count - 7);
            for (NSInteger i = start; i < (NSInteger)self.dailyUsage.count; i++) {
                NSDictionary *day = self.dailyUsage[i];
                long long tokens = [day[@"tokens"] longLongValue];
                double share = sevenDays > 0 ? tokens * 100.0 / sevenDays : 0;
                NSString *date = day[@"startDate"] ?: @"--";
                if (date.length >= 10) date = [date substringFromIndex:5];
                NSString *line = [NSString stringWithFormat:@"    %@  %@  ·  %.1f%%", date, [self compactNumber:tokens], share];
                [self.menu addItem:[[NSMenuItem alloc] initWithTitle:line action:nil keyEquivalent:@""]];
            }
            NSMenuItem *shareNote = [[NSMenuItem alloc] initWithTitle:@"百分比＝当天占最近 7 个使用日总量" action:nil keyEquivalent:@""];
            shareNote.attributedTitle = [[NSAttributedString alloc] initWithString:shareNote.title attributes:@{NSForegroundColorAttributeName: NSColor.secondaryLabelColor, NSFontAttributeName: [NSFont systemFontOfSize:10]}];
            [self.menu addItem:shareNote];
            NSString *latestDate = self.dailyUsage.lastObject[@"startDate"];
            if (latestDate.length >= 10) latestDate = [latestDate substringToIndex:10];
            if (latestDate.length > 0) {
                NSMenuItem *settled = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"每日数据已结算至：%@", latestDate] action:nil keyEquivalent:@""];
                settled.attributedTitle = [[NSAttributedString alloc] initWithString:settled.title attributes:@{NSForegroundColorAttributeName: NSColor.secondaryLabelColor, NSFontAttributeName: [NSFont systemFontOfSize:10]}];
                [self.menu addItem:settled];
            }
        }
        NSString *pace = [self paceEstimateForWindows:visibleWindows];
        if (pace != nil) [self.menu addItem:[[NSMenuItem alloc] initWithTitle:pace action:nil keyEquivalent:@""]];
        [self.menu addItem:[NSMenuItem separatorItem]];

        [self.menu addItem:[[NSMenuItem alloc] initWithTitle:@"模型续航参考（估算）" action:nil keyEquivalent:@""]];
        [self.menu addItem:[[NSMenuItem alloc] initWithTitle:@"Luna high：约 12.5× Sol medium" action:nil keyEquivalent:@""]];
        [self.menu addItem:[[NSMenuItem alloc] initWithTitle:@"Terra medium：约 4.4× Sol medium" action:nil keyEquivalent:@""]];
        [self.menu addItem:[[NSMenuItem alloc] initWithTitle:@"5.5 high：约 0.7× Sol medium" action:nil keyEquivalent:@""]];
        NSMenuItem *note = [[NSMenuItem alloc] initWithTitle:@"按 CodexRadar 单次任务成本估算，非账户余额" action:nil keyEquivalent:@""];
        note.attributedTitle = [[NSAttributedString alloc] initWithString:note.title attributes:@{NSForegroundColorAttributeName: NSColor.secondaryLabelColor, NSFontAttributeName: [NSFont systemFontOfSize:10]}];
        [self.menu addItem:note];
        NSMenuItem *radar = [[NSMenuItem alloc] initWithTitle:@"打开 CodexRadar" action:@selector(openURLItem:) keyEquivalent:@""];
        radar.target = self;
        radar.representedObject = @"https://codexradar.com/";
        [self.menu addItem:radar];
        [self.menu addItem:[NSMenuItem separatorItem]];
    }

    [self.menu addItem:[[NSMenuItem alloc] initWithTitle:@"Tibo · @thsottiaux" action:nil keyEquivalent:@""]];
    if (self.tweetError != nil) {
        [self.menu addItem:[[NSMenuItem alloc] initWithTitle:[@"⚠︎ " stringByAppendingString:self.tweetError] action:nil keyEquivalent:@""]];
    } else if (self.latestTweets.count == 0) {
        [self.menu addItem:[[NSMenuItem alloc] initWithTitle:@"正在检查新帖子…" action:nil keyEquivalent:@""]];
    } else {
        NSInteger count = MIN(3, self.latestTweets.count);
        for (NSInteger i = 0; i < count; i++) {
            NSDictionary *tweet = self.latestTweets[i];
            NSString *text = [tweet[@"text"] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            if (text.length > 54) text = [[text substringToIndex:54] stringByAppendingString:@"…"];
            NSMenuItem *tweetItem = [[NSMenuItem alloc] initWithTitle:text action:@selector(openTweet:) keyEquivalent:@""];
            tweetItem.target = self;
            tweetItem.representedObject = [NSString stringWithFormat:@"https://x.com/thsottiaux/status/%@", tweet[@"id"]];
            [self.menu addItem:tweetItem];
        }
    }
    [self.menu addItem:[NSMenuItem separatorItem]];

    NSDate *shownUpdate = self.lastUsageUpdate ?: [NSDate date];
    self.updatedItem = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"用量每分钟 · 上次成功 %@ · 帖子每 3 分钟", [NSDateFormatter localizedStringFromDate:shownUpdate dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterMediumStyle]] action:nil keyEquivalent:@""];
    [self.menu addItem:self.updatedItem];
    [self.menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *refresh = [[NSMenuItem alloc] initWithTitle:@"立即刷新" action:@selector(refresh:) keyEquivalent:@"r"];
    refresh.target = self;
    refresh.enabled = !self.refreshing;
    [self.menu addItem:refresh];

    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:@"退出" action:@selector(quit:) keyEquivalent:@"q"];
    quit.target = self;
    [self.menu addItem:quit];
}

- (void)configureNotifications {
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError *error) {}];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

- (void)refreshTweets {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *error = nil;
        NSArray *tweets = [self fetchTweets:&error];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (tweets.count > 0) [self processTweets:tweets];
            self.tweetError = error;
            [self rebuildMenuWithWindows:nil error:nil];
        });
    });
}

- (NSArray *)fetchTweets:(NSString **)errorOut {
    NSString *config = [NSHomeDirectory() stringByAppendingPathComponent:@".agent-reach/config.yaml"];
    NSString *twitter = [NSHomeDirectory() stringByAppendingPathComponent:@".local/bin/twitter"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:config] || ![[NSFileManager defaultManager] isExecutableFileAtPath:twitter]) {
        *errorOut = @"X 监控尚未配置";
        return nil;
    }

    NSString *script = @"c=YAML.load_file(ARGV.shift); ENV['TWITTER_AUTH_TOKEN']=c['twitter_auth_token']; ENV['TWITTER_CT0']=c['twitter_ct0']; exec(*ARGV)";
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/ruby"];
    task.arguments = @[@"-ryaml", @"-e", script, config, twitter, @"user-posts", @"thsottiaux", @"-n", @"10", @"--json"];
    NSPipe *output = [NSPipe pipe], *errors = [NSPipe pipe];
    task.standardOutput = output;
    task.standardError = errors;
    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) { *errorOut = launchError.localizedDescription; return nil; }
    [task waitUntilExit];
    NSData *data = [output.fileHandleForReading readDataToEndOfFile];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *tweets = json[@"data"];
    if (task.terminationStatus != 0 || ![tweets isKindOfClass:NSArray.class]) {
        *errorOut = @"暂时无法读取 X，请稍后重试";
        return nil;
    }
    return tweets;
}

- (void)processTweets:(NSArray<NSDictionary *> *)tweets {
    NSString *lastSeen = [[NSUserDefaults standardUserDefaults] stringForKey:@"thsottiaux.lastSeenID"];
    NSString *newest = tweets.firstObject[@"id"];
    if (lastSeen != nil) {
        NSMutableArray *newTweets = [NSMutableArray array];
        for (NSDictionary *tweet in tweets) {
            if ([tweet[@"id"] isEqualToString:lastSeen]) break;
            [newTweets addObject:tweet];
        }
        for (NSDictionary *tweet in [newTweets reverseObjectEnumerator]) [self notifyForTweet:tweet];
    }
    if (newest != nil) {
        [[NSUserDefaults standardUserDefaults] setObject:newest forKey:@"thsottiaux.lastSeenID"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    self.latestTweets = tweets;
}

- (void)notifyForTweet:(NSDictionary *)tweet {
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = @"Tibo 发布了新帖子";
    NSString *text = [tweet[@"text"] stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    content.body = text.length > 180 ? [[text substringToIndex:180] stringByAppendingString:@"…"] : text;
    content.sound = [UNNotificationSound defaultSound];
    content.userInfo = @{@"url": [NSString stringWithFormat:@"https://x.com/thsottiaux/status/%@", tweet[@"id"]]};
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:[@"thsottiaux." stringByAppendingString:tweet[@"id"]] content:content trigger:nil];
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
}

- (void)openTweet:(NSMenuItem *)sender {
    NSURL *url = [NSURL URLWithString:sender.representedObject];
    if (url) [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void)openURLItem:(NSMenuItem *)sender {
    NSURL *url = [NSURL URLWithString:sender.representedObject];
    if (url) [[NSWorkspace sharedWorkspace] openURL:url];
}

- (NSString *)compactNumber:(long long)value {
    if (value >= 1000000000LL) return [NSString stringWithFormat:@"%.2f 亿", value / 100000000.0];
    if (value >= 1000000LL) return [NSString stringWithFormat:@"%.1f 万", value / 10000.0];
    return [NSString stringWithFormat:@"%lld", value];
}

- (long long)latestDailyTokens {
    NSDictionary *latest = self.dailyUsage.lastObject;
    return [latest[@"tokens"] longLongValue];
}

- (long long)recentTokensForDays:(NSInteger)days {
    long long total = 0;
    NSInteger start = MAX(0, (NSInteger)self.dailyUsage.count - days);
    for (NSInteger i = start; i < (NSInteger)self.dailyUsage.count; i++) total += [self.dailyUsage[i][@"tokens"] longLongValue];
    return total;
}

- (NSString *)paceEstimateForWindows:(NSArray<NSDictionary *> *)windows {
    NSDictionary *window = windows.firstObject;
    if (window == nil) return nil;
    double remaining = [window[@"remaining"] doubleValue];
    double used = 100 - remaining;
    NSDate *reset = window[@"reset"];
    NSInteger durationMinutes = [window[@"duration"] integerValue];
    if (used < 1 || reset == nil || durationMinutes <= 0) return @"当前数据不足，暂不估算耗尽时间";
    NSDate *start = [reset dateByAddingTimeInterval:-(durationMinutes * 60.0)];
    NSTimeInterval elapsed = -start.timeIntervalSinceNow;
    if (elapsed < 1800) return @"本周期刚开始，耗尽时间仍不稳定";
    NSTimeInterval seconds = elapsed * remaining / used;
    NSDateComponentsFormatter *formatter = [[NSDateComponentsFormatter alloc] init];
    formatter.allowedUnits = NSCalendarUnitDay | NSCalendarUnitHour | NSCalendarUnitMinute;
    formatter.unitsStyle = NSDateComponentsFormatterUnitsStyleShort;
    formatter.maximumUnitCount = 2;
    NSString *time = [formatter stringFromTimeInterval:seconds];
    return time ? [NSString stringWithFormat:@"按本周期速度：约 %@ 后用尽（估算）", time] : nil;
}

- (void)refresh:(id)sender {
    if (self.refreshing) return;
    self.refreshing = YES;
    [self rebuildMenuWithWindows:nil error:nil];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *error = nil;
        NSDictionary *payload = [self fetchUsage:&error];
        NSArray *windows = payload[@"windows"];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.refreshing = NO;
            if (payload[@"summary"] != nil) self.tokenSummary = payload[@"summary"];
            if (payload[@"daily"] != nil) self.dailyUsage = payload[@"daily"];
            if (windows.count > 0) {
                self.lastUsageUpdate = [NSDate date];
                double lowest = 100;
                for (NSDictionary *window in windows) lowest = MIN(lowest, [window[@"remaining"] doubleValue]);
                self.statusItem.button.title = [NSString stringWithFormat:@" GPT %.0f%%", lowest];
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setDouble:lowest forKey:@"usage.lastRemainingPercent"];
                [defaults setObject:self.lastUsageUpdate forKey:@"usage.lastUpdatedAt"];
                NSNumber *lifetime = self.tokenSummary[@"lifetimeTokens"];
                if ([lifetime isKindOfClass:NSNumber.class]) [defaults setObject:lifetime forKey:@"usage.lastLifetimeTokens"];
                [defaults synchronize];
            } else {
                self.statusItem.button.title = @" GPT";
            }
            [self rebuildMenuWithWindows:windows error:error];
        });
    });
}

- (NSDictionary *)fetchUsage:(NSString **)errorOut {
    NSArray *candidates = @[@"/opt/homebrew/bin/codex", @"/usr/local/bin/codex", [NSHomeDirectory() stringByAppendingPathComponent:@".local/bin/codex"]];
    NSString *codexPath = nil;
    for (NSString *path in candidates) if ([[NSFileManager defaultManager] isExecutableFileAtPath:path]) { codexPath = path; break; }
    if (!codexPath) { *errorOut = @"未找到 Codex"; return nil; }

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:codexPath];
    task.arguments = @[@"app-server", @"--listen", @"stdio://"];
    NSPipe *input = [NSPipe pipe], *output = [NSPipe pipe], *errors = [NSPipe pipe];
    task.standardInput = input; task.standardOutput = output; task.standardError = errors;
    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) { *errorOut = launchError.localizedDescription; return nil; }

    NSArray *messages = @[
        @{@"method": @"initialize", @"id": @1, @"params": @{@"clientInfo": @{@"name": @"gpt_usage_monitor", @"title": @"GPT Usage Monitor", @"version": @"1.0.0"}}},
        @{@"method": @"initialized", @"params": @{}},
        @{@"method": @"account/rateLimits/read", @"id": @2},
        @{@"method": @"account/usage/read", @"id": @3}
    ];
    for (NSDictionary *message in messages) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
        [input.fileHandleForWriting writeData:data];
        [input.fileHandleForWriting writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];
    }

    NSMutableData *buffer = [NSMutableData data];
    __block NSDictionary *rateResult = nil;
    __block NSDictionary *usageResult = nil;
    dispatch_semaphore_t finished = dispatch_semaphore_create(0);
    NSFileHandle *reader = output.fileHandleForReading;
    reader.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *chunk = handle.availableData;
        @synchronized (buffer) {
            if (chunk.length == 0) { dispatch_semaphore_signal(finished); return; }
            [buffer appendData:chunk];
            while (YES) {
                const void *bytes = buffer.bytes;
                NSUInteger length = buffer.length;
                const void *newline = memchr(bytes, '\n', length);
                if (newline == NULL) break;
                NSUInteger lineLength = (const uint8_t *)newline - (const uint8_t *)bytes;
                NSData *lineData = [buffer subdataWithRange:NSMakeRange(0, lineLength)];
                [buffer replaceBytesInRange:NSMakeRange(0, lineLength + 1) withBytes:NULL length:0];
                if (lineData.length == 0) continue;
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:nil];
                NSInteger responseID = [json[@"id"] integerValue];
                if (responseID == 2 && [json[@"result"] isKindOfClass:NSDictionary.class]) rateResult = json[@"result"];
                if (responseID == 3 && [json[@"result"] isKindOfClass:NSDictionary.class]) usageResult = json[@"result"];
                if (rateResult != nil && usageResult != nil) dispatch_semaphore_signal(finished);
            }
        }
    };
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC);
    dispatch_semaphore_wait(finished, timeout);
    reader.readabilityHandler = nil;
    if (task.running) [task terminate];
    if (rateResult != nil && usageResult != nil) {
        NSArray *parsed = [self parseResult:rateResult];
        return @{@"windows": parsed ?: @[], @"summary": usageResult[@"summary"] ?: @{}, @"daily": usageResult[@"dailyUsageBuckets"] ?: @[]};
    }
    *errorOut = @"读取超时，请稍后重试";
    return nil;
}

- (NSArray *)parseResult:(NSDictionary *)result {
    NSMutableArray *windows = [NSMutableArray array];
    NSDictionary *byID = result[@"rateLimitsByLimitId"];
    if ([byID isKindOfClass:NSDictionary.class]) {
        for (NSString *key in byID) [self appendBucket:byID[key] fallback:key to:windows];
    } else if ([result[@"rateLimits"] isKindOfClass:NSDictionary.class]) {
        [self appendBucket:result[@"rateLimits"] fallback:@"codex" to:windows];
    }
    [windows sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"duration"] compare:b[@"duration"]];
    }];
    return windows;
}

- (void)appendBucket:(NSDictionary *)bucket fallback:(NSString *)fallback to:(NSMutableArray *)windows {
    NSString *limitID = bucket[@"limitId"] ?: fallback;
    NSString *friendly = bucket[@"limitName"];
    NSArray *definitions = @[@[@"primary", @"短时额度"], @[@"secondary", @"周期额度"]];
    NSInteger index = 0;
    for (NSArray *definition in definitions) {
        NSDictionary *raw = bucket[definition[0]];
        if (![raw isKindOfClass:NSDictionary.class] || !raw[@"usedPercent"]) continue;
        double remaining = MAX(0, MIN(100, 100 - [raw[@"usedPercent"] doubleValue]));
        NSInteger durationMinutes = [raw[@"windowDurationMins"] integerValue];
        NSString *automaticName;
        if (durationMinutes >= 10080) automaticName = @"每周额度";
        else if (durationMinutes >= 1440) automaticName = @"多日额度";
        else if (durationMinutes >= 60) automaticName = @"小时额度";
        else automaticName = definition[1];
        NSString *name = friendly ?: (index == 0 ? automaticName : [NSString stringWithFormat:@"%@ · %@", automaticName, limitID]);
        NSMutableDictionary *entry = [@{@"name": name, @"remaining": @(remaining), @"duration": raw[@"windowDurationMins"] ?: @999999} mutableCopy];
        if (raw[@"resetsAt"]) entry[@"reset"] = [NSDate dateWithTimeIntervalSince1970:[raw[@"resetsAt"] doubleValue]];
        [windows addObject:entry];
        index++;
    }
}

- (void)quit:(id)sender { [NSApp terminate:nil]; }

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        app.activationPolicy = NSApplicationActivationPolicyAccessory;
        [app run];
    }
    return 0;
}

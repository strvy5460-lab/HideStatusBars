#import "SBHAppListController.h"
#import "SBHShared.h"

@interface SBHAppListController ()
@property (nonatomic, strong) NSArray<NSDictionary *> *all;
@property (nonatomic, strong) NSArray<NSDictionary *> *shown;
@property (nonatomic, strong) UISearchController *search;
@end

@implementation SBHAppListController

- (instancetype)init {
    return [super initWithStyle:UITableViewStyleInsetGrouped];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Pilih Aplikasi";
    [self loadApps];

    self.search = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater = self;
    self.search.obscuresBackgroundDuringPresentation = NO;
    self.search.searchBar.placeholder = @"Cari";
    self.navigationItem.searchController = self.search;
    self.navigationItem.hidesSearchBarWhenScrolling = NO;
    self.definesPresentationContext = YES;
}

- (void)loadApps {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    Class wsClass = NSClassFromString(@"LSApplicationWorkspace");
    id ws = [wsClass performSelector:NSSelectorFromString(@"defaultWorkspace")];
    NSArray *apps = [ws performSelector:NSSelectorFromString(@"allInstalledApplications")];
    for (id proxy in apps) {
        @try {
            NSString *bid = [proxy valueForKey:@"applicationIdentifier"];
            NSString *name = [proxy valueForKey:@"localizedName"];
            NSArray *tags = [proxy valueForKey:@"appTags"];
            if (!bid.length || [seen containsObject:bid]) continue;
            if ([tags isKindOfClass:NSArray.class] && [tags containsObject:@"hidden"]) continue;
            if (!name.length) name = bid;
            [seen addObject:bid];
            [out addObject:@{@"bid": bid, @"name": name}];
        } @catch (__unused NSException *e) {}
    }
#pragma clang diagnostic pop
    [out sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] caseInsensitiveCompare:b[@"name"]];
    }];
    self.all = out;
    self.shown = out;
}

- (void)updateSearchResultsForSearchController:(UISearchController *)sc {
    NSString *t = sc.searchBar.text;
    if (!t.length) { self.shown = self.all; }
    else {
        NSPredicate *p = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@ OR bid CONTAINS[cd] %@", t, t];
        self.shown = [self.all filteredArrayUsingPredicate:p];
    }
    [self.tableView reloadData];
}

- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return @"APPLICATIONS"; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    return @"Status bar hanya disembunyikan di aplikasi yang diaktifkan. Tutup lalu buka lagi aplikasinya setelah mengubah pilihan.";
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return self.shown.count; }

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *cell = [tv dequeueReusableCellWithIdentifier:@"sbhcell"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"sbhcell"];

    NSDictionary *app = self.shown[ip.row];
    NSString *bid = app[@"bid"];
    cell.textLabel.text = app[@"name"];
    cell.detailTextLabel.text = bid;
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    SEL s = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
    if ([UIImage respondsToSelector:s]) {
        UIImage *(*f)(id, SEL, NSString *, int, CGFloat) = (void *)[UIImage methodForSelector:s];
        cell.imageView.image = f(UIImage.class, s, bid, 0, UIScreen.mainScreen.scale);
        cell.imageView.layer.cornerRadius = 7;
        cell.imageView.layer.masksToBounds = YES;
    }

    UISwitch *sw = [UISwitch new];
    CFPropertyListRef v = CFPreferencesCopyValue((__bridge CFStringRef)[@"app-" stringByAppendingString:bid],
                                                 (__bridge CFStringRef)kSBHDomain,
                                                 kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    BOOL on = NO;
    if (v) { on = [CFBridgingRelease(v) boolValue]; }
    sw.on = on;
    sw.tag = ip.row;
    [sw addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = sw;
    return cell;
}

- (void)switchChanged:(UISwitch *)sw {
    if (sw.tag < 0 || sw.tag >= (NSInteger)self.shown.count) return;
    NSString *bid = self.shown[sw.tag][@"bid"];
    SBHSetPref([@"app-" stringByAppendingString:bid], sw.isOn ? @YES : nil);
}

@end

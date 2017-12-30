#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import "BMRootViewController.h"
#import "BMSecondViewController.h"
#import "BMProcessViewController.h"
#import "BMSettingsViewController.h"
#import "BMListViewController.h"
#import "BMConfirmationViewController.h"
#import "OrderedDictionary.h"
#import "SVProgressHUD/SVProgressHUD.h"

@interface BMRootViewController()
@property (nonatomic, retain) UIWindow *window;
@end

@implementation BMRootViewController {
    bool success;
    bool finished;
    bool neverDonate;
 	NSInteger currentRepo;
	NSInteger appLanguage;
    NSInteger tryingLanguage;
    NSInteger launchCount;
	NSString *savePath;
	NSString *blitzPath;
    NSString *blitzVersion;
	NSArray *languageArray;
	NSMutableArray *modNameArray;
	NSMutableArray *modDetailArray;
	NSMutableArray *modCategoryArray;
    NSMutableArray *repoArray;
    NSMutableArray *repoNameArray;
    NSMutableArray *repoVersionArray;
	NSMutableArray *buttonArray;
	NSMutableArray *installedArray;
    UIView *loadingView;
}

// initialize view
- (void)viewDidLoad {
    NSLog(@"BMRootViewController:viewDidLoad.start");
	[super viewDidLoad];

	// initialize NSUserDefaults
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
    [defaults setObject:@"0" forKey:@"appLanguage"];
    [defaults setObject:@[@"http://subdiox.com/repo"] forKey:@"repoArray"];
    [defaults setObject:@[@"BlitzModder"] forKey:@"repoNameArray"];
    [defaults setObject:@[@"0.0.0"] forKey:@"repoVersionArray"];
	[defaults setObject:@"0" forKey:@"currentRepo"];
	[defaults setObject:[NSMutableArray array] forKey:@"modCategoryArray"];
	[defaults setObject:[NSMutableArray array] forKey:@"modNameArray"];
	[defaults setObject:[NSMutableArray array] forKey:@"modDetailArray"];
	[defaults setObject:@"" forKey:@"blitzPath"];
	[defaults setObject:[NSMutableArray array] forKey:@"buttonArray"];
	[defaults setObject:[NSMutableArray array] forKey:@"installedArray"];
    [defaults setObject:@"0.0.0" forKey:@"blitzVersion"];
    [defaults setObject:@"0" forKey:@"launchCount"];
    [defaults setObject:@"NO" forKey:@"neverDonate"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];

	[self getUserDefaults];
    NSLog(@"repoArray: %@, repoNameArray: %@, currentRepo: %ld", repoArray, repoNameArray, currentRepo);
	if (![repoArray[0] isEqualToString:@"http://subdiox.com/repo"] || ![repoNameArray[0] isEqualToString:@"BlitzModder"]) {
		repoArray[0] = @"http://subdiox.com/repo";
        repoNameArray[0] = @"BlitzModder";
		[self saveUserDefaults];
	}
    savePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];

	// run methods
	[self checkBlitzExists];
    [self makeSaveDirectory];
    [self getUserDefaults];
	[self checkForUpdate];
    tryingLanguage = 0;
    launchCount += 1;
    blitzVersion = [self getBlitzVersion];
    [self refreshMods];

	// initialize rootViewController
    BMRootViewController *rootViewController = [[BMRootViewController alloc] init];
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:rootViewController];
    self.window.rootViewController = navigationController;

	// initialize title button
	UIButton *titleLabelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    titleLabelButton.backgroundColor = [UIColor clearColor];
    titleLabelButton.showsTouchWhenHighlighted = YES;
    titleLabelButton.tintColor = [UIColor blackColor];
    [titleLabelButton setTitle:[self BMLocalizedString:@"Mods List ▼"] forState:UIControlStateNormal];
    titleLabelButton.frame = CGRectMake(0, -10, 0, 0);
    titleLabelButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [titleLabelButton addTarget:self action:@selector(titleTapped:) forControlEvents:UIControlEventTouchUpInside];
    [titleLabelButton sizeToFit];

	// initialize subtitle label
    UILabel *subTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 17, 0, 0)];
    subTitleLabel.backgroundColor = [UIColor clearColor];
    subTitleLabel.textColor = [UIColor grayColor];
    subTitleLabel.font = [UIFont systemFontOfSize:12];
    subTitleLabel.text = repoNameArray[currentRepo];
    [subTitleLabel sizeToFit];

	float widthDiff = subTitleLabel.frame.size.width - titleLabelButton.frame.size.width;
    if (widthDiff > 0) {
        CGRect frame = titleLabelButton.frame;
        frame.origin.x = widthDiff / 2;
        titleLabelButton.frame = CGRectIntegral(frame);
    } else {
        CGRect frame = subTitleLabel.frame;
        frame.origin.x = fabsf(widthDiff) / 2;
        subTitleLabel.frame = CGRectIntegral(frame);
    }

	// add title and subtitle views
    UIView *twoLineTitleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, MAX(subTitleLabel.frame.size.width, titleLabelButton.frame.size.width), 30)];
    [twoLineTitleView addSubview:titleLabelButton];
    [twoLineTitleView addSubview:subTitleLabel];
    self.navigationItem.titleView = twoLineTitleView;

	// initialize UIRefreshControl
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl = refreshControl;
    [refreshControl addTarget:self action:@selector(refreshOccurred:) forControlEvents:UIControlEventValueChanged];

	// initialize UITableView
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.tableView.alwaysBounceVertical = YES;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];

	// initialize navigation bar items
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[self BMLocalizedString:@"Settings"] style:UIBarButtonItemStylePlain target:self action:@selector(settingsButtonTapped:)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[self BMLocalizedString:@"Apply"] style:UIBarButtonItemStyleDone target:self action:@selector(applyButtonTapped:)];

	// run a method
	[self getUserDefaults];

	// initialize NSNotificationCenter
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadView) name:@"reloadData" object:nil];

    if (launchCount % 7 == 3 && !neverDonate) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[self BMLocalizedString:@"Donation Title"] message:[NSString stringWithFormat:@"\n%@",[self BMLocalizedString:@"Donation Message"]] preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:[self BMLocalizedString:@"OK, I will donate"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            neverDonate = YES;
            [self saveUserDefaults];
            NSURL *url = [NSURL URLWithString:@"http://subdiox.com/blitzmodder/contact.html"];
            [[UIApplication sharedApplication] openURL:url
                                   options:@{}
                         completionHandler:nil];
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:[self BMLocalizedString:@"No, I won't donate"] style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            neverDonate = YES;
            [self saveUserDefaults];
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:[self BMLocalizedString:@"Remind me later"] style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        }]];
        NSArray *viewArray = [[[[[[[[[[[[alertController view] subviews] firstObject] subviews] firstObject] subviews] firstObject] subviews] firstObject] subviews] firstObject] subviews];
        UILabel *alertMessage = viewArray[1];
        [self presentViewController:alertController animated:YES completion:nil];
        alertMessage.textAlignment = NSTextAlignmentLeft;
        alertMessage.font = [UIFont systemFontOfSize:13];
    }
    NSLog(@"BMRootViewController:viewDidLoad.finish");
}

- (void)reloadView {
    NSLog(@"BMRootViewController:reloadView.start");
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"reloadData" object:nil];
    [self loadView];
	[self viewDidLoad];
	BMSecondViewController *secondViewController = [[BMSecondViewController alloc] init];
	[self.tableView selectRowAtIndexPath: secondViewController.indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle];
    NSLog(@"BMRootViewController:reloadView.finish");
}

- (NSString *)removeHttp:(NSString *)repo {
    if ([repo hasPrefix:@"http://"]) {
        return [repo substringFromIndex:7];
    } else if ([repo hasPrefix:@"https://"]) {
        return [repo substringFromIndex:8];
    } else {
        return repo;
    }
}

- (NSString *)escapeSlash:(NSString *)string {
    NSArray *array = [string componentsSeparatedByString:@"/"];
    return [array componentsJoinedByString:@":"];
}

- (NSString *)escapeRepo:(NSString *)string {
    return [self escapeSlash:[self removeHttp:string]];
}

// make a directory to save repo files
- (void)makeRepoDirectory:(NSString *)repo {
    NSLog(@"BMRootViewController:makeRepoDirectory.start");
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@",savePath,repo] withIntermediateDirectories:YES attributes:nil error:nil];
    NSLog(@"BMRootViewController:makeRepoDirectory.finish");
}

// called when title button is tapped
- (void)titleTapped:(id)sender {
    NSLog(@"BMRootViewController:titleTapped.start");
    BMListViewController *listViewController = [[BMListViewController alloc] init];

	CATransition* transition = [CATransition animation];
    transition.duration = 0.5;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    transition.type = kCATransitionMoveIn;
    transition.subtype = kCATransitionFromTop;

    [self.navigationController.view.layer addAnimation:transition forKey:nil];
    [self.navigationController pushViewController:listViewController animated:NO];
    NSLog(@"BMRootViewController:titleTapped.finish");
}

// called when settings button is tapped
- (void)settingsButtonTapped:(id)sender {
    NSLog(@"BMRootViewController:settingsButtonTapped.start");
    BMSettingsViewController *settingsViewController = [[BMSettingsViewController alloc] init];

	CATransition* transition = [CATransition animation];
    transition.duration = 0.5;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
    transition.type = kCATransitionMoveIn;
    transition.subtype = kCATransitionFromTop;

    [self.navigationController.view.layer addAnimation:transition forKey:nil];
    [self.navigationController pushViewController:settingsViewController animated:NO];
    NSLog(@"BMRootViewController:settingsButtonTapped.finish");
}

// called when the tableview is pulled down
- (void)refreshOccurred:(id)sender {
    [self getUserDefaults];
    [self refreshMods];
    while (!finished) {}
    [self.refreshControl endRefreshing];
}

// localize strings
- (NSString *)BMLocalizedString:(NSString *)key {
    NSString *path = [[NSBundle mainBundle] pathForResource:languageArray[appLanguage] ofType:@"lproj"];
    NSString *escapedString = [[NSBundle bundleWithPath:path] localizedStringForKey:key value:@"" table:nil];
    return [escapedString stringByReplacingOccurrencesOfString:@"\\n" withString: @"\n"];
}

// make a directory to save temporary files
- (void)makeSaveDirectory {
    NSLog(@"BMRootViewController:makeSaveDirectory.start");
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:savePath withIntermediateDirectories:YES attributes:nil error:nil];
    NSLog(@"BMRootViewController:makeSaveDirectory.finish");
}

- (void)checkForUpdate {
    NSLog(@"BMRootViewController:checkForUpdate.start");
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURL *requestURL = [NSURL URLWithString:@"https://github.com/BlitzModder/BMiOS/raw/master/version"];
    NSURLSessionDataTask *task = [session dataTaskWithURL:requestURL
                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
											if (!error) {
												NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
												if (statusCode == 404) {
	                                                dispatch_async(dispatch_get_main_queue(), ^{
	                                                    [self showError:[self BMLocalizedString:@"Failed to check for update. Please report this to subdiox."]];
	                                                    return;
	                                                });
	                                            } else {
													NSString *appVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
													NSString *latestVersion = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
													NSLog(@"appVersion:%@,latestVersion:%@",appVersion,latestVersion);
													if ([self convertVersion:appVersion] < [self convertVersion:latestVersion]) {
														[self showError:[self BMLocalizedString:@"New version of BlitzModder is available. Please go to Cydia to get the update."]];
													}
	                                            }
											}}];
    [task resume];
    NSLog(@"BMRootViewController:checkForUpdate.finish");
}

- (double)convertVersion:(NSString *)version {
	NSArray *versionArray = [version componentsSeparatedByString:@"."];
	double converted = 0;
	for (int i = 0; i < versionArray.count; i++) {
		converted += [versionArray[i] doubleValue] * pow(10.0, -(double)i);
	}
	return converted;
}

// get NSUserDefaults
- (void)getUserDefaults {
    NSLog(@"BMRootViewController:getUserDefaults.start");
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    appLanguage = [ud integerForKey:@"appLanguage"];
	languageArray = [ud arrayForKey:@"AppleLanguages"];
    repoArray = [[ud arrayForKey:@"repoArray"] mutableCopy];
    repoNameArray = [[ud arrayForKey:@"repoNameArray"] mutableCopy];
    currentRepo = [ud integerForKey:@"currentRepo"];
	blitzPath = [ud stringForKey:@"blitzPath"];
    blitzVersion = [ud stringForKey:@"blitzVersion"];
	buttonArray = [[ud arrayForKey:@"buttonArray"] mutableCopy];
	installedArray = [[ud arrayForKey:@"installedArray"] mutableCopy];
	modCategoryArray = [[ud arrayForKey:@"modCategoryArray"] mutableCopy];
	modNameArray = [[ud arrayForKey:@"modNameArray"] mutableCopy];
	modDetailArray = [[ud arrayForKey:@"modDetailArray"] mutableCopy];
    launchCount = [ud integerForKey:@"launchCount"];
    neverDonate = [ud boolForKey:@"neverDonate"];
    repoVersionArray = [[ud arrayForKey:@"repoVersionArray"] mutableCopy];
    NSLog(@"BMRootViewController:getUserDefaults.finish");
}

// save NSUserDefaults
- (void)saveUserDefaults {
    NSLog(@"BMRootViewController:saveUserDefaults.start");
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setInteger:appLanguage forKey:@"appLanguage"];
	[ud setObject:languageArray forKey:@"AppleLanguages"];
    [ud setObject:[repoArray copy] forKey:@"repoArray"];
    [ud setObject:[repoNameArray copy] forKey:@"repoNameArray"];
    [ud setInteger:currentRepo forKey:@"currentRepo"];
	[ud setObject:blitzPath forKey:@"blitzPath"];
    [ud setObject:blitzVersion forKey:@"blitzVersion"];
	[ud setObject:[buttonArray copy] forKey:@"buttonArray"];
	[ud setObject:[installedArray copy] forKey:@"installedArray"];
	[ud setObject:[modCategoryArray copy] forKey:@"modCategoryArray"];
	[ud setObject:[modNameArray copy] forKey:@"modNameArray"];
	[ud setObject:[modDetailArray copy] forKey:@"modDetailArray"];
    [ud setInteger:launchCount forKey:@"launchCount"];
    [ud setBool:neverDonate forKey:@"neverDonate"];
    [ud setObject:[repoVersionArray copy] forKey:@"repoVersionArray"];
    [ud synchronize];
    NSLog(@"BMRootViewController:saveUserDefaults.finish");
}

// show error message
- (void)showError:(NSString *)errorMessage {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[self BMLocalizedString:@"Error"] message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:[self BMLocalizedString:@"OK"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

// refresh mods list
- (void)refreshMods {
    NSLog(@"BMRootViewController:refreshMods.start");
    __block NSMutableArray *tryArray = [languageArray mutableCopy];
    [tryArray exchangeObjectAtIndex:0 withObjectAtIndex:appLanguage];
    finished = NO;
    [self makeRepoDirectory:[self escapeRepo:repoArray[currentRepo]]];
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/plist/%@.plist",repoArray[currentRepo],tryArray[tryingLanguage]]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
		if (!error) {
			NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
			if (statusCode == 404) {
                if (tryingLanguage + 1 < [tryArray count]) {
                    tryingLanguage += 1;
                    [self refreshMods];
                }
                return;
            } else {
                NSFileManager *fm = [NSFileManager defaultManager];
                NSString *filePath = [NSString stringWithFormat:@"%@/%@/%@.plist",savePath,[self escapeRepo:repoArray[currentRepo]],tryArray[tryingLanguage]];
                [fm createFileAtPath:filePath contents:data attributes:nil];
                NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:filePath];
                [file writeData:data];
				MutableOrderedDictionary *dic = [[MutableOrderedDictionary alloc] initWithContentsOfFile:filePath];
                NSLog(@"dic: %@", dic);
				modCategoryArray = [NSMutableArray array];
				modNameArray = [NSMutableArray array];
				modDetailArray = [NSMutableArray array];
                [modCategoryArray removeAllObjects];
                [modNameArray removeAllObjects];
                [modDetailArray removeAllObjects];
				modCategoryArray = [[dic allKeys] mutableCopy];
				for (int i = 0; i < [modCategoryArray count]; i++) {
                    NSString *key1 = modCategoryArray[i];
                    NSLog(@"key1: %@",key1);
					[modNameArray addObject:[dic[key1] allKeys]];
					NSMutableArray *tempDetailArray = [NSMutableArray array];
                    [tempDetailArray removeAllObjects];
					for (int j = 0; j < [modNameArray[i] count]; j++) {
                        NSString *key2 = modNameArray[i][j];
                        NSLog(@"key2: %@",key2);
                        NSMutableArray *keysArray = [NSMutableArray array];
                        NSMutableArray *valuesArray = [NSMutableArray array];
                        [keysArray removeAllObjects];
                        [valuesArray removeAllObjects];
						keysArray = [[dic[key1][key2] allKeys] mutableCopy];
						valuesArray = [[dic[key1][key2] allValues] mutableCopy];
						int current = 0;
						int removed = 0;
						while (current < valuesArray.count) {
							if (![self checkValidate:valuesArray[current]]) {
								[keysArray removeObjectAtIndex:current - removed];
								removed += 1;
							}
							current += 1;
						}
                        if (keysArray.count == 0) {
                            NSMutableArray *tempNameArray = [NSMutableArray array];
                            [tempNameArray removeAllObjects];
                            tempNameArray = [modNameArray[i] mutableCopy];
                            [tempNameArray removeObjectAtIndex:j];
                            [modNameArray replaceObjectAtIndex:i withObject:tempNameArray];
                            j--;
                        } else {
                            [tempDetailArray addObject:keysArray];
                        }
					}
					[modDetailArray addObject:tempDetailArray];
				}
                [self getRepoVersion];
				[self saveUserDefaults];
				dispatch_async(dispatch_get_main_queue(), ^{
					[self.tableView reloadData];
				});
            }
		} else {
			[self showError:[self BMLocalizedString:@"Your internet connection seems to be offline."]];
		}
        finished = YES;
        NSLog(@"BMRootViewController:refreshMods.finish");
	}];
    [task resume];
    while(!finished) {}
}

- (void)getRepoVersion {
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/info.plist",repoArray[currentRepo]]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
			if (statusCode == 404) {
                repoVersionArray[currentRepo] = @"0.0.0";
            } else {
                NSFileManager *fm = [NSFileManager defaultManager];
                NSString *filePath = [NSString stringWithFormat:@"%@/%@/info.plist",savePath,[self escapeRepo:repoArray[currentRepo]]];
                [fm createFileAtPath:filePath contents:data attributes:nil];
                NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:filePath];
                [file writeData:data];
                NSDictionary *dic = [[NSDictionary alloc] initWithContentsOfFile:filePath];
                if ([self convertVersion:repoVersionArray[currentRepo]] < [self convertVersion:[dic objectForKey:@"version"]]) {
                    [self showChangelog:[dic objectForKey:@"version"]];
                }
            }
        }
    }];
    [task resume];
}

- (void)showChangelog:(NSString *)latestVersion {
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/changelog.txt",repoArray[currentRepo]]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:requestURL completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
			if (statusCode != 404) {
                NSString *changelog = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[self BMLocalizedString:@"Changes"] message:[NSString stringWithFormat:@"\n%@",changelog] preferredStyle:UIAlertControllerStyleAlert];
                [alertController addAction:[UIAlertAction actionWithTitle:[self BMLocalizedString:@"OK"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    repoVersionArray[currentRepo] = latestVersion;
                    [self saveUserDefaults];
                }]];
                NSArray *viewArray = [[[[[[[[[[[[alertController view] subviews] firstObject] subviews] firstObject] subviews] firstObject] subviews] firstObject] subviews] firstObject] subviews];
                UILabel *alertMessage = viewArray[1];
                [self presentViewController:alertController animated:YES completion:nil];
                alertMessage.textAlignment = NSTextAlignmentLeft;
                alertMessage.font = [UIFont systemFontOfSize:12];
            }
        }
    }];
    [task resume];
}

- (NSString *)getBlitzVersion {
	NSString *versionPath = [NSString stringWithFormat:@"%@/Data/version.txt",blitzPath];
    NSString *fullVersion = [NSString stringWithContentsOfFile:versionPath encoding:NSUTF8StringEncoding error:nil];
	NSArray *versionArray = [fullVersion componentsSeparatedByString:@"."];
	return [NSString stringWithFormat:@"%@.%@.%@",versionArray[0],versionArray[1],versionArray[2]];
}

- (BOOL)checkValidate :(NSString *)string {
	NSArray *stringArray = [string componentsSeparatedByString:@":"];
	if (stringArray.count == 2) {
		if ([self convertVersion:stringArray[0]] >= [self convertVersion:blitzVersion]) {
			NSRange range = [stringArray[1] rangeOfString:@"i"];
			if (range.location != NSNotFound) {
				return YES;
			} else {
				return NO;
			}
		} else {
			return NO;
		}
	} else {
		return YES;
	}
}

- (NSString *)getFullString :(int)i :(int)j :(int)k {
	return [self getString:modDetailArray[i][j][k]];
}

- (NSString *)getFullID :(int)i :(int)j :(int)k {
	return [NSString stringWithFormat:@"%@.%@.%@",[self getID:modCategoryArray[i]],[self getID:modNameArray[i][j]],[self getID:modDetailArray[i][j][k]]];
}

- (NSString *)getSaveID :(int)i :(int)j :(int)k {
	return [NSString stringWithFormat:@"%@.%@",[self escapeRepo:repoArray[currentRepo]],[self getFullID:i:j:k]];
}

- (NSString *)getString:(NSString *)string{
	NSArray *array = [string componentsSeparatedByString:@":"];
	if ([array count] == 2) {
		return array[0];
	} else {
		return @"error";
	}
}

- (NSString *)getID:(NSString *)string{
	NSArray *array = [string componentsSeparatedByString:@":"];
	if ([array count] == 2) {
		return array[1];
	} else {
		return @"error";
	}
}

// check whether WoTBlitz exists
- (void)checkBlitzExists {
    NSLog(@"BMRootViewController:checkBlitzExists.start");
    NSString *appsPath = @"";
    NSArray  *iOSVersions = [[[UIDevice currentDevice]systemVersion] componentsSeparatedByString:@"."];
    NSInteger iOSVersionMajor = [iOSVersions[0] intValue];
    NSInteger iOSVersionMinor = [iOSVersions[1] intValue];
    if ((iOSVersionMajor == 9 && iOSVersionMinor < 3) || iOSVersionMajor == 8) {
        appsPath = @"/var/mobile/Containers/Bundle/Application";
    } else if ((iOSVersionMajor == 9 && iOSVersionMinor >= 3) || iOSVersionMajor > 9) {
        appsPath = @"/var/containers/Bundle/Application";
    } else {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[self BMLocalizedString:@"Warning"] message:[self BMLocalizedString:@"Your iOS Version is not supported.\nPlease update to iOS9 and jailbreak again."] preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    [self findBlitz:appsPath];
    if ([blitzPath isEqualToString:@""]) {
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[self BMLocalizedString:@"Warning"] message:[self BMLocalizedString:@"World of Tanks Blitz is not installed.\nPlease install it from App Store."] preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertController animated:YES completion:nil];
    }
	[self saveUserDefaults];
    NSLog(@"BMRootViewController:checkBlitzExists.finish");
}

- (void)findBlitz:(NSString*)appsPath {
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *path in [fm contentsOfDirectoryAtPath:appsPath error:nil]) {
        BOOL dir;
        NSString *absolutePath = [NSString stringWithFormat:@"%@/%@",appsPath,path];
        if ([fm fileExistsAtPath:absolutePath isDirectory:&dir]) {
            if (dir) {
                for (NSString *path2 in [fm contentsOfDirectoryAtPath:absolutePath error:nil]) {
                    NSString *absolutePath2 = [NSString stringWithFormat:@"%@/%@",absolutePath,path2];
                    if ([absolutePath2 hasSuffix:@"wotblitz.app"]) {
                        blitzPath = absolutePath2;
                    }
                }
            }
        }
    }
}

// called when Apply button is tapped
- (void)applyButtonTapped:(id)sender {
    [self getUserDefaults];
	NSMutableArray *removeQueueArray = [NSMutableArray array];
	NSMutableArray *installQueueArray = [NSMutableArray array];
    for (int i = 0; i < [modDetailArray count]; i++) {
        for (int j = 0; j < [modDetailArray[i] count]; j++) {
            for (int k = 0; k < [modDetailArray[i][j] count]; k++) {
                if (![buttonArray containsObject:[self getSaveID:i:j:k]] && [installedArray containsObject:[self getSaveID:i:j:k]]) {
					[removeQueueArray addObject:@[@(i),@(j),@(k)]];
                } else if ([buttonArray containsObject:[self getSaveID:i:j:k]] && ![installedArray containsObject:[self getSaveID:i:j:k]]) {
                    [installQueueArray addObject:@[@(i),@(j),@(k)]];
                }
            }
        }
    }
	[self saveUserDefaults];
	if (removeQueueArray.count + installQueueArray.count == 0) {
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[self BMLocalizedString:@"Notice"] message:[self BMLocalizedString:@"There are no changes to be applied."] preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:[self BMLocalizedString:@"OK"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
	} else {
		BMConfirmationViewController *confirmationViewController = [[BMConfirmationViewController alloc] init];

		confirmationViewController.removeQueueArray = removeQueueArray;
		confirmationViewController.installQueueArray = installQueueArray;

	    CATransition* transition = [CATransition animation];
	    transition.duration = 0.5;
	    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
	    transition.type = kCATransitionMoveIn;
	    transition.subtype = kCATransitionFromTop;

	    [self.navigationController.view.layer addAnimation:transition forKey:nil];
	    [self.navigationController pushViewController:confirmationViewController animated:NO];
	}
}

// UITableView settings
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [modNameArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [modNameArray[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self getString:modCategoryArray[section]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
	if (!cell) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	}
    cell.textLabel.text = [self getString:modNameArray[indexPath.section][indexPath.row]];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    BMSecondViewController *secondViewController = [[BMSecondViewController alloc] init];
    secondViewController.indexPath = indexPath;
	UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:[self BMLocalizedString:@"Back"] style:UIBarButtonItemStylePlain target:self action:nil];
    [self.navigationItem setBackBarButtonItem:backButton];
    [self.navigationController pushViewController:secondViewController animated:YES];
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section {
    if([view isKindOfClass:[UITableViewHeaderFooterView class]]){
        UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
        tableViewHeaderFooterView.textLabel.text = [tableViewHeaderFooterView.textLabel.text capitalizedString];
    }
}

// deselect row when view appears
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
}

@end

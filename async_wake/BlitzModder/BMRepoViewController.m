#import <UIKit/UIKit.h>

#import "BMRepoViewController.h"
#import "SVProgressHUD/SVProgressHUD.h"

@interface BMRepoViewController()
@end

@implementation BMRepoViewController {
    NSInteger appLanguage;
    NSArray *languageArray;
    NSMutableArray *repoArray;
    NSMutableArray *repoNameArray;
    NSMutableArray *repoVersionArray;
    NSString *savePath;
    BOOL exists;
    BOOL okRepo;
    BOOL downloaded;
    BOOL checked;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	[self getUserDefaults];
    self.title = [self BMLocalizedString:@"Repository List"];
	self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addButtonTapped:)];
    savePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    [self getUserDefaults];
}

- (NSString *)BMLocalizedString:(NSString *)key {
    NSString *path = [[NSBundle mainBundle] pathForResource:languageArray[appLanguage] ofType:@"lproj"];
    return [[NSBundle bundleWithPath:path] localizedStringForKey:key value:@"" table:nil];
}

- (void)getUserDefaults {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    appLanguage = [ud integerForKey:@"appLanguage"];
	languageArray = [ud arrayForKey:@"AppleLanguages"];
    repoArray = [[ud arrayForKey:@"repoArray"] mutableCopy];
    repoNameArray = [[ud arrayForKey:@"repoNameArray"] mutableCopy];
    repoVersionArray = [[ud arrayForKey:@"repoVersionArray"] mutableCopy];
}

- (void)saveUserDefaults {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setInteger:appLanguage forKey:@"appLanguage"];
    [ud setObject:[repoArray copy] forKey:@"repoArray"];
    [ud setObject:[repoNameArray copy] forKey:@"repoNameArray"];
    [ud setObject:[repoVersionArray copy] forKey:@"repoVersionArray"];
    [ud synchronize];
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

- (NSString *)getFullRepo:(NSString *)repoName {
    NSString *repo;
    if ([repoName hasPrefix:@"http://"] || [repoName hasPrefix:@"https://"]) {
;        if ([repoName hasSuffix:@"/"]) {
            repo = [repoName substringToIndex:repoName.length - 1];
        } else {
            repo = repoName;
        }
    } else {
        NSArray *array = [repoName componentsSeparatedByString:@"/"];
        if (array.count == 1) {
            repo = [NSString stringWithFormat:@"http://%@.github.io/BMRepository", array[0]];
        } else if (array.count == 2) {
            repo = [NSString stringWithFormat:@"http://%@.github.io/%@", array[0], array[1]];
        } else {
            repo = @"error";
        }
    }
    return repo;
}

- (void)checkRepo:(NSString *)repoName {
    checked = NO;
    okRepo = NO;
    NSString *repo = [self getFullRepo:repoName];
    if ([repo isEqualToString:@"error"]) {
        [self showError:[self BMLocalizedString:@"Repository format is incorrect. Please input correctly."]];
        return;
    }
    NSMutableArray *tryArray = [languageArray mutableCopy];
    [tryArray exchangeObjectAtIndex:0 withObjectAtIndex:appLanguage];
	for (int i = 0; i < [tryArray count]; i++) {
		downloaded = NO;
		exists = NO;
		NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
		NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
		NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/plist/%@.plist",repo,tryArray[i]]];
		NSURLSessionDataTask *task = [session dataTaskWithURL:requestURL
											completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
												if (!error) {
													NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
													NSLog(@"%ld",(long)statusCode);
													if (statusCode == 404) {
														exists = NO;
													} else {
														exists = YES;
													}
												} else {
													[self showError:[self BMLocalizedString:@"Your internet connection seems to be offline."]];
												}
												downloaded = YES;
											}];
		[task resume];
		while (!downloaded) {} // wait for completion of download
		if (exists) {
            checked = YES;
        	okRepo = YES;
            [repoNameArray addObject:[self getRepoInfo:repo]];
            [repoVersionArray addObject:@"0.0.0"];
            return;
        } else {
            if (i == [tryArray count] - 1) {
                dispatch_async(dispatch_get_main_queue(), ^{
    				[self showError:[self BMLocalizedString:@"This repository is invalid! Please contact the owner of this repository."]];
    			});
                checked = YES;
    			okRepo = NO;
            }
        }
	}
}

- (NSString *)getRepoInfo:(NSString *)repo {
    __block NSString *string = repo;
    __block bool finished;
    NSURLSessionConfiguration* config = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    NSURL *requestURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/info.plist", repo]];
    NSURLSessionDataTask *task = [session dataTaskWithURL:requestURL
                                        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
											if (!error) {
												NSInteger statusCode = ((NSHTTPURLResponse *)response).statusCode;
												if (statusCode != 404) {
                                                    [self makeRepoDirectory:[self escapeRepo:repo]];
                                                    NSFileManager *fm = [NSFileManager defaultManager];
	                                                NSString *filePath = [NSString stringWithFormat:@"%@/%@/info.plist",savePath,[self escapeRepo:repo]];
	                                                [fm createFileAtPath:filePath contents:data attributes:nil];
	                                                NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:filePath];
	                                                [file writeData:data];
													NSDictionary *dic = [[NSDictionary alloc] initWithContentsOfFile:filePath];
                                                    string = [dic objectForKey:@"name"];
                                                }
                                            }
                                            finished = YES;
                                        }];
    [task resume];
    while (!finished) {}
    return string;
}

// make a directory to save repo files
- (void)makeRepoDirectory:(NSString *)repo {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:[NSString stringWithFormat:@"%@/%@",savePath,repo] withIntermediateDirectories:YES attributes:nil error:nil];
}

- (void)showError:(NSString *)errorMessage {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[self BMLocalizedString:@"Error"] message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle:[self BMLocalizedString:@"OK"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)addButtonTapped:(id)sender {
    UIAlertController *textAlert = [UIAlertController alertControllerWithTitle:[self BMLocalizedString:@"Enter Repository"]
                                                                       message:nil
                                                                preferredStyle:UIAlertControllerStyleAlert];
    [textAlert addTextFieldWithConfigurationHandler:^(UITextField *textField){
        textField.placeholder = @"http://subdiox.com/repo";
    }];
    UIAlertAction *keywordOkAction = [UIAlertAction actionWithTitle:@"OK"
                                                              style:UIAlertActionStyleDefault
                                                            handler:^(UIAlertAction *action) {
                                                                NSString *textField = textAlert.textFields.firstObject.text;
                                                                BOOL sameRepo = NO;
                                                                for (int i = 0; i < [repoArray count]; i++) {
                                                                    if ([repoArray[i] isEqualToString:textField]) {
                                                                        sameRepo = YES;
                                                                    }
                                                                }
                                                                if (sameRepo) {
                                                                    [self showError:[self BMLocalizedString:@"This repository has already been registered."]];
                                                                } else {
                                                                    [SVProgressHUD setDefaultStyle:SVProgressHUDStyleDark];
                                                                    [SVProgressHUD showWithStatus:[self BMLocalizedString:@"Checking Repository..."]];
                                                                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                                                                        [self checkRepo:textField];
                                                                        while (!checked) {}
                                                                        dispatch_async(dispatch_get_main_queue(), ^{
                                                                            [SVProgressHUD dismiss];
                                                                            if (okRepo) {
                                                                                [repoArray insertObject:textField atIndex:[repoArray count]];
                                                                                [self.tableView reloadData];
                                                                                [self saveUserDefaults];
                                                                            }
                                                                        });
                                                                    });
                                                                }
                                                            }];

    UIAlertAction *keywordCancelAction = [UIAlertAction actionWithTitle:[self BMLocalizedString:@"Cancel"]
                                                                  style:UIAlertActionStyleDefault
                                                                handler:^(UIAlertAction *action) {
                                                                }];
    [textAlert addAction:keywordCancelAction];
    [textAlert addAction:keywordOkAction];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        textAlert.popoverPresentationController.sourceView = self.view;
        textAlert.popoverPresentationController.sourceRect = self.view.bounds;
        textAlert.popoverPresentationController.permittedArrowDirections = 0;
    }
    [self presentViewController:textAlert animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return repoArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    if ([repoNameArray count] > indexPath.row) {
        cell.textLabel.text = repoNameArray[indexPath.row];
    }
    cell.detailTextLabel.text = repoArray[indexPath.row];
    cell.detailTextLabel.textColor = [UIColor grayColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    [repoArray removeObjectAtIndex:indexPath.row];
    [repoNameArray removeObjectAtIndex:indexPath.row];
    [repoVersionArray removeObjectAtIndex:indexPath.row];
    [tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self saveUserDefaults];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        return NO;
    } else {
        return YES;
    }
}

@end

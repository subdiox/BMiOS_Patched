#import <UIKit/UIKit.h>

@interface BMProcessViewController : UIViewController <NSURLSessionDelegate, NSFileManagerDelegate>
@property (strong, nonatomic) NSMutableArray *removeQueueArray;
@property (strong, nonatomic) NSMutableArray *installQueueArray;
@end

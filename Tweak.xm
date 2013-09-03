#import <UIKit/UIKit.h>
#include <substrate.h>

#define kPullToRefreshTag 965

static BOOL PTDAPullToActivateEnabled;
static NSInteger activeAlarmCount;

@interface AlarmManager
+ (id)sharedManager;
@property(readonly, retain, nonatomic) NSArray *alarms;
@end

@interface AlarmViewController 
- (void)activeChangedForAlarm:(id)arg1 active:(BOOL)arg2; // Thread-safe
- (void)alarmDidUpdate:(id)arg1; // Not
@end

@interface AlarmViewController (BHPullToDisableAlarms)
- (void)handleRefresh:(id)sender;
- (void)countActiveAlarms;
- (void)BHPTDAUpdateUI;
@end


static void SettingsCallback()
{
    NSDictionary *settings = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.Bader.PullToDisableAlarms.plist"];
    id temp = [settings objectForKey:@"PTDAPullToActivateEnabled"];
    PTDAPullToActivateEnabled = (temp) ? [temp boolValue] : YES;
	[settings release];
}


%hook AppController

- (void)applicationDidBecomeActive:(id)arg1
{
    // If you switch fast enough, the settings darwin notif wont be served in time(!).
    %orig(arg1);
	SettingsCallback();
	
}
%end

%hook AlarmViewController
- (void)loadView
{
    %orig;
    UIRefreshControl *pullToRefreshControl = [[UIRefreshControl alloc] init];
    pullToRefreshControl.tintColor = [UIColor clearColor];
	pullToRefreshControl.tag = kPullToRefreshTag;  // Hacky
    [pullToRefreshControl addTarget:self
                             action:@selector(handleRefresh:)
                   forControlEvents:UIControlEventValueChanged];
	
    
	UITableView *theTableView = MSHookIvar<UITableView *>(self, "_tableView");
    [theTableView addSubview:pullToRefreshControl];
	
	[pullToRefreshControl release];
}

- (id)view
{
    id theView = %orig;
    [self countActiveAlarms];
    [self BHPTDAUpdateUI];
    return theView;
}

- (void)activeChangedForAlarm:(id)alarm active:(BOOL)active
{
	BOOL shouldUpdateUI = NO;   // update UI in 0->1 and 1->0 edges only.
    
	if (active) {
		if (++activeAlarmCount == 1) // 0 -> 1.
			shouldUpdateUI = YES;
	
	} else {
		if (--activeAlarmCount <= 0) // 1 -> 0.
			shouldUpdateUI = YES;
	}
       
   if (activeAlarmCount < 0) // Will never occur, but just to be safe.
       activeAlarmCount = 0;
           
    %orig(alarm,active);
	
	if (shouldUpdateUI)
	    [self performSelectorOnMainThread:@selector(BHPTDAUpdateUI) withObject:nil waitUntilDone:YES];
}


%new
- (void)BHPTDAUpdateUI
{
	
    NSString *pullString = (activeAlarmCount < 1 && PTDAPullToActivateEnabled) ? @"Pull Down To Enable Alarms" :
    																			 @"Pull Down To Disable Alarms";
	NSAttributedString *attPullString = [[NSAttributedString alloc] initWithString:pullString];
	
	UITableView *theTableView = MSHookIvar<UITableView *>(self, "_tableView");
	((UIRefreshControl *)[theTableView viewWithTag:kPullToRefreshTag]).attributedTitle = attPullString;

	[attPullString release];
}


%new
- (void)handleRefresh:(id)sender
{
    NSArray *myAlarms = [((AlarmManager *)[%c(AlarmManager) sharedManager]) alarms];
    
    if (activeAlarmCount > 0){
        // Disable all active alarms.
        for (id anAlarm in myAlarms){
            if ([anAlarm isActive]){
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
					[self activeChangedForAlarm:anAlarm active:NO];
			        dispatch_async(dispatch_get_main_queue(), ^{
                        [self alarmDidUpdate:anAlarm];
                        
			        });
                });
            }
        }
        
 
    } else if (PTDAPullToActivateEnabled) {
        for (id anAlarm in myAlarms){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(void){
                [self activeChangedForAlarm:anAlarm active:YES];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self alarmDidUpdate:anAlarm];
                    
                });
            });
        }
        
    }
    [(UIRefreshControl *)sender endRefreshing];
}

%new
- (void)countActiveAlarms
{
    activeAlarmCount = 0;
    NSArray *theAlarms = [((AlarmManager *)[%c(AlarmManager) sharedManager]) alarms];
    for (id anAlarm in theAlarms){
        if ([anAlarm isActive]){
            activeAlarmCount += 1;
        }
    }
    
}
%end



%ctor {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    %init;
    SettingsCallback();
    [pool drain];
}

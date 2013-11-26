#import "ApplicationDelegate.h"
#import "BackgroundChanger.h"
#import "ZipArchive.h"
#import "NSApplication+Relaunch.h"

@implementation ApplicationDelegate

@synthesize receivedData;
@synthesize panelController = _panelController;
@synthesize menubarController = _menubarController;
@synthesize iotdTitle = _iotdTitle;
@synthesize iotdDescription = _iotdDescription;

#pragma mark -

- (void)dealloc
{
    [_panelController removeObserver:self forKeyPath:@"hasActivePanel"];
}

#pragma mark -

void *kContextActivePanel = &kContextActivePanel;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kContextActivePanel) {
        self.menubarController.hasActiveIcon = self.panelController.hasActivePanel;
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // add app to login items.
    [self addAppAsLoginItem];
    
    // Install icon into the menu bar
    self.menubarController = [[MenubarController alloc] init];
    
    [self updateWallpaper];
    
    [self checkForUpdate];
    
    //get current datetime
    NSDate *now = [NSDate date];
    
    //get the current month day and year as a string.
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [dateFormatter setLocale:usLocale];
    NSString *formattedDateString = [dateFormatter stringFromDate:now];
    
    //create a new date object for today at 10:30a EST (GMT-5)
    NSString *string1030 = [formattedDateString stringByAppendingString:@" 10:30:00 -0500"];
    NSDate *now1030 = [NSDate dateWithString:string1030];
    
    //Get the number of seconds between current time and today at 10:30a EST.
    NSTimeInterval timeTil1030 = [now1030 timeIntervalSinceDate:now];
    
    //if it's already past 10:30 today.
    if(timeTil1030 <= 0) {
        // set date to tomorrow at 10:30 by adding 24 hours.
        now1030 = [now1030 dateByAddingTimeInterval:86400];
        // Get the number of seconds between current time and tomorrow at 10:30a EST. 
        timeTil1030 = [now1030 timeIntervalSinceDate:now]; 
    }
    //create a timer to update the wallpaper after the time interval calculated above has elapsed.
    [NSTimer scheduledTimerWithTimeInterval:timeTil1030 target:self selector:@selector(update1030:) userInfo:@{ @"StartDate" : [NSDate date] } repeats:NO];
}

- (void)update1030:(NSTimer*)theTimer {
    NSDate *startDate = [[theTimer userInfo] objectForKey:@"StartDate"];
    NSLog(@"Timer started on %@", startDate);
    [self updateWallpaper];
    // create a new timer that will fire after 24 hours and repeats until the app is closed.
    [NSTimer scheduledTimerWithTimeInterval:86400 target:self selector:@selector(update24:) userInfo:@{ @"StartDate" : [NSDate date] } repeats:YES];
}

- (void)update24:(NSTimer*)theTimer {
    NSDate *startDate = [[theTimer userInfo] objectForKey:@"StartDate"];
    NSLog(@"Timer started on %@", startDate);
    [self updateWallpaper];
}

- (void)updateWallpaper {
    //Update Wallpaper.
    BackgroundChanger *bc = [BackgroundChanger new];
    NSArray *titleDesc = [bc setWallpaper:nil];
    if(titleDesc) {
        _iotdTitle = [titleDesc objectAtIndex:0];
        _iotdDescription = [titleDesc objectAtIndex:1];
    }
    else {
        _iotdTitle = @"There was a problem downloading the image.";
        _iotdDescription = @"";
    }
}

- (void)checkForUpdate {
    NSError *err = nil;
    
    // start putting the version number in the build.
    // compare the version number of the running app to the version number from github in the .app package's info.plist xml file.
    double currentVersion = [[NSString stringWithFormat:@"%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] doubleValue];
    NSLog(@"%f",currentVersion);
    NSString *currentVersionStr = [NSString stringWithFormat:@"%.2f", currentVersion];
    //https://raw.github.com/BillCacy/NPOD/master/mac/NPOD.app/Contents/Info.plist
    //[[NSString stringWithFormat:@"%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] doubleValue];
    
    NSURL *myURL2 = [NSURL URLWithString:@"https://raw.github.com/BillCacy/NPOD/master/mac/NPOD.app/Contents/Info.plist"];
    NSXMLDocument *iotdxml = [[NSXMLDocument alloc] initWithContentsOfURL:myURL2 options:0 error:&err];
    
    NSArray *nodes = [iotdxml nodesForXPath:@"./plist[1]/dict[1]/key[text()='CFBundleShortVersionString']"
                                      error:&err];
    NSXMLNode *versionNode = [[nodes objectAtIndex:0] nextSibling];
    double latestVersion = [[versionNode stringValue] doubleValue];
    NSString *latestVersionStr = [NSString stringWithFormat:@"%.2f", latestVersion];
    NSLog(@"%f",latestVersion);
    
    if(latestVersion > currentVersion) {
        //ask the user if they would like to update to the latest version.
        //if they choose yes, continue to update.
        //if they choose no, don't update.
        
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"Yes"];
        [alert addButtonWithTitle:@"No"];
        NSString *msgTxt = [[[[@"A new version of NASA Pic Of The Day is available!\n\nCurrent Version: " stringByAppendingString:currentVersionStr] stringByAppendingString:@"\nLatest Version: "] stringByAppendingString:latestVersionStr] stringByAppendingString:@"\n\nWould you like to update now?"];
        [alert setMessageText:msgTxt];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        if ([alert runModal] == NSAlertFirstButtonReturn) {
            // Yes clicked, get the new version and install it.
            //download npod.zip from github to users downloads folder.
            NSURL *downloadURL = [NSURL URLWithString:@"https://github.com/BillCacy/NPOD/raw/master/mac/NPOD.zip"];
            NSURLRequest *theRequest=[NSURLRequest requestWithURL:downloadURL
                                                      cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                  timeoutInterval:60.0];
            // create the connection with the request
            // and start loading the data
            NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
            if (theConnection) {
                // Create the NSMutableData to hold the received data.
                // receivedData is an instance variable declared elsewhere.
                receivedData = [NSMutableData data];
            } else {
                // Inform the user that the connection failed.
            }
        }
    }
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Explicitly remove the icon from the menu bar
    self.menubarController = nil;
    return NSTerminateNow;
}

#pragma mark - Actions

- (IBAction)togglePanel:(id)sender
{
    self.menubarController.hasActiveIcon = !self.menubarController.hasActiveIcon;
    self.panelController.hasActivePanel = self.menubarController.hasActiveIcon;
}

#pragma mark - Public accessors

- (PanelController *)panelController
{
    if (_panelController == nil) {
        _panelController = [[PanelController alloc] initWithDelegate:self];
        [_panelController addObserver:self forKeyPath:@"hasActivePanel" options:0 context:kContextActivePanel];
        _panelController.iotdTitleText = _iotdTitle;
        _panelController.iotdDescriptionText = _iotdDescription;
    }
    return _panelController;
}

#pragma mark - PanelControllerDelegate

- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller
{
    return self.menubarController.statusItemView;
}

-(void) addAppAsLoginItem{
	NSString * appPath = [[NSBundle mainBundle] bundlePath];
    
	// This will retrieve the path for the application
	// For example, /Applications/test.app
	CFURLRef url = (__bridge CFURLRef)[NSURL fileURLWithPath:appPath];
    
	// Create a reference to the shared file list.
    // We are adding it to the current user only.
    // If we want to add it all users, use
    // kLSSharedFileListGlobalLoginItems instead of
    //kLSSharedFileListSessionLoginItems
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL,
                                                            kLSSharedFileListSessionLoginItems, NULL);
	if (loginItems) {
		//Insert an item to the list.
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems,
                                                                     kLSSharedFileListItemLast, NULL, NULL,
                                                                     url, NULL, NULL);
		if (item){
			CFRelease(item);
        }
	}
    
	CFRelease(loginItems);
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    // This method is called when the server has determined that it
    // has enough information to create the NSURLResponse.
    
    // It can be called multiple times, for example in the case of a
    // redirect, so each time we reset the data.
    
    // receivedData is an instance variable declared elsewhere.
    [receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    // Append the new data to receivedData.
    // receivedData is an instance variable declared elsewhere.
    [receivedData appendData:data];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    // release the connection, and the data object
    //[connection release];
    // receivedData is declared as a method instance elsewhere
    //[receivedData release];
    
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    // do something with the data
    // receivedData is declared as a method instance elsewhere
    NSLog(@"Succeeded! Received %ld bytes of data",[receivedData length]);
    
    NSString *writeToFile = [@"~/Downloads/NPOD.zip" stringByExpandingTildeInPath];
    
    if ([receivedData writeToFile:writeToFile
                       atomically:YES])
    {
        // It was successful, do stuff here
        //extract it
        ZipArchive *zipArchive = [[ZipArchive alloc] init];
        [zipArchive UnzipOpenFile:writeToFile Password:@""];
        NSString *unzipDir = [@"~/Downloads/" stringByExpandingTildeInPath];
        [zipArchive UnzipFileTo:unzipDir overWrite:YES];
        [zipArchive UnzipCloseFile];
        NSString *newVersionPath = [unzipDir stringByAppendingPathComponent:@"NPOD.app"];
        NSLog(@"%@", newVersionPath);
        NSString *appPath = @"/Applications/NPOD.app";

        if ( [[NSFileManager defaultManager] isDeletableFileAtPath:appPath] ) {
            //copy npod.app to /applications replacing the existing app.
            if ( [[NSFileManager defaultManager] isReadableFileAtPath:newVersionPath] ) {
                [[NSFileManager defaultManager] removeItemAtPath:appPath error:nil];
                [[NSFileManager defaultManager] moveItemAtPath:newVersionPath toPath:appPath error:nil];
            }
        }
        
        //delete npod.zip from downloads folder.
        if ( [[NSFileManager defaultManager] isDeletableFileAtPath:[unzipDir stringByAppendingPathComponent:@"NPOD.zip"]] ) {
            [[NSFileManager defaultManager] removeItemAtPath:[unzipDir stringByAppendingPathComponent:@"NPOD.zip"] error:nil];
        }
        
        //restart the app.
        [NSApp relaunch:nil];
        
    }
    else
    {
        // There was a problem writing the file
    }
}

@end

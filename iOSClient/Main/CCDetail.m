//
//  CCDetail.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 16/01/15.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCDetail.h"
#import "AppDelegate.h"
#import "CCMain.h"
#import "NCUchardet.h"
#import "MediaViewController.h"
#import <KTVHTTPCache/KTVHTTPCache.h>

#import "NCBridgeSwift.h"

#define TOOLBAR_HEIGHT 49.0f

#define alertRequestPasswordPDF 1

@interface CCDetail ()
{
    AppDelegate *appDelegate;
    
    UIToolbar *_toolbar;
    
    UIBarButtonItem *_buttonModifyTxt;
    UIBarButtonItem *_buttonAction;
    UIBarButtonItem *_buttonShare;
    UIBarButtonItem *_buttonDelete;
    
    NSInteger _indexNowVisible;
    NSString *_fileIDNowVisible;
    
    NSMutableOrderedSet *_dataSourceDirectoryID;
    NSString *_fileNameExtension;
}
@end

@implementation CCDetail

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:@"NotificationProgressTask" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(backNavigationController) name:@"detailBack" object:nil];

        self.metadataDetail = [[tableMetadata alloc] init];
        self.photos = [[NSMutableArray alloc] init];
        self.dataSourceImagesVideos = [[NSMutableArray alloc] init];
        _dataSourceDirectoryID = [[NSMutableOrderedSet alloc] init];
        _indexNowVisible = -1;
        _fileIDNowVisible = nil;

        appDelegate.activeDetail = self;
    }
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(insertGeocoderLocation:) name:@"insertGeocoderLocation" object:nil];

    self.imageBackground.image = [UIImage imageNamed:@"backgroundDetail"];
    
    // Proxy
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setupHTTPCache];
    });
    
    // Change bar bottom line shadow
    self.navigationController.navigationBar.shadowImage = [CCGraphics generateSinglePixelImageWithColor:[NCBrandColor sharedInstance].brand];
    
    if ([self.metadataDetail.fileNameView length] > 0 || [self.metadataDetail.directoryID length] > 0 || [self.metadataDetail.fileID length] > 0) {
    
        // open view
        [self viewFile];
    }
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.splitViewController.isCollapsed) {
        
        self.tabBarController.tabBar.hidden = YES;
        self.tabBarController.tabBar.translucent = YES;
    }
    
    if (self.splitViewController.isCollapsed)
        [appDelegate plusButtonVisibile:false];
}

// E' scomparso
- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    // remove all
    if (self.isMovingFromParentViewController)
        [self removeAllView];    
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [coordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        
    }];
    
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

// remove all view
- (void)removeAllView
{
    // Document
    if (_webView) {
        [_webView removeFromSuperview];
        _webView = nil;
    }
        
    // PDF
    if (_readerPDFViewController) {
        [_readerPDFViewController.view removeFromSuperview];
        _readerPDFViewController.delegate = nil;
        _readerPDFViewController = nil;
    }
        
    // Photo-Video-Audio
    if (_photoBrowser) {
        [_photos removeAllObjects];
        _photoBrowser.delegate = nil;
        _photoBrowser = nil;
    }
    
    // ToolBar
    if (_toolbar) {
        [_toolbar removeFromSuperview];
        _toolbar = nil;
    }
    
    // Title
    self.title = nil;
}

- (void)backNavigationController
{
    [self removeAllView];
    [self.navigationController popViewControllerAnimated:NO];
}

- (void)changeToDisplayMode
{
    if (_readerPDFViewController)
        [self.readerPDFViewController updateContentViews];
}

- (void)createToolbar
{
    CGFloat safeAreaBottom = 0;
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadataDetail.directoryID];
    if (!serverUrl)
        return;
    
    if (@available(iOS 11, *)) {
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
    
    _toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - TOOLBAR_HEIGHT - safeAreaBottom, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
    
    UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil];
    UIBarButtonItem *fixedSpaceMini = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:self action:nil];
    fixedSpaceMini.width = 25;
    
    _buttonModifyTxt = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"actionSheetModify"] style:UIBarButtonItemStylePlain target:self action:@selector(modifyTxtButtonPressed:)];
    _buttonAction = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"openFile"] style:UIBarButtonItemStylePlain target:self action:@selector(actionButtonPressed:)];
    _buttonShare  = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"share"] style:UIBarButtonItemStylePlain target:self action:@selector(shareButtonPressed:)];
    _buttonDelete = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteButtonPressed:)];
    
    if ([CCUtility isDocumentModifiableExtension:_fileNameExtension]) {
        if ([CCUtility isFolderEncrypted:serverUrl account:appDelegate.activeAccount]) // E2EE
            [_toolbar setItems:[NSArray arrayWithObjects: _buttonModifyTxt, flexible, _buttonDelete, fixedSpaceMini, _buttonAction,  nil]];
        else
            [_toolbar setItems:[NSArray arrayWithObjects: _buttonModifyTxt, flexible, _buttonDelete, fixedSpaceMini, _buttonShare, fixedSpaceMini, _buttonAction,  nil]];
    } else {
        if ([CCUtility isFolderEncrypted:serverUrl account:appDelegate.activeAccount]) // E2EE
            [_toolbar setItems:[NSArray arrayWithObjects: flexible, _buttonDelete, fixedSpaceMini, _buttonAction,  nil]];
        else
            [_toolbar setItems:[NSArray arrayWithObjects: flexible, _buttonDelete, fixedSpaceMini, _buttonShare, fixedSpaceMini, _buttonAction,  nil]];
    }
    
    [_toolbar setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    
    _toolbar.barTintColor = [NCBrandColor sharedInstance].tabBar;
    _toolbar.tintColor = [NCBrandColor sharedInstance].brandElement;

    [self.view addSubview:_toolbar];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self];
    
    if (_toolbar) {
        _toolbar.barTintColor = [NCBrandColor sharedInstance].tabBar;
        _toolbar.tintColor = [NCBrandColor sharedInstance].brandElement;
    }    
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View File  =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewFile
{
    // verifico se esiste l'icona e se la posso creare
    if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:self.metadataDetail.fileID fileNameView:self.metadataDetail.fileNameView]] == NO) {
        
        [CCGraphics createNewImageFrom:self.metadataDetail.fileNameView fileID:self.metadataDetail.fileID extension:[self.metadataDetail.fileNameView pathExtension] size:@"m" imageForUpload:NO typeFile:self.metadataDetail.typeFile writeImage:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
    }
    
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_image]) {
        
        self.edgesForExtendedLayout = UIRectEdgeAll;
        [self viewImageVideoAudio];
    }
    
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_video] || [self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_audio]) {
        
        [self createToolbar];
        [self viewMedia];
    }
    
    if ([self.metadataDetail.typeFile isEqualToString: k_metadataTypeFile_document]) {
        
        _fileNameExtension = [[self.metadataDetail.fileNameView pathExtension] uppercaseString];
        
        if ([_fileNameExtension isEqualToString:@"PDF"]) {
            
            self.edgesForExtendedLayout = UIRectEdgeBottom;
            [self viewPDF:@""];
            [self createToolbar];
            [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];

        } else {

            self.edgesForExtendedLayout = UIRectEdgeBottom;
            [self viewDocument];
            [self createToolbar];
            [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View Document =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDocument
{
    CGFloat safeAreaBottom = 0;
    
    if (@available(iOS 11, *)) {
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
    
    if ([CCUtility fileProviderStorageExists:self.metadataDetail.fileID fileName:self.metadataDetail.fileNameView] == NO) {
        
        [self backNavigationController];
        return;
    }
    
    NSString *fileNamePath = [NSTemporaryDirectory() stringByAppendingString:self.metadataDetail.fileNameView];
    
    [[NSFileManager defaultManager] removeItemAtPath:fileNamePath error:nil];
    [[NSFileManager defaultManager] linkItemAtPath:[CCUtility getDirectoryProviderStorageFileID:self.metadataDetail.fileID fileName:self.metadataDetail.fileNameView] toPath:fileNamePath error:nil];
    
    NSURL *url = [NSURL fileURLWithPath:fileNamePath];

    WKPreferences *wkPreferences = [[WKPreferences alloc] init];
    wkPreferences.javaScriptEnabled = true;
    WKWebViewConfiguration *wkConfig = [[WKWebViewConfiguration alloc] init];
    wkConfig.preferences = wkPreferences;
    
    self.webView = [[WKWebView alloc] initWithFrame:(CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT - safeAreaBottom)) configuration:wkConfig];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    [self.webView setBackgroundColor:[NCBrandColor sharedInstance].backgroundView];
    [self.webView setOpaque:NO];
    
    if ( [_fileNameExtension isEqualToString:@"CSS"] || [_fileNameExtension isEqualToString:@"PY"] || [_fileNameExtension isEqualToString:@"XML"] || [_fileNameExtension isEqualToString:@"JS"] ) {
        
        NSString *dataFile = [[NSString alloc] initWithData:[NSData dataWithContentsOfURL:url] encoding:NSASCIIStringEncoding];
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            [self.webView  loadHTMLString:[NSString stringWithFormat:@"<div style='font-size:%@;font-family:%@;'><pre>%@",@"40",@"Sans-Serif",dataFile] baseURL:nil];
        }else{
            [self.webView  loadHTMLString:[NSString stringWithFormat:@"<div style='font-size:%@;font-family:%@;'><pre>%@",@"20",@"Sans-Serif",dataFile] baseURL:nil];
        }
        
    } else if ([CCUtility isDocumentModifiableExtension:_fileNameExtension]) {
        
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:nil delegateQueue:nil];
        
        NSMutableURLRequest *headRequest = [NSMutableURLRequest requestWithURL:url];
        [headRequest setHTTPMethod:@"HEAD"];
        
        NSURLSessionDataTask *task = [session dataTaskWithRequest:headRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *encodingName = [[NCUchardet sharedNUCharDet] encodingStringDetectWithData:data];
                [self.webView loadData:[NSData dataWithContentsOfURL: url] MIMEType:response.MIMEType characterEncodingName:encodingName baseURL:url];
            });
        }];
        
        [task resume];
        
    } else {
        
        [self.webView loadRequest:[NSMutableURLRequest requestWithURL:url]];
    }
    
    [self.view addSubview:self.webView];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View Media =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewMedia
{
    NSURL *videoURL;
    CGFloat safeAreaBottom = 0;
    
    if (@available(iOS 11, *)) {
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
    
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadataDetail.directoryID];
    if (!serverUrl)
        return;
    
    if ([CCUtility fileProviderStorageExists:self.metadataDetail.fileID fileName:self.metadataDetail.fileNameView] == NO) {
        
        videoURL = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageFileID:self.metadataDetail.fileID fileName:self.metadataDetail.fileNameView]];
        
        
    } else {
        
        NSURL *url = [NSURL URLWithString:[[NSString stringWithFormat:@"%@/%@", serverUrl, _metadataDetail.fileName] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
        videoURL = [KTVHTTPCache proxyURLWithOriginalURL:url];

        NSMutableDictionary *header = [NSMutableDictionary new];
        NSData *authData = [[NSString stringWithFormat:@"%@:%@", appDelegate.activeUser, appDelegate.activePassword] dataUsingEncoding:NSUTF8StringEncoding];
        NSString *authValue = [NSString stringWithFormat: @"Basic %@",[authData base64EncodedStringWithOptions:0]];
        [header setValue:authValue forKey:@"Authorization"];
        [header setValue:[CCUtility getUserAgent] forKey:@"User-Agent"];        
        [KTVHTTPCache downloadSetAdditionalHeaders:header];
    }
    
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithURL:videoURL];
    AVPlayer *player = [AVPlayer playerWithPlayerItem:playerItem];
    AVPlayerViewController *playesController = [AVPlayerViewController new];

    playesController.player = player;
    playesController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT - safeAreaBottom);
    [self addChildViewController:playesController];
    [self.view addSubview:playesController.view];
    
    [player play];
}

- (void)setupHTTPCache
{
    [KTVHTTPCache logSetConsoleLogEnable:YES];
    NSError * error;
    [KTVHTTPCache proxyStart:&error];
    if (error) {
        NSLog(@"Proxy Start Failure, %@", error);
    } else {
        NSLog(@"Proxy Start Success");
    }
    [KTVHTTPCache tokenSetURLFilter:^NSURL * (NSURL * URL) {
        
        NSLog(@"URL Filter reviced URL : %@", URL);
        return URL;
    }];
    [KTVHTTPCache downloadSetUnsupportContentTypeFilter:^BOOL(NSURL * URL, NSString * contentType) {
        NSLog(@"Unsupport Content-Type Filter reviced URL : %@, %@", URL, contentType);
        return NO;
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View Image =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewImageVideoAudio
{
    self.photoBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    _indexNowVisible = -1;
    _fileIDNowVisible = nil;
    
    [self.photos removeAllObjects];
    [_dataSourceDirectoryID removeAllObjects];
    
    // if not images, exit
    if ([self.dataSourceImagesVideos count] == 0)
        return;
    
    // test
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadataDetail.directoryID];
    if (!serverUrl)
        return;
    
    NSUInteger index = 0;
    for (tableMetadata *metadata in self.dataSourceImagesVideos) {
        
        // start from here ?
        if (self.metadataDetail.fileID && [metadata.fileID isEqualToString:self.metadataDetail.fileID])
            [self.photoBrowser setCurrentPhotoIndex:index];
        
        [self.photos addObject:[MWPhoto photoWithImage:nil]];
        
        // add directory
        [_dataSourceDirectoryID addObject:metadata.directoryID];
        index++;
    }
    
    // PhotoBrowser
    self.photoBrowser.displayActionButton = YES;
    self.photoBrowser.displayDeleteButton = YES;
    if ([CCUtility isFolderEncrypted:serverUrl account:appDelegate.activeAccount]) // E2EE
        self.photoBrowser.displayShareButton = NO;
    else
        self.photoBrowser.displayShareButton = YES;
    self.photoBrowser.displayNavArrows = YES;
    self.photoBrowser.displaySelectionButtons = NO;
    self.photoBrowser.alwaysShowControls = NO;
    self.photoBrowser.zoomPhotosToFill = NO;
    self.photoBrowser.autoPlayOnAppear = NO;
    self.photoBrowser.delayToHideElements = 15;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        self.photoBrowser.enableSwipeToDismiss = NO;
    
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        
        [self addChildViewController:self.photoBrowser];
        [self.view addSubview:self.photoBrowser.view];
        [self.photoBrowser didMoveToParentViewController:self];
        
    } else {
        
        [self.navigationController pushViewController:self.photoBrowser animated:NO];
    }
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser
{
    return [self.dataSourceImagesVideos count];
}

- (NSString *)photoBrowser:(MWPhotoBrowser *)photoBrowser titleForPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    
    NSString *titleDir = metadata.fileNameView;
    self.title = titleDir;
    
    return titleDir;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    
    _indexNowVisible = index;
    _fileIDNowVisible = metadata.fileID;
    
    photoBrowser.toolbar.hidden = NO;
    
    // Download image ?
    if (metadata) {
        
        tableMetadata *metadataDB = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", metadata.fileID]];

        if ([CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView] == NO && metadataDB.status == k_metadataStatusNormal) {
            
            [self downloadPhotoBrowser:metadata];
        }
    }
    
    // Title
    if (metadata)
        self.title = metadata.fileNameView;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index
{
    UIImage *image;
//    UIImage *loadingGIF = [UIImage animatedImageWithAnimatedGIFURL:[[NSBundle mainBundle] URLForResource:@"loading" withExtension:@"gif"]];

    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    
    if (index < self.photos.count) {
        
        if (metadata.fileID) {
            
            UIImage *imagePreview = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]];
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image]) {
                
                if (!imagePreview) imagePreview = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"file_photo"] multiplier:3 color:[[NCBrandColor sharedInstance] icon]];
                
                NSString *fileImage = [CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileName:metadata.fileNameView];
                NSString *ext = [CCUtility getExtension:metadata.fileNameView];
                
                if ([ext isEqualToString:@"GIF"]) image = [UIImage animatedImageWithAnimatedGIFURL:[NSURL fileURLWithPath:fileImage]];
                else image = [UIImage imageWithContentsOfFile:fileImage];
                
                if (image) {
                    
                    MWPhoto *photo = [MWPhoto photoWithImage:image];
                    
                    // Location ??
                    [self setLocationCaptionPhoto:photo fileID:metadata.fileID];
                    
                    [self.photos replaceObjectAtIndex:index withObject:photo];
                    
                } else {
                    
                    if (metadata.status == k_metadataStatusDownloadError) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:imagePreview]];
                    }
                }
            }
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video]) {
                
                if (!imagePreview) imagePreview = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"file_photo"] multiplier:3 color:[[NCBrandColor sharedInstance] icon]];
                
                if ([CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView]) {
                    
                    NSURL *url = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileName:metadata.fileNameView]];
                    
                    MWPhoto *video = [MWPhoto photoWithImage:[CCGraphics thumbnailImageForVideo:url atTime:1.0]];
                    video.videoURL = url;
                    
                    [self.photos replaceObjectAtIndex:index withObject:video];
                    
                } else {
                    
                    if (metadata.status == k_metadataStatusDownloadError) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:imagePreview]];
                    }
                }
            }
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_audio]) {
                
                if (!imagePreview) imagePreview = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"file_audio"] multiplier:3 color:[[NCBrandColor sharedInstance] icon]];
                
                if ([CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView]) {
                    
                    MWPhoto *audio;
                    UIImage *audioImage;
                    
                    NSURL *url = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileName:metadata.fileNameView]];
                    
                    if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]]) {
                        audioImage = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]];
                    } else {
                        audioImage = [UIImage imageNamed:@"notaMusic"]; //[CCGraphics scaleImage:[UIImage imageNamed:@"notaMusic"] toSize:CGSizeMake(200, 200) isAspectRation:YES];
                    }
                    
                    audio = [MWPhoto photoWithImage:audioImage];
                    audio.videoURL = url;
                    [self.photos replaceObjectAtIndex:index withObject:audio];
                    
                } else {
                    
                    if (metadata.status == k_metadataStatusDownloadError) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:imagePreview]];
                    }
                }
            }
        }
        
        // energy saving memory
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            int iPrev = (int)index - 2;
            if (iPrev >= 0) {
                if ([self.photos objectAtIndex:iPrev] != nil)
                    [self.photos replaceObjectAtIndex:iPrev withObject:[MWPhoto photoWithImage:nil]];
            }
        
            int iNext = (int)index + 2;
            if (iNext < _photos.count) {
                if ([self.photos objectAtIndex:iNext] != nil)
                    [self.photos replaceObjectAtIndex:iNext withObject:[MWPhoto photoWithImage:nil]];
            }
        });
        
        return [self.photos objectAtIndex:index];
    }
    
    return nil;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser actionButtonPressedForPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    if (metadata == nil) return;

    self.docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageFileID:metadata.fileID fileName:metadata.fileNameView]]];
    
    self.docController.delegate = self;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [self.docController presentOptionsMenuFromRect:photoBrowser.view.frame inView:photoBrowser.view animated:YES];
    
    [self.docController presentOptionsMenuFromBarButtonItem:photoBrowser.actionButton animated:YES];
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser shareButtonPressedForPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    
    [appDelegate.activeMain openWindowShare:metadata];
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser deleteButtonPressedForPhotoAtIndex:(NSUInteger)index deleteButton:(UIBarButtonItem *)deleteButton
{
    tableMetadata *metadata = [self.dataSourceImagesVideos objectAtIndex:index];
    if (metadata == nil || [CCUtility fileProviderStorageExists:metadata.fileID fileName:metadata.fileNameView] == NO) {
        
        [appDelegate messageNotification:@"_info_" description:@"_file_not_found_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
        
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil)
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           [self deleteFile:metadata];
                                                       }]];

    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil)
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                       }]];
    
    alertController.popoverPresentationController.barButtonItem = deleteButton;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self.parentViewController presentViewController:alertController animated:YES completion:NULL];
}

- (void)photoBrowserDidFinishPresentation:(MWPhotoBrowser *)photoBrowser
{
    [self removeAllView];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)triggerProgressTask:(NSNotification *)notification
{
    /*
    NSDictionary *dict = notification.userInfo;
    NSString *fileID = [dict valueForKey:@"fileID"];
    //NSString *serverUrl = [dict valueForKey:@"serverUrl"];
    //long status = [[dict valueForKey:@"status"] longValue];
    float progress = [[dict valueForKey:@"progress"] floatValue];
    //long long totalBytes = [[dict valueForKey:@"totalBytes"] longLongValue];
    //long long totalBytesExpected = [[dict valueForKey:@"totalBytesExpected"] longLongValue];
    
    if ([fileID isEqualToString:_fileIDNowVisible])
        [_hud progress:progress];
    */
}

- (void)downloadPhotoBrowserSuccessFailure:(tableMetadata *)metadata selector:(NSString *)selector errorCode:(NSInteger)errorCode
{
    // if a message for a directory of these
    if (![metadata.fileID isEqualToString:_fileIDNowVisible])
        return;
    
    if (errorCode == 0) {
        // verifico se esiste l'icona e se la posso creare
        if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconFileID:metadata.fileID fileNameView:metadata.fileNameView]] == NO)
            [CCGraphics createNewImageFrom:metadata.fileNameView fileID:metadata.fileID extension:[metadata.fileNameView pathExtension] size:@"m" imageForUpload:NO typeFile:metadata.typeFile writeImage:YES optimizedFileName:[CCUtility getOptimizedPhoto]];
        
        [self.photoBrowser reloadData];

    } else {
        [appDelegate messageNotification:@"_download_selected_files_" description:@"_error_download_photobrowser_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
        
        [self backNavigationController];
    }
}

- (void)downloadPhotoBrowser:(tableMetadata *)metadata
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    
    if (serverUrl) {
        
        metadata.session = k_download_session;
        metadata.sessionError = @"";
        metadata.sessionSelector = selectorLoadViewImage;
        metadata.status = k_metadataStatusWaitDownload;
        
        // Add Metadata for Download
        (void)[[NCManageDatabase sharedInstance] addMetadata:metadata];
        [appDelegate performSelectorOnMainThread:@selector(loadAutoDownloadUpload) withObject:nil waitUntilDone:YES];
    }
}

- (void)insertGeocoderLocation:(NSNotification *)notification
{
    if (notification.userInfo.count == 0)
        return;
    
    NSString *fileID = [[notification.userInfo allKeys] objectAtIndex:0];
    //NSDate *date = [[notification.userInfo allValues] objectAtIndex:0];
 
    // test [Chrash V 1.14,15]
    if (_indexNowVisible >= [self.photos count])
        return;
    
    if ([fileID isEqualToString:_fileIDNowVisible]) {
            
        MWPhoto *photo = [self.photos objectAtIndex:_indexNowVisible];
            
        [self setLocationCaptionPhoto:photo fileID:fileID];
        
        [self.photoBrowser reloadData];
    }
}

- (void)setLocationCaptionPhoto:(MWPhoto *)photo fileID:(NSString *)fileID
{
    tableLocalFile *localFile;

    // read Geocoder
    localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
    
    if ([localFile.exifLatitude doubleValue] != 0 || [localFile.exifLongitude doubleValue] != 0) {
        
        // Fix BUG Geo latitude & longitude
        if ([localFile.exifLatitude doubleValue] == 9999 || [localFile.exifLongitude doubleValue] == 9999) {
            
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
            if (metadata) {
                [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata];
            }
        }
        
        [[CCExifGeo sharedInstance] setGeocoderEtag:fileID exifDate:localFile.exifDate latitude:localFile.exifLatitude longitude:localFile.exifLongitude];
        
        localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"fileID == %@", fileID]];
        
        if ([localFile.exifLatitude floatValue] != 0 || [localFile.exifLongitude floatValue] != 0) {
                        
            NSString *location = [[NCManageDatabase sharedInstance] getLocationFromGeoLatitude:localFile.exifLatitude longitude:localFile.exifLongitude];
            
            if ([localFile.exifDate isEqualToDate:[NSDate distantPast]] == NO && location) {
                
                NSString *localizedDateTime = [NSDateFormatter localizedStringFromDate:localFile.exifDate dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterMediumStyle];
                
                photo.caption = [NSString stringWithFormat:NSLocalizedString(@"%@\n%@", nil), localizedDateTime, location];
            }
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  View PDF =====
#pragma --------------------------------------------------------------------------------------------

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [alertView dismissWithClickedButtonIndex:buttonIndex animated:YES];
    
    [[alertView textFieldAtIndex:0] resignFirstResponder];
    
    if (alertView.tag == alertRequestPasswordPDF) [self performSelector:@selector(viewPDF:) withObject:[alertView textFieldAtIndex:0].text afterDelay:0.3];
}

- (void)viewPDF:(NSString *)password
{
    NSString *fileNamePath = [CCUtility getDirectoryProviderStorageFileID:self.metadataDetail.fileID fileName:self.metadataDetail.fileNameView];
    
    if ([CCUtility fileProviderStorageExists:self.metadataDetail.fileID fileName:self.metadataDetail.fileNameView] == NO) {
        
        // read file error
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_read_file_error_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL((CFURLRef)[NSURL fileURLWithPath:fileNamePath]);
    
    if (pdf) {
        
        // Encrypted
        if (CGPDFDocumentIsEncrypted(pdf) == YES) {
            
            // Try a blank password first, per Apple's Quartz PDF example
            if (CGPDFDocumentUnlockWithPassword(pdf, "") == YES) {
                
                // blank password
                [self readerPDF:fileNamePath password:@""];
                
            } else {
                
                if ([password length] == 0) {
                    
                    // password request
                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_insert_password_pfd_",nil) message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                    [alertView setAlertViewStyle:UIAlertViewStylePlainTextInput];
                    alertView.tag = alertRequestPasswordPDF;
                    [alertView show];
                    
                } else {
                    
                    const char *key = [password UTF8String];
                    
                    // failure
                    if (CGPDFDocumentUnlockWithPassword(pdf, key) == NO) {
                        
                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_password_pdf_error_", nil) preferredStyle:UIAlertControllerStyleAlert];
                        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                        
                        [alertController addAction:okAction];
                        [self presentViewController:alertController animated:YES completion:nil];
                        
                    } else {
                        
                        // pdf with password
                        [self readerPDF:fileNamePath password:password];
                    }
                }
            }
            
        } else{
            
            // No password
            [self readerPDF:fileNamePath password:@""];
        }
        
    } else {
        
        // read file error
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_read_file_error_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)readerPDF:(NSString *)fileName password:(NSString *)password
{
    ReaderDocument *documentPDF = [ReaderDocument withDocumentFilePath:fileName password:password];
    CGFloat safeAreaBottom = 0;
    
    if (@available(iOS 11, *)) {
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
    
    if (documentPDF != nil) {
        
        self.readerPDFViewController = [[ReaderViewController alloc] initWithReaderDocument:documentPDF];
        self.readerPDFViewController.delegate = self;
        self.readerPDFViewController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT - safeAreaBottom);
        [self.readerPDFViewController updateContentViews];

        [self addChildViewController:self.readerPDFViewController];
        [self.view addSubview:self.readerPDFViewController.view];
        [self.readerPDFViewController didMoveToParentViewController:self];
        
    } else {

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_read_file_error_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)handleSingleTapReader
{
    UILayoutGuide *layoutGuide;
    CGFloat safeAreaTop = 0;
    CGFloat safeAreaBottom = 0;
    
    if (@available(iOS 11, *)) {
        layoutGuide = [UIApplication sharedApplication].delegate.window.safeAreaLayoutGuide;
        safeAreaTop = [UIApplication sharedApplication].delegate.window.safeAreaInsets.top;
        safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
    }
    
    self.navigationController.navigationBarHidden = !self.navigationController.navigationBarHidden;
    _toolbar.hidden = !_toolbar.isHidden;
    
    if (_toolbar.isHidden) {
        self.readerPDFViewController.view.frame = CGRectMake(0, safeAreaTop, self.view.bounds.size.width, self.view.bounds.size.height - safeAreaTop - safeAreaBottom);
    } else {
        self.readerPDFViewController.view.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT - safeAreaBottom);
    }
    [self.readerPDFViewController updateContentViews];
}

- (void)handleSwipeUpDown
{
    // REMOVE IT'S UNUSABLE
    /*
    self.navigationController.navigationBarHidden = false;  // iOS App is unusable after swipe up or down with PDF in fullscreen #526

    [self removeAllView];
    [self.navigationController popViewControllerAnimated:YES];
    */
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFile:(tableMetadata *)metadata
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
    tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND e2eEncrypted == 1 AND serverUrl == %@", appDelegate.activeAccount, serverUrl]];
    
    [[NCMainCommon sharedInstance ] deleteFileWithMetadatas:[[NSArray alloc] initWithObjects:metadata, nil] e2ee:tableDirectory.e2eEncrypted serverUrl:serverUrl folderFileID:tableDirectory.fileID completion:^(NSInteger errorCode, NSString *message) {
        
        if (errorCode == 0) {
            
            // reload Main
            [appDelegate.activeMain reloadDatasource];
            
            // If removed document (web) or PDF close
            if (_webView || _readerPDFViewController)
                [self removeAllView];
            
            // if a message for a directory of these
            if (![_dataSourceDirectoryID containsObject:metadata.directoryID])
                return;
            
            // if we are not in browserPhoto and it's removed photo/video in preview then "< Back"
            if (!self.photoBrowser && [self.metadataDetail.fileID isEqualToString:metadata.fileID]) {
                
                NSArray *viewsToRemove = [self.view subviews];
                for (id element in viewsToRemove) {
                    
                    if ([element isMemberOfClass:[UIView class]] || [element isMemberOfClass:[UIToolbar class]])
                        [element removeFromSuperview];
                }
                
                self.title = @"";
                
                [self.navigationController popViewControllerAnimated:YES];
                
            } else {
                
                // only photoBrowser if exists
                for (NSUInteger index=0; index < [self.dataSourceImagesVideos count] && _photoBrowser; index++ ) {
                    
                    tableMetadata *metadataTemp = [self.dataSourceImagesVideos objectAtIndex:index];
                    
                    if ([metadata isInvalidated] || [metadataTemp.fileID isEqualToString:metadata.fileID]) {
                        
                        [self.dataSourceImagesVideos removeObjectAtIndex:index];
                        [self.photos removeObjectAtIndex:index];
                        [self.photoBrowser reloadData];
                        
                        // Title
                        if ([self.dataSourceImagesVideos count] == 0) {
                            
                            self.title = @"";
                            [self.navigationController popViewControllerAnimated:YES];
                        }
                    }
                }
            }
        } else {
            NSLog(@"[LOG] DeleteFileOrFolder failure error %d, %@", (int)errorCode, message);
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== ButtonPressed =====
#pragma --------------------------------------------------------------------------------------------

- (void)modifyTxtButtonPressed:(UIBarButtonItem *)sender
{
    UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"NCText" bundle:nil] instantiateViewControllerWithIdentifier:@"NCText"];
    
    NCText *viewController = (NCText *)navigationController.topViewController;
    
    viewController.metadata = self.metadataDetail;
    
    navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
    navigationController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)actionButtonPressed:(UIBarButtonItem *)sender
{
    if ([self.metadataDetail.fileNameView length] == 0) return;
    
    NSString *filePath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), self.metadataDetail.fileNameView];

    self.docController = [UIDocumentInteractionController interactionControllerWithURL:[NSURL fileURLWithPath:filePath]];

    self.docController.delegate = self;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [self.docController presentOptionsMenuFromRect:self.view.frame inView:self.view animated:YES];
    
    [self.docController presentOptionsMenuFromBarButtonItem:sender animated:YES];
}

- (void)shareButtonPressed:(UIBarButtonItem *)sender
{
    [appDelegate.activeMain openWindowShare:self.metadataDetail];
}

- (void)deleteButtonPressed:(UIBarButtonItem *)sender
{
    if ([self.metadataDetail.fileNameView length] == 0) return;
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil)
                                                         style:UIAlertActionStyleDestructive
                                                       handler:^(UIAlertAction *action) {
                                                           [self deleteFile:self.metadataDetail];
                                                       }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil)
                                                         style:UIAlertActionStyleCancel
                                                       handler:^(UIAlertAction *action) {
                                                           [alertController dismissViewControllerAnimated:YES completion:nil];
                                                       }]];
    
    alertController.popoverPresentationController.barButtonItem = _buttonDelete;
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];

    [self presentViewController:alertController animated:YES completion:NULL];
}

@end

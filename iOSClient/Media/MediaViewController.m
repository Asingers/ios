//
//  MediaViewController.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/14.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "AppDelegate.h"
#import "MediaViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <KTVHTTPCache/KTVHTTPCache.h>
#import "NCBridgeSwift.h"

@interface MediaViewController ()
{
    AppDelegate *appDelegate;
}

@property (nonatomic, strong) tableMetadata *metadata;
@property (nonatomic, strong) NSString * URLProxyString;

@end

@implementation MediaViewController

- (instancetype)initWithURLProxyString:(NSString *)URLProxyString metadata:(tableMetadata *)metadata
{
    if (self = [super init])
    {
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        self.URLProxyString = URLProxyString;
        self.metadata = metadata;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.player = [AVPlayer playerWithURL:[NSURL URLWithString:self.URLProxyString]];
    [self.player play];
}

- (void)dealloc
{
    NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:self.metadata.directoryID];
    NSString *urlString = [[NSString stringWithFormat:@"%@/%@", serverUrl, self.metadata.fileName] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];

    NSString *path = [KTVHTTPCache cacheCompleteFilePathIfExistedWithURLString:urlString];
    
    [self.player.currentItem.asset cancelLoading];
    [self.player.currentItem cancelPendingSeeks];
    [self.player cancelPendingPrerolls];
}

@end

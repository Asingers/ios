//
//  MediaViewController.h
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/14.
//  Copyright © 2017年 Single. All rights reserved.
//

#import <AVKit/AVKit.h>

@class tableMetadata;

@interface MediaViewController : AVPlayerViewController

- (instancetype)initWithURLProxyString:(NSString *)URLProxyString metadata:(tableMetadata *)metadata;

@end

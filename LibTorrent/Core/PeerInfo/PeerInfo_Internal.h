//
//  PeerInfo_Internal.h
//  LibTorrent
//

#import "PeerInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface PeerInfo ()
@property (readwrite, strong, nonatomic) NSString *ip;
@property (readwrite, nonatomic) BOOL isSeeder;
@property (readwrite, strong, nonatomic) NSString *client;
@property (readwrite, nonatomic) double progress;
@property (readwrite, nonatomic) int64_t totalDownload;
@property (readwrite, nonatomic) int64_t totalUpload;
@property (readwrite, nonatomic) int64_t downloadSpeed;
@property (readwrite, nonatomic) int64_t uploadSpeed;
@property (readwrite, strong, nonatomic) NSArray<NSString *> *connectionFlags;
@end

NS_ASSUME_NONNULL_END

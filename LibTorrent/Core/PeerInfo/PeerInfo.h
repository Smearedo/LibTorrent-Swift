//
//  PeerInfo.h
//  LibTorrent
//
//  Peer detail information matching hayase torrent engine peerInfo().
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(PeerInfo)
@interface PeerInfo : NSObject

/// Peer IP address and port (e.g. "192.168.1.1:6881")
@property (readonly, strong, nonatomic) NSString *ip;

/// Whether peer is a seeder
@property (readonly, nonatomic) BOOL isSeeder;

/// Peer client name and version (e.g. "qBittorrent 4.5.0")
@property (readonly, strong, nonatomic) NSString *client;

/// Peer's progress of the torrent (0.0 - 1.0)
@property (readonly, nonatomic) double progress;

/// Total bytes downloaded from this peer
@property (readonly, nonatomic) int64_t totalDownload;

/// Total bytes uploaded to this peer
@property (readonly, nonatomic) int64_t totalUpload;

/// Current download speed from this peer (bytes/s)
@property (readonly, nonatomic) int64_t downloadSpeed;

/// Current upload speed to this peer (bytes/s)
@property (readonly, nonatomic) int64_t uploadSpeed;

/// Connection type flags: "incoming", "outgoing", "utp", "encrypted"
@property (readonly, strong, nonatomic) NSArray<NSString *> *connectionFlags;

@end

NS_ASSUME_NONNULL_END

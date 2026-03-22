//
//  NSObject+SessionSettings.m
//  TorrentKit
//
//  Created by Даниил Виноградов on 14.05.2022.
//

#import "SessionSettings_Internal.h"

#import "libtorrent/alert.hpp"

lt::settings_pack::proxy_type_t proxyTypeConverter(SessionSettings *pack) {
    switch (pack.proxyType) {
        case SessionSettingsProxyTypeNone:
            return lt::settings_pack::proxy_type_t::none;
        case SessionSettingsProxyTypeSocks4:
            return lt::settings_pack::proxy_type_t::socks4;
        case SessionSettingsProxyTypeSocks5:
            return pack.proxyAuthRequired ?
                lt::settings_pack::proxy_type_t::socks5_pw :
                lt::settings_pack::proxy_type_t::socks5;
        case SessionSettingsProxyTypeHttp:
            return pack.proxyAuthRequired ?
                lt::settings_pack::proxy_type_t::http_pw :
                lt::settings_pack::proxy_type_t::http;
        case SessionSettingsProxyTypeI2p_proxy:
            return lt::settings_pack::proxy_type_t::i2p_proxy;
    }
}

@implementation SessionSettings

- (instancetype)init {
    self = [super init];

    if (self) {
        _preallocateStorage = false;
        _connectionLimit = 200;
    }

    return self;
}

- (lt::settings_pack)settingsPack {
    lt::settings_pack settings;

    // Must have
    settings.set_int(lt::settings_pack::alert_mask, lt::alert_category_t::all());
    settings.set_str(lt::settings_pack::user_agent, [_agentName UTF8String]);

    // Torrent limitations
    settings.set_int(lt::settings_pack::active_limit, (int)_maxActiveTorrents);
    settings.set_int(lt::settings_pack::active_downloads, (int)_maxDownloadingTorrents);
    settings.set_int(lt::settings_pack::active_seeds, (int)_maxUploadingTorrents);

    // Speed limitations
    settings.set_int(lt::settings_pack::download_rate_limit, (int)_maxDownloadSpeed);
    settings.set_int(lt::settings_pack::upload_rate_limit, (int)_maxUploadSpeed);

    // Networking protocols
    settings.set_bool(lt::settings_pack::enable_dht, _isDhtEnabled);
    settings.set_bool(lt::settings_pack::enable_lsd, _isLsdEnabled);
    settings.set_bool(lt::settings_pack::enable_incoming_utp, _isUtpEnabled);
    settings.set_bool(lt::settings_pack::enable_outgoing_utp, _isUtpEnabled);
    settings.set_bool(lt::settings_pack::enable_upnp, _isUpnpEnabled);
    settings.set_bool(lt::settings_pack::enable_natpmp, _isNatEnabled);

    // Encryption policy
    settings.set_bool(lt::settings_pack::validate_https_trackers, _validateHttpsTrackers);
    switch (_encryptionPolicy) {
        case SessionSettingsEncryptionPolicyEnabled:
            settings.set_int(lt::settings_pack::out_enc_policy, lt::settings_pack::pe_enabled);
            settings.set_int(lt::settings_pack::in_enc_policy, lt::settings_pack::pe_enabled);
            break;
        case SessionSettingsEncryptionPolicyForced:
            settings.set_int(lt::settings_pack::out_enc_policy, lt::settings_pack::pe_forced);
            settings.set_int(lt::settings_pack::in_enc_policy, lt::settings_pack::pe_forced);
            break;
        case SessionSettingsEncryptionPolicyDisabled:
            settings.set_int(lt::settings_pack::out_enc_policy, lt::settings_pack::pe_disabled);
            settings.set_int(lt::settings_pack::in_enc_policy, lt::settings_pack::pe_disabled);
            break;
    }

    // Ports
    settings.set_int(lt::settings_pack::max_retry_port_bind, (int)_portBindRetries);

    // Interfaces
    settings.set_str(lt::settings_pack::outgoing_interfaces, [_outgoingInterfaces UTF8String]);
    settings.set_str(lt::settings_pack::listen_interfaces, [_listenInterfaces UTF8String]);

    // Proxy
    settings.set_int(lt::settings_pack::proxy_type, proxyTypeConverter(self));
    if (_proxyType != SessionSettingsProxyTypeNone) {
        settings.set_int(lt::settings_pack::proxy_port, (int)_proxyHostPort);
        settings.set_str(lt::settings_pack::proxy_hostname, [_proxyHostname UTF8String]);
        if (_proxyAuthRequired) {
            settings.set_str(lt::settings_pack::proxy_username, [_proxyUsername UTF8String]);
            settings.set_str(lt::settings_pack::proxy_password, [_proxyPassword UTF8String]);
        }
        settings.set_bool(lt::settings_pack::proxy_peer_connections, _proxyPeerConnections);
        settings.set_bool(lt::settings_pack::proxy_tracker_connections, true);
        settings.set_bool(lt::settings_pack::proxy_hostnames, true);
    }

    // Connection limit
    settings.set_int(lt::settings_pack::connections_limit, (int)_connectionLimit);

    // Streaming mode optimizations
    if (_isStreamingMode) {
        // Faster piece picking for sequential playback
        settings.set_int(lt::settings_pack::whole_pieces_threshold, 2);

        // Faster peer timeouts for responsive streaming
        settings.set_int(lt::settings_pack::request_timeout, 10);
        settings.set_int(lt::settings_pack::peer_timeout, 20);
        settings.set_int(lt::settings_pack::peer_connect_timeout, 5);

        // Larger buffer for smoother streaming (bytes)
        const int sendBufferWatermark = 1 * 1024 * 1024;     // 1 MB
        const int sendBufferLowWatermark = 256 * 1024;        // 256 KB
        settings.set_int(lt::settings_pack::send_buffer_watermark, sendBufferWatermark);
        settings.set_int(lt::settings_pack::send_buffer_low_watermark, sendBufferLowWatermark);

        // Allow more connections per torrent for streaming
        settings.set_int(lt::settings_pack::max_out_request_queue, 500);
        const int maxPeerRecvBuffer = 2 * 1024 * 1024;       // 2 MB
        settings.set_int(lt::settings_pack::max_peer_recv_buffer_size, maxPeerRecvBuffer);

        // Prioritize partial pieces for faster initial data
        settings.set_bool(lt::settings_pack::prioritize_partial_pieces, true);

        // More aggressive unchoke for faster data from more peers
        settings.set_int(lt::settings_pack::unchoke_interval, 5);       // default is 15
        settings.set_int(lt::settings_pack::optimistic_unchoke_interval, 10); // default is 30

        // Allow more outstanding requests for faster downloads
        settings.set_int(lt::settings_pack::max_queued_disk_bytes, 8 * 1024 * 1024); // 8 MB disk write queue

        // Faster initial peer connections
        settings.set_int(lt::settings_pack::connection_speed, 200);  // default is 30, connect to more peers quickly

        // Allow multiple connections from the same IP address.
        // Critical for low-seed swarms where seeds may share IPs behind NAT/VPN.
        settings.set_bool(lt::settings_pack::allow_multiple_connections_per_ip, true);

        // Strict end-game mode: request remaining blocks from all peers simultaneously,
        // cancelling duplicates as soon as one peer delivers. Faster piece completion.
        settings.set_bool(lt::settings_pack::strict_end_game_mode, true);

        // Prefer TCP over uTP for more reliable streaming throughput
        settings.set_int(lt::settings_pack::mixed_mode_algorithm, lt::settings_pack::prefer_tcp);

        // Skip the random initial piece selection phase. Use deadline/rarest-first
        // picker immediately, which is essential for streaming piece prioritization.
        settings.set_int(lt::settings_pack::initial_picker_threshold, 0);

        // Connect to many peers immediately when a torrent starts (default ~10).
        // With only 10-15 seeds, we need to reach all of them as fast as possible.
        settings.set_int(lt::settings_pack::torrent_connect_boost, 100);

        // Disable rate-limiting of outgoing connection attempts so we connect to
        // all available peers at once rather than trickling connections over time.
        settings.set_bool(lt::settings_pack::smooth_connects, false);

        // Retry failed peers more quickly (default 60s)
        settings.set_int(lt::settings_pack::min_reconnect_time, 5);

        // Don't give up on peers too quickly (default 3). In low-seed swarms
        // every peer is valuable and worth retrying.
        settings.set_int(lt::settings_pack::max_failcount, 7);

        // Allow more pending requests per peer for better pipeline utilization
        settings.set_int(lt::settings_pack::max_allowed_in_request_queue, 1000);

        // Suggest pieces already in disk cache to peers, reducing redundant disk reads
        settings.set_int(lt::settings_pack::suggest_mode, lt::settings_pack::suggest_read_cache);

        // Keep all peer connections open even if they appear redundant.
        // In low-seed swarms every connection is valuable.
        settings.set_bool(lt::settings_pack::close_redundant_connections, false);

        // Allow connecting to privileged ports (some seeds may use them)
        settings.set_bool(lt::settings_pack::no_connect_privileged_ports, false);

        // Use fastest-upload choking algorithm for seeds so they send to us at
        // maximum rate rather than round-robin across all leechers.
        settings.set_int(lt::settings_pack::seed_choking_algorithm, lt::settings_pack::fastest_upload);
    }

    return settings;
}

@end

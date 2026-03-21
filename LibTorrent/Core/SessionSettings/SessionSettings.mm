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
    }

    return settings;
}

@end

PROGRAM PLC_PRG
VAR
    (* Тестовый массив данных: 35000 WORD *)
    DataArray : ARRAY[0..34999] OF WORD;

    (* Экземпляр FB широковещательной UDP-передачи *)
    UdpBroadcast : FB_UdpWordBroadcast;

    (* Индекс для инициализации массива *)
    i : UDINT;

    (* Триггер для однократного заполнения массива *)
    initDone : BOOL;
END_VAR

// === IMPLEMENTATION ===

IF NOT initDone THEN
    FOR i := 0 TO 34999 DO
        DataArray[i] := UDINT_TO_WORD(i MOD 65536);
    END_FOR
    initDone := TRUE;
END_IF

// ============================================================
//  Запуск UDP-широковещательной рассылки
//  Массив 35000 WORD передается максимально крупными UDP-пакетами.
// ============================================================
UdpBroadcast(
    Enable      := udp_enable,
    Signature   := udp_signature,
    LocalIp     := udp_local_ip,
    BroadcastIp := udp_broadcast_ip,
    LocalPort   := udp_local_port,
    RemotePort  := udp_remote_port,
    MaxPacketBytesLimit := udp_max_packet_bytes_limit,
    Period      := udp_period,
    StartSend   := udp_start_send,
    DataStartIndex := udp_data_start_index,
    DataEndIndex   := udp_data_end_index,
    Data := DataArray,

    SequenceId    => udp_sequence_id,
    PacketIndex   => udp_packet_index,
    PacketCount   => udp_packet_count,
    SourceDataWords => udp_source_data_words,
    EffectiveDataStartIndex => udp_effective_data_start_index,
    EffectiveDataEndIndex   => udp_effective_data_end_index,
    EffectiveDataWords      => udp_effective_data_words,
    SendDoneCount => udp_send_count,
    Error         => udp_error,
    ErrorId       => udp_error_id,
    DiagState     => udp_diag_state,
    DiagErrorSource => udp_diag_error_source,
    DiagPeerEnable => udp_diag_peer_enable,
    DiagPeerActive => udp_diag_peer_active,
    DiagPeerError => udp_diag_peer_error,
    DiagPeerErrorId => udp_diag_peer_error_id,
    DiagSendExecute => udp_diag_send_execute,
    DiagSendBusy    => udp_diag_send_busy,
    DiagSendError   => udp_diag_send_error,
    DiagSendErrorId => udp_diag_send_error_id,
    DiagSendCount   => udp_diag_send_count,
    DiagSendLength  => udp_diag_send_length,
    DiagWordsPerPacketLimit => udp_diag_words_per_packet_limit,
    DiagEffectivePacketBytesLimit => udp_diag_effective_packet_bytes_limit,
    DiagLocalAddrInitError => udp_diag_local_init_error,
    DiagRemoteAddrInitError => udp_diag_remote_init_error
);

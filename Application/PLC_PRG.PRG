PROGRAM PLC_PRG
VAR
    (* Тестовый массив данных: 35000 WORD *)
    DataArray : ARRAY[0..34999] OF WORD;

    (* Массив экземпляров FB широковещательной UDP-передачи *)
    UdpBroadcast : ARRAY[0..UDP_CHANNEL_COUNT - 1] OF FB_UdpWordBroadcast;

    (* Индексы циклов *)
    i : UDINT;
    ch : UINT;

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
//  Запуск массива FB UDP-широковещательной рассылки
//  Каждый канал использует свои настройки из udp_cfg[ch]
// ============================================================
FOR ch := 0 TO UDP_CHANNEL_COUNT - 1 DO
    UdpBroadcast[ch](
        Enable      := udp_common.enable_all AND udp_cfg[ch].enable,
        Signature   := udp_cfg[ch].signature,
        LocalIp     := udp_common.local_ip,
        BroadcastIp := udp_common.broadcast_ip,
        LocalPort   := udp_cfg[ch].local_port,
        RemotePort  := udp_cfg[ch].remote_port,
        MaxPacketBytesLimit := udp_cfg[ch].max_packet_bytes_limit,
        Period      := UDINT_TO_TIME(WORD_TO_UDINT(udp_cfg[ch].period_ms)),
        StartSend   := udp_cfg[ch].start_send,
        DataStartIndex := udp_cfg[ch].udp_data_start_index,
        DataEndIndex   := udp_cfg[ch].udp_data_end_index,
        Data := DataArray,

        Active        => udp_state[ch].active,
        Busy          => udp_state[ch].busy,
        Error         => udp_state[ch].error,
        ErrorId       => udp_state[ch].error_id,
        SequenceId    => udp_state[ch].sequence_id,
        PacketIndex   => udp_state[ch].packet_index,
        PacketCount   => udp_state[ch].packet_count,
        SourceDataWords => udp_state[ch].source_data_words,
        EffectiveDataStartIndex => udp_state[ch].effective_data_start_index,
        EffectiveDataEndIndex   => udp_state[ch].effective_data_end_index,
        EffectiveDataWords      => udp_state[ch].effective_data_words,
        SendDoneCount => udp_state[ch].send_count,
        LastWordIndex => udp_state[ch].last_word_index,
        LastWordCount => udp_state[ch].last_word_count,
        CycleDone     => udp_state[ch].cycle_done,

        DiagState     => udp_state[ch].diag_state,
        DiagErrorSource => udp_state[ch].diag_error_source,
        DiagPeerEnable => udp_state[ch].diag_peer_enable,
        DiagPeerActive => udp_state[ch].diag_peer_active,
        DiagPeerError => udp_state[ch].diag_peer_error,
        DiagPeerErrorId => udp_state[ch].diag_peer_error_id,
        DiagSendExecute => udp_state[ch].diag_send_execute,
        DiagSendBusy    => udp_state[ch].diag_send_busy,
        DiagSendError   => udp_state[ch].diag_send_error,
        DiagSendErrorId => udp_state[ch].diag_send_error_id,
        DiagSendCount   => udp_state[ch].diag_send_count,
        DiagSendLength  => udp_state[ch].diag_send_length,
        DiagWordsPerPacketLimit => udp_state[ch].diag_words_per_packet_limit,
        DiagEffectivePacketBytesLimit => udp_state[ch].diag_effective_packet_bytes_limit,
        DiagLocalAddrInitError => udp_state[ch].diag_local_init_error,
        DiagRemoteAddrInitError => udp_state[ch].diag_remote_init_error
    );
END_FOR

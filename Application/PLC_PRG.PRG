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
    cfgInitDone : BOOL;
    startSendPrev : ARRAY[0..UDP_CHANNEL_COUNT - 1] OF WORD;  (* Предыдущее значение start_send для детектора фронта *)
    startSendPulse : BOOL;                                     (* Односкановый импульс ручного запуска *)
    fbEnable : BOOL;                                           (* Итоговое разрешение FB на текущем канале *)
END_VAR

// === IMPLEMENTATION ===

IF NOT initDone THEN
    FOR i := 0 TO 34999 DO
        DataArray[i] := UDINT_TO_WORD(i MOD 65536);
    END_FOR
    initDone := TRUE;
END_IF

(* Однократная загрузка дефолтов из udp_cfg в карту регистров Modbus (%MW0...) *)
IF NOT cfgInitDone THEN
    FOR ch := 0 TO UDP_CHANNEL_COUNT - 1 DO
        udp_channel_modbus[ch].cfg.enable := udp_cfg[ch].enable;
        udp_channel_modbus[ch].cfg.signature := udp_cfg[ch].signature;
        udp_channel_modbus[ch].cfg.local_port := udp_cfg[ch].local_port;
        udp_channel_modbus[ch].cfg.remote_port := udp_cfg[ch].remote_port;
        udp_channel_modbus[ch].cfg.max_packet_bytes_limit := udp_cfg[ch].max_packet_bytes_limit;
        udp_channel_modbus[ch].cfg.period_ms := udp_cfg[ch].period_ms;
        udp_channel_modbus[ch].cfg.start_send := udp_cfg[ch].start_send;
        udp_channel_modbus[ch].cfg.udp_data_start_index := udp_cfg[ch].udp_data_start_index;
        udp_channel_modbus[ch].cfg.udp_data_count_register := udp_cfg[ch].udp_data_count_register;
        udp_channel_modbus[ch].cfg.packet_type := udp_cfg[ch].header_packet_type;
        udp_channel_modbus[ch].cfg.version := udp_cfg[ch].header_version;
        udp_channel_modbus[ch].cfg.payload_endianness := udp_cfg[ch].payload_endianness;
        udp_channel_modbus[ch].cfg.inter_packet_delay_ms := udp_cfg[ch].inter_packet_delay_ms;
        udp_channel_modbus[ch].cfg.reserved[0] := 0;
        udp_channel_modbus[ch].cfg.reserved[1] := 0;
    END_FOR
    cfgInitDone := TRUE;
END_IF

// ============================================================
//  Запуск массива FB UDP-широковещательной рассылки
//  Каждый канал использует свои настройки из udp_cfg[ch]
// ============================================================
FOR ch := 0 TO UDP_CHANNEL_COUNT - 1 DO
    (* Актуализируем рабочие настройки из Modbus-карты регистров *)
    udp_cfg[ch].enable := udp_channel_modbus[ch].cfg.enable;
    udp_cfg[ch].signature := udp_channel_modbus[ch].cfg.signature;
    udp_cfg[ch].local_port := udp_channel_modbus[ch].cfg.local_port;
    udp_cfg[ch].remote_port := udp_channel_modbus[ch].cfg.remote_port;
    udp_cfg[ch].max_packet_bytes_limit := udp_channel_modbus[ch].cfg.max_packet_bytes_limit;
    udp_cfg[ch].period_ms := udp_channel_modbus[ch].cfg.period_ms;
    udp_cfg[ch].start_send := udp_channel_modbus[ch].cfg.start_send;
    udp_cfg[ch].udp_data_start_index := udp_channel_modbus[ch].cfg.udp_data_start_index;
    udp_cfg[ch].udp_data_count_register := udp_channel_modbus[ch].cfg.udp_data_count_register;
    udp_cfg[ch].header_packet_type := udp_channel_modbus[ch].cfg.packet_type;
    udp_cfg[ch].header_version := udp_channel_modbus[ch].cfg.version;
    udp_cfg[ch].payload_endianness := udp_channel_modbus[ch].cfg.payload_endianness;
    udp_cfg[ch].inter_packet_delay_ms := udp_channel_modbus[ch].cfg.inter_packet_delay_ms;

    (* Ручной старт только по фронту 0->1, даже если SCADA держит 1 несколько циклов *)
    startSendPulse := (udp_cfg[ch].start_send <> 0) AND (startSendPrev[ch] = 0);
    startSendPrev[ch] := udp_cfg[ch].start_send;

    (* Логика режима:
       - enable=1: периодическая отправка по таймеру
       - enable=0: отправка только по ручному импульсу start_send
       Во время активного цикла FB остается включенным до завершения. *)
    fbEnable := udp_common.enable_all AND
        (WORD_TO_BOOL(udp_cfg[ch].enable) OR startSendPulse OR udp_state[ch].busy);

    UdpBroadcast[ch](
        Enable      := fbEnable,
        Signature   := udp_cfg[ch].signature,
        LocalIp     := udp_common.local_ip,
        BroadcastIp := udp_common.broadcast_ip,
        LocalPort   := WORD_TO_UINT(udp_cfg[ch].local_port),
        RemotePort  := WORD_TO_UINT(udp_cfg[ch].remote_port),
        MaxPacketBytesLimit := WORD_TO_UDINT(udp_cfg[ch].max_packet_bytes_limit),
        Period      := UDINT_TO_TIME(WORD_TO_UDINT(udp_cfg[ch].period_ms)),
        StartSend   := startSendPulse,
        PacketType  := udp_cfg[ch].header_packet_type,
        Version     := udp_cfg[ch].header_version,
        PayloadEndianness := udp_cfg[ch].payload_endianness,
        InterPacketDelay := UDINT_TO_TIME(WORD_TO_UDINT(udp_cfg[ch].inter_packet_delay_ms)),
        DataStartIndex    := WORD_TO_UDINT(udp_cfg[ch].udp_data_start_index),
        DataCountRegister := WORD_TO_UDINT(udp_cfg[ch].udp_data_count_register),
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

    (* Экспорт состояния канала в Modbus-карту *)
    udp_channel_modbus[ch].state.active := BOOL_TO_WORD(udp_state[ch].active);
    udp_channel_modbus[ch].state.busy := BOOL_TO_WORD(udp_state[ch].busy);
    udp_channel_modbus[ch].state.error := BOOL_TO_WORD(udp_state[ch].error);
    udp_channel_modbus[ch].state.error_id := TO_WORD(udp_state[ch].error_id);
    udp_channel_modbus[ch].state.sequence_id := UDINT_TO_WORD(udp_state[ch].sequence_id);
    udp_channel_modbus[ch].state.packet_index := udp_state[ch].packet_index;
    udp_channel_modbus[ch].state.packet_count := udp_state[ch].packet_count;
    udp_channel_modbus[ch].state.source_data_words := UDINT_TO_WORD(udp_state[ch].source_data_words);
    udp_channel_modbus[ch].state.effective_data_start_index := UDINT_TO_WORD(udp_state[ch].effective_data_start_index);
    udp_channel_modbus[ch].state.effective_data_end_index := UDINT_TO_WORD(udp_state[ch].effective_data_end_index);
    udp_channel_modbus[ch].state.effective_data_words := UDINT_TO_WORD(udp_state[ch].effective_data_words);
    udp_channel_modbus[ch].state.send_count := UDINT_TO_WORD(udp_state[ch].send_count);
    udp_channel_modbus[ch].state.last_word_index := UDINT_TO_WORD(udp_state[ch].last_word_index);
    udp_channel_modbus[ch].state.last_word_count := udp_state[ch].last_word_count;
    udp_channel_modbus[ch].state.cycle_done := BOOL_TO_WORD(udp_state[ch].cycle_done);
    udp_channel_modbus[ch].state.diag_state := UINT_TO_WORD(udp_state[ch].diag_state);
    udp_channel_modbus[ch].state.diag_error_source := UINT_TO_WORD(udp_state[ch].diag_error_source);
    udp_channel_modbus[ch].state.diag_peer_enable := BOOL_TO_WORD(udp_state[ch].diag_peer_enable);
    udp_channel_modbus[ch].state.diag_peer_active := BOOL_TO_WORD(udp_state[ch].diag_peer_active);
    udp_channel_modbus[ch].state.diag_peer_error := BOOL_TO_WORD(udp_state[ch].diag_peer_error);
    udp_channel_modbus[ch].state.diag_peer_error_id := TO_WORD(udp_state[ch].diag_peer_error_id);
    udp_channel_modbus[ch].state.diag_send_execute := BOOL_TO_WORD(udp_state[ch].diag_send_execute);
    udp_channel_modbus[ch].state.diag_send_busy := BOOL_TO_WORD(udp_state[ch].diag_send_busy);
    udp_channel_modbus[ch].state.diag_send_error := BOOL_TO_WORD(udp_state[ch].diag_send_error);
    udp_channel_modbus[ch].state.diag_send_error_id := TO_WORD(udp_state[ch].diag_send_error_id);
    udp_channel_modbus[ch].state.diag_send_count := UDINT_TO_WORD(udp_state[ch].diag_send_count);
    udp_channel_modbus[ch].state.diag_send_length := UDINT_TO_WORD(udp_state[ch].diag_send_length);
    udp_channel_modbus[ch].state.diag_words_per_packet_limit := UINT_TO_WORD(udp_state[ch].diag_words_per_packet_limit);
    udp_channel_modbus[ch].state.diag_effective_packet_bytes_limit := UDINT_TO_WORD(udp_state[ch].diag_effective_packet_bytes_limit);
    udp_channel_modbus[ch].state.diag_local_init_error := TO_WORD(udp_state[ch].diag_local_init_error);
    udp_channel_modbus[ch].state.diag_remote_init_error := TO_WORD(udp_state[ch].diag_remote_init_error);
END_FOR


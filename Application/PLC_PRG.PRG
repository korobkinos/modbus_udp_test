PROGRAM PLC_PRG
VAR
	AISettingsData : MAIN_SENSOR_AI_SETTINGS;                         (* Данные для FB №1 (ch=0) *)
	PidData : PidSettings; 							                   (* Данные для FB №2 (ch=1) *)
    PidData2 : PidSettings_1; 							                   (* Данные для FB №3 (ch=1) *)
    PidData3 : PidSettings_2; 							                   (* Данные для FB №4 (ch=1) *)
  
   
	(* Массив экземпляров FB широковещательной UDP-передачи *)
    UdpBroadcast : ARRAY[0..UDP_CHANNEL_COUNT - 1] OF FB_UdpWordBroadcast;

    (* Индексы циклов *)
    ch : UINT;
    ipSlot : UINT;

    cfgInitDone : BOOL;
    localIpInitDone : BOOL;
    detectedLocalIp : STRING(16);
    
    startSendPrev : ARRAY[0..UDP_CHANNEL_COUNT - 1] OF WORD;  (* Предыдущее значение start_send для детектора фронта *)
    startSendPulse : BOOL;                                     (* Односкановый импульс ручного запуска *)
    fbEnable : BOOL;                                           (* Итоговое разрешение FB на текущем канале *)
    payloadPtr : POINTER TO BYTE;                              (* Указатель на payload текущего канала *)
    payloadSizeBytes : UDINT;                                  (* Размер payload текущего канала, байт *)
END_VAR

// === IMPLEMENTATION ===

(* Однократное автоопределение локального IP ПЛК *)
IF NOT localIpInitDone THEN
    detectedLocalIp := F_GetLocalIPv4();
    IF detectedLocalIp <> '' THEN
        udp_common.local_ip := detectedLocalIp;
        localIpInitDone := TRUE;
    END_IF
END_IF

(* Применяем IP-получателей из Modbus.
   Проверка и сборка строки IP находятся в отдельной функции. *)
FOR ipSlot := 1 TO 4 DO
    udp_common_modbus.target_status[ipSlot] := F_UdpApplyIPv4FromWords(
        Ip := udp_common_modbus.target_ip[ipSlot],
        PreviousIp := udp_common.broadcast_ip,
        SlotIndex := ipSlot,
        IpAddress := udp_common.broadcast_ip[ipSlot]
    );
END_FOR

(* Однократная загрузка дефолтов из udp_cfg в карту регистров Modbus (%MW0...) *)
IF NOT cfgInitDone THEN
    FOR ch := 0 TO UDP_CHANNEL_COUNT - 1 DO
        udp_channel_modbus[ch].cfg := udp_cfg[ch];
    END_FOR
    cfgInitDone := TRUE;
END_IF

// ============================================================
//  Запуск массива FB UDP-широковещательной рассылки
//  Каждый канал использует свои настройки из udp_cfg[ch]
// ============================================================
FOR ch := 0 TO UDP_CHANNEL_COUNT - 1 DO
    (* Актуализируем рабочие настройки из Modbus-карты регистров *)
    udp_cfg[ch] := udp_channel_modbus[ch].cfg;

    (* Ручной старт только по фронту 0->1, даже если SCADA держит 1 несколько циклов *)
    startSendPulse := (udp_cfg[ch].start_send <> 0) AND (startSendPrev[ch] = 0);
    startSendPrev[ch] := udp_cfg[ch].start_send;

    (* Логика режима:
       - enable=1: периодическая отправка по таймеру
       - enable=0: отправка только по ручному импульсу start_send
       Во время активного цикла FB остается включенным до завершения. *)
    fbEnable := udp_common.enable_all AND
        (WORD_TO_BOOL(udp_cfg[ch].enable) OR startSendPulse OR udp_state[ch].busy);

    (* Источник данных по умолчанию: структура канала Modbus *)
    payloadPtr := ADR(udp_channel_modbus[ch]);
    payloadSizeBytes := SIZEOF(udp_channel_modbus[ch]);

    (* FB №1 (первый в массиве, ch=0) отправляет AISettingsData *)
    IF ch = 0 THEN
        payloadPtr := ADR(AISettingsData);
        payloadSizeBytes := SIZEOF(AISettingsData);
    END_IF

	(* FB №2 (второй в массиве, ch=1) отправляет PidData *)
    IF ch = 1 THEN
        payloadPtr := ADR(PidData);
        payloadSizeBytes := SIZEOF(PidData);
    END_IF
	
	(* FB №3 (второй в массиве, ch=2) отправляет PidData *)
    IF ch = 2 THEN
        payloadPtr := ADR(PidData2);
        payloadSizeBytes := SIZEOF(PidData2);
    END_IF
	
	(* FB №4 (второй в массиве, ch=2) отправляет PidData *)
    IF ch = 3 THEN
        payloadPtr := ADR(PidData3);
        payloadSizeBytes := SIZEOF(PidData3);
    END_IF
		
	
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
        PacketType  := udp_cfg[ch].packet_type,
        Version     := udp_cfg[ch].version,
        PayloadEndianness := udp_cfg[ch].payload_endianness,
        InterPacketDelay := UDINT_TO_TIME(WORD_TO_UDINT(udp_cfg[ch].inter_packet_delay_ms)),
        pPayloadData      := payloadPtr,
        PayloadSizeBytes  := payloadSizeBytes,

        Busy          => udp_state[ch].busy,
        PacketCount   => udp_state[ch].packet_count,
        SendDoneCount => udp_state[ch].send_count,
        LastCycleTimeMs => udp_state[ch].last_cycle_time_ms,
        DiagErrorSource => udp_state[ch].error_code
    );

    (* Экспорт состояния канала в Modbus-карту *)
    udp_channel_modbus[ch].state.packet_count := udp_state[ch].packet_count;
    udp_channel_modbus[ch].state.send_count := UDINT_TO_WORD(udp_state[ch].send_count);
    udp_channel_modbus[ch].state.error_code := UINT_TO_WORD(udp_state[ch].error_code);
    udp_channel_modbus[ch].state.last_cycle_time_ms := udp_state[ch].last_cycle_time_ms;
END_FOR

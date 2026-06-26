PROGRAM PLC_PRG
VAR
    AISettingsData : MAIN_SENSOR_AI_SETTINGS;  (* Данные канала 0 *)
    PidData        : PidSettings;              (* Данные канала 1 *)
    PidData2       : PidSettings_1;            (* Данные канала 2 *)
    PidData3       : PidSettings_2;            (* Данные канала 3 *)

    UdpManager : FB_UdpBroadcastManager;
END_VAR

UdpManager.SetPayload(
    ChannelIndex := 0,
    pData := ADR(AISettingsData),
    SizeBytes := SIZEOF(AISettingsData)
);

UdpManager.SetPayload(
    ChannelIndex := 1,
    pData := ADR(PidData),
    SizeBytes := SIZEOF(PidData)
);

UdpManager.SetPayload(
    ChannelIndex := 2,
    pData := ADR(PidData2),
    SizeBytes := SIZEOF(PidData2)
);

UdpManager.SetPayload(
    ChannelIndex := 3,
    pData := ADR(PidData3),
    SizeBytes := SIZEOF(PidData3)
);

UdpManager(
    Settings := udp_settings,
    ChannelMap := udp_channel_modbus,
    CommonMap := udp_common_modbus
);

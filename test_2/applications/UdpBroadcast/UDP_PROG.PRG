PROGRAM UDP_PROG
VAR
	UdpManager			:	FB_UdpBroadcastManager;
	udp_settings		:	ST_UdpBroadcastSettings;
	udp_common_modbus	AT %MW160 : ST_UdpBroadcastCommonModbus;
	
	
	DI_DO_STATE_INIT:	DI_DO_UNIT;
END_VAR

// === IMPLEMENTATION ===

DI_DO_STATE_INIT.DI_STATE_MAIN:= MODBUS.DI_MAIN;
DI_DO_STATE_INIT.DO_STATE_MAIN:= MODBUS.DO_MAIN;


UdpManager.SetPayload(
    ChannelIndex := 0,
    pData := ADR(MODBUS.ARMATURE_STATE),
    SizeBytes := SIZEOF(MODBUS.ARMATURE_STATE)
);

UdpManager.SetPayload(
    ChannelIndex := 1,
    pData := ADR(MODBUS.ARMATURE_ANALOG_OPCUA),
    SizeBytes := SIZEOF(MODBUS.ARMATURE_ANALOG_OPCUA)
);

UdpManager.SetPayload(
    ChannelIndex := 2,
    pData := ADR(MODBUS.PROTECT_STATE),
    SizeBytes := SIZEOF(MODBUS.PROTECT_STATE)
);

UdpManager.SetPayload(
    ChannelIndex := 3,
    pData := ADR(MODBUS.REGULATOR_TREND_DATA),
    SizeBytes := SIZEOF(MODBUS.REGULATOR_TREND_DATA)
);

UdpManager.SetPayload(
    ChannelIndex := 4,
    pData := ADR(SETTINGS.DATA.PID_SETTINGS),
    SizeBytes := SIZEOF(SETTINGS.DATA.PID_SETTINGS)
);

UdpManager.SetPayload(
    ChannelIndex := 5,
    pData := ADR(MODBUS.AI_MAIN_OUT),
    SizeBytes := SIZEOF(MODBUS.AI_MAIN_OUT)
);

UdpManager.SetPayload(
    ChannelIndex := 6,
    pData := ADR(MODBUS.AI_MAIN_STATE),
    SizeBytes := SIZEOF(MODBUS.AI_MAIN_STATE)
);

UdpManager.SetPayload(
    ChannelIndex := 7,
    pData := ADR(SETTINGS.DATA.AI_SETTINGS),
    SizeBytes := SIZEOF(SETTINGS.DATA.AI_SETTINGS)
);

UdpManager.SetPayload(
    ChannelIndex := 8,
    pData := ADR(DI_DO_STATE_INIT),
    SizeBytes := SIZEOF(DI_DO_STATE_INIT)
);

UdpManager(
    Settings := udp_settings,
    CommonMap := udp_common_modbus
);

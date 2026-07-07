PROGRAM EVENTS

VAR
	save_ready				:	BOOL;
	settings_tof			:	TOF;
	settings_ton			:	TON;
	
	ton_array				:	ARRAY[1..EVENT_QUANTITY] OF ton;
	trig_array				:	ARRAY[1..EVENT_QUANTITY] OF r_trig;
	
	file_header				:	STRING(255);
END_VAR

VAR CONSTANT
	itf_number			:	WORD:=1;	//Номер интерфейса
	object_number		:	WORD:=2;	//Номер объекта
	event_enable		:	WORD:=3;	//=1, задействован
	itf_director		:	WORD:=4;	//Номер интерфейса директора
	object_director		:	WORD:=5;	//Номер объекта директора
	object_director_bit	:	WORD:=6;	//Номер бита директора
	command				:	WORD:=7;	//Действие на себе
	ton_time			:	WORD:=8;	//Задержка действия
	invert_bit			:	WORD:=9;	//4я настройка - по ON или по OFF
	and_event			:	WORD:=10;	//Событие активируется только по AND с указанным событием
	//11 - reserv
END_VAR

// === IMPLEMENTATION ===

Control();

MODBUS.EVENT_MANAGER_DATA.EventTotal:= GetEventCount();
MODBUS.EVENT_MANAGER_DATA.EventRemainder:= EVENT_QUANTITY - MODBUS.EVENT_MANAGER_DATA.EventTotal;

//Получаем настройки событий выбранного пункта
IF MODBUS.EVENT_MANAGER_DATA.Command = 2 AND MODBUS.EVENT_MANAGER_DATA.SelectedNumber > 0 AND MODBUS.EVENT_MANAGER_DATA.SelectedNumber <= EVENT_QUANTITY THEN
	MODBUS.EVENT_MANAGER_DATA.Settings:= SETTINGS.DATA.EVENT_SETTINGS.Number[MODBUS.EVENT_MANAGER_DATA.SelectedNumber];
	//MAIN.main_itf[MODBUS.EVENT_MANAGER_DATA.ItfNumber].GetEvents(MODBUS.EVENT_MANAGER_DATA.SelectedNumber, MODBUS.EVENT_MANAGER_DATA.DirectorNumber, EventData=> MODBUS.EVENT_MANAGER_DATA.Settings);
END_IF

//Запись настроек по команде
save_ready:= FALSE;
IF MODBUS.EVENT_MANAGER_DATA.Command = 1 THEN
	save_ready:= SaveEvents(ADR(MODBUS.EVENT_MANAGER_DATA));
END_IF

settings_tof(IN:= save_ready, PT:= T#1S);
settings_ton(IN:= settings_tof.Q, PT:= T#500MS);
IF settings_ton.Q THEN
	SettingsSaveDone();
END_IF

//Чтение настроек событий из файла
IF MODBUS.EVENT_MANAGER_DATA.Command = 4 THEN
//('/mnt/user/codesys/usb0/event_settings.txt');
	MODBUS.EVENT_MANAGER_DATA.Command:= ReadEventFile('event_settings.txt');//
END_IF

file_header:= CONCAT(FILE_HEADER_UNITE, 'EventNumber$09ItfNumber$09ObjectNumber$09EventEnable$09ItfDirector$09ObjectDirector$09ObjectDirectorBit$09Command$09Delay$09InvertBit$09AndEvent$09NotUse$0A');
//Сохраняем настройки событий в файл
IF MODBUS.EVENT_MANAGER_DATA.Command = 5 THEN
	IF SaveEventFile('event_settings.txt', file_header) THEN
		MODBUS.EVENT_MANAGER_DATA.Command:= 6;
	END_IF
END_IF
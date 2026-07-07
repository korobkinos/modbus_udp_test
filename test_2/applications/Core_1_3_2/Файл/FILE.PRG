PROGRAM FILE
VAR
	file_massage	:	WSTRING;
	file_control	:	file_control;
	settings_file	:	SettingsData;
	load_active		:	BOOL;//Загрузка с карты начата
	
	file_size		:	DWORD;
END_VAR

VAR CONSTANT
	save			:	WORD:= 5;
	read			:	WORD:= 4;
	done			:	WORD:= 6;
	error			:	WORD:= 7;
	
END_VAR

// === IMPLEMENTATION ===

file_control.SettingsBuffer(	ToFile:= MODBUS.FILE_COMMAND_PANEL.Command = save,// CONTROL_WORD_MAIN[1].settings_save,
								ToSettings:= FALSE,
								SettingsFile:= settings_file);

file_control(	save:= MODBUS.FILE_COMMAND_PANEL.Command = save,
				read:= MODBUS.FILE_COMMAND_PANEL.Command = read,
				//w_r_device:= file_sourse,
				buffer:= settings_file,
				file_massage=> file_massage,
				value_w_r:= file_size);

IF MODBUS.FILE_COMMAND_PANEL.Command = read THEN
	load_active:= TRUE;
END_IF
				
IF file_massage = "Успешно!" THEN
	MODBUS.FILE_COMMAND_PANEL.Command:= done;//STATE_WORD_MAIN[1].settings_rw_ok:= TRUE;
ELSE
	MODBUS.FILE_COMMAND_PANEL.Command:= 0;
END_IF
(*
IF file_massage = "Ошибка!" THEN
	MODBUS.FILE_COMMAND.Command:= error;//STATE_WORD_MAIN[1].settings_rw_broken:= TRUE;
ELSE
	MODBUS.FILE_COMMAND.Command:= 0;
END_IF
*)

//Загрузка данных с SD карты
IF load_active AND MODBUS.FILE_COMMAND_PANEL.Command = done THEN
	file_control.SettingsBuffer(	ToFile:= FALSE,
									ToSettings:= load_active,
									SettingsFile:= settings_file);
	load_active:= FALSE;//Загрузка завершена
END_IF

//Сброс на заводские
//factory_to_settings(to_factory:= CONTROL_WORD_MAIN[1].factory_settings AND factory_confirm = 99);
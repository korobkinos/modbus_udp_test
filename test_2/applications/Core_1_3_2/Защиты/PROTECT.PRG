PROGRAM PROTECT
VAR
	protect_control	:	protect_control;
END_VAR

// === IMPLEMENTATION ===

protect_control();

protect_control.SetCommand(MODBUS.SELECTED_PROTECT_OPCUA);

//Показываем состояние выбранной защиты на верхний уровень
IF MODBUS.SELECTED_PROTECT_OPCUA.SelectedNumber <> 0 THEN
	MODBUS.SELECTED_PROTECT_OPCUA.State.DwValue:= MODBUS.PROTECT_STATE[MODBUS.SELECTED_PROTECT_OPCUA.SelectedNumber];
END_IF
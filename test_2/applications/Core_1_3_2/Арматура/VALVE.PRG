PROGRAM VALVE
VAR
	valve_control		:	valve_control;
	//counter			:	WORD;
	//command_local		:	CommandStructure;
	
END_VAR

// === IMPLEMENTATION ===

valve_control();

//Передаем команду на арматуру от верхнего уровня
//command_local.Command:= MODBUS.SELECTED_ARMATURE_OPCUA.Command;
//command_local.SelectedNumber:= MODBUS.SELECTED_ARMATURE_OPCUA.SelectedNumber;
(*IF *)valve_control.SetCommand(MODBUS.SELECTED_ARMATURE_OPCUA);(* THEN*) (*Прередаем в функцию структуру, первые элементы которой - CommandStructure!!!*)
(*	MODBUS.ARMATURE_COMMAND.Command:= 0;
END_IF*)
//Передаем состояние всей арматуры на верхний уровень
//FOR counter:= 1 TO ARMATURE_QUANTITY  DO
	//MODBUS.ARMATURE_STATE.Number[counter].DwValue:= valve_control.GetState(counter);
	//MODBUS.ARMATURE_STATE[counter]:= valve_control.GetState(counter);
///END_FOR

//Показываем состояние выбранной арматуры на верхний уровень
IF MODBUS.SELECTED_ARMATURE_OPCUA.SelectedNumber <> 0 THEN
	MODBUS.SELECTED_ARMATURE_OPCUA.State.DwValue:= MODBUS.ARMATURE_STATE[MODBUS.SELECTED_ARMATURE_OPCUA.SelectedNumber];//MODBUS.SELECTED_ARMATURE_STATE:= MODBUS.ARMATURE_STATE.Number[MODBUS.ARMATURE_COMMAND.ObjectNumber];
	MODBUS.SELECTED_ARMATURE_OPCUA.AnalogData:= MODBUS.ARMATURE_ANALOG_OPCUA[MODBUS.SELECTED_ARMATURE_OPCUA.SelectedNumber];
END_IF
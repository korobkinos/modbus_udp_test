PROGRAM MAIN
VAR
	main_itf		:	ARRAY[1..ITF_QUANTITY] OF ITF_MAIN;
	
END_VAR

// === IMPLEMENTATION ===

main_itf[1]:= VALVE.valve_control;
main_itf[2]:= IN_OUT.di_control;
main_itf[3]:= IN_OUT.do_control;
main_itf[4]:= IN_OUT.ai_control;
main_itf[5]:= PROTECT.protect_control;
main_itf[6]:= REGULATOR.pid_control;
MODBUS.PLC_NUMBER:= 1;

VALVE();
REGULATOR();
PROTECT();
IN_OUT();
EVENTS();
FILE();

UDP_PROG();
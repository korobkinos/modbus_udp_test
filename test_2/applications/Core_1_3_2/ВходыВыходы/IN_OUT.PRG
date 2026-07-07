PROGRAM IN_OUT
VAR
	di_control			:	di_control;
	do_control			:	do_control;
	ai_control			:	ai_control;
	
	//digital_binding		:	DigitalBindingData;		//Временное хранилище дискретных и аналоговых привязок одного выбранного объекта
	
	//counter				:	WORD;
	
END_VAR

// === IMPLEMENTATION ===

//Получаем физические входы
di_control();
ai_control();

//Устанавливаем физические дискретные выходы
do_control();
bus_diag();
//DO можно привязать к DI, а наоборот - нельзя! SetState в DO не работает
//Если привязка к объекту была и = TRUE, и если привязку убрать, то TRUE в объекте останется до перезагрузки ПЛК.
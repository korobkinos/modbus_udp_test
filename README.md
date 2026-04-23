# UDP Word Broadcast для CODESYS 3.5 (Net Base Services)

## Назначение
Проект реализует передачу массива `WORD` по UDP через `NBS.UDP_Peer`.
Основная логика упакована в один функциональный блок `FB_UdpWordBroadcast`, пригодный для переноса в библиотеку.

Ключевая особенность:
- массив данных передается через интерфейс FB: `VAR_IN_OUT Data : ARRAY[*] OF WORD`
- можно подключить массив любой длины
- внутри FB задается диапазон отправки `DataStartIndex..DataEndIndex`

## Состав
- `Application/UdpBroadcast/Functions/FB_UdpWordBroadcast` - основной FB передачи
- `Application/UdpBroadcast/Struct/ST_UdpPacketHeader` - структура заголовка AMKS
- `Application/GVL_UDP` - общие настройки + массив настроек/состояний каналов
- `Application/PLC_PRG.PRG` - пример использования массива FB

## Формат UDP-пакета
Пакет собирается как непрерывный буфер:
- `Header` (`ST_UdpPacketHeader`)
- `Payload` (`WORD[]`)

Поля заголовка:
- `Signature : DWORD` (по умолчанию `AMKS`, hex `16#534B4D41`)
- `Version : WORD`
- `PacketType : WORD`
- `SequenceId : UDINT`
- `PacketIndex : WORD`
- `PacketCount : WORD`
- `StartWordIndex : UDINT`
- `WordCount : WORD`
- `PayloadSizeBytes : WORD`
- `Checksum : WORD`

Контрольная сумма:
- поле `Header.Checksum` сейчас не используется (`0`)
- UDP checksum рассчитывается сетевым стеком библиотеки

## Как использовать FB
Пример вызова:

```iecst
VAR
    TxData : ARRAY[0..34999] OF WORD;
    UdpBroadcast : ARRAY[0..UDP_CHANNEL_COUNT - 1] OF FB_UdpWordBroadcast;
    ch : UINT;
END_VAR

FOR ch := 0 TO UDP_CHANNEL_COUNT - 1 DO
    UdpBroadcast[ch](
        Enable      := udp_common.enable_all AND WORD_TO_BOOL(udp_cfg[ch].enable),
        Signature   := udp_cfg[ch].signature,
        LocalIp     := udp_common.local_ip,
        BroadcastIp := udp_common.broadcast_ip,
        LocalPort   := WORD_TO_UINT(udp_cfg[ch].local_port),
        RemotePort  := WORD_TO_UINT(udp_cfg[ch].remote_port),
        MaxPacketBytesLimit := WORD_TO_UDINT(udp_cfg[ch].max_packet_bytes_limit),
        Period      := UDINT_TO_TIME(WORD_TO_UDINT(udp_cfg[ch].period_ms)),
        StartSend   := WORD_TO_BOOL(udp_cfg[ch].start_send),
        DataStartIndex := WORD_TO_UDINT(udp_cfg[ch].udp_data_start_index),
        DataEndIndex   := WORD_TO_UDINT(udp_cfg[ch].udp_data_end_index),
        Data := TxData
    );
END_FOR
```

## Входы FB
- `Enable` - включение FB
- `Signature` - сигнатура протокола в заголовке
- `LocalIp` - локальный IP
- `BroadcastIp` - IP назначения
- `LocalPort` - локальный UDP порт
- `RemotePort` - удаленный UDP порт
- `MaxPacketBytesLimit` - лимит размера UDP datagram, `0` = авто до `65507`
- `Period` - период автозапуска полного цикла передачи (`TIME`)
- `StartSend` - ручной старт цикла по фронту
- `PacketType`, `Version` - параметры заголовка пакета
- `PayloadEndianness` - порядок байт в WORD payload (`0=little`, `1=swap bytes`)
- `InterPacketDelay` - пауза между пакетами внутри цикла
- `DataStartIndex` - старт индекса в массиве `Data`
- `DataEndIndex` - конец индекса в массиве `Data`
- `Data` - массив `ARRAY[*] OF WORD` через `VAR_IN_OUT`

## Выходы FB
Основные:
- `Active`, `Busy`, `Error`, `ErrorId`
- `SequenceId`, `PacketIndex`, `PacketCount`
- `SendDoneCount`, `CycleDone`
- `LastWordIndex`, `LastWordCount`

По данным:
- `SourceDataWords` - фактическая длина входного массива
- `EffectiveDataStartIndex` - примененный старт после ограничения
- `EffectiveDataEndIndex` - примененный конец после ограничения
- `EffectiveDataWords` - число передаваемых WORD в цикле

Диагностика:
- `DiagState`
- `DiagErrorSource`
- `DiagPeerEnable`, `DiagPeerActive`, `DiagPeerError`, `DiagPeerErrorId`
- `DiagSendExecute`, `DiagSendBusy`, `DiagSendError`, `DiagSendErrorId`
- `DiagSendCount`, `DiagSendLength`
- `DiagWordsPerPacketLimit`, `DiagEffectivePacketBytesLimit`
- `DiagLocalAddrInitError`, `DiagRemoteAddrInitError`

## Правила диапазона DataStartIndex/DataEndIndex
FB автоматически нормализует границы:
- если `DataStartIndex` больше длины массива, старт прижимается к последнему элементу
- если `DataEndIndex` больше длины массива, конец прижимается к последнему элементу
- если `DataEndIndex < DataStartIndex`, конец становится равным старту

Таким образом FB всегда отправляет валидный диапазон минимум из 1 слова.

## Ограничения
- Максимальный payload буфер FB: `32753 WORD`
- Максимум UDP datagram на уровне данных: `65507` байт
- `PacketCount` хранится в `WORD`, максимум `65535` пакетов за цикл

## Рекомендации по настройке
- Для Ethernet MTU 1500 обычно безопасный лимит `MaxPacketBytesLimit = 1472`
- При больших массивах начинайте с небольшого диапазона `DataStartIndex..DataEndIndex`

## Пример настроек из GVL
В `GVL_UDP` данные сгруппированы в структуры:
- `udp_common` - общие настройки для всех каналов (`local_ip`, `broadcast_ip`, `enable_all`)
- `udp_cfg[0..UDP_CHANNEL_COUNT-1]` - индивидуальные настройки каналов
- `udp_state[0..UDP_CHANNEL_COUNT-1]` - состояние и диагностика каналов
- `udp_channel_modbus[0..UDP_CHANNEL_COUNT-1]` - карта Modbus (настройки + состояния)

Для каналов по умолчанию заданы разные порты:
- канал 0: `local_port = 15001`, `remote_port = 15000`
- канал 1: `local_port = 15003`, `remote_port = 15002`

## Зависимости
Нужны библиотеки CODESYS:
- `Net Base Services` (`NBS`)
- стандартные `TON`, `R_TRIG`

## Приложение: карта Modbus для SCADA

### Назначение
Этот раздел нужен для привязки тегов в SCADA к `GVL_UDP.udp_channel_modbus`.

### Размер и диапазоны
- Старт карты: `%MW0`
- Размер одного канала: `48 WORD`
- Размер всех 10 каналов: `480 WORD`
- Диапазон всей карты: `%MW0..%MW479`
- Структура канала:
- `cfg` (настройки): `16 WORD` (`MW(base+0)..MW(base+15)`)
- `state` (состояние и диагностика): `32 WORD` (`MW(base+16)..MW(base+47)`)

### Формула адресов для канала `ch`
- `base = ch * 48`
- `cfg_base = base + 0`
- `state_base = base + 16`

Примеры:
- FB1 (`ch=0`): `MW0..MW47`
- FB2 (`ch=1`): `MW48..MW95`
- FB3 (`ch=2`): `MW96..MW143`

### FB1 (`ch=0`) настройка `cfg` (`MW0..MW15`)
| Адрес MW | Поле | Тип | Доступ | Описание и значения |
|---|---|---|---|---|
| `MW0` | `enable` | `WORD` | `R/W` | Включение канала. `0` = выкл, `1` = вкл. |
| `MW1..MW2` | `signature` | `DWORD` | `R/W` | Сигнатура заголовка. 4 ASCII-символа в hex, например `AM01` = `16#31304D41`. |
| `MW3` | `local_port` | `WORD` | `R/W` | Локальный UDP-порт ПЛК (порт источника). |
| `MW4` | `remote_port` | `WORD` | `R/W` | UDP-порт назначения на приемнике. |
| `MW5` | `max_packet_bytes_limit` | `WORD` | `R/W` | Лимит размера UDP-пакета, байт. `0` = авто до `65507`. Для Ethernet обычно `1472`. |
| `MW6` | `period_ms` | `WORD` | `R/W` | Период автозапуска цикла отправки, мс. Пример: `2000` = 2 сек. |
| `MW7` | `start_send` | `WORD` | `R/W` | Ручной старт цикла по фронту. Импульс: записать `1`, затем вернуть `0`. |
| `MW8` | `udp_data_start_index` | `WORD` | `R/W` | Начальный индекс в `DataArray[0..34999]`. |
| `MW9` | `udp_data_end_index` | `WORD` | `R/W` | Конечный индекс в `DataArray[0..34999]`. |
| `MW10` | `packet_type` | `WORD` | `R/W` | Поле `PacketType` в заголовке AMxx. |
| `MW11` | `version` | `WORD` | `R/W` | Поле `Version` в заголовке AMxx. |
| `MW12` | `payload_endianness` | `WORD` | `R/W` | Порядок байт WORD в payload: `0` = native/little, `1` = swap bytes. |
| `MW13` | `inter_packet_delay_ms` | `WORD` | `R/W` | Пауза между пакетами внутри одного цикла, мс. |
| `MW14..MW15` | `reserved[0..1]` | `WORD[2]` | `R/W` | Резерв. Держать `0`. |

### FB1 (`ch=0`) состояние `state` (`MW16..MW47`)
| Адрес MW | Поле | Тип | Доступ | Описание и значения |
|---|---|---|---|---|
| `MW16` | `active` | `WORD` | `R` | `0` = FB неактивен, `1` = FB активен. |
| `MW17` | `busy` | `WORD` | `R` | `0` = цикл не выполняется, `1` = идет цикл передачи. |
| `MW18` | `error` | `WORD` | `R` | `0` = ошибок нет, `1` = есть ошибка. |
| `MW19` | `error_id` | `WORD` | `R` | Общий код последней ошибки FB (`NBS.ERROR`). Это не код `diag_error_source`. |
| `MW20` | `sequence_id` | `WORD` | `R` | Номер цикла передачи, младшее WORD. |
| `MW21` | `packet_index` | `WORD` | `R` | Индекс текущего пакета в цикле (`0..packet_count-1`). |
| `MW22` | `packet_count` | `WORD` | `R` | Общее число пакетов в текущем цикле. |
| `MW23` | `source_data_words` | `WORD` | `R` | Длина входного массива `Data`, WORD. |
| `MW24` | `effective_data_start_index` | `WORD` | `R` | Фактически примененный старт после ограничений FB. |
| `MW25` | `effective_data_end_index` | `WORD` | `R` | Фактически примененный конец после ограничений FB. |
| `MW26` | `effective_data_words` | `WORD` | `R` | Фактическое число WORD в выбранном диапазоне отправки. |
| `MW27` | `send_count` | `WORD` | `R` | Счетчик успешно отправленных UDP-пакетов, младшее WORD. |
| `MW28` | `last_word_index` | `WORD` | `R` | Индекс первого WORD в последнем отправленном пакете. |
| `MW29` | `last_word_count` | `WORD` | `R` | Количество WORD в последнем отправленном пакете. |
| `MW30` | `cycle_done` | `WORD` | `R` | `0` = цикл не завершен, `1` = цикл завершен. |
| `MW31` | `diag_state` | `WORD` | `R` | Текущее состояние автомата FB. |
| `MW32` | `diag_error_source` | `WORD` | `R` | Внутренний код источника ошибки FB (`0..10`, коды см. ниже). Это не `NBS.ERROR`. |
| `MW33` | `diag_peer_enable` | `WORD` | `R` | `0` = UDP_Peer запрещен, `1` = разрешен. |
| `MW34` | `diag_peer_active` | `WORD` | `R` | `0` = UDP_Peer неактивен, `1` = активен. |
| `MW35` | `diag_peer_error` | `WORD` | `R` | `0` = ошибки peer нет, `1` = есть ошибка peer. |
| `MW36` | `diag_peer_error_id` | `WORD` | `R` | Код ошибки UDP_Peer (`NBS.ERROR`). |
| `MW37` | `diag_send_execute` | `WORD` | `R` | `0` = вызова `Send` не было, `1` = выполнялся вызов `Send`. |
| `MW38` | `diag_send_busy` | `WORD` | `R` | Резерв диагностики, обычно `0`. |
| `MW39` | `diag_send_error` | `WORD` | `R` | `0` = ошибки `Send` нет, `1` = ошибка `Send`. |
| `MW40` | `diag_send_error_id` | `WORD` | `R` | Код результата/ошибки `udpPeer.Send` (`NBS.ERROR`). |
| `MW41` | `diag_send_count` | `WORD` | `R` | Фактически отправлено байт, младшее WORD. |
| `MW42` | `diag_send_length` | `WORD` | `R` | Запрошенная длина отправки, байт, младшее WORD. |
| `MW43` | `diag_words_per_packet_limit` | `WORD` | `R` | Расчетный лимит WORD в одном пакете. |
| `MW44` | `diag_effective_packet_bytes_limit` | `WORD` | `R` | Примененный лимит размера пакета, байт. |
| `MW45` | `diag_local_init_error` | `WORD` | `R` | Результат `SetInitialValue(LocalIp)`, код `NBS.ERROR`. |
| `MW46` | `diag_remote_init_error` | `WORD` | `R` | Результат `SetInitialValue(BroadcastIp)`, код `NBS.ERROR`. |
| `MW47` | `reserved[0]` | `WORD` | `R` | Резерв. |

### Коды `diag_error_source`
- `0` - нет ошибки источника
- `1` - ошибка инициализации LocalIp
- `2` - ошибка инициализации BroadcastIp
- `3` - LocalIp = `0.0.0.0`
- `4` - ошибка `UDP_Peer`
- `5` - ошибка границ массива `Data`
- `6` - ошибка диапазона `DataStartIndex..DataEndIndex`
- `7` - слишком большой диапазон (переполнение по числу пакетов)
- `8` - ошибка `Send`
- `9` - ошибка расчета лимита пакета
- `10` - `sendLen` больше лимита пакета

### Как читать регистры ошибок
- `diag_error_source` это внутренний код логики FB (таблица `0..10` выше), он показывает в каком месте возникла ошибка.
- `error_id` это общий код ошибки FB типа `NBS.ERROR`.
- `diag_peer_error_id` это код ошибки компонента `UDP_Peer` типа `NBS.ERROR`.
- `diag_send_error_id` это код результата вызова `udpPeer.Send` типа `NBS.ERROR`.
- Практика диагностики: сначала смотреть `diag_error_source`, затем уже связанный с ним `NBS.ERROR` код.
- Если `diag_error_source = 4`, обычно ключевой код в `diag_peer_error_id`.
- Если `diag_error_source = 8`, обычно ключевой код в `diag_send_error_id`.
- Если `diag_error_source = 1` или `2`, смотрите `diag_local_init_error` и `diag_remote_init_error`.

### Важные примечания для SCADA
- В `cfg` только `signature` занимает 2 регистра (`DWORD`), остальные поля `cfg` по 1 регистру (`WORD`).
- Блок `state` полностью `WORD`.
- Для внутренних 32-битных счетчиков в `state` передается младшее слово (`LOW WORD`).
- `start_send` нужно использовать как импульсный бит (не держать постоянно в `1`).
- Поля `reserved` лучше не использовать под теги, держать нулевыми.

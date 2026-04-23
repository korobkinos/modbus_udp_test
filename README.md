# UDP Word Broadcast для CODESYS 3.5 (Net Base Services)

## Назначение
Проект реализует передачу массива `WORD` по UDP через `NBS.UDP_Peer`.
Основная логика упакована в один функциональный блок `FB_UdpWordBroadcast`, пригодный для переноса в библиотеку.

Ключевая особенность:
- массив данных передается через интерфейс FB: `VAR_IN_OUT Data : ARRAY[*] OF WORD`
- можно подключить массив любой длины
- внутри FB задается диапазон отправки `DataStartIndex..DataEndIndex`

## Состав
- `Application/FB_UdpWordBroadcast` - основной FB передачи
- `Application/ST_UdpPacketHeader` - структура заголовка AMKS
- `Application/F_CalcWordChecksum` - контрольная сумма payload
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
- сумма всех `WORD` payload
- тип суммы `UDINT`
- в пакет пишутся младшие 16 бит

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
        Enable      := udp_common.enable_all AND udp_cfg[ch].enable,
        Signature   := udp_cfg[ch].signature,
        LocalIp     := udp_common.local_ip,
        BroadcastIp := udp_common.broadcast_ip,
        LocalPort   := udp_cfg[ch].local_port,
        RemotePort  := udp_cfg[ch].remote_port,
        MaxPacketBytesLimit := udp_cfg[ch].max_packet_bytes_limit,
        Period      := UDINT_TO_TIME(WORD_TO_UDINT(udp_cfg[ch].period_ms)),
        StartSend   := udp_cfg[ch].start_send,
        DataStartIndex := udp_cfg[ch].udp_data_start_index,
        DataEndIndex   := udp_cfg[ch].udp_data_end_index,
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

Для каналов по умолчанию заданы разные порты:
- канал 0: `local_port = 15001`, `remote_port = 15000`
- канал 1: `local_port = 15003`, `remote_port = 15002`

## Зависимости
Нужны библиотеки CODESYS:
- `Net Base Services` (`NBS`)
- стандартные `TON`, `R_TRIG`

## Что уже исправлено
- Убрана зависимость FB от внешних указателей `DataPtr/DataWords`
- Добавлена работа с массивом любой длины через `VAR_IN_OUT ARRAY[*]`
- Исправлен шаг указателя в `F_CalcWordChecksum` (`+ SIZEOF(WORD)`)
- Сигнатура по умолчанию обновлена на `AMKS`

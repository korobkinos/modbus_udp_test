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
- `Application/GVL_UDP` - пример настроечных и диагностических переменных
- `Application/PLC_PRG.PRG` - пример использования одного FB

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
    UdpTx  : FB_UdpWordBroadcast;
END_VAR

UdpTx(
    Enable      := TRUE,
    Signature   := 16#534B4D41, (* AMKS *)
    LocalIp     := '192.168.4.220',
    BroadcastIp := '192.168.4.255',
    LocalPort   := 15001,
    RemotePort  := 15000,
    MaxPacketBytesLimit := 1472,
    Period      := T#2S,
    StartSend   := udp_start_send,
    DataStartIndex := 0,
    DataEndIndex   := 34999,
    Data := TxData
);
```

## Входы FB
- `Enable` - включение FB
- `Signature` - сигнатура протокола в заголовке
- `LocalIp` - локальный IP
- `BroadcastIp` - IP назначения
- `LocalPort` - локальный UDP порт
- `RemotePort` - удаленный UDP порт
- `MaxPacketBytesLimit` - лимит размера UDP datagram, `0` = авто до `65507`
- `Period` - период автозапуска полного цикла передачи
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
В `GVL_UDP` есть готовые переменные:
- `udp_signature`
- `udp_data_start_index`
- `udp_data_end_index`
- `udp_max_packet_bytes_limit`
- `udp_start_send`
- `udp_effective_data_start_index`
- `udp_effective_data_end_index`
- `udp_effective_data_words`
- `udp_source_data_words`

## Зависимости
Нужны библиотеки CODESYS:
- `Net Base Services` (`NBS`)
- стандартные `TON`, `R_TRIG`

## Что уже исправлено
- Убрана зависимость FB от внешних указателей `DataPtr/DataWords`
- Добавлена работа с массивом любой длины через `VAR_IN_OUT ARRAY[*]`
- Исправлен шаг указателя в `F_CalcWordChecksum` (`+ SIZEOF(WORD)`)
- Сигнатура по умолчанию обновлена на `AMKS`

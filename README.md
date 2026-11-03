<br />
<div align="center">
  <img src="images/zust_icon.png" alt="Z.UST" width="140" height="140">
  <h1 align="center">Z.UST для Android</h1>
  <p align="center">
    TOR с мостами в одну кнопку.
    <br />
    <a href="https://t.me/zdotust"><strong>Канал проекта</strong></a>
    &middot;
    <a href="https://github.com/f1zzen/zust">Z.UST для ПК</a>
  </p>
</div>

## Что это

Z.UST подключает телефон к TOR через мосты, поэтому работает и там, где сам TOR заблокирован.
Мосты Z.UST находит сам: берёт сохранённые, потом свежие от сервера Z.UST и с torproject.org,
а после подключения скачивает новые уже через TOR и запоминает рабочие.

Два режима:

- **VPN** - через TOR идёт трафик всего телефона или только выбранных приложений.
- **Прокси** - только SOCKS5-прокси `127.0.0.1:9050`. Его можно указать в Telegram (кнопка
  "Добавить в Telegram") или в браузере, остальной телефон работает напрямую.

TOR живёт в фоновом сервисе с уведомлением и не отключается, когда приложение закрыто.
Пять тем оформления - те же, что в Z.UST для ПК.

## Установка

1. Скачайте APK из [релизов](../../releases). Выбирайте `app-arm64-v8a-release.apk`,
   а для старых (32-битных) телефонов - `app-armeabi-v7a-release.apk`. Если не знаете какой у вас телефон то берите первую.
2. Откройте файл и разрешите установку из этого источника.
3. Play Protect может предупредить, что разработчик неизвестен: "Подробнее" → "Всё равно установить".

**Нужен Android 7.0 или новее!**

## Первый запуск

- Приложение попросит разрешение на уведомления, а в режиме VPN, соответственно,  подключение VPN.
- Первое подключение может занять 2-3 минуты: Z.UST ищет рабочие мосты. Дальше быстрее :D
- Если телефон агрессивно экономит батарею (Xiaomi, Huawei, Samsung), отключите для Z.UST
  оптимизацию батареи - внизу будет кнопка.
- В режиме VPN браузеры могут показывать капчу - это норма. Так они реагируют на TOR

## Сборка

Нужны Flutter 3.47+ и Android SDK с NDK.

```
flutter build apk --release --split-per-abi
```

Для подписи релиза положите `android/key.properties` (`storeFile`, `storePassword`,
`keyAlias`, `keyPassword`). Без него APK подписывается отладочным ключом!

## Внутри?

- [tor](https://www.torproject.org/) 0.4.9.6 и [lyrebird](https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird) (obfs4, webtunnel)
- [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) - VPN поверх SOCKS, DNS через TOR

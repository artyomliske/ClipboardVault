# Автозапуск и режим Menu Bar

Clipboard Vault использует нативный `SMAppService.mainApp` из фреймворка ServiceManagement. Этот API предназначен для регистрации главного приложения как Login Item в macOS 13 и новее [1]. Автозапуск **по умолчанию выключен**: включить его можно только явно в настройках приложения.

| Аспект | Реализация |
|---|---|
| Включение | Пользователь включает переключатель «Запускать при входе в macOS». Приложение вызывает `register()`. |
| Отключение | При выключении переключателя приложение вызывает `unregister()`. |
| Статус | Настройки считывают фактический `SMAppService.mainApp.status`, а не полагаются на сохранённый флаг. |
| Системное управление | Кнопка открывает системную панель Login Items, где пользователь может изменить состояние. |
| Режим Menu Bar | `LSUIElement = true` скрывает приложение из Dock; основной интерфейс открывается через `MenuBarExtra`. |
| Выход | В интерфейсе Menu Bar доступна явная команда «Выйти из Clipboard Vault». |

> Регистрация Login Item выполняется только после действия пользователя. macOS может показать системное уведомление о добавлении элемента входа; пользователь также может управлять им из системных настроек [1] [2].

## Совместимость

Проект уже ориентирован на macOS 14.0 и новее, поэтому `SMAppService` доступен без обратного пути через устаревший `SMLoginItemSetEnabled` [1].

## References

[1]: https://developer.apple.com/documentation/servicemanagement/smappservice "Apple Developer Documentation — SMAppService"
[2]: https://nilcoalescing.com/blog/LaunchAtLoginSetting "Nil Coalescing — Add launch at login setting to a macOS app"

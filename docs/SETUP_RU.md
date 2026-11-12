# Настройка проекта — пошагово (для новичка)

Эта инструкция нужна один раз, чтобы код из GitHub попадал в Roblox Studio.

## Как всё устроено

- **GitHub (этот репозиторий)** хранит весь код игры.
- **Rojo** — программа, которая копирует код из папки на вашем компьютере в Roblox Studio.
- **Roblox Studio** хранит карту, свет, модели и звуки — в файле места (place).

Важно: Rojo копирует только в одну сторону (файлы → Studio) и **не трогает Workspace**.
Карта, построенная в Studio, в GitHub не попадает. Её нужно сохранять отдельно (шаг 7).

## Шаг 1. Установите программы

1. Roblox Studio: <https://create.roblox.com/landing>
2. Git: <https://git-scm.com/downloads>
3. Rokit (менеджер инструментов Roblox): <https://github.com/rojo-rbx/rokit/releases/latest>
   — скачайте архив для вашей системы, распакуйте и запустите `rokit self-install`.

## Шаг 2. Скачайте репозиторий

Откройте терминал (Windows: PowerShell) и выполните, подставив адрес своего репозитория:

```bash
git clone <адрес-репозитория>
cd <папка-репозитория>
```

## Шаг 3. Установите инструменты проекта

```bash
rokit install
rojo --version
```

Должно показать `Rojo 7.7.1`.

## Шаг 4. Установите плагин Rojo в Studio

```bash
rojo plugin install
```

После этого перезапустите Roblox Studio.

## Шаг 5. Создайте место (place)

1. Откройте Roblox Studio → **New** → шаблон **Baseplate**.
2. **File → Save to Roblox As…** → назовите `The Last Signal`.
3. **File → Game Settings → Security** → включите **Enable Studio Access to API Services**.

## Шаг 6. Подключите Rojo

1. В терминале, в папке репозитория: `rojo serve` (окно не закрывайте).
2. В Studio: вкладка **Plugins** → **Rojo** → **Connect**.
3. Нажмите **Play**. В окне **Output** (View → Output) должны появиться строки:

```text
[TLS:Server] THE LAST SIGNAL v0.1.0 started: 0 services, 0 systems
[TLS:Client] Client started: 0 controllers
```

Если строки появились — всё работает.

## Шаг 7. Резервные копии карты

После каждой работы в Studio: **File → Save to File As…** → сохраните файл
`TheLastSignal_ГГГГ-ММ-ДД.rbxl` в отдельную папку вне репозитория. Храните несколько копий.

## Чего делать нельзя

- Не создавайте объекты вручную внутри папок `ReplicatedStorage.Shared`,
  `ReplicatedStorage.Config`, `ServerScriptService.TheLastSignal` и
  `StarterPlayerScripts.TheLastSignal` — Rojo удалит их при синхронизации.
- Не редактируйте скрипты в Studio — изменения потеряются. Код меняется только в репозитории.

## Roblox Studio MCP (необязательно)

MCP-сервер позволяет ИИ-ассистенту напрямую работать со Studio. Он запускается на вашем
компьютере рядом со Studio, поэтому доступен только ассистенту, запущенному локально.
Официальный репозиторий: <https://github.com/Roblox/studio-rust-mcp-server>.

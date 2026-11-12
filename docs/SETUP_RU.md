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
[TLS:Server] THE LAST SIGNAL v0.2.0 started: 3 services, 2 systems
[TLS:Client] Client started: 1 controllers
```

Если строки появились — всё работает.

## Шаг 7. Резервные копии карты

После каждой работы в Studio: **File → Save to File As…** → сохраните файл
`TheLastSignal_ГГГГ-ММ-ДД.rbxl` в отдельную папку вне репозитория. Храните несколько копий.

## Черновая карта STATION-09

Карту создаёт отдельный инструмент — он не часть игры и сам ничего не запускает.
Подробности (на английском): [MAP_GENERATOR.md](MAP_GENERATOR.md).

1. Rojo подключён, игра **остановлена**.
2. Откройте **View → Command Bar**, вставьте строку и нажмите Enter:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).generate()
   ```

3. В Output появится строка `[TLS:MapGenerator] Created Workspace.Station09: …`.
4. В Explorer выберите `Workspace → Station09` и нажмите **F** — камера перейдёт к карте
   (она находится под Baseplate).
5. Чтобы увидеть планировку сверху, скройте потолки:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).setCeilingsVisible(false)
   ```

   Вернуть потолки — та же команда с `true`.
6. Чтобы пройтись по карте: наведите камеру на пол комнаты `A_Elevator`, нажмите правой
   кнопкой по полу → **Play Here**.

Правила безопасности инструмента:

- Он создаёт только `Workspace.Station09` и больше ничего не трогает.
- Повторный `generate()` ничего не меняет.
- `regenerate()` не удаляет старую карту, а переносит её в `ServerStorage.TLS_MapBackups`.
- Свои объекты стройте в отдельной папке, например `Workspace.Station09_Custom`, а не
  внутри `Station09` — иначе при `regenerate()` они уедут в резервную копию вместе с картой.

## Чего делать нельзя

- Не создавайте объекты вручную внутри папок `ReplicatedStorage.Shared`,
  `ReplicatedStorage.Config`, `ServerScriptService.TheLastSignal` и
  `StarterPlayerScripts.TheLastSignal` — Rojo удалит их при синхронизации.
- Не редактируйте скрипты в Studio — изменения потеряются. Код меняется только в репозитории.

## Roblox Studio MCP (необязательно)

MCP-сервер позволяет ИИ-ассистенту напрямую работать со Studio. Он запускается на вашем
компьютере рядом со Studio, поэтому доступен только ассистенту, запущенному локально.
Официальный репозиторий: <https://github.com/Roblox/studio-rust-mcp-server>.

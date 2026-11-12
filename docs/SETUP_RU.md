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

## Как получать обновления кода

Весь готовый код находится в одной основной ветке — `hoplite/katane-c6d07c95`. Работайте
только в ней. Каждый раз, когда ассистент сообщает о новых изменениях:

1. Остановите `rojo serve` (Ctrl+C в его окне).
2. В папке репозитория выполните:

   ```bash
   git fetch origin
   git checkout hoplite/katane-c6d07c95
   git pull
   ```

3. Снова запустите `rojo serve`.
4. В Studio: **Plugins → Rojo → Disconnect**, затем **Connect**. Если плагин показывает
   список изменений — нажмите **Accept**.

Перезапуск `rojo serve` обязателен, когда менялся файл `default.project.json`: работающий
сервер может продолжать отдавать старую структуру.

## Шаг 7. Резервные копии карты

После каждой работы в Studio: **File → Save to File As…** → сохраните файл
`TheLastSignal_ГГГГ-ММ-ДД.rbxl` в отдельную папку вне репозитория. Храните несколько копий.

## Черновая карта STATION-09

Карту создаёт отдельный инструмент — он не часть игры и сам ничего не запускает.
Подробности (на английском): [MAP_GENERATOR.md](MAP_GENERATOR.md).

Все команды вставляются в **View → Command Bar** при **остановленной** игре (режим
редактирования). В режиме Play генератор откажется работать.

1. Обновите код и переподключите Rojo (раздел «Как получать обновления кода» выше).
2. Проверьте, что генератор попал в Studio. В Explorer должно быть
   `ServerStorage → TLS_DevTools → MapGenerator`. Или выполните:

   ```lua
   local t = game.ServerStorage:FindFirstChild("TLS_DevTools") print(t and t:FindFirstChild("MapGenerator") and "MapGenerator OK" or "MapGenerator missing")
   ```

3. Создайте карту. Если карты ещё нет:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).generate()
   ```

   Если карта уже есть и нужно построить новую версию:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).regenerate()
   ```

   Старая карта не удаляется — она переносится в `ServerStorage → TLS_MapBackups`.
4. В Output появится строка `[TLS:MapGenerator] Created Workspace.Station09: …`.
5. В Explorer выберите `Workspace → Station09` и нажмите **F**. Карта находится под
   Baseplate — опустите камеру ниже.
6. Скройте потолки и крышу, чтобы видеть комнаты сверху и выделять объекты внутри:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).hideCeilings()
   ```

   Вернуть их:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).showCeilings()
   ```

   Перед тестом игры потолки нужно вернуть — скрытые потолки остаются скрытыми и в игре.
7. Чтобы осмотреть одну комнату: выберите её папку в Explorer (например
   `B_Corridors → B_MainCorridor`) и нажмите **F**.
8. Чтобы пройтись по карте: наведите камеру на пол комнаты `A_Elevator`, нажмите правой
   кнопкой по полу → **Play Here**.

Правила безопасности инструмента:

- Он создаёт только `Workspace.Station09` и больше ничего не трогает.
- Повторный `generate()` ничего не меняет.
- `regenerate()` не удаляет старую карту, а переносит её в `ServerStorage.TLS_MapBackups`.
- Одинаковая планировка всегда даёт одинаковую карту с теми же именами объектов.
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

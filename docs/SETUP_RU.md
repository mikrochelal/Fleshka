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
[TLS:Server] THE LAST SIGNAL v0.3.0 started: 6 services, 14 systems
[TLS:Client] Client started: 7 controllers
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
6. Посмотрите на станцию сверху. Команда сама скрывает потолки и ставит камеру над картой:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).viewFromAbove()
   ```

   Над станцией находится Baseplate, и камера не видит сквозь него, поэтому вся станция в
   кадр может не поместиться — об этом будет строка в Output. Тогда смотрите по комнатам:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).viewFromAbove("MainCorridor")
   ```

   Подходят имена комнат из Explorer без префикса зоны: `Lobby`, `MainCorridor`,
   `Junction`, `MainLab`, `CommCenter` и другие.
7. Скрыть или вернуть потолки отдельно:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).hideCeilings()
   ```

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).showCeilings()
   ```

   Скрываются только потолки, секции крыши и верхняя часть скалы. Полы, стены и дверные
   рамы не меняются. При запуске игры потолки показываются автоматически.
8. По желанию — тёмное базовое освещение (убирает солнце и свет неба, чтобы комнаты
   освещались только своими лампами):

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).applyLightingPreset()
   ```

   Вернуть прежнее освещение:

   ```lua
   require(game.ServerStorage.TLS_DevTools.MapGenerator:Clone()).restoreLighting()
   ```

9. Чтобы пройтись по карте: наведите камеру на пол комнаты `A_Elevator`, нажмите правой
   кнопкой по полу → **Play Here**.

Правила безопасности инструмента:

- `generate()` и `regenerate()` создают только `Workspace.Station09` и больше ничего не
  трогают. Камеру редактора двигает только `viewFromAbove()`, а свойства `Lighting` меняет
  только `applyLightingPreset()` — и это отменяется командой `restoreLighting()`.
- Повторный `generate()` ничего не меняет.
- `regenerate()` не удаляет старую карту, а переносит её в `ServerStorage.TLS_MapBackups`.
- Одинаковая планировка всегда даёт одинаковую карту с теми же именами объектов.
- Свои объекты стройте в отдельной папке, например `Workspace.Station09_Custom`, а не
  внутри `Station09` — иначе при `regenerate()` они уедут в резервную копию вместе с картой.

## Как пройти игровой срез (версия 0.3.0)

Нужна сгенерированная карта `Workspace.Station09` (раздел выше) и подключённый Rojo.
Перед тестом верните потолки командой `showCeilings()` — или не возвращайте: при запуске
игры они показываются сами.

Управление: **Shift** — бег, **F** — фонарик, **E** — взаимодействие, **X** — закрыть
документ. На телефоне — кнопки RUN и LIGHT справа.

1. Нажмите **Play**. Через несколько секунд появится заставка STATION-09, затем вы
   окажетесь в лифте. Слева вверху — текущая цель, слева внизу — выносливость и заряд
   фонарика.
2. Выйдите из лифта в холл. Цель сменится на «Find the emergency power controls».
   В холле на тумбе лежит документ — подойдите и нажмите **E**.
3. Зайдите в будку охраны (дверь в холле слева от прохода вперёд). Там лежит памятка
   **MAINTENANCE MEMO** — в ней порядок включения трёх щитков. Порядок каждый запуск новый.
4. Дальше темно: включите фонарик (**F**). Щитки находятся в будке охраны, в
   генераторной (Power Room) и в мастерской (Maintenance). Включите их в порядке из
   памятки, затем дёрните рубильник в генераторной.
   - Правильно: свет в коридорах загорается, цель меняется.
   - Неправильно: все щитки сбрасываются, свет мигает — и это слышит не только вы.
5. Найдите заработавшую радиостанцию в комнате мониторов (Monitor Room, с севера от
   главного коридора) и нажмите **E**. Прослушайте передачу до конца.
6. Выйдите в главный коридор. Свет мигнёт, в дальнем конце коридора появится силуэт.
7. Идите на восток до развязки, затем на юг — в центр связи (Comm Center). Используйте
   центральный компьютер.
8. Возвращайтесь к лифту. Теперь существо может преследовать: если экран рябит и
   появилась надпись «IT HAS SEEN YOU» — бегите и уходите из его поля зрения.
9. В лифте нажмите **E** на панели на стене. Экран погаснет, прозвучит последняя фраза,
   появится экран завершения.

Что прислать после теста: всё содержимое окна **Output** (особенно жёлтые и красные
строки) и на каком шаге что-то пошло не так.

## Чего делать нельзя

- Не создавайте объекты вручную внутри папок `ReplicatedStorage.Shared`,
  `ReplicatedStorage.Config`, `ServerScriptService.TheLastSignal` и
  `StarterPlayerScripts.TheLastSignal` — Rojo удалит их при синхронизации.
- Не редактируйте скрипты в Studio — изменения потеряются. Код меняется только в репозитории.

## Roblox Studio MCP (необязательно)

MCP-сервер позволяет ИИ-ассистенту напрямую работать со Studio. Он запускается на вашем
компьютере рядом со Studio, поэтому доступен только ассистенту, запущенному локально.
Официальный репозиторий: <https://github.com/Roblox/studio-rust-mcp-server>.

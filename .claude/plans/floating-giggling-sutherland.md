# Plan: System notifications when the agent needs an answer and the chat window is inactive

> **Implementation target:** `/Volumes/Vault/Documents/Projects/Xcode/Claude-Code`
> (the `Claude Code.xcodeproj` macOS host app), **not** this LiquidGlass package.
> This plan file lives here only because it is the session's plan file.

## Context

Claude Code can block a turn waiting on the user in three ways, all on `ChatViewModel`:

- **Tool permission** — `pendingPermission` (`can_use_tool`)
- **Question** — `pendingQuestion` (an unsettled `AskUserQuestion` row)
- **Plan review** — `pendingPlan` / `pendingPlanText` (`ExitPlanMode`)

All three live only inside the chat window / plan sheet. The host is designed to keep
running when its windows close (`applicationShouldTerminateAfterLastWindowClosed == false`,
`isReleasedWhenClosed = false`), so an agent can sit blocked for a long time with no visible
signal. Add a macOS local notification for each pending ask whenever the chat window is not
active, and clear it once the ask is answered or the chat becomes visible.

`HostWindowCoordinator` already observes `ChatViewModel` even while the chat window is
closed, but that observer (`chatObserver`) is recreated only when chat content is installed.
This feature needs its own dedicated observer so companion-driven prompts with no main
window are still caught.

## Decisions (defaults, since the scoping questions were skipped)

- **Scope:** Claude Code host only. Remote companion and Agmente are out of scope.
- **"Not active":** the chat window (or its attached sheet) is not the key window of an
  active app — covers backgrounded/hidden, minimized, closed, or Settings/launch frontmost.
  Re-evaluated on focus changes, not only when the ask arrives.
- **One banner per ask:** once an ask has been alerted, returning to the chat and leaving
  again does not re-alert for the same ask. A new/replaced ask alerts again.
- **Authorization:** request once, after the launch window is up, when the setting is on;
  add a General settings toggle (default on).
- **Click:** activate the app, deminiaturize, and show the chat. No Allow/Deny actions —
  the user must see the tool arguments before answering.
- **Privacy:** notification copy names the ask, never its payload (no tool arguments, plan
  text, or command lines); lock-screen banners must not leak file contents.

## Architecture

### 1. New mapping type: `Claude Code/Services/Notifications/PendingPromptNotification.swift`

A pure, `nonisolated`, `Sendable` value type plus a builder over `ChatViewModel` (no
UserNotifications import), so identity and copy are centralized and testable:

```swift
#if os(macOS)
nonisolated struct PendingPromptNotification: Sendable, Equatable, Identifiable {
    let id: String              // "permission:<uuid>" / "question:<uuid>" / "plan:<toolUseId>"
    let kind: Kind
    let title: String
    let subtitle: String?       // conversation title, else project name
    let body: String
    let userInfo: [String: String]
}
#endif
```

| Source | Identifier | Title | Body |
|---|---|---|---|
| `pendingPermission` | `permission:<PendingPermission.id>` | reuse “Claude wants to run “\(toolName)”” (same literal as the permission card) | “Waiting for your approval in the chat.” |
| `pendingQuestion` | `question:<ChatMessage.id>` | “Claude has a question” | first question text, whitespace-collapsed, truncated (~160 chars) |
| `pendingPlan` | `plan:<Plan.toolUseId>` | reuse “Review Plan” (same literal as the sheet title) | “Claude is waiting for you to accept or decline the plan.” |

- The **question** draft is emitted only while `chat.isRunning`. `pendingQuestion` is derived
  from transcript rows, and an old unanswered row loaded from disk would otherwise notify on
  `open(_:)` when the window is not key. Permission/plan are only ever set by a live turn.
- `subtitle` uses `chat.conversationTitle ?? catalog.activeProject?.name`.
- `threadIdentifier` = `chat.sessionId ?? "claude-code"`; `sound = .default`; no badge; no
  interruption level (time-sensitive needs an entitlement).
- All copy uses `String(localized:comment:)`; the string catalog is auto-extracted.

### 2. New service: `Claude Code/Services/Notifications/AgentNotificationService.swift`

```swift
final class AgentNotificationService: NSObject, UNUserNotificationCenterDelegate {
    var revealChat: () -> Void = {}      // installed by HostWindowCoordinator

    func start(isEnabled: Bool)          // delegate + purge stale + authorization
    func refreshAuthorization()
    func reconcile(prompts: [PendingPromptNotification],
                   isEnabled: Bool,
                   isChatWindowActive: Bool)
}
```

- Default actor isolation already makes this `@MainActor`; do **not** add `@MainActor`
  (repo convention). It holds a strong `UNUserNotificationCenter` reference.
- `start(isEnabled:)`:
  - `center.delegate = self` (the delegate is weak — the coordinator retains the service).
  - `removeAllDeliveredNotifications()` and clear the tracked sets: nothing can be pending
    before a launch, so any delivered banner is stale from a previous run.
  - `refreshAuthorization()`; when enabled and `.notDetermined`, request
    `[.alert, .sound]`. Called after `showWelcome()` so the system prompt appears over the
    active app.
- Two sets, with distinct meanings:
  - `delivered` — identifiers currently in Notification Center.
  - `notified` — asks already alerted. This is what makes it one banner per ask: a focus
    return removes the banner but keeps `notified`, so a later alt-tab does not re-alert.
- `reconcile(prompts:isEnabled:isChatWindowActive:)`:
  1. `pendingIDs = Set(prompts.map(\.id))`; drop ids from `delivered`/`notified` that are no
     longer pending (answered, replaced, turn stopped) and remove their delivered banners.
  2. If `!isEnabled`: remove all delivered, clear `notified`, return.
  3. If `isChatWindowActive`: remove delivered for still-pending ids, **keep** `notified`,
     return.
  4. If unauthorized: remove delivered, return.
  5. Otherwise post every pending id not in `notified`; insert into `delivered` **and**
     `notified` **before** awaiting `center.add` (re-entrancy guard). On add failure remove
     the id from both so a later pass retries.
- Authorization status is not static: `refreshAuthorization()` on
  `NSApplication.didBecomeActiveNotification` and before the Settings pane's rebuild.
  Use a continuation helper that only lets a `Bool` cross the isolation boundary — never
  pass `UNNotificationSettings` across.
- Delegate methods are **nonisolated** requirements under Swift 6 complete checking; use the
  async variants (available at the macOS 12 floor):
  - `willPresent` → `[.banner, .list, .sound]`. **Not `[]`:** when Settings is frontmost the
    app is active while the chat is not, so a notification delivered then would otherwise be
    a silent Notification Center entry.
  - `didReceive` → ignore everything except `UNNotificationDefaultActionIdentifier`; read
    only the identifier `String` from the response, then
    `await MainActor.run { NSApp.activate(...); self.revealChat() }`. Never capture
    `UNNotificationResponse`/`UNNotification`/a completion handler across the hop.
  - Do not implement both async and completion-handler forms. If the SDK raises a Sendable
    diagnostic, use `@preconcurrency import UserNotifications`; try without it first.

### 3. Wiring: `Claude Code/AppKit/Windows/HostWindowCoordinator.swift`

- The coordinator owns the service (constructed in its `init`, no app-target changes); this
  also avoids touching `UNUserNotificationCenter` before `NSApplication.run()`.
- In `start()`, after `showWelcome()`:
  - `agentNotifications.revealChat = { [weak self] in self?.revealChat() }`
  - `agentNotifications.start(isEnabled: chat.settings.notificationsEnabled)`
  - create a dedicated
    `MainActorObjectObserver(chat, coalesce: 0.2) { [weak self] in self?.syncAgentNotifications() }`
    stored in its own property — do not reuse `chatObserver`, which is cancelled/recreated by
    `installMainContent()` and absent with no main window.
  - register selector observers for `NSApplication.didBecomeActiveNotification` /
    `didResignActiveNotification`; on active also call
    `agentNotifications.refreshAuthorization()`.
- `chatIsActive()` must mean "the user can see and answer the chat":
  ```swift
  guard NSApp.isActive, conversation != nil, let mainWindow else { return false }
  if mainWindow.isKeyWindow { return true }
  if let key = NSApp.keyWindow, key.sheetParent === mainWindow { return true }
  return false
  ```
  - The sheet clause is required: the plan review sheet is its own key window, so without it
    a notification fires while the user is staring at the plan.
  - `conversation != nil` excludes the key main window showing `HostNoProjectViewController`.
- `revealChat()` must not use `showActiveWindow()` (it falls through to `showWelcome()` when
  `mainWindow == nil`, even with an active project):
  ```swift
  if catalog.activeProject != nil { showMain() } else { showWelcome() }
  mainWindow?.deminiaturize(nil)
  mainWindow?.makeKeyAndOrderFront(nil)
  NSApp.activate(ignoringOtherApps: true)
  ```
  Also add `mainWindow?.deminiaturize(nil)` inside `showMain()` before its
  `makeKeyAndOrderFront`.
- `syncAgentNotifications()`:
  ```swift
  let prompts = chat.settings.notificationsEnabled
      ? PendingPromptNotification.drafts(from: chat, subtitle: ...)
      : []
  agentNotifications.reconcile(
      prompts: prompts,
      isEnabled: chat.settings.notificationsEnabled,
      isChatWindowActive: chatIsActive())
  ```
- Add the currently-missing `NSWindowDelegate` methods (the class already conforms and is the
  delegate for both windows): `windowDidBecomeKey`, `windowDidResignKey`,
  `windowDidMiniaturize`, `windowDidDeminiaturize`, and `windowWillClose`.
  - Everything except close is post-state and safe to sync directly.
  - **`windowWillClose` fires while the window is still key**: defer one turn with
    `Task { @MainActor [weak self] in self?.syncAgentNotifications() }`, otherwise closing
    the window with a pending ask silently posts nothing and no later event fires.
  - Coalesce focus-driven syncs by one runloop tick so `showMain()`'s close-welcome →
    `makeKeyAndOrderFront` sequence cannot flash a banner.

### 4. Settings

- `Claude Code/Models/AppSettings.swift`:
  - Add **`var notifyWhenWindowInactive: Bool?`** plus a computed
    `var notificationsEnabled: Bool { get { notifyWhenWindowInactive ?? true } set { ... } }`.
  - It must be optional: synthesized `Decodable` uses `decode` for non-optional stored
    properties and **ignores default values**, so a missing key throws; `AppSettings.load()`
    then falls back to a fully default value and silently wipes every existing setting.
  - Put it in the existing “Front-end behaviour” section (settings-blob convention).
- `Claude Code/AppKit/Settings/Panes/Behaviour/HostGeneralSettingsViewController.swift`:
  - Add a `private let viewModel: ChatViewModel` and init parameter; pass
    `viewModel: viewModel` from `HostSettingsWindowController.init` where the `.general` tab
    is built (matching `.permissions` / `.acp`).
  - Add a **Notifications** section after “CLI Defaults” with one `ClosureToggle`
    (pattern at `HostPermissionsSettingsViewController.swift:116-124`):
    - Label: “Notify me when the chat needs an answer”
    - Caption: “Shows a system notification when a permission, question, or plan is waiting
      while the chat window isn’t active.”
    - `onToggle` → `viewModel.settings.notificationsEnabled = value` then
      `viewModel.persistSettings()` immediately. The `@Published settings` write wakes the
      notification observer, which removes delivered banners when switched off.
  - Do **not** add `observeObject(viewModel)` to the pane: a rebuild on every chat change
    would drop focus in the CLI-defaults text fields.
  - Optional polish: a caption plus an “Open System Settings” button when authorization is
    denied. `requestAuthorization` never re-prompts after a denial; surface the state instead.

### 5. Project configuration

- No entitlement, Info.plist, or pbxproj change: local notifications need none, the host is
  not sandboxed, the deployment floor is macOS 12, and `import UserNotifications` is
  auto-linked under Swift. Bundle id `com.joenpersonalteam.ClaudeCode` and ad-hoc signing are
  sufficient (fully unsigned builds are not).
- New files under `Claude Code/Services/Notifications/` compile automatically through the
  target's `PBXFileSystemSynchronizedRootGroup`; wrap AppKit/UN code in `#if os(macOS)` per
  the folder convention.

## Edge cases

- **Plan sheet frontmost:** treated as active via the `sheetParent` check — no notification
  while the user is reading the plan; alt-tab away notifies.
- **Settings/launch window frontmost, chat not key:** notify, and `willPresent` makes the
  banner visible even though the app is active.
- **Window closed with a pending ask:** `windowWillClose` is deferred one turn so the
  post-close state is sampled; clicking the banner recreates/shows the window.
- **Minimized:** notify; clicking deminiaturizes.
- **Replaced permission:** new `PendingPermission.id` → old banner removed, new alert posted.
- **Several asks at once:** one notification each, distinct prefixed identifiers.
- **Answered from the Remote companion:** the shared `chat` model changes → reconcile clears
  the host banner.
- **Prompt arrives while focused, user leaves:** `didResignActive`/`didResignKey` posts it.
- **User returns to the chat:** banners are removed; `notified` is kept, so leaving again
  does not re-alert for that ask.
- **Conversation/project change:** `newChat()` / `open(_:)` abandon the pending permission
  and clear the pending plan → reconcile removes their banners and history.
- **Historical unanswered question loaded from disk:** suppressed by the `chat.isRunning`
  guard in the draft builder.
- **Authorization denied / Focus / DND:** posting is a no-op or the system suppresses it; the
  in-app card is unaffected; re-check status on activation and when Settings opens.
- **Multi-display:** a chat visible on another display still counts as inactive when another
  app is frontmost. Accepted; occlusion tracking is not worth it.
- **Ad-hoc signing:** local notifications normally work; verify authorization in a real run
  first.

## Out of scope

Remote companion (iOS/macOS) notifications, Agmente, notification action buttons, Dock icon
bounce, and “turn finished” notifications.

## Verification (manual; no app test target)

1. **Smoke-test authorization first:** build and run; the system prompt appears over the
   launch window, System Settings → Notifications lists “Claude Code”, and
   `GetConsoleOutput` shows no `UNUserNotificationCenter` errors.
2. **Old-blob decode:** write a settings blob without the new key, relaunch; working
   directory/model/backend survive and notifications default on.
3. Build the `Claude Code` scheme with the xcode MCP `BuildProject` (no app test target; do
   not use `RunAllTests`). Zero Swift 6 strict-concurrency diagnostics.
4. `RunProject`, then in Manual permission mode ask Claude to run a harmless command
   (`touch /tmp/lg-notify-test`) and switch to Finder before answering:
   - banner appears; no banner while the chat window stays key;
   - click activates, deminiaturizes, and shows the chat;
   - Allow/Deny removes it from Notification Center.
5. Repeat for `AskUserQuestion` (live turn only) and a plan-mode `ExitPlanMode` prompt.
   With the plan sheet frontmost, confirm **no** notification; alt-tab away → notification;
   click → chat + sheet.
6. Settings window frontmost while the chat is not key → banner appears (proves
   `willPresent`); click routes to the chat.
7. Close the main window with a pending permission → notification posts (proves the deferred
   `windowWillClose`); click recreates/shows the window. Repeat with minimize.
8. Return to the chat → banner clears; leave again → it does **not** re-alert. Answer in-app
   or from the companion while away → banner clears.
9. Toggle off → new prompts silent and existing banners cleared; toggle on → next ask
   banners. Deny in System Settings, re-enable while running, switch away → works without
   relaunch.
10. `RunCodeSnippet` the pure draft mapping for all three kinds.
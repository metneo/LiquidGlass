# Plan: System notifications when the agent needs an answer and the chat window is inactive

> **Implementation target:** `/Volumes/Vault/Documents/Projects/Xcode/Claude-Code`
> (the `Claude Code.xcodeproj` macOS host app), **not** this LiquidGlass package.
> This plan file lives here only because it is the session's plan file.

## Context

Claude Code can block a turn waiting on the user in three ways:

- **Tool permission** — `ChatViewModel.pendingPermission` (`can_use_tool`)
- **Question** — `ChatViewModel.pendingQuestion` (an unsettled `AskUserQuestion` row)
- **Plan review** — `ChatViewModel.pendingPlan` / `pendingPlanText` (`ExitPlanMode`)

All three currently live only inside the chat window / plan sheet. The host app is
explicitly designed to keep running when its windows close
(`applicationShouldTerminateAfterLastWindowClosed == false`, `isReleasedWhenClosed = false`),
so an agent can sit blocked for a long time with no visible signal. The goal is a macOS
local notification for each pending ask whenever the chat window is not active, cleared
once the ask is answered or the chat becomes visible again.

The host already has the right single observation point: `ChatViewModel` is owned by
`ClaudeCodeApp`, re-publishes both the `@Observable` (macOS 14+) and `ObservableObject`
(macOS 12) implementations through `objectWillChange`, and its pending fields are derived
from whichever backend runs (CLI or ACP). `HostWindowCoordinator.chatObserver` keeps
observing even while the chat window is closed.

## Decisions (defaults, since the scoping questions were skipped)

- **Scope:** Claude Code host only. Remote companion and Agmente are out of scope.
- **"Not active":** notify whenever the chat window is not the key window of an active app —
  covers backgrounded/hidden, minimized, closed, or the app frontmost while Settings/launch
  is key. Re-evaluate on focus changes, not only when the ask arrives.
- **Authorization:** request once at launch when the setting is on; add a General settings
  toggle (default on).
- **Click:** activate the app and bring the chat window forward. No Allow/Deny action
  buttons — the user should see the tool arguments in the app before answering.
- **Privacy:** the notification names the ask, never its payload (no tool arguments, no plan
  text, no command lines) so lock-screen banners don't leak file contents.

## Architecture

### 1. New service: `Claude Code/Services/Notifications/AgentNotificationService.swift`

```swift
final class AgentNotificationService: NSObject, UNUserNotificationCenterDelegate {
    var isChatWindowActive: () -> Bool = { false }   // set by HostWindowCoordinator
    var revealChat: () -> Void = {}                  // set by HostWindowCoordinator

    func start(isEnabled: Bool)                      // delegate + authorization + purge stale
    func reconcile(drafts: [PendingPromptNotification])
}
```

- Types are already main-actor-isolated by default
  (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`); do **not** add `@MainActor`.
- `start(isEnabled:)` is called from `ClaudeCodeApp.applicationWillFinishLaunching`
  (not from the coordinator) so the delegate is installed before launch completes — that is
  what lets a click that launched the app route correctly:
  - `UNUserNotificationCenter.current().delegate = self`
  - `removeAllDeliveredNotifications()` and clear the tracked set — nothing can be pending
    before a launch, so any delivered banner is stale from a previous run.
  - when enabled, `requestAuthorization(options: [.alert, .sound])` and cache the result;
    refresh it on `NSApplication.didBecomeActiveNotification`.
- `reconcile(drafts:)` is the whole delivery policy:
  - If authorization is `.notDetermined` and a draft is waiting, request it once and re-run
    reconciliation on completion — this covers a user who launches with the toggle off and
    enables it later.
  - Desired = drafts when authorized, otherwise empty.
  - Add missing identifiers via `UNNotificationRequest(identifier:content:trigger: nil)`;
    track them in a `delivered: Set<String>`. Insert optimistically; if `add` fails, remove
    from the set so a later sync retries.
  - Remove identifiers that are tracked but no longer desired with
    `removeDeliveredNotifications(withIdentifiers:)` — also covers toggle-off, focus return,
    and answered prompts.
  - Stable identifiers make reconciliation idempotent; unrelated transcript changes do not
    re-alert.
- `UNUserNotificationCenterDelegate` callbacks are **not** main-actor under Swift 6 complete
  checking. The deployment floor is macOS 12, so use the async delegate variants and mark
  them `nonisolated`:
  - `userNotificationCenter(_:willPresent:) async -> []` — we never post while active; this
    guards same-tick focus changes.
  - `userNotificationCenter(_:didReceive:) async` → `await MainActor.run { self.revealChat() }`
    (the async variant is called off the main executor). Handle the default action only.
  - Do not implement both the async and completion-handler forms of the same method.

### 2. Draft mapping: `Claude Code/Services/Notifications/PendingPromptNotification.swift`

A pure value type plus one builder over `ChatViewModel`, so content and identity are in one
place and can be exercised with `RunCodeSnippet`:

```swift
struct PendingPromptNotification {
    enum Kind: String { case permission, question, plan }
    let kind: Kind
    let identifier: String
    let title: String
    let subtitle: String?          // conversation title, else active project name
    let body: String
    let userInfo: [String: String]
}
```

| Source | Identifier | Title | Body |
|---|---|---|---|
| `pendingPermission` | `permission.<PendingPermission.id>` | reuse “Claude wants to run “\(toolName)”” (same literal as the permission card) | “Waiting for your approval in the chat.” |
| `pendingQuestion` | `question.<ChatMessage.id>` | “Claude has a question” | first question text, whitespace-collapsed and truncated (~160 chars) |
| `pendingPlan` | `plan.<Plan.toolUseId>` | reuse “Review Plan” (same literal as the sheet title) | “Claude is waiting for you to accept or decline the plan.” |

- `threadIdentifier` = `chat.sessionId ?? "claude-code"` (keeps a conversation's banners
  grouped).
- `sound = .default`; no badge; no interruption level (time-sensitive needs an entitlement).
- `userInfo`: `kind`, prompt id, and `sessionId` for future routing.
- All copy uses `String(localized:comment:)`; the string catalog is auto-extracted, so no
  `Localizable.xcstrings` edit is needed.

### 3. Wiring: `Claude Code/AppKit/Windows/HostWindowCoordinator.swift`

- Construct the service in `ClaudeCodeApp.init` (same manual-constructor pattern as
  `companion`/`acpServer`/`mcpServer`) and:
  - `applicationWillFinishLaunching` → `agentNotifications.start(isEnabled:)`, so the
    delegate exists before launch completes.
  - pass it into `HostWindowCoordinator.init`; store it as `private let agentNotifications`.
- In the coordinator's `start()` (not `installMainContent()`, which only exists once a
  project chat is built):
  1. Install closures:
     - `isChatWindowActive`: `NSApp.isActive && (NSApp.keyWindow === mainWindow ||
       NSApp.keyWindow === mainWindow?.attachedSheet)`. The sheet clause matters because the
       plan review sheet is its own window and takes key status while it is up — without it
       we would notify about a plan the user is looking at. A minimized/closed window is
       never key.
     - `revealChat`: existing `showActiveWindow()`, which activates the app and routes to
       `showMain()` / `showWelcome()`.
  2. Add a dedicated
     `MainActorObjectObserver(chat, coalesce: 0.1) { [weak self] in self?.syncAgentNotifications() }`.
     This exists regardless of whether a chat window was ever opened.
  3. Register selector-based observers for
     `NSApplication.didBecomeActiveNotification` / `didResignActiveNotification`.
- Add the currently-missing `NSWindowDelegate` methods (the class already conforms and is the
  delegate for both windows): `windowDidBecomeKey`, `windowDidResignKey`,
  `windowDidMiniaturize`, `windowDidDeminiaturize`, `windowWillClose` (plus the sheet-related
  key changes are covered by `NSApplication.didBecomeActive`/`didResignActive` and the
  attached-sheet check above). Route focus-driven calls through a one-runloop coalescer so
  `showMain()`'s close-welcome → `makeKeyAndOrderFront` sequence cannot flash a banner.
- `syncAgentNotifications()`:
  ```swift
  let subtitle = chat.conversationTitle ?? catalog.activeProject?.name
  let enabled = chat.settings.notificationsEnabled
  let drafts = (enabled && !agentNotifications.isChatWindowActive)
      ? PendingPromptNotification.drafts(from: chat, subtitle: subtitle)
      : []
  agentNotifications.reconcile(drafts: drafts)
  ```
- The notification observer and focus hooks are the only change needed here; `chatChanged()`
  stays focused on title/turn/session bookkeeping.

### 4. Settings

- `Claude Code/Models/AppSettings.swift`:
  - Add **`var notifyWhenWindowInactive: Bool?`** and a computed
    `var notificationsEnabled: Bool { get { notifyWhenWindowInactive ?? true } set { ... } }`.
    It must be optional: `AppSettings` uses the synthesized `Decodable`, and a new
    non-optional key would make every existing user's blob fail to decode and silently
    reset all settings (`AppSettings.load()` falls back to `AppSettings()`).
  - Place it in the existing “Front-end behaviour” section (settings-blob convention), since
    it is changed only from Settings and never reaches the SDK.
- `Claude Code/AppKit/Settings/Panes/Behaviour/HostGeneralSettingsViewController.swift`:
  - The General pane currently takes only `environment`; give it the shared
    `ChatViewModel` (mirroring `HostPermissionsSettingsViewController` /
    `HostBackendSettingsViewController`).
  - Pass `viewModel: viewModel` from `HostSettingsWindowController.init`
    (where the `.general` tab is constructed).
  - Add a **Notifications** section with one `ClosureToggle` (pattern at
    `HostPermissionsSettingsViewController.swift:116-124`):
    - Label: “Notify when Claude needs a response”
    - Subtitle: “Shows a system notification when a permission, question, or plan is waiting
      while the chat window isn’t active.”
    - `onToggle` → `viewModel.settings.notificationsEnabled = value` then
      `viewModel.persistSettings()` immediately (a single bool; the General pane's existing
      debouncer is for `settings.json`, not this blob). The `@Published settings` write wakes
      the chat observer, and `syncAgentNotifications()` removes delivered banners when
      switched off — no direct service reference is needed in the pane.

### 5. Project configuration

- No entitlement, Info.plist, or pbxproj change: local notifications need none, the host is
  not sandboxed, the deployment floor is macOS 12 (`UserNotifications` is available since
  10.14), and `import UserNotifications` is auto-linked under Swift.
- New files under `Claude Code/Services/Notifications/` compile automatically through the
  target's `PBXFileSystemSynchronizedRootGroup`.

## Edge cases

- **Replaced permission:** new `PendingPermission.id` → old banner removed, new posted.
- **Several asks at once:** one notification each, distinct identifiers.
- **Answered from the Remote companion:** the shared `chat` model changes → `sync` clears
  the host banner.
- **Prompt arrives while focused, user leaves:** the resign-key/didResignActive hook posts it
  then.
- **User returns to the chat:** banners for still-pending asks are removed; the in-app card
  or sheet is visible.
- **Conversation/project change:** `newChat()` / `open(_:)` already abandon the pending
  permission and clear the pending plan, so reconciliation removes their banners.
- **Authorization denied / Focus / Do Not Disturb:** posting is a no-op or the system
  suppresses it; the in-app card is unaffected; the toggle remains.
- **Ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`, no entitlements):** local notifications
  normally work, but this is the one environmental risk — verify authorization in a real run
  first (see Verification step 1).
- **Plan revised in place:** same `toolUseId`; leave the existing banner alone (generic copy).

## Out of scope

- Remote companion (iOS/macOS) local notifications, Agmente, notification action buttons,
  Dock icon bounce, and “turn finished” notifications.

## Verification

1. **Smoke-test authorization first:** build and run; confirm the system permission prompt
   appears, System Settings → Notifications lists “Claude Code”, and `GetConsoleOutput`
   shows no `UNUserNotificationCenter` errors. If ad-hoc signing blocks it, resolve that
   before continuing.
2. Build the `Claude Code` scheme with the xcode MCP `BuildProject` (there is no app test
   target; do not use `RunAllTests`).
3. `RunProject`, then in Manual permission mode ask Claude to run a harmless command
   (e.g. `touch /tmp/lg-notify-test`) and switch to Finder before answering:
   - the banner appears; no banner appears while the chat window stays key;
   - clicking the banner activates the app and shows the chat;
   - Allow/Deny removes it from Notification Center.
4. Repeat for `AskUserQuestion` and for a plan-mode `ExitPlanMode` prompt.
5. Switch away after a prompt is already pending → the banner appears on resign-key.
6. Return to the chat → the delivered banner is cleared.
7. Toggle the Settings switch off → existing banners clear and new prompts stay silent.
8. Quit and relaunch → no stale banners survive.
9. `RunCodeSnippet` the pure draft mapping for all three kinds; inspect `GetBuildLog` for
   concurrency warnings in the nonisolated delegate methods.
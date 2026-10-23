# Installation guide for clubs

This guide is for the person in your club who sets up the shared device. You do not have to be a programmer, but you do need admin access to zweef.app. Expect it to take about an hour.

It describes the usual setup: one iPad in the workshop. The app also runs on an iPhone, and the steps are the same there — each device keeps and uploads its own hours.

## What you need
- An iPhone or iPad running iOS/iPadOS 26 or later. For the workshop, an iPad with a stand or a wall mount.
- A zweef.app account with access to the admin pages (to create an API key).
- Your club's **schema name** in zweef.app (you will find it in the club settings).

## Step 1 — Create an API key in zweef.app
1. Log in to zweef.app with an admin account.
2. Go to the admin pages and create an API key (API token).
3. Store the key in a password manager. You will need it in step 3.

**Read this before you continue.** That key opens your club's whole zweef.app
account — every member's address and date of birth, the financial ledgers, the
ability to change accounts and flights. The app stores it in the device's
Keychain and only ever uses six endpoints, but anyone who gets the key off the
device has all of it. So:

- Keep the shared device physically secured, and set a device passcode.
- If the device is lost or stolen, create a new key in zweef.app straight away
  and enter it on any other device that used the old one.
- See [SECURITY.md](../SECURITY.md) and
  [ADR 0013](decisions/0013-no-proxy.md) for the full picture.

## Step 2 — Find your club's schema name
It is in your club settings in zweef.app — a short identifier that appears in
the API's address. You need it in step 3.

## Step 3 — Install the app
Three ways, depending on what your club has.

**Build it yourself** (no Apple Developer Program needed, good for one device):
install Xcode on a Mac, follow the [README](../README.md#building-it-yourself),
plug the device in and run. A free Apple ID signs the app for seven days, after
which you plug it in again — tedious for a wall-mounted device, fine for trying
it out.

**TestFlight** (needs the Apple Developer Program, €99/year) is what most clubs
will want:

1. In App Store Connect, create an app record with the bundle identifier from
   your `Config/Local.xcconfig`.
2. In Xcode: Product › Archive, then Distribute App › TestFlight & App Store.
3. Add the people who set up devices as internal testers. Builds last 90 days
   and update over the air, so a device on a wall keeps itself current.

**Apple Business Manager / MDM**, if the club already has one: distribute the
app to the device and push the `clubSchema` and `closingTime` keys with it
([configuration.md](configuration.md)). The API key is never pushed — a managed
configuration is readable on the device — so it is still typed once per device.

The app is not on the App Store. It is one club's tool, and publishing it would
mean a review process for a screen full of Dutch member names.

## Step 4 — First launch
The app opens with the setup assistant:
1. **Connection**: fill in the schema name and the API key. Tap **Test connection**; you should see the active maintenance period.
2. **Club**: type your club's name — it becomes the title on the home screen. (zweef.app is supposed to supply it, but that endpoint is currently broken, so the field is filled in for you only when it answers.) After that, set the closing time (when forgotten timers stop automatically).
3. **Logo**: pick your club's logo from Photos. It is shown large on the home screen. You can skip it and add it later in Settings.
4. **Admin code**: six digits. Store them with your other club passwords; without this code you can no longer change the settings. Three wrong attempts are free, after that the app makes you wait a little longer each time.
5. **Done**: the members are fetched as soon as there is internet. (zweef.app has no member photos, so the app shows initials.)

## Step 5 — Lock the shared device into the app
Only for the shared workshop device; skip this on a personal phone.

1. Settings › Accessibility › Guided Access: turn it on and set a passcode.
2. Open the app and triple-click the side or home button to start Guided Access.
3. Set Settings › Display & Brightness › Auto-Lock to "Never" (the app dims itself).
4. Keep the device on its charger.

## Language
The app is available in English, Dutch and French and follows the device's language — so set the device to the language your members read. You can change it per app in Settings › Winter › Language. On a device in any other language, the app shows English.

What members pick when they stop is your club's material from zweef.app — aircraft, rolling stock and projects, in the same three tabs as zweef.app's own form — so there is no task list to keep up. Add or rename material in zweef.app; the app follows at the next refresh.

## Changing settings later
Press and hold the title (your club's name) for 3 seconds and enter the admin code. You can then change the connection, the token, the closing time, the logo and the admin code, and test the connection again.

## Troubleshooting
| Problem | Solution |
|---|---|
| "Connection refused" | The API key is wrong or has been revoked. Check it in Settings. |
| The status button stays orange | No internet. The hours are safe; open the sync screen to see how many are waiting. |
| A session is "rejected" on the sync screen | zweef.app did not accept the registration (e.g. the member is no longer active). Fix it in zweef.app and tap "Retry". |
| The wrong club name | The name comes from zweef.app; change it there. The app picks it up on the next refresh. |
| A new member is missing | The app checks zweef.app every six hours. To fetch now, pull down on the member list. |
| Admin code forgotten | Delete the app and reinstall it. **Careful:** sessions that have not been uploaded yet are lost. Check the sync screen first to see whether everything has been uploaded. |
| Too many wrong codes | The wait grows to at most five minutes. It does not reset by force-quitting the app; just wait. |
| The device is stolen or lost | Create a new API key in zweef.app immediately, and enter it on every other device that used the old one. |
| A timer from the workshop iPad is missing on a phone | Timers stay on the device they were started on. Stop it on that iPad; after upload, all hours come together in zweef.app. |

# Installation guide for clubs

This guide is for the person in your club who sets up the iPad. You do not have to be a programmer, but you do need admin access to zweef.app. Expect it to take about an hour.

## What you need
- An iPad running iPadOS 26 or later, preferably with a stand or a wall mount.
- A zweef.app account with access to the admin pages (to create an API key).
- Your club's **schema name** in zweef.app (you will find it in the club settings).
- For the recommended setup: a free Cloudflare account and a computer with Node.js.

## Step 1 — Choose how the iPad talks to zweef.app
| | Proxy (recommended) | Direct |
|---|---|---|
| Where does the zweef.app key live? | At Cloudflare, not on the iPad | In the iPad's Keychain |
| What if the iPad is stolen? | Revoke the token, done | Revoke the key in zweef.app and create a new one |
| Technical knowledge | Running a few commands | None |

The zweef.app documentation advises against keeping the key on a device. So pick the proxy if you possibly can.

## Step 2 — Create an API key in zweef.app
1. Log in to zweef.app with an admin account.
2. Go to the admin pages and create an API key (API token).
3. Store the key in a password manager. You will need it in step 3 or step 5.

## Step 3 — Set up the proxy (only for the proxy setup)
Follow [proxy/README.md](../proxy/README.md). In summary:
```sh
npm i -g wrangler
wrangler login
cd proxy
wrangler secret put ZWEEF_API_KEY   # the key from step 2
wrangler secret put CLUB            # your club's schema name
openssl rand -hex 32                # create a device token and copy it
wrangler secret put DEVICE_TOKENS   # paste the token
wrangler deploy                     # note the URL that appears
```
You now have a **proxy URL** and a **device token**.

## Step 4 — Install the app
Through TestFlight, Apple Business Manager, or by building it yourself with Xcode (see the [README](../README.md#building-it-yourself)).

## Step 5 — First launch
The app opens with the setup assistant:
1. **Connection**: choose Proxy and fill in the proxy URL and the device token, or choose Direct and fill in the schema name and the API key. Tap **Test connection**; you should see the active maintenance period.
2. **Club**: the app shows your club's name as it appears in zweef.app; check that it is the right one. After that, set the closing time (when forgotten timers stop automatically) and the task list.
3. **Admin code**: six digits. Store them with your other club passwords; without this code you can no longer change the settings.
4. **Done**: the members and their photos are fetched as soon as there is internet.

## Step 6 — Lock the iPad into the app
1. Settings › Accessibility › Guided Access: turn it on and set a passcode.
2. Open the app and triple-click the side or home button to start Guided Access.
3. Set Settings › Display & Brightness › Auto-Lock to "Never" (the app dims itself).
4. Keep the iPad on its charger.

## Changing settings later
Press and hold the title (your club's name) for 3 seconds and enter the admin code. You can then change the connection, the token, the closing time, the tasks and the admin code, and test the connection again.

## Troubleshooting
| Problem | Solution |
|---|---|
| "Connection refused" | The token or key is wrong or has been revoked. Check it in Settings. |
| The status button stays orange | No internet. The hours are safe; open the sync screen to see how many are waiting. |
| A session is "rejected" on the sync screen | zweef.app did not accept the registration (e.g. the member is no longer active). Fix it in zweef.app and tap "Retry". |
| The wrong club name | The name comes from zweef.app; change it there. The iPad picks it up on the next refresh. |
| A new member is missing | Members are refreshed whenever there is internet. Or: Settings › Refresh members now. |
| Admin code forgotten | Delete the app and reinstall it. **Careful:** sessions that have not been uploaded yet are lost. Check the sync screen first to see whether everything has been uploaded. |
| The iPad is stolen or lost | Proxy: remove the token from `DEVICE_TOKENS` and redeploy. Direct: revoke the API key in zweef.app. |

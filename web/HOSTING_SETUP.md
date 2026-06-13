# Gathr invites — how the links work and what to upload

Invite links now look like:

```
https://thebighead.ca/gathr/invite?e=<eventId>&g=<guestId>
```

What happens when someone taps that link:

1. **Has the Gathr app** → iOS opens the app straight to the RSVP screen.
2. **No app (or on desktop)** → a web page loads showing the event and letting
   them RSVP right there — Going / Maybe / Can't go, plus a guest count.
   Their response is saved to your Firebase and shows up in the host's app.

So an invitee can always respond, app or not. The link can't 404 because it
points at a real file (`gathr/invite.html`) through your site's existing
clean-URL rule.

---

## What you need to do (one time)

### 1. Upload the website files to Hostinger

These live in your `thebighead` site folder (already set up there):

| File | Where it goes |
|------|---------------|
| `gathr/invite.html` | the Gathr folder (the web RSVP page) |
| `.well-known/apple-app-site-association` | site root, inside `.well-known/` (no file extension) |
| `.htaccess` | site root (already updated) |

In Hostinger File Manager / your FTP client, **turn on "show hidden files"** so
`.well-known/` and `.htaccess` actually upload (dot-files are hidden by default).

### 2. Publish the Firestore security rules

This is what lets a guest's web RSVP reach you. In the
**Firebase Console → Firestore Database → Rules**, paste the contents of
`firestore.rules` (in the repo root) and click **Publish**.

These rules:
- keep the full event (with guest phone numbers/emails) **private to you**,
- expose only a safe summary (title, date, location) to invitees,
- let a guest write **only their own** RSVP, validated.

### 3. Make sure Anonymous sign-in is on

Firebase Console → **Authentication → Sign-in method → Anonymous → Enabled.**
(You already turned this on for Demo sign-in — just confirm it's still on.)
The web RSVP page signs in anonymously so the security rules apply.

---

## Verify it works

1. Open `https://thebighead.ca/.well-known/apple-app-site-association` in a
   browser → you should see JSON, not a 404 or a download.
2. Open `https://thebighead.ca/gathr/invite?e=test&g=test` → you should see the
   Gathr invite page (it'll say "invitation unavailable" for the fake id — that's
   correct; it proves the page and Firebase connection load).
3. Create a real event in the app, send yourself an invite, open the link on a
   phone **without** the app → RSVP from the web → confirm it appears on the
   event's guest list in the app.

---

## If the web RSVP shows an error

Most likely the **Firebase API key is restricted to iOS**. Fix: Firebase Console
→ Project Settings → **Add app → Web**, register a web app, and it'll show a web
config. If the values differ from what's in `gathr/invite.html`, paste the web
ones into the `firebaseConfig` block near the bottom of that file. (By default
Firebase keys are unrestricted and the current values work as-is.)

## Notes

- Team ID in the association file is `F385ZL83XQ`. If links open the website
  instead of the app even after reinstalling, confirm that matches your Team ID
  in App Store Connect → App Information.
- Universal links bind at install time, so after uploading, delete and reinstall
  the TestFlight build once before testing the app-open path.

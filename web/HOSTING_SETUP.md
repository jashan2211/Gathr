# Make invite links work — thebighead.ca setup (one-time, ~10 minutes)

Invite links are now real web links like
`https://thebighead.ca/gathr/rsvp/ABC.../XYZ...`.
They are always clickable in WhatsApp/SMS/email. For them to **open the
Gathr app directly**, your website needs two things:

## 1. Upload the apple-app-site-association file

Upload [`apple-app-site-association`](apple-app-site-association) (the file in
this folder, **no file extension**) so it is reachable at **both**:

```
https://thebighead.ca/.well-known/apple-app-site-association
https://thebighead.ca/apple-app-site-association        (fallback location)
```

Requirements:
- Served over HTTPS (your site already is)
- Content-Type `application/json` (most hosts do this automatically; if your
  host lets you set headers, set it explicitly)
- No redirect — it must be served directly from that exact URL

Verify after upload: open the URL in Safari — you should see the JSON.
Then test with Apple's checker: https://app-site-association.cdn-apple.com/a/v1/thebighead.ca

## 2. Upload the landing page

Upload [`invite.html`](invite.html) and configure your host so that any URL
under `/gathr/rsvp/` and `/gathr/event/` serves it. How depends on your host:

- **Netlify**: add `_redirects` file with:
  `/gathr/rsvp/*  /invite.html  200` and `/gathr/event/*  /invite.html  200`
- **Vercel**: rewrites in `vercel.json` to `/invite.html`
- **cPanel/Apache**: add to `.htaccess`:
  ```
  RewriteEngine On
  RewriteRule ^gathr/(rsvp|event)/ /invite.html [L]
  ```
- **Squarespace/Wix/etc.**: these can't do path rewrites — tell me which one
  you use and I'll adjust the approach.

This page is only seen by people **without** the app: it shows
"You're invited!" with an *Open in Gathr* button and an App Store link.
People **with** the app skip the website entirely — iOS opens Gathr straight
to the RSVP screen.

## 3. Nothing else

The app side is already done (Associated Domains entitlement +
universal-link handling). After you upload both files, delete and reinstall
the TestFlight build once — iOS fetches the association file at install time.

## Why the old links were broken

- The old `gather://rsvp/...` link is a custom URL scheme — WhatsApp and
  Messages refuse to make those tappable, and they do nothing without the
  app installed.
- The old App Store link used a placeholder ID (`id939330451`) that was never
  replaced with the real one, so Apple showed "app not available in your
  region." The real ID (`6758989661`) is now used everywhere.

# Publishing Flip Jar on Google Play, step by step

Checked against Google's rules on 6 November 2026. Two rules matter most right now:

- New apps must target Android 16 (API level 36). The project's "Android AAB" preset and the release workflow already do this with Godot 4.7.2.
- A personal developer account created after 13 November 2023 must run a closed test with at least 12 testers for 14 continuous days before it can publish to production. Plan about three weeks from account creation to a public listing.

## Step 1. Create the Google Play developer account (day 1)

1. Go to https://play.google.com/console and sign in with the Google account you want to own the game. Use an account you will keep for years.
2. Choose "Personal" account type, pay the one-time 25 USD registration fee with a card.
3. Complete identity verification: upload a government ID and confirm your phone and email. Approval usually takes 1 to 3 days, sometimes a week.
4. While waiting, do steps 2 to 4 below. They don't need the account.

## Step 2. Put the privacy policy online (10 minutes)

Play requires a public privacy policy URL. One is written in `docs/privacy-policy.md`.

1. On GitHub open the repository, Settings, Pages.
2. Under "Build and deployment" choose Source: Deploy from a branch, Branch: `main`, Folder: `/docs`, Save.
3. After a minute or two the policy is live at `https://fuad7161.github.io/flip-jar/privacy-policy.html`. Open it to confirm.

## Step 3. Create the upload key and build the Play Store bundle (20 minutes)

Play only accepts an Android App Bundle (AAB) signed with a release key. The GitHub workflow builds it for you.

1. On your PC run once:
   ```
   bash game/tools/make_release_keystore.sh
   ```
   It creates `~/flipjar-upload.jks` and prints three values. Back up the `.jks` file and the password somewhere safe (a password manager and a USB stick). Without them you cannot ship updates.
2. On GitHub open Settings, Secrets and variables, Actions, New repository secret. Add the three secrets exactly as printed: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`.
3. Commit and push the latest project, then on GitHub open Actions, "Build Play Store AAB", Run workflow. Or push a tag:
   ```
   git tag v0.1.0 && git push origin v0.1.0
   ```
4. When the run is green, download `flipjar-release-aab` from Artifacts and unzip it. You get `flipjar-release.aab`.
5. Every later build gets a higher version code automatically (it is the GitHub run number), so Play will always accept it as an update.

## Step 4. Collect the store listing material (done, review it)

Everything is in the `store/` folder:

- `listing.md`: app name, short and full description, category, and the answers for every Play Console questionnaire.
- `icon_512.png`, `feature_graphic_1024x500.png`, `screenshot_1_menu.png` to `screenshot_5_result.png`.

Read the descriptions once and change any wording you don't like. If you can, replace one or two screenshots with real phone captures of a full jar mid-flip, they sell the game best.

## Step 5. Create the app in Play Console (30 minutes)

1. In Play Console click "Create app". App name: Flip Jar. Default language: English (United States). App or game: Game. Free or paid: Free. Accept the declarations and create.
2. The dashboard shows a checklist called "Set up your app". Go through every item, using `store/listing.md` for the answers:
   - App access: all functionality available without restrictions.
   - Ads: no ads.
   - Content rating: fill the IARC questionnaire, category Game, answer no to everything. You get an "Everyone" rating.
   - Target audience: 13 and over.
   - News app: no. COVID-19 app: no. Data safety: no data collected or shared. Government app: no. Financial features: none. Health: none.
   - Privacy policy: the URL from step 2.
   - App category: Game, Puzzle. Contact email: your email.
   - Store listing: paste the short and full description, upload the icon, feature graphic and screenshots.
3. Save everything. Nothing is public yet.

## Step 6. Internal testing (same day)

1. Left menu: Testing, Internal testing, Create new release.
2. Play asks about app signing. Choose "Use Google-generated key" (Play App Signing). Your keystore from step 3 becomes the upload key, Google keeps the signing key. This is the recommended setup.
3. Upload `flipjar-release.aab`, write release notes ("First test build"), save and review, then start rollout to internal testing.
4. Under Testers create a list with your own email and a few friends, copy the opt-in link, open it on each phone, accept, and install from Play. Confirm it runs. This is the first time the game is installed through Play.

## Step 7. Closed testing, the 12 testers for 14 days rule (2 to 3 weeks)

This is the step that takes time, so start recruiting testers in step 1.

1. Testing, Closed testing, create a track (the default "Alpha" is fine), create a release and use the same AAB (or a newer one).
2. Add a tester list with at least 12 Gmail addresses. Aim for 15 to 20 so dropouts don't break the count. Friends, classmates, family, Discord or Reddit testing communities all work. They need a Google account and an Android phone.
3. Send every tester the opt-in link. They must click "Become a tester", install from Play, and keep the app installed and stay opted in for the whole 14 days. Message them on day 1, day 7 and day 13 to confirm.
4. The 14-day counter starts when 12 testers are opted in at the same time. Check the count in the console daily. If it drops below 12 the clock does not reset, but the days below 12 don't count.
5. You can push updated builds to the track during the test. Gather feedback and fix bugs meanwhile.

## Step 8. Apply for production access (1 to 7 days)

1. After 14 continuous days the dashboard shows "Apply for production". Click it.
2. Google asks a short questionnaire: how you recruited testers, what feedback you got, what you changed, and whether the app is ready. Answer honestly in a few sentences each. Mention concrete changes you made from feedback.
3. Google reviews the application, usually within a week. If rejected, it tells you why; fix it and reapply. The testing phase does not need to be repeated unless Google says so.

## Step 9. Production release (review up to 7 days)

1. Production, Create new release, upload the newest AAB (build a fresh one with a tag like `v1.0.0`).
2. Countries: select all countries, since the market is global.
3. Release notes: "First release."
4. Review and start rollout. Google reviews the app, usually 1 to 3 days for a new app, up to 7.
5. When it is approved the store page is live at `https://play.google.com/store/apps/details?id=com.flipjar.game`. Then update `STORE_LINK` in `game/scripts/game.gd` if the link differs, tag a new version, and push the update.

## Step 10. After launch

- Updates: change code, push, tag `vX.Y.Z`, download the AAB, upload it to Production. Google reviews updates faster than first releases.
- Watch Play Console for crash reports (Android vitals) and user reviews. Reply to reviews; it boosts ranking.
- Post short gameplay clips, especially flips and chain merges, on TikTok, Reels and Shorts. The store listing alone brings almost no installs.
- Do not change the package name `com.flipjar.game` after publishing; Play treats it as a different app.

## If something goes wrong

- Workflow fails at "Export the signed release AAB": copy the red log lines into the chat; it is usually a missing secret or a Gradle download hiccup (re-run the workflow once).
- Play rejects the AAB for target API level: confirm the workflow used Godot 4.7.2 and the preset has `gradle_build/target_sdk="36"`.
- "You need to use a different package name": someone owns `com.flipjar.game`. Change `package/unique_name` in both presets to something unique like `com.yourname.flipjar`, rebuild, and re-create the app in Play Console.

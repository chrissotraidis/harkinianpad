# Install the HarkinianPad developer preview

The planned HarkinianPad download is an unsigned developer-preview IPA. It is
not an App Store or TestFlight build. AltStore Classic re-signs it with your
Apple ID for your own iPhone or iPad.

The IPA does not include Ocarina of Time, a ROM, or generated game data.

## Install

1. Install AltStore Classic by following its official
   [macOS](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)
   or [Windows](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
   guide.
2. Trust the computer and your Apple ID on the device when prompted. On iOS or
   iPadOS 16 and later, enable **Settings → Privacy & Security → Developer
   Mode**.
3. Download the HarkinianPad `-unsigned.ipa` from the GitHub prerelease to the
   Files app.
4. Keep AltServer running on the computer. Connect the device by USB, or keep
   both devices on the same Wi-Fi network.
5. Open AltStore Classic, choose **My Apps**, tap **+**, select the downloaded
   IPA, and let AltStore sign and install it.
6. Launch HarkinianPad once, then follow the README's
   [first-launch instructions](../README.md#first-launch) to import your own
   supported ROM through Files.

Your Apple ID credentials are handled by AltStore/AltServer and Apple, not by
HarkinianPad. The
[official AltStore installation guide](https://faq.altstore.io/altstore-classic/how-to-install-altstore-macos)
states that the credentials are sent to Apple.

## Refresh and update

Apps signed with a free Apple ID expire after seven days. AltStore can refresh
them while AltServer is available; you can also use **Refresh All** in
**My Apps**. Free accounts are limited to three active sideloaded apps. See
AltStore's official [Getting Started](https://faq.altstore.io/altstore-classic/your-altstore)
and [AltServer](https://faq.altstore.io/altstore-classic/altserver) pages for
the current rules.

Refreshing extends the current signature; it does not install a newer
HarkinianPad build. To update:

1. Download the newer IPA.
2. Install it from **My Apps** using the same Apple ID and sideload tool.
3. Do not delete HarkinianPad first. Replacing it in place gives iPadOS the
   opportunity to preserve the Files-visible Documents container.

Back up the HarkinianPad folder in Files before any preview update. Personal
signing and sideload tools can still fail, expire, or replace an app container;
the project cannot guarantee preservation outside its own tested update path.

## What the preview means

- It is early test software and may contain bugs.
- It is re-signed by the installer; the published IPA contains no maintainer
  provisioning profile or certificate.
- No jailbreak or JIT is required by HarkinianPad.
- App Store, TestFlight, AltStore PAL, and SideStore support are not part of
  this preview.

# Vela IPTV
Vela IPTV is a modern and minimalist IPTV player designed specifically for macOS.

Note: as of right now there is no VOD support but it may come in the future

---

## ⚠️ IMPORTANT: LEGAL DISCLAIMER
Vela IPTV is a **player only**. It does not provide any content, playlists, or streaming services.
- **User Responsibility**: You must provide your own legal IPTV service credentials (Xtream Codes compatible).
- **No Liability**: The developer of Vela IPTV is not responsible for any content viewed through the app, nor for any illegal use of the software. Users are responsible for ensuring their use of the app complies with all applicable laws and terms of service of their content providers.

---

## 🔒 Privacy & Security
- **100% Local Storage**: Your login credentials, server URLs, and viewing history are stored **only on your Mac**. No data is ever sent to a cloud server, developer, or third party.
- **Secure Keychain Access**: Vela uses the official macOS Keychain to encrypt and protect your passwords. 
    - **Note**: When you first add an account, macOS will ask for your computer password to secure the data. **Please click "Always Allow"** so the app can securely log you in automatically next time.
- **Direct Communication**: The app only communicates with the internet to fetch your streams and check for app updates.

---

## 🚀 Installation Guide

### 1. Download
Click [RELEASES](https://github.com/jacksonf-netizen/Vela-IPTV/releases) to go to the download page. Look for the most recent version at the top and click on **VelaIPTV.dmg** to download it.

### 2. Install
Double-click the **VelaIPTV.dmg** file you just downloaded. A window will pop up—simply drag the **Vela IPTV** icon onto the **Applications** folder icon.

### 3. First Launch (IMPORTANT)
Because Vela is an independent community project, macOS will initially try to block it for your safety. Follow these simple steps to open it:
1. Go to your **Applications** folder.
2. **Right-Click** (or hold Control and click) on **Vela IPTV**.
3. Select **Open** from the menu.
4. A popup will appear—click **Open** again.
5. *If it still won't open:* Go to your Mac's **System Settings** > **Privacy & Security**, scroll all the way to the bottom, and click **"Open Anyway"**.

### 4. Allow Keychain Access
On your **first launch** and again **after each update**, macOS will show a popup asking for your computer password to securely save your IPTV credentials:

> *"VelaIPTV wants to use your confidential information stored in Keychain"*

**Click "Always Allow"** — this is completely safe and just lets the app automatically retrieve your saved login details without asking every time.

---

## 📝 License
This project is released under the MIT License.

## 🏗️ Technical Credits
Vela IPTV is built using the following open-source libraries:
- **[VLCKit](https://code.videolan.org/videolan/VLCKit)**: The powerful engine behind our video playback. Distributed under the [GNU LGPLv2.1](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html) license.
- **[Sparkle](https://sparkle-project.org/)**: Provides our seamless "Quit and Install" update experience. Distributed under the [MIT License](https://github.com/sparkle-project/Sparkle/blob/master/LICENSE).
*Vela IPTV is not affiliated with VideoLAN or the VLC project.*

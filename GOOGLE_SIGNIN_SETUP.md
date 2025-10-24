# Google Sign-In Android Setup Guide

Jika Google Sign-In tidak berfungsi di Android, ikuti langkah-langkah berikut untuk memperbaikinya:

## 1. Verifikasi SHA-1 Certificate

SHA-1 certificate yang terdaftar di Firebase harus sesuai dengan yang digunakan untuk signing APK.

### Untuk Debug Build:

1. Jalankan script yang disediakan:
   ```bash
   # Di Windows
   cd android
   get_sha1.bat
   
   # Di Linux/Mac
   cd android
   chmod +x get_sha1.sh
   ./get_sha1.sh
   ```

2. Atau jalankan manual dengan keytool:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

3. Copy SHA-1 fingerprint yang dihasilkan

### Untuk Release Build:

1. Jika menggunakan keystore khusus untuk release:
   ```bash
   keytool -list -v -keystore path/to/your/release.keystore -alias your-key-alias
   ```

## 2. Update Firebase Console

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Pilih project Anda: `myproject-fgd5`
3. Klik ⚙️ Settings → Project Settings
4. Scroll ke bagian "Your apps"
5. Pilih Android app Anda (`com.mojadiapp.smartmoney`)
6. Klik "Add fingerprint" 
7. Paste SHA-1 fingerprint yang Anda copy
8. Klik "Save"

## 3. Download google-services.json Terbaru

1. Di Firebase Console, klik "Download google-services.json"
2. Replace file `android/app/google-services.json` dengan file yang baru
3. Pastikan package name di file tersebut sesuai: `com.mojadiapp.smartmoney`

## 4. Verifikasi Konfigurasi Android

Pastikan file `android/app/build.gradle` memiliki:

```gradle
android {
    namespace = "com.mojadiapp.smartmoney"
    // ... other config
    
    defaultConfig {
        applicationId = "com.mojadiapp.smartmoney"
        // ... other config
    }
}

// Di bagian bawah file
apply plugin: 'com.google.gms.google-services'
```

## 5. Enable Google Sign-In di Firebase

1. Di Firebase Console, klik "Authentication"
2. Klik tab "Sign-in method"
3. Pilih "Google"
4. Pastikan status "Enabled"
5. Isi "Project support email"
6. Klik "Save"

## 6. Clean dan Rebuild

```bash
flutter clean
flutter pub get
cd android
./gradlew clean
cd ..
flutter build apk --debug
```

## 7. Testing

1. Install APK di device fisik (bukan emulator)
2. Pastikan device memiliki Google Play Services
3. Test Google Sign-In

## Common Issues:

### Issue: "Google Sign-In failed"
**Solution:** Periksa SHA-1 certificate di Firebase Console

### Issue: "App not authorized"
**Solution:** Pastikan package name sesuai dan Google Sign-In enabled di Firebase

### Issue: "Network error"
**Solution:** Pastikan internet connection dan Google Play Services up to date

### Issue: "Configuration error"
**Solution:** Re-download google-services.json dari Firebase Console

## Debug Tips:

1. Periksa logcat untuk error details:
   ```bash
   adb logcat | grep -E "(GoogleSignIn|Firebase|Auth)"
   ```

2. Pastikan Google Play Services terinstall di device

3. Test dengan akun Google yang berbeda

4. Untuk emulator, pastikan menggunakan emulator dengan Google Play Store

## Contact

Jika masih ada masalah, berikan informasi berikut:
- Versi Flutter: `flutter --version`
- Error message dari logcat
- Screenshot Firebase Console configuration
- Device/emulator yang digunakan
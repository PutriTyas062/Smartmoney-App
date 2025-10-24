@echo off
echo Getting SHA-1 fingerprint for debug keystore...
echo.

REM Check if JAVA_HOME is set
if "%JAVA_HOME%"=="" (
    echo JAVA_HOME is not set. Please set JAVA_HOME to your Java installation directory.
    echo Example: set JAVA_HOME=C:\Program Files\Java\jdk-11.0.x
    pause
    exit /b 1
)

REM Get user home directory
set USER_HOME=%USERPROFILE%

REM Path to debug keystore
set KEYSTORE_PATH=%USER_HOME%\.android\debug.keystore

REM Check if debug keystore exists
if not exist "%KEYSTORE_PATH%" (
    echo Debug keystore not found at: %KEYSTORE_PATH%
    echo Please run a Flutter app in debug mode first to generate the keystore.
    pause
    exit /b 1
)

echo Using keystore: %KEYSTORE_PATH%
echo.

REM Run keytool command
"%JAVA_HOME%\bin\keytool" -list -v -keystore "%KEYSTORE_PATH%" -alias androiddebugkey -storepass android -keypass android

echo.
echo Copy the SHA1 fingerprint from above and add it to your Firebase project:
echo 1. Go to Firebase Console
echo 2. Select your project
echo 3. Go to Project Settings
echo 4. Add the SHA1 fingerprint under "Your apps"
echo.
pause
#!/bin/bash

echo "Getting SHA-1 fingerprint for debug keystore..."
echo

# Check if JAVA_HOME is set
if [ -z "$JAVA_HOME" ]; then
    echo "JAVA_HOME is not set. Please set JAVA_HOME to your Java installation directory."
    echo "Example: export JAVA_HOME=/usr/lib/jvm/java-11-openjdk"
    exit 1
fi

# Path to debug keystore
KEYSTORE_PATH="$HOME/.android/debug.keystore"

# Check if debug keystore exists
if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "Debug keystore not found at: $KEYSTORE_PATH"
    echo "Please run a Flutter app in debug mode first to generate the keystore."
    exit 1
fi

echo "Using keystore: $KEYSTORE_PATH"
echo

# Run keytool command
"$JAVA_HOME/bin/keytool" -list -v -keystore "$KEYSTORE_PATH" -alias androiddebugkey -storepass android -keypass android

echo
echo "Copy the SHA1 fingerprint from above and add it to your Firebase project:"
echo "1. Go to Firebase Console"
echo "2. Select your project"
echo "3. Go to Project Settings"
echo "4. Add the SHA1 fingerprint under 'Your apps'"
echo
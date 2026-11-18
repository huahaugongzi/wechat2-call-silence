# WeChat 2 incoming-call banner suppression

This directory backs up the currently installed WeChat 2 macOS call-banner suppression hook.

## What it does

`src/wechat2_call_silence.m` builds a universal macOS dynamic library. It loads only for bundle ID `com.tencent.xinWeChat.copy`, hooks AppKit window ordering methods, and hides small modal panels matching the observed incoming-call banner dimensions. A 200 ms timer scans only that process's own windows as a fallback.

This does not disable WeChat's network update checks or downloads. The hook is version-sensitive: WeChat updates can replace the executable or change its window behavior.

## Files

- `src/wechat2_call_silence.m`: hook source.
- `scripts/install_original.py`: repeatable installer; embeds a load command into the unmodified universal executable archived in `installed-backup/`.
- `dist/libwechat2_call_silence.dylib`: compiled universal binary currently installed.
- `installed-backup/`: pre-patch executable and Info.plist for restoring the original copy.
- `SHA256.json`: hashes for the archived source, installer, and binary.

## Build

On macOS with Xcode Command Line Tools:

```sh
clang -dynamiclib -fobjc-arc -framework Cocoa \
  -o dist/libwechat2_call_silence.dylib src/wechat2_call_silence.m \
  -arch arm64 -arch x86_64
```

The installer deliberately refuses an already patched executable. It restores its starting executable from `installed-backup/WeChat`, so use it only for the matching WeChat build archived here. Review the source and hashes before reusing this version-specific patch.

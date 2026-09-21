//go:build ohos

package main

// HarmonyOS supplies DNS through the VpnExtension/TUN path. The Android-only
// mihomo system-DNS hooks are not available in the OHOS core build.
func updateSystemDNS(string) {}

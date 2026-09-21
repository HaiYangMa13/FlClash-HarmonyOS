//go:build !ohos

package main

import (
	"strings"

	MDNS "github.com/metacubex/mihomo/dns"
)

func updateSystemDNS(value string) {
	MDNS.UpdateSystemDNS(strings.Split(value, ","))
	MDNS.FlushCacheWithDefaultResolver()
}

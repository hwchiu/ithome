[Day13] 初探 CNI 的 IP 分配問題 (IPAM)
===================================

> 本文同步刊登於 [hwchiu.com - CNI - IP Address Management](https://www.hwchiu.com/cni-ipam.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- Container Storage Interface
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

上篇文章中我們使用 golang 作為開發語言嘗試撰寫第一個簡單的 CNI 解決方案，並且在這個解決方案內我們完成 Linux Bridge 的建置，並且透過 **veth** 的方式連接 **host** 與 **network namespace** 串連起來。

此外上篇文章中也有檢討設計的問題，最重要的就是 **IP** 位址的分配，上篇的範例採用靜態分配的方式，沒有辦法擴展使用，單純只能作為測試實驗。
而本篇文章則會針對三個由 [CNI 官方 GitHub](https://github.com/containernetworking/plugins/tree/master/plugins/ipam) 維護的 IP Address Management (IPAM) 解決方案。

探討到 IPAM 之前，我們先來複習一下 CNI 的基本設定格式 **Network Configuration**，其中有個[欄位](https://github.com/containernetworking/cni/blob/master/SPEC.md#network-configuration) 就叫做 **ipam**.

其說明非常簡單:
>ipam (dictionary, optional): Dictionary with IPAM specific values:
type (string): Refers to the filename of the IPAM plugin executable.

這邊再次重申一個概念，不論是建立網路功能，分配 IP，各式各樣的輔助功能，這些應用程式只要有符合 **CNI** 標準，都可以稱之為 **CNI Plugin**。

所謂的 **IPAM** 也都有符合 **CNI** 的標準，但是其主要的功能就是幫你找到一個可用的 IP，非常簡單，但是這邊也要注意。這邊唯一的標準只有 **CNI** 的格式， **IPAM** 本身沒有標準，所以你要怎麼實作都沒有規範，能夠滿足需求就好。

我認為官方為了讓整個 CNI 的設定檔案看起來有結構且規範，特別在 **Network Configuration** 中加入了一個 **IPAM** 的欄位，讓這個 **CNI Plugin** 知道當前的設定有特別指定的 **IPAM** 方式，你就依照這個資料將相關的設定傳入 **IPAM** 參數指定的執行檔，期盼該執行檔會回你一個可以用的 IP， 最後你再將該 IP 設定到你自己創建的網路介面上。

所以下列設定檔案其運作邏輯是
1. 先呼叫 **bridge** 這個執行檔去處理
2. **bridge** 內部建立一切資訊後，會準備好相關資訊，再次呼叫 **host-local** 這隻相容 **CNI** 標準的執行檔(但是目的是為了 IP)
3. **host-local**被呼叫後根據設定回傳資訊，該資訊包含了一個可用的 IP 地址
4. **bridge** 取得該可用的 **IP** 地址後，設定到創立的網路介面。
```json=
{
	"name": "mynet",
	"type": "bridge",
	"bridge": "mynet0",
	"isDefaultGateway": true,
	"forceAddress": false,
	"ipMasq": true,
	"hairpinMode": true,
	"ipam": {
		"type": "host-local",
		"subnet": "10.10.0.0/16"
	}
}
```

上述的流程看似合理但是我認為確有一個致命的問題就是，上面的流程都只是 **Bridge** 自己說的，並不在 **CNI** 的標準規範內。
今天我們也可以寫一個 **CNI** 完全忽略 **IPAM** 這個欄位，自己用別的方式取得 IP 來設定，也是可以。
甚至我寫一個欄位，然後我也呼叫 **IPAM**， 但是我期盼 **IPAM** 不要只是回傳 **IP** 給我，請幫我一起設定。 這種邏輯也可以

因此 **CNI** 這邊由於網路架構太多元化，沒有辦法訂下一個完美的標準，最後就變成溝通介面標準化，剩下就是各自努力想辦法讓一切運作，同時每個 CNI 都要描述自己支援的設定有哪些。


## DHCP
首先介紹的第一個 IPAM 就是 **DHCP**，這個 **DHCP IPAM** 我自己只有拿來做一些 POC 測試的時候玩過，其使用限制不少，並不太容易直接整合到大部分的使用情境中。

一個 DHCP 的服務流程需要有兩個元件分別是
1. dhcp client
2. dhcp server

而這個 DHCP IPAM 扮演的角色就是 **DHCP Client**，而 **dhcp client** 按照慣例的運作模式就是
1. 發送 DHCP Request
2. 等待 DHCP Reply
3. 設定 IP 到目標網路介面
4. 定期 Renew

而 **DHCP IPAM** 實實在在的扮演上面四個角色，而這邊就有一個問題了，這個 **IPAM** 會幫你設定 **IP**，因為 **DHCP** 會需要定期 **renew**，同時有更換 IP 的話就會自動幫你替換掉，這個是正常的行為。

由這邊可以知道不同的 **IPAM** 的運作行為不同，所以使用前一定要確認其使用方法與情境。

另外一個問題就是 **DHCP** 的封包，在預設的情況下是 **Layer2** 的封包，沒有任何的 **dhcp relay** 的幫忙的話，你的 **DHCP Request** 很難送到外面的 **dhcp server** 來取得一個 IP，所以這個 **DHCP IPAM** 的官方文件有特別說明

> With dhcp plugin the containers can get an IP allocated by a DHCP server already running on your network. This can be especially useful with plugin types such as macvlan. 
> 

一種使用情境是直接透過 **macvlan** 的方式把 **host** 上的網路介面與 **network namespace** 共用，這樣從 **network namespace** 出去的封包就會直接從該網路介面出去。

接下來來探討一下整個 **DHCP IPAM** 的運作模式，該專案本身提供個兩種運作模式，一種是單純的 **CNI** 模式，一種則是一個不停運行的 **daemon** 模式。

**daemon** 模式的功用很簡單，接受所有來自 **CNI** 模式的請求，然後切換到目標的 **network namespace** 裡面去根據目標的網路介面發送一個 **DHCP** 請求封包。

所以運行這個 **DHCP IPAM**  之前，要先在系統上跑一隻 **daemon**，然後會透過 **unix socket** 的方式等待 **DHCP IPAM CNI** 發送命令過來，當然該命令會包含
1. 目標的 network namespace
2. 目標的 網路卡名稱

整個運作流程可以歸納為下圖
![](https://i.imgur.com/2sSTHuq.png)

1. 首先當該 **DHCP CNI**被呼叫後，會先透過 **unix socket**  的方式通知 **daemon**
2. **daemon** 接者潛入到該 netns 之中，確認該 Interface 存在後，就開始發送 **DHCP** 請求
3. 這邊我用一個 **magic** 的意思代表沒有限定外表要怎麼實作，總之你的 **DHCP** 封包要有辦法出去就好
4. 最後外面的(甚至同一台機器)上面的 **DHCP Server** 可以看到 **Request** 並且回覆 **Reply**
5. 最後當 **DHCP Daemon** 發送 **DHCP**  請求的那隻 thread 接收到 **DHCP** 回覆後，就會幫目標網卡設定 **IP** 地址。

最後，這個 **IPAM** 沒有這麼好用，光是那個 **magic** 的部分就不是一般使用者習慣的用法，我認為可以當作研究並增廣見聞即可。

## Static
這個 **IPAM** 其實沒有什麼好說，就是一個測試用的 IPAM，根據其 [GitHub](https://github.com/containernetworking/plugins/tree/master/plugins/ipam/static) 上面的介紹

>Overview
static IPAM is very simple IPAM plugin that assigns IPv4 and IPv6 addresses statically to container. This will be useful in debugging purpose and in case of assign same IP address in different vlan/vxlan to containers.
>

就是一個除錯使用的 IPAM，我覺得唯一可以看的就是格式內容，完全可以補足我們前篇文章所設計的用法，將其擴大到更完整。

首先裡面分成三大塊，分別是
1. IP 地址，包含了 ipv4/ipv6
2. Route 路由表
3. DNS 設定

如果你對於上述三個概念都熟悉的話，其實下面的設定檔案不太需要講，大概看過就知道代表什麼意思。

另外要注意一下的是這個 **IPAM** 的運作模式就比較上述講述的，只專心在分 **IP** 地址，本身沒有任何設定的功能。 所以呼叫者最後要根據回傳的資訊自己去決定要怎麼設定。


```json=
{
    "name": "test",
	"ipam": {
		"type": "static",
		"addresses": [
			{
				"address": "10.10.0.1/24",
				"gateway": "10.10.0.254"
			},
			{
				"address": "3ffe:ffff:0:01ff::1/64",
				"gateway": "3ffe:ffff:0::1"
			}
		],
		"routes": [
			{ "dst": "0.0.0.0/0" },
			{ "dst": "192.168.0.0/16", "gw": "10.10.5.1" },
			{ "dst": "3ffe:ffff:0:01ff::1/64" }
		],
		"dns": {
			"nameservers" : ["8.8.8.8"],
			"domain": "example.com",
			"search": [ "example.com" ]
		}
	}
}
```

### Example 
**kubeadm** 本身沒有內建這個 **CNI** 執行檔，需要的要自行去官方下載或是自行編譯安裝。
假設有這個檔案後，我們可以直接使用之前執行 **CNI** 的方式來執行該檔案，先把上述的設定存成一個名為 **static** 的檔案。
最後可以觀察其輸出結果，這些結果理論上是呼叫他的 **CNI** 去解讀，然後根據需求去設定 **IP, Route, DNS** 這些資源。

```bash=
$ sudo CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth10 CNI_PATH=/opt/cni/bin/ /opt/cni/bin/static < static
{
    "cniVersion": "0.2.0",
    "ip4": {
        "ip": "10.10.0.1/24",
        "gateway": "10.10.0.254",
        "routes": [
            {
                "dst": "0.0.0.0/0"
            },
            {
                "dst": "192.168.0.0/16",
                "gw": "10.10.5.1"
            }
        ]
    },
    "ip6": {
        "ip": "3ffe:ffff:0:1ff::1/64",
        "gateway": "3ffe:ffff::1",
        "routes": [
            {
                "dst": "3ffe:ffff:0:1ff::1/64"
            }
        ]
    },
    "dns": {
        "nameservers": [
            "8.8.8.8"
        ],
        "domain": "example.com",
        "search": [
            "example.com"
        ]
    }
}
```




## Host-Local

最後終於要講最重要的 **IPAM** 了，其使用率也是頗高的，滿多的 **CNI** 會使用這個 **IPAM** 作為基底去處理 **IP** 分配的問題，因此這邊來好好的研究一下這個 **IPAM**。

### Example

開始研究其特色之前，我們直接先直接運行一個簡單的範例
1. 準備一個 config 給 host-local
2. 呼叫 **host-local cni**，觀察其結果 
3. 呼叫 **host-local cni**，觀察其結果
4. 呼叫 **host-local cni**，觀察其結果

上面是認真的要呼叫三次，來觀察呼叫三次會有什麼不一樣的結果


首先我們先觀察一下其設定檔案，裡面相對於 **static** 來說，裡面最大的不一樣是出現了 **range**, **subnet** 之類的字眼
```bash=
$ cat config
{
        "ipam": {
                "type": "host-local",
                "ranges": [
                        [
                                {
                                        "subnet": "10.10.0.0/16",
                                        "rangeStart": "10.10.1.20",
                                        "rangeEnd": "10.10.3.50",
                                        "gateway": "10.10.0.254"
                                },
                                {
                                        "subnet": "172.16.5.0/24"
                                }
                        ]
                ]
        }
}
```

接者我們就運行該 **host-local CNI** 三次，看看三次的結果如何
```bash=
$ sudo CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth10 CNI_PATH=/opt/cni/bin/ /opt/cni/bin/host-local < config
{
    "cniVersion": "0.2.0",
    "ip4": {
        "ip": "10.10.1.20/16",
        "gateway": "10.10.0.254"
    },
    "dns": {}
}
$ sudo CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth10 CNI_PATH=/opt/cni/bin/ /opt/cni/bin/host-local <config
{
    "cniVersion": "0.2.0",
    "ip4": {
        "ip": "10.10.1.21/16",
        "gateway": "10.10.0.254"
    },
    "dns": {}
}
$ sudo CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth10 CNI_PATH=/opt/cni/bin/ /opt/cni/bin/host-local <config
{
    "cniVersion": "0.2.0",
    "ip4": {
        "ip": "10.10.1.22/16",
        "gateway": "10.10.0.254"
    },
    "dns": {}
}
```

輸出的結果非常的有趣，每次的輸出內容幾乎都一樣，除了 **ip4.ip** 這個欄位之外有些許差別，分別是
**10.10.1.20/16, 10.10.1.21/16, 10.10.1.22/16**

同時我們在複習一下剛剛設定裡面的 **range.subnet** 相關設定
```json=
"subnet": "10.10.0.0/16",
"rangeStart": "10.10.1.20",
"rangeEnd": "10.10.3.50",
"gateway": "10.10.0.254"
```                     

看到這邊應該心裡已經有個譜了， **host-local** 會根據參數給予的 **IP** 範圍，依序回傳一個沒有被使用過的 **IP**， 這個運作原理非常的符合我們真正的需求，每次有 **POD** 產生的時候都可以得到一個沒有被使用過的 **IP** 地址，避免重複同時又能夠使用。


接下來我們來正式的研究這個 **IPAM CNI**，看看其設計上還有什麼樣的特色與注意事項

### Introduction

如慣例一樣，我們先看看官方 [GitHub](https://github.com/containernetworking/plugins/tree/master/plugins/ipam/host-local) 怎麼描述這個專案

> host-local IPAM plugin allocates ip addresses out of a set of address ranges. It stores the state locally on the host filesystem, therefore ensuring uniqueness of IP addresses on a single host.
The allocator can allocate multiple ranges, and supports sets of multiple (disjoint) subnets. The allocation strategy is loosely round-robin within each range set.

擷取幾個重點
1. 從 address ranges 中分配 IP
2. 將分配的結果存在本地機器，所以這也是為什麼叫做 **host-local**

其中(2)算是一個手段，用來滿足(1)，畢竟如果沒有地方進行紀錄來進行比較，就沒有辦法每次都回傳一個沒有被用過的 **IP** 地址。

接下來看一個比較完整的設定檔案
```json=
{
	"ipam": {
		"type": "host-local",
		"ranges": [
			[
				{
					"subnet": "10.10.0.0/16",
					"rangeStart": "10.10.1.20",
					"rangeEnd": "10.10.3.50",
					"gateway": "10.10.0.254"
				},
				{
					"subnet": "172.16.5.0/24"
				}
			],
			[
				{
					"subnet": "3ffe:ffff:0:01ff::/64",
					"rangeStart": "3ffe:ffff:0:01ff::0010",
					"rangeEnd": "3ffe:ffff:0:01ff::0020"
				}
			]
		],
		"routes": [
			{ "dst": "0.0.0.0/0" },
			{ "dst": "192.168.0.0/16", "gw": "10.10.5.1" },
			{ "dst": "3ffe:ffff:0:01ff::1/64" }
		],
		"dataDir": "/run/my-orchestrator/container-ipam-state"
	}
}
```

這裡面我認為相對有趣的事情有
1. 支援 ipv6, 其支援 ipv6 的速度遠早於 kubernetes 1.16，這意味之前其實就可以透過 host-local 的方式去分配 ipv6 address， 只是 kubernetes 內部的所有功能都還是基於 ipv4，變成使用上沒有整合很不方便
2. **dataDir** 的變數會指定要用哪個資料夾作為 **host-local** 記錄用過的資訊，預設值是 **/var/lib/cni/networks/**.

根據上述簡單的範例，因為我沒有特別指定 **dataDir**，所以所有的檔案都會存放在 **/var/lib/cni/networks/** 裡面

```bash=
$ sudo find /var/lib/cni/networks/ -type f
/var/lib/cni/networks/last_reserved_ip.0
/var/lib/cni/networks/10.10.1.20
/var/lib/cni/networks/10.10.1.22
/var/lib/cni/networks/10.10.1.21

$ sudo find /var/lib/cni/networks/ -type f | xargs -I % sh -c 'echo -n "%:   ->"; cat %; echo "";'
/var/lib/cni/networks/last_reserved_ip.0:   ->10.10.1.22
/var/lib/cni/networks/10.10.1.20:   ->ns1
/var/lib/cni/networks/10.10.1.22:   ->ns1
/var/lib/cni/networks/10.10.1.21:   ->ns1

```

我們可以觀察到，每個被用過的 **IP** 都會產生一個以該 **IP** 為名的檔案，該檔案中的內容非常簡單，就是使用的 **container ID**，由於我目前的範例非常簡單，所以資訊不夠豐富，等之後我們探討 kubernetes 的使用情境後，就可以再次觀察這個欄位。

此外，還可以觀察到一個名為 **last_reserved_ip** 的檔案，該檔案用來記住每個 **range** 目前分配的最後一個 **IP** 是哪個。
目前 **host-local** 分配的演算法是 **round-robin**，對演算法有興趣的可以參考下方的[原始碼](https://github.com/containernetworking/plugins/blob/ded2f1757770e8e2aa41f65687f8fc876f83048b/plugins/ipam/host-local/backend/allocator/allocator.go#L150)

```golang=
// GetIter encapsulates the strategy for this allocator.
// We use a round-robin strategy, attempting to evenly use the whole set.
// More specifically, a crash-looping container will not see the same IP until
// the entire range has been run through.
// We may wish to consider avoiding recently-released IPs in the future.
func (a *IPAllocator) GetIter() (*RangeIter, error) {
....
```

最後我們再來思考一個問題，今天我們可以使用 **range.subnet** 這類的設定檔案讓 **host-local**來幫我們分配 **IP** 地址，避免重複的問題。
但是前述有提過， **CNI** 本身是每個節點都要配置的，所以如果今天每個節點都使用一樣的設定檔，會發生什麼事情?
基於 **round-robin** 的演算法下，就會發生不同節點上的 **Pod** 使用到相同的 **IP** 地址，這樣問題還是沒有解決。
為了解決這個問題，唯一的辦法就是每台節點上面都要部署不同內容的設定檔案，譬如第一個節點使用 **10.0.1.0/24**，第二個使用 **10.0.2.0/24**，諸如此類的方式。
這樣的使用雖然可以解決問題，但是對於安裝與部署來說又產生其他的困擾，如果今天有舊的節點要移除，新的節點要進來，也要確保設定檔案沒有重複，不然 **IP** 問題就會繼續浮上來。

只能說這種分散式的東西本身在處理與使用上就要格外小心，沒有集中控制的管理就容易導致群龍無首然後各自為王。

當然要解決這個問題也是有其他的辦法，下一篇會來探討 **ｆlannel** 的基本安裝過程，並且探討一下 **flannel** 是如何解決對所有節點上的 **Pod** 都能夠分配一個不重複的 **IP** 地址。

# Summary

本篇文章介紹三種不同官方提供的 **IPAM** 解決方案，這些解決方案也都基於 **CNI** 的標準去設計，所以相容彼此的參數傳遞以及結果回傳。這使得這些 **IPAM** 能夠與其他的 **CNI** 更好整合，藉由分層的概念讓 **IPAM** 專心處理 **IP** 管理分配的問題，而其他的 **CNI** 則是專注於如何建立網路資源，確保目標 **network namespace** 可以獲得想要的上網能力。

到這一邊我們已經對 **CNI** 有一些基本概念了，接下來我們要實際演練一台具有三個節點的 kubernetes cluster 與 **Flannel CNI** 是如何運作的，包含了安裝過程，設定檔案內容，到最後封包的轉發是如何做到跨節點存取的。

# 參考
- https://github.com/containernetworking/plugins
- https://github.com/containernetworking/cni
- https://github.com/containernetworking/cni/blob/master/SPEC.md#network-configuration

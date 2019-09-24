[Day12] 使用 golang 打造一個基本 CNI
=================================

> 本文同步刊登於 [hwchiu.com - First CNI by golang](https://www.hwchiu.com/cni-golang.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- Container Network Interface
- Container Storage Interface
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論


# 前言

前面兩篇文章探討了 `Container Network Interface(CNI)` 的概念，並且從 Kubernetes 的環境中去探討如何使用 CNI，包含了各種設定。

此外之前也有提過 [containernetworking GitHub](https://github.com/containernetworking/plugins) 有提供很多基本好用的 CNI 解決方案供其他的 `CNI` 解決方案重複使用，譬如
1. bridge
2. lo
3. portmapper
4. local-host
5. dhcp
6. ...等

而今天要來探討到底 `bridge` 這個簡單的 CNI 怎麼實現的，以及我們將使用 golang 自己打造一個簡單版本的 bridge CNI。

另外本文所使用的 golang 基於測試與開發方便，沒有講究太多架構與維護性，單純就是功能上的驗證。

# 介紹

本篇文章使用的程式碼都基於下列 [CNI Tutorial](ttps://github.com/hwchiu/CNI_Tutorial_2018) repo，裡面還有含有一個建置好所有環境的 **vagrant** 檔案，會直接準備好所有環境供測試。


這次的目標很簡單，使用 golang 寫一個基於 CNI 的解決方案，該解決方案會執行下列行為
1. 讀取 config, 取得 bridge 名稱以及想要設定的 IP 地址
2. 根據上述的資訊創建對應的 Linux Bridge
3. 創建一條特殊的虛擬 link (veth)
4. 將該虛擬 link 的兩端分別接到 Linux Bridge 以及 傳入的 network namespace 上，並且命名為 eth0
5. 幫 network namespace 內的 eth0 設定 IP 地址

整個結果就如同下圖，這次的概念非常簡單，也沒有牽扯過多額外的功能，基本上就是看一下一個 CNI 可能會怎麼實現，有個這個概念之後再來看其他的 `CNI` 解決方案的原始碼的時候就比較有概念該怎麼去理解與閱讀。
![](https://i.imgur.com/botAbi0.png)

# 流程

## Step 1

為了快速使用 golang 開發 `CNI` 的應用程式，我們可以借助官方提供的函示庫來幫助我們快速建立整個 `CNI` 的框架

```golang=
package main

import (
	"fmt"
	"github.com/containernetworking/cni/pkg/skel"
	"github.com/containernetworking/cni/pkg/version"
)

func cmdAdd(args *skel.CmdArgs) error {
	fmt.Printf("interfance Name: %s\n", args.IfName)
	fmt.Printf("netns path: %s\n", args.Netns)
	fmt.Printf("the config data: %s\n", args.StdinData)
	return nil
}

func cmdDel(args *skel.CmdArgs) error {
	return nil
}

func main() {
	skel.PluginMain(cmdAdd, cmdDel, version.All)
}
```

這個範例中，我們建立的兩個 function, 分別要用來處理 ADD/DEL 兩個事件，對應到 Container 被創立以及 Container 被刪除

接者透過 `skel` 這個函式庫將這兩個 function 與 **ADD/DEL** 事件給關聯起來
其中要注意的是這些 function 的參數都必須是 **skel.CmdArgs**，其結構如下
```golang=
type CmdArgs struct {
	ContainerID string
	Netns       string
	IfName      string
	Args        string
	Path        string
	StdinData   []byte
}
```
有沒有覺得這些欄位與之前介紹的 CNI 標準內定義的欄位很相似？ 這個結構就是用來幫助處理相關參數的，該 **skel** 的函式庫會幫忙把相關參數收集完畢後塞到這個結構內，並且傳入到 ADD/DEL 對應的 function.

此外這邊的 **StdinData** 其實就是所謂的 **Network Configuration** 的 json檔案，而這個範例中我們希望透過一個 config 去描述 bridge 的名稱以及 **network namespace** 會用到的 IP 地址。
因此我們先設計一個簡單的 Config 內容，並且存放到名為 **config** 的檔案內

```json=
{
        "name": "mynet",
        "BridgeName": "test",
        "IP": "192.0.2.12/24"
}
```

假設上述的 golang 程式編譯完成後名為 **mycni**，則我們可以這樣進行測試

```bash=
$ sudo ip netns add ns1
$ sudo CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth10 CNI_PATH=`pwd` ./mycni < config

interfance Name: eth10
netns path: /var/run/netns/ns1
the config data: {
        "name": "mynet",
        "BridgeName": "test",
        "IP": "192.0.2.12/24"
}
```

其中用到的環境變數 **CNI_XXX** 由 [CNI SPEC](https://github.com/containernetworking/cni/blob/master/SPEC.md#parameters) 所定義，分別有
1. CNI_COMMAND
2. CNI_CONYAINERID
3. CNI_IFNAME
4. CNI_ARGS
5. CNI_PATH

完成了這一步就意味我們的程式已經可以處理 CNI 相關的資訊了，只要把上述的設定檔案與執行檔放入到 kubernetes cluster 內，依照 **--cni-bin-dri** 以及 **--cni-conf-dir** 的設定的位置下，就可以順利地被執行然後印出相關資訊。

不過由於目前的程式什麼都沒有做，所以執行起來的 Pod 會變成沒有對外連接上網的能力，但是整個流程算是已經打通了，下一步就是如何透過這些資訊來操作 Linux 以及 Network Namespace。

## Step 2

接下來我們要做的事情就是在系統內創建一個 **Linux Bridge**，這部分會使用到 **netlink** 相關的函示庫進行操作，主要是透過 **netlink** 這個**IPC**的機制直接告訴 **kernel** 幫忙操作。

此外，我們在上一個步驟定義了簡單的 config 內容，因此這次也要在程式內定義相關的結構來讀取這些資料。
```json=
{
        "name": "mynet",
        "BridgeName": "test",
        "IP": "192.0.2.12/24"
}
```


```golang=
import (
	"encoding/json"
	"fmt"
	"syscall"

	"github.com/containernetworking/cni/pkg/skel"
	"github.com/containernetworking/cni/pkg/version"
	"github.com/vishvananda/netlink"
)

type SimpleBridge struct {
	BridgeName string `json:"bridgeName"`
	IP         string `json:"ip"`
}

func cmdAdd(args *skel.CmdArgs) error {
	sb := SimpleBridge{}
	if err := json.Unmarshal(args.StdinData, &sb); err != nil {
		return err
	}
	fmt.Println(sb)

	br := &netlink.Bridge{
		LinkAttrs: netlink.LinkAttrs{
			Name: sb.BridgeName,
			MTU:  1500,
			// Let kernel use default txqueuelen; leaving it unset
			// means 0, and a zero-length TX queue messes up FIFO
			// traffic shapers which use TX queue length as the
			// default packet limit
			TxQLen: -1,
		},
	}

	err := netlink.LinkAdd(br)
	if err != nil && err != syscall.EEXIST {
		return err
	}

	if err := netlink.LinkSetUp(br); err != nil {
		return err
	}
	return nil
}
```

1. 定義一個簡單的結構，用來讀取該 json 檔案
2. 該 config 會放到 **args.StdinData** ，嘗試從這邊讀取內容
3. 接下來我們要使用 **netlink** 的函示庫操作 **Linux Bridge** 分成三個步驟
    - 創建 Bridge 的物件
    - 告知 Kernel 幫忙創建 Bridge
    - 將該 Bridge 啟動 (類似 ifconfig br0 up)

由於這個範例中我們還沒有真的去操控到 **namespace**，所以不需要真的創建 **namespace** 也是可以運行的

```bash=
$ brctl show
bridge name     bridge id               STP enabled     interfaces

$ sudo CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth10 CNI_PATH=`pwd` ./mycni < config
{test 192.0.2.12/24}

$ brctl show
bridge name     bridge id               STP enabled     interfaces
test            8000.000000000000       no

```

## Step 3

再來重新檢視一下我們的目標圖
![](https://i.imgur.com/botAbi0.png)

第三步驟我們要滿足上圖的(2)的功能，建立一對 **veth** 並且分別連接到 **Linux Bridge** 以及預先創立好的 **network namespace** 上，同時該名稱必須是我們透過參數傳進去的。

由於接下來要直接針對 **network namespace (netns)** 進行操作，同時也會用到一些相關的介面，因此我們要引用更多官方提供的函示庫

```golang=
import (
	"encoding/json"
	"fmt"
	"syscall"

	"github.com/containernetworking/cni/pkg/skel"
	"github.com/containernetworking/cni/pkg/types/current"
	"github.com/containernetworking/cni/pkg/version"
	"github.com/containernetworking/plugins/pkg/ip"
	"github.com/containernetworking/plugins/pkg/ns"
	"github.com/vishvananda/netlink"
)
```


延續 Step 2的程式，我們創建完畢 **Linux Bridge** 之後，接下來我們要開始處理 network namespace，運作流程如下
1. 根據參數 **CNI_NETNS** 給的路徑取得相關 network namespace(netns) 的物件
2. 於該 netns 內創建一對 **veth** ，需要三個參數，分別是
    - interface name, 也就是 CNI_INFNAME
    - mtu, 範例測試使用 1500 即可
    - 另外一端的 netns 物件，由於我們是在目標的 netns 內創造，所以這個變數則是要給 **host** 本身的 netns
3. 創建完畢後透過 **veth** 的回傳變數取得創建於 **host** 上的 interface 名稱，通常是 **vethxxxxxxx** 這種格式
4. 根據上述的名稱再次透過 **netlink** 去取得該網路介面的物件
5. 最後透過 **netlink** 的方式把該介面接上已經創建好的 **Linux Bridfge** 

接下來一個步驟一個步驟試試看

首先透過 [官方函式庫](https://github.com/containernetworking/plugins/blob/master/pkg/ns/ns_linux.go#L136) 提供的功能來取得 netns 的物件，其參數就是我們在執行時傳入的 **/var/run/netns/ns1**
```golang=
	netns, err := ns.GetNS(args.Netns)
	if err != nil {
		return err
	}
```

接者我們可以透過 [netns.Do](https://github.com/containernetworking/plugins/blob/master/pkg/ns/ns_linux.go#L165) 的方式於該 netns 內執行任意 function.

所以先定義一個 function (handler)，該 function 必須要能夠創建一對 **veth** 並且收集到創建後的另外一端名稱 **vethxxxx**

```golang=
	hostIface := &current.Interface{}
	var handler = func(hostNS ns.NetNS) error {
		hostVeth, _, err := ip.SetupVeth(args.IfName, 1500, hostNS)
		if err != nil {
			return err
		}
		hostIface.Name = hostVeth.Name
		return nil
	}

	if err := netns.Do(handler); err != nil {
		return err
	}
```

對 **netns.Do** 有興趣的可以觀看其[原始碼](https://github.com/containernetworking/plugins/blob/master/pkg/ns/ns_linux.go#L165)，該實作內會取得當前 **host** 的 **netns** 並且傳入到參數的函式中。


上述流程其實可以把 **current.Interface** 物件單純換成字串就好，因為我們這個範例中只有要收集 interface name, 沒有其他的網卡資訊。


接下來就是透過 **netlink** 將該 interface name 轉換成相關的物件，以利後面的  **LinkSetMaster**操作
```golang=    

	hostVeth, err := netlink.LinkByName(hostIface.Name)
	if err != nil {
		return err
	}

	if err := netlink.LinkSetMaster(hostVeth, br); err != nil {
		return err
	}
```


最後依序執行下列的步驟，先清除先前創立過的所有資源，然後手動創建一個 **netns**。

要注意 **netns** 的名稱 **ns1** 必須要與參數 **CNI_NETNS** 後面的名稱一致。
```bash=
# Teardown all resoureces
$ sudo ip netns del ns1
$ sudo ifconfig test down
$ sudo brctl delbr test

# Create network namespace
$ sudo ip netns add ns1

$ sudo CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth10 CNI_PATH=`pwd` ./mycni < config
$ sudo brctl show test
bridge name     bridge id               STP enabled     interfaces
test            8000.6a5cc34310be       no              veth99b22b47
$ sudo ip netns exec ns1 ifconfig -a
eth10     Link encap:Ethernet  HWaddr 96:7c:33:2b:f3:42
          inet6 addr: fe80::947c:33ff:fe2b:f342/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:1 errors:0 dropped:0 overruns:0 frame:0
          TX packets:1 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:90 (90.0 B)  TX bytes:90 (90.0 B)

lo        Link encap:Local Loopback
          LOOPBACK  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

跑完這個範例我們就已經順利的建立好相關的橋樑，將 **host** 與 **network namespace** 透過虛擬連結 **veth** 給打通了。

最後一件事情就是設立該 **network namespace** 裡面使用的 IP 地址

## Step 4

由於先前的 **config** 以及相關的結構已經有將 **IP** 的欄位給設定好了，因此接下來我們只要針對 **設定IP** 這個步驟進行探討

1. 創建 **veth** 後我們還需要額外取得當前 **eth10** 的 **netlink** 物件，這樣才可以透過 **netlink** 對該物件進行 **IP** 的設定
2. **netlink** 設定 IP 的方式是透過物件 **ip.IPNet**, 這邊要怎麼創造這個物件方法百百種，也跟你怎麼設計自己的 config 有關。


跟剛剛上述不同，這次創建 **veth** 配對的時候，我們第二個物件也要一併收集 **containerVeth**，代表的就是 **eth10** 這張網卡。
```golang=
		hostVeth, containerVeth, err := ip.SetupVeth(args.IfName, 1500, hostNS)
		if err != nil {
			return err
		}
        
		hostIface.Name = hostVeth.Name
```

因為 config 內目前的設計是 **192.168.1.12/24** 這種 CIDR 的格式，所以我直接採用 **net.ParseCIDR** 的方式來解讀該格式，並且可以直接取得 **ip.IPNet** 的物件。

由於 **ParseCIDR** 產生後的 IPNet 物件，放置的是網段內容並非 IP 資訊，我們需要將 IP 的部分重新覆蓋

假如我們傳進去的參數是 **192.168.2.12/24**, 則創建出來的 **ip.IPNet** 會長
```golang=

IPNet{
    192.0.2.0/24
}
```
但是要傳入給 **netlink** 的物件，我們希望是
```golang=
IPNet{
    192.0.2.12/24
}
```
因此需要把 **IP**欄位重新設定

```golang=
		ipv4Addr, ipv4Net, err := net.ParseCIDR(sb.IP)
		if err != nil {
			return err
		}
		ipv4Net.IP = ipv4Addr
```

最後透過 **netlink** 的方式先把 **eth10** 的物件找出來，接者使用 **netlink** 的方式去設定 **IP** 地址。
```golang=

		link, err := netlink.LinkByName(containerVeth.Name)
		if err != nil {
			return err
		}

		addr := &netlink.Addr{IPNet: ipv4Net, Label: ""}
		if err = netlink.AddrAdd(link, addr); err != nil {
			return err
		}
        
```


```bash=
$ cat  config
{
        "name": "mynet",
        "BridgeName": "test",
        "IP": "192.0.2.12/24"
}

# Teardown all resoureces
$ sudo ip netns del ns1
$ sudo ifconfig test down
$ sudo brctl delbr test

# Create network namespace
$ sudo ip netns add ns1

$ sudo CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth10 CNI_PATH=`pwd` ./mycni < config
$ sudo brctl show test
bridge name     bridge id               STP enabled     interfaces
test            8000.6a5cc34310be       no              veth99b22b47
$ sudo ip netns exec ns1 ifconfig -a
eth10     Link encap:Ethernet  HWaddr 9a:f9:1c:98:9b:7c
          inet addr:192.0.2.12  Bcast:192.0.2.255  Mask:255.255.255.0
          inet6 addr: fe80::98f9:1cff:fe98:9b7c/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:1 errors:0 dropped:0 overruns:0 frame:0
          TX packets:1 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:90 (90.0 B)  TX bytes:90 (90.0 B)

lo        Link encap:Local Loopback
          LOOPBACK  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

這時候你如果嘗試使用 **ping** 去測試剛剛創建好的 **IP**，你會發現完全打不通，主要問題有兩個
1. 系統上沒有配置適當的 routing
2. 跨網段連接沒有對應的 gateway 幫忙轉發

最簡單的辦法就是幫 Linux Bridge 設定一個 IP，譬如 **192.0.2.1** 即可。

```bash=
$ ping 192.0.2.15
PING 192.0.2.15 (192.0.2.15) 56(84) bytes of data.
^C
--- 192.0.2.15 ping statistics ---
1 packets transmitted, 0 received, 100% packet loss, time 0ms

$ sudo ifconfig test 192.0.2.1/24
$ ping 192.0.2.15
PING 192.0.2.15 (192.0.2.15) 56(84) bytes of data.
64 bytes from 192.0.2.15: icmp_seq=1 ttl=64 time=0.038 ms
64 bytes from 192.0.2.15: icmp_seq=2 ttl=64 time=0.023 ms
```

# Summay

經過了四個簡單的範例我們成功的撰寫了一個基於 CNI 標準的解決方案，內容非常簡單就是將 **host** 與 **network namespace** 連接起來並且設定IP。 目前的做法還有很多問題需要改善
1. 相關的 Routing 沒有設定，封包出不去也進不來
2. 沒有設定相關的 SNAT, **network namespace** 內的封包可能出不去
3. IP 完全寫死，這意味如果針對第二個 **network namespace** 去執行就會發生 IP 相同且衝突的問題

所以為了完成一個堪用的 CNI，背後要做的事情其實滿多的，為了讓網路可以於各式各樣的環境內都可以正常使用，這部分需要做很多的處理與判斷。

下文章我們要來探討 **IP** 分配的問題，看看目前官方維護的三套 [IPAM](https://github.com/containernetworking/plugins/tree/master/plugins/ipam) 分別是哪些以及如何運作才可以避免各種 IP 衝突且寫死的問題。

# 參考
- https://github.com/hwchiu/CNI_Tutorial_2018
- https://github.com/containernetworking/plugins
- https://github.com/containernetworking/cni

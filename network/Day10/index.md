[Day10] Container Network Interface 介紹
=======================================

> 本文同步刊登於 [hwchiu.com - Container Network Interface](https://www.hwchiu.com/kubernetes-cni.html)

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

`kubernetes` 自架的安裝過程中，所有人都會遇到的一個問題及步驟就是，安裝 `CNI`，而官方教學文章下能夠選擇的 `CNI` 也是洋洋灑灑一大堆，對於第一次踏入 `kubernetes` 的使用者來說，往往覺得一頭霧水，到底要選哪個 `CNI` 安裝，同時這些 `CNI` 分別有什麼效果，對於使用者來說會有差別嗎?

之前與大家探討過 `Contaienr Runtime Interface (CRI)` 這種標準架構，使得 `kubernetes` 能夠很順利的切換各種不同 `Kubernetes Wokrload` 的底層實現，你可以使用原本的 `dockershim`，或是切到整合度更高的 `containetd`, `cri-o`甚至是直接使用基於 `virtual machine` 的 `virtlet`， 這一切都依賴 `CRI` 標準來完成。

# CNI
`CNI` 就是一個與 `CRI` 相當的標準架構，其針對的則是 `kubernetes` 內的網路功能，這網路功能就目前所知，可以包括以下幾項
1. 提供 `Pod` 上網能力，通常都會希望能夠有連接外網的能力
2. 分配 `IP` 地址，幫每個 `Pod` 找一個獨立不重複的 `IP`，至於是 `ipv4` 或是 `ipv6` 都可以。從  kubernetes 1.16 開始支援 `ipv6` 之後對於使用 `ipv6` 的`Pod` 再管理上會顯得相對容易
3. 幫忙實現 Network Policy， kubernetes 內部有 Network Policy 去限制 `Pod` 與 `Pod` 之間的網路傳輸，然而 `kubernetes` 本身只有定義介面，仰賴各個 `CNI` 去完成。


我個人對於上面這些所謂的網路功能都是抱持者非必要的選項，因為網路世界的使用情境實在太多種，舉例來說也有 `CNI` 是不給 `IP` 地址的，完全針對特殊應用情境採用 `point to point (layer2)` 來連接，因為這個世界上還是有非 `TCP/IP` 的應用繼續存在。

至於 `Network Policy` 其實說到底也不是 `CNI` 標準介面要解決的事情，只是有些 `CNI` 解決方案會額外額外實現控制器來滿足 `Network Policy` 的需求。

`CNI` 相關的檔案都可以到 [GitHub](https://github.com/containernetworking/cni) 找到，目前其最新版本是 **0.4.0**

有興趣的可以點選下列連結到不同版本的 `spec` 去看詳細內容。

| tag                                                                                  | spec permalink                                                                        | major changes                     |
| ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------- | --------------------------------- |
| [`spec-v0.4.0`](https://github.com/containernetworking/cni/releases/tag/spec-v0.4.0) | [spec at v0.4.0](https://github.com/containernetworking/cni/blob/spec-v0.4.0/SPEC.md) | Introduce the CHECK command and passing prevResult on DEL |
| [`spec-v0.3.1`](https://github.com/containernetworking/cni/releases/tag/spec-v0.3.1) | [spec at v0.3.1](https://github.com/containernetworking/cni/blob/spec-v0.3.1/SPEC.md) | none (typo fix only)              |
| [`spec-v0.3.0`](https://github.com/containernetworking/cni/releases/tag/spec-v0.3.0) | [spec at v0.3.0](https://github.com/containernetworking/cni/blob/spec-v0.3.0/SPEC.md) | rich result type, plugin chaining |
| [`spec-v0.2.0`](https://github.com/containernetworking/cni/releases/tag/spec-v0.2.0) | [spec at v0.2.0](https://github.com/containernetworking/cni/blob/spec-v0.2.0/SPEC.md) | VERSION command                   |
| [`spec-v0.1.0`](https://github.com/containernetworking/cni/releases/tag/spec-v0.1.0) | [spec at v0.1.0](https://github.com/containernetworking/cni/blob/spec-v0.1.0/SPEC.md) | initial version                   |


## Specification
接下來跟大家探討一下 `CNI` 的標準介面以及是如何運作的，不同於 `CRI` 是定義 `gRPC` 介面， `CNI` 的標準要求 `CNI` 解決方案需要提供一個執行檔(為了方便我接下來都用 binary 稱呼），該 binary 要能夠接收不同的參數來處理不同的網路生命週期，譬如創建網路，回收網路。

當 `kubernetes` 創建或刪除 `Pod` 時，就會準備好一系列的參數與設定檔案，然後呼叫該執行擋來幫忙提供網路能力。

舉例來說，假設今天 `kubelet` 決定要創建一個 `Pod`， 透過 `CRI` 已經準備好相關資源，如 `network namespace` 後，就會呼叫該 binary，同時帶入下列參數

- Container ID
當前要被提供網路能力的 Container ID，基本上就是一個唯一不重複的數值，有些 `CNI `解決方案可能會用此 ID 作為一些資料索引之類的需求。
- Network namespace path.
這個是最重要的參數，就是目標 `container` 其真正 `network namespace` 的路徑，之前提到過這些 `namespace` 都是透過 `linux kernel` 的方式來達成的，所以其實大家可以到 `host` 上找到這些 `network namespace` 並且對其操作。
因此大部分的 `CNI` 的 binary 就是會根據這個位置，然後找到該 `network namespace` 最後進入到該空間去進行一些網路設定
- Network configuration
這個部分非常長，等等再來說明
- Extra arguments
一個彈性的部分，以 `Container` 為單位的不同參數，主要是要看上面的呼叫者怎麼處理，因為 `CNI` 其實不是只有單純 `kubernetes` 有支援，所以最上層的應用可以根據自己的需求傳入這些額外的參數，同時只要你選擇的 `CNI` 解決方案會去處理這些參數即可
- Name of the interface inside the container
最後這個就是會在該 `Container` 內被創建的 `network interface` 名稱，常見的基本上都是 `eth0`, `enp0s8`  這種變化


假設今天有一個名為 `mycni` 的 `CNI` binary，且假設 `Network Configuration` 的內容存放一個名為 `config` 的檔案。

那執行一個 `CNI` 的過程就類似如下
其中 `CNI_COMMAND` 要告訴該 binary 目前要執行 ADD 的功能，剩下的 CONTAINERID, NETNS, IFNAME 就如同上面所述。

```bash=
$ sudo ip netns add ns1
$ sudo CNI_COMMAND=ADD CNI_CONTAINERID=ns1 CNI_NETNS=/var/run/netns/ns1 CNI_IFNAME=eth10 CNI_PATH=`pwd` ./mycni < config
```

### Sandbox Container
這邊有一個觀點要先大家討論一下，就是 `network namespace` 共用的議題，每個 `contaienr` 都會有一個 `network namespace` 是個常態，但是並非絕對。實際上可以多個 `container` 共用一個相同的 `network  namespace`，這樣這些 `container` 就會看到相同的網路介面，譬如 `network interface name` 以及 IP 地址。

看到這邊有沒有想到關於 `kubernetes POD` 的定義?
> The applications in a Pod all use the same network namespace (same IP and port space), and can thus “find” each other and communicate using localhost. Because of this, applications in a Pod must coordinate their usage of ports. Each Pod has an IP address in a flat shared networking space that has full communication with other physical computers and Pods across the network.

如果你手邊能夠操作 `docker` 的話，其實我們也可以透過 `docker run` 中的 `--net=container:xxx` 這個參數來指定目標的 `container id`，希望他的網路與特定 `container` 是綁定再一起的。

```bash=
$ sudo docker run -d --name c1 hwchiu/netutils
$ sudo docker exec c1 ifconfig
eth0      Link encap:Ethernet  HWaddr 02:42:ac:12:00:02
          inet addr:172.18.0.2  Bcast:172.18.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:13 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:1046 (1.0 KB)  TX bytes:0 (0.0 B)
...          
$ c1_id=$(sudo docker ps | grep hwchiu/netutils | awk '{print $1}')
$ sudo docker run -d --net=container:${c1_id} --name c2 hwchiu/netutils
$ sudo docker exec c2 ifconfig
eth0      Link encap:Ethernet  HWaddr 02:42:ac:12:00:02
          inet addr:172.18.0.2  Bcast:172.18.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:14 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:1116 (1.1 KB)  TX bytes:0 (0.0 B)
...          
```

在上述的測試中，我們先創建了 `c1` container，並且讓 `c2` 跟 `c1` 共用同樣一個 `network namespace`. 試想一個情況，這時候如果 `c1` container 終止了，整個情況會變成怎樣?

```bash=
$ sudo docker exec  c2 ifconfig
eth0      Link encap:Ethernet  HWaddr 02:42:ac:12:00:02
          inet addr:172.18.0.2  Bcast:172.18.255.255  Mask:255.255.0.0
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:15 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0
          RX bytes:1242 (1.2 KB)  TX bytes:0 (0.0 B)
...          
$ sudo docker stop c1         
$ sudo docker exec  c2 ifconfig
lo        Link encap:Local Loopback
          inet addr:127.0.0.1  Mask:255.0.0.0
          UP LOOPBACK RUNNING  MTU:65536  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)          

```

可以觀察到當 `c1` 結束後， `c2` 的 `container` 其實還在運作，但是最重要的 `eth0` 這個網卡卻消失了，這是因為 `c1` 離開使得其`network namespace` 的 `owner` 一併消失。如果 `c2` 這時候有一些對外的網路服務，就會沒有辦法存取與使用。

在這種狀況下，我們可以思考一下假如我想要有一個類似 `Pod` 的服務，裡面可以同時運行多個 `Container` 且可以共用同的 `network namespace`，到底該怎麼設計才可以滿足這個需求又要避免上述的問題。

通常的一個作法是於背後創造一個非常簡單 `container`，本身可能就是睡眠等待信號中斷來結束自己的 `sandbox container`，接下來所有使用者請求的 `container` 全部都掛到這個 `sandbox container` 上，這樣使用者請求的任何一個 `container` 出現問題終止，甚至重啟都不會影響到其他 `container` 的網路環境。

整個運作流程可以參考下圖，當 `contaienrtd` 創造好整個 `Pod` 所需要的一切資源後，最上層的呼叫者 `cri-contaienrd` 就會去呼叫 `CNI` 並且傳入上述所描述的參數。

![](https://i.imgur.com/K95n3LP.png)
上圖節錄自[Containerd Brings More Container Runtime Options for Kubernetes
](https://kubernetes.io/blog/2017/11/containerd-container-runtime-options-kubernetes/)

### Network Configuration

前面沒有講完的 Network  Configuration，這個本質是上一個 json 格式的檔案內容，由於是 json 的格式，所以其內容格式是由兩種規格所組成
1. CNI 標準所定義
2. 各自 `CNI` 解決方案所定義

所以未來去看每個 `CNI` 解決方案所使用的設定檔案時就會覺得看起來都很像，但是又看起來不像，原因就在於每個解決方案都有自己需要的資訊。

根據 [CNI Spec](https://github.com/containernetworking/cni/blob/master/SPEC.md#network-configuration)，目前的 Network Configuration 有下列欄位

#### cniVersion(Required)
設定檔案希望對應到的 `CNI` 版本，如果不符合的話 `CNI Plugin` binary 要回報錯誤

#### name(Required)
一個單純用來標示的名稱，本身沒有額外作用，唯一即可

#### type(Required)
這個非常重要，他對應的就是 `CNI Plugin` binary 的名稱。上層工具會先解析這個名稱，接者去找到對應的 binary 來執行，因此只要知道這個名稱就可以知道會被呼叫的 binary 是哪隻，反之依然這個名稱錯打錯，那整個 CNI 就不會順利執行，網路也就不會順利建立。

#### args
一些額外的參數，主要是由上層呼叫 `CNI`的應用程式填入的，譬如上述的 `cri-containerd` 如果有一些額外資訊也可以這邊提供。

#### ipMasq
標明當前這個 `CNI Plugin` 會不會幫忙做 `SNAT` 的動作，實作都還在各自 `CNI` 解決方案裡面，本身只是個欄位

#### dns
如果希望該 `CNI` 幫忙設定 DNS 相關資訊的話，可以在這邊去設定 DNS 譬如
  - name servers
  - search 
  - domain
  - options
這樣要特別注意的是雖然 `CNI` 有這個欄位，但是 `kubernetes` 本身並不希望 `CNI` 去設定 `DNS`，而是透過 `Pod Yaml` 裡面的欄位去處理，因此 `kubernetes` 處理這邊得時候會忽略這個值。

#### ipam
IP Address Management Plugin(IPAM), 專門負責管理 IP 的分配，這部分目前常見的有 `host-local` 以及 `dhcp`

這邊這個欄位的意思是讓 `CNI` binary 知道當前設定的 `IPAM` 是哪個應用程式，請呼叫該 `ipam` 去取得可用的 `IP address` 並且套用到相關的 `network namespace` 上。

之後會有一篇文章詳細的介紹 IPAM 的運作原理。



下面是兩個範例，可以觀察到範例中有一些欄位是上述標準沒有定義的，則是該 `CNI Plugin` 自己需要的欄位。

- 使用名為 `bridge` 的 `CNI` 解決方案，其中希望 `IPAM` 透過 `host-local` 去處理，並且分發的網段是 `10.1.0.0/16`。
- DNS 的部份希望可以設定成 `10.1.0.1`。
- 自定義參數有 `bridge`。
```jwon=
{
  "cniVersion": "0.4.0",
  "name": "dbnet",
  "type": "bridge",
  // type (plugin) specific
  "bridge": "cni0",
  "ipam": {
    "type": "host-local",
    // ipam specific
    "subnet": "10.1.0.0/16",
    "gateway": "10.1.0.1"
  },
  "dns": {
    "nameservers": [ "10.1.0.1" ]
  }
}
```

下面這個範例則是
- 使用名為 `ovs` 的 `CNI` binary
- `ipam` 的部份希望採用 `dhcp`，並且希望最後可以加入一些 `routes` 相關的資訊。

- 自定義參數有 `bridge`, `bxlanID` 等

```json=
{
  "cniVersion": "0.4.0",
  "name": "pci",
  "type": "ovs",
  // type (plugin) specific
  "bridge": "ovs0",
  "vxlanID": 42,
  "ipam": {
    "type": "dhcp",
    "routes": [ { "dst": "10.3.0.0/16" }, { "dst": "10.4.0.0/16" } ]
  },
  // args may be ignored by plugins
  "args": {
    "labels" : {
        "appVersion" : "1.0"
    }
  }
}
```

最後最後要談的是 **Network Configuration Lists**， `CNI` 標準中還提供了類似 `Plugin List` 的功能，允許對於相同 `network namespace` 運行多次 `CNI` 來創建多次網路，其中有個特別的點在於上層的 `CNI` 呼叫者需要把當前 `CNI` binary 的輸出結果當作下一個 `CNI` binary 的輸入一併傳入。

這種情況下會使用名為 **plugins** 的方式創造一個 **Network Configuration Array**，範例如下。

```json=
{
  "name": "cbr0",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}
```

對於上層呼叫 `CNI` 的應用程式，每個處理的邏輯跟流程並不一定相同，這個完全是看最上層的應用程式想要怎麼使用 `CNI`，這邊以 **dockershim** 為範例
1. 尋找 `CNI` 放置設定檔案的資料夾，並且排序所有檔案(*.conf *conflist *json)
2. 如果是 *.conflist 的檔案，就用 `Network Configuration List`的格式去讀取解析, 否則就用 `Network Configuration` 的格式去讀取來解析
3. 找到第一個合法的 `CNI` 設定檔案後，就根據裡面的 `type` 去執行對應的 CNI  binary。



``` go=
func getDefaultCNINetwork(confDir string, binDirs []string) (*cniNetwork, error) {
	files, err := libcni.ConfFiles(confDir, []string{".conf", ".conflist", ".json"})
	switch {
	case err != nil:
		return nil, err
	case len(files) == 0:
		return nil, fmt.Errorf("no networks found in %s", confDir)
	}

	cniConfig := &libcni.CNIConfig{Path: binDirs}

	sort.Strings(files)
	for _, confFile := range files {
		var confList *libcni.NetworkConfigList
		if strings.HasSuffix(confFile, ".conflist") {
			confList, err = libcni.ConfListFromFile(confFile)
			if err != nil {
				klog.Warningf("Error loading CNI config list file %s: %v", confFile, err)
				continue
			}
		} else {
			conf, err := libcni.ConfFromFile(confFile)
			if err != nil {
				klog.Warningf("Error loading CNI config file %s: %v", confFile, err)
				continue
			}
			// Ensure the config has a "type" so we know what plugin to run.
			// Also catches the case where somebody put a conflist into a conf file.
			if conf.Network.Type == "" {
				klog.Warningf("Error loading CNI config file %s: no 'type'; perhaps this is a .conflist?", confFile)
				continue
			}

			confList, err = libcni.ConfListFromConf(conf)
			if err != nil {
				klog.Warningf("Error converting CNI config file %s to list: %v", confFile, err)
				continue
			}
		}
		if len(confList.Plugins) == 0 {
			klog.Warningf("CNI config list %s has no networks, skipping", confFile)
			continue
		}

		// Before using this CNI config, we have to validate it to make sure that
		// all plugins of this config exist on disk
		caps, err := cniConfig.ValidateNetworkList(context.TODO(), confList)
		if err != nil {
			klog.Warningf("Error validating CNI config %v: %v", confList, err)
			continue
		}

		klog.V(4).Infof("Using CNI configuration file %s", confFile)

		return &cniNetwork{
			name:          confList.Name,
			NetworkConfig: confList,
			CNIConfig:     cniConfig,
			Capabilities:  caps,
		}, nil
	}
	return nil, fmt.Errorf("no valid networks found in %s", confDir)
}
```

# Summary

本篇文章開始跟大家討論什麼是 Container Network Interface (CNI)， 由於 CNI 牽扯到的內容實在太多，同時網路這個詞就是個概念，能夠做的事情實在太多，一時之間沒有辦法再一篇文章內講述並消化所有的事情。

因此本篇文章主要先有一個基本概念就是 CNI 本身的標準長什麼樣，會有什麼樣的設定
接下來會先探討 CNI 與 Kubernetes 的整合，包含了 kubelet 的設定檔案，以及相關 sandbox container 的架構。

再 CNI 的世界裡面，一切都是透過 `binary` 來呼叫對方，同時透過 STDOUT/STDIN 來傳輸資料，因此幾乎所有的 CNI 解決方案都是由不少個 Binary 組成的

因此我會特別介紹 IPAM(HostLocal) 以及 Linux Bridge (CNI) 這兩個最常被使用的工具，其被廣泛地使用到各個 CNI 解決方案內，原因就是他們提供的功能基本上很基本，但是也很好用。



# 參考
- https://github.com/containernetworking/cni
- https://kubernetes.io/blog/2017/11/containerd-container-runtime-options-kubernetes/
- https://kubernetes.io/docs/concepts/workloads/pods/pod/
- https://github.com/kubernetes/kubernetes/blob/master/pkg/kubelet/dockershim/network/cni/cni.go

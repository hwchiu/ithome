[Day26] Device Plugin - SRIOV
=============================

> 本文同步刊登於 [hwchiu.com - Device Plugin(SRIOV)](https://www.hwchiu.com/k8s-device-plugin-sriov.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin


有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

前篇文章基於 **RDMA** 介紹了一種提供高效能網路設備的 **device plugin**，然而除了 **RDMA** 之外，也有另外一款 **device plugin** 也可以針對改善網路環境而開發的，本篇就會針對這款更常被使用的 **SR-IOV** 進行介紹。

如同前述的 **RDMA** 一樣，也會先介紹一下其概念與架構，最後一下部署於 **kubernetes** 內的使用方法。


# 介紹
SR-IOV 簡單的說明就是透過虛擬化的方式將一個實體的 PCIe 裝置變成多個可以存取得 PCIe 裝置，也就是 IOV 的涵義， I/O Virtualization.

**SR-IOV** 可以應用的部分不單侷限於網路卡這一塊，其是基於 **PCIe** 裝置來完成的技術，不過本篇文章會專注於網路方便的應用，因此接下來的敘述都會針對網路部分去探討。

**SR-IOV** 本身利用了兩個概念來完成裝置虛擬化，分別是** Phyical Function(PF)** 以及 **Virtual Function(VF)**。

**PF** 算是整個 **PCIe** 裝置的主體，而 **VF** 只能算是一個輕量化的功能，專注於 **I/O** 方面的資源共享，同時本身不太能被設定控管。所有的操作都要基於 **PF** 來處理。

從使用者的角度來看，可以這樣去想像 **SR-IOV** 的使用情境，假設一個系統上只有一張實體網卡，但是該系統上需要運行多個虛擬化系統，不論是 **Virtual Machine** 或是 **Container**，而這些虛擬化系統本身都希望能夠有對外網路存取的能力，這時候可以有不同的作法
1. 如同前述 Container Network Interface 章節探討過的方式，可以利用 Linux Bridge + Veth + IPtables 等功能組合出讓封包流通的方式。
但是這種方式並不是特別討喜的原因在於封包會經過太多層的處理，有 **VETH** 要處理，又有 **Linux Bridge** 要處理，同時虛擬化本身的 **Kernel** 會處理一次，到達 **Host** 本身又要處理一次，因此整個封包經過的路徑太多，對於其效能不會特別完美。
2. 另外一種就是想辦法讓該虛擬化容器有可以直接使用 **host** 上網卡直接進行封包的傳送與接收，這種情況下封包就不會經過 **Host** 上的 **Linux Kernel Network Stack** 被處理，也不會上述的 **veth**, **Linux Brideg** 等不同層級封包處理的消耗，對於延遲性以及傳輸效能都會比較好。

**SR-IOV** 就是提供第二種類型的使用方式，將一張實體網卡切成多張虛擬網卡，每張虛擬網卡都可以獨立的給任意的虛擬化系統使用。

整個架構可以參考下圖
![](https://i.imgur.com/p3uVpf5.png)
本圖節錄自 [Networking Fundamentals](http://networkingtechprinciples.blogspot.com/2014/05/sr-iov-explained.html)

該圖中的網卡(NIC)有兩個孔，其中一個開啟 **SR-IOV** 的功能，另外一個沒有，可以用來進行比較。
上圖總共有四個 **Virtual Machine** ，其中左邊兩台直接透過 **SR-IOV** 的方式與 **Host** 上的 **Vitual Function** 連接，特別要注意的是每台 **VM** 上使用的是 **VF Device Driver** 相關的驅動程式來連接，這意味如果要使用 **SR-IOV**，並不是單純的將該 **Device** 掛載即可，還需要有額外的驅動程式來使用。

而上圖右邊兩個用法則是接近上述的用法一，透過一個 **Virtual Switch** 連接 **Host** 網卡以及 **VM** 上的所有虛擬網卡，所以可以觀察其使用的是 **vNIC Device Driver**，與前述的 **VF Deivce Driver** 不同。

不同於 **RDMA**， **SR-IOV** 本身是裝置的處理，透過網卡以及驅動程式相關的技術，模擬出一張網卡給應用程式使用，這種情況下
1. 應用程式不需要重寫，依然使用習慣的 **BSD Socket** 來撰寫，繼續走 **TCP/IP, UDP/IP** 等協定使用
2. 改變的層次在於更底層的裝置，所以並不是任何一張網路卡都可以支援這種做法，必須要配置支援 **SR-IOV** 的網卡，同時安裝對應版本的驅動程式，並且透過相關的設定去產生虛擬的網卡即可。

另外要注意的是，由於這些網卡都是基於 **Virtual Function** 來關聯到實體網卡，同時這些 **VF** 是共享網卡的資源，所以其效能最好就是逼近於實體網卡的使用，不像 **RDMA** 是整個協定層次都全部重來，效能比較起來自然會有所差異。

# Kubernetes

接下來要探討就是對於 **kubernetes** 的架構中，要如何使用這個 **SR-IOV**的裝置，要使用一個 **SR-IOV** 有幾個步驟需要完成

1. 安裝 **Driver**，創建 **PF,VF** 相關的設定
2. 將欲使用的 **VF NIC** 掛載到欲使用的 **Container**裡面
3. 針對該 **device** 創建相關的 **network interface** 進行設定，譬如 **IP**, **Routing**

上述的三個步驟實際上牽扯到不同的功能，第一個是偏向是 **device plugin** 來處理的，負責將相關的 **PF/VF** 設定並且掛載到 **Container** 中。
實際上這部分還仰賴系統的安裝，包括安裝對應的 **drvier** 來確保相關的 **kernel module** 可以使用。

而後兩個步驟則是之前介紹的 **CNI** 要處理的，根據需求選擇對應的 **VF** 來使用，並且設定相關的網路設定，如 **IP** 地址。

所以欲使用 **SR-IOV** 這個裝置的時候，通常除了安裝 **device-plugin** 相關的套件之外，也會一起安裝 **SR-IOV** 的 **CNI** 解決方案來處理。

## Multus CNI
但是先前於 **CNI** 的章節有介紹過 **CNI** 是一個基於節點的設定，且基本上是所有跑在該節點上的容器都會採用該 **CNI** 來處理。
麻煩的地方在於 **SR-IOV** 的環境並不一定是每個機器都需要使用，同時 **VF** 的數量是有上限的，每張網卡的能力不同，能夠支援的 **VF** 數量也不一致，所以這反而會影響能夠運行的 **Pod** 數量上限

另外一個麻煩的點在於一旦透過 **SR-IOV** 的技術，封包就直接從網卡出去了，這導致這些封包不會被 **Host** 端的 **Linux Kernel** 處理，這樣的後果就是 **Kubernetes service** 這個功能會完全壞光，完全不能用了。

為了解決這個問題，幾乎所有使用 **SR-IOV** 的解決方案，都會採用第三方的 **CNI** 來達到讓 **Pod** 動態選擇 **CNI** 的效果，譬如 **Multus, Geneie** 解決方案

透過 **Multus** 的幫忙，管理者可以於系統中管理多套 **CNI** 解決方案，並且每個 **Pod** 本身在創建的時候可以透過 **Annotation** 去決定要使用哪個 **CNI** 的解決方案。
此架構下，就可以根據需求來決定哪些應用需要引入 **SR-IOV** 來處理，哪些不需要可以繼續本來常用的 **Calico/Flannel** 處理。

這邊就不提及太多關於 **Multus** 的使用方法，有興趣的可以到[GitHub](https://github.com/intel/multus-cni/wiki/README_draft_1811)閱讀相關文件。

有了上述這種多重 **CNI** 管理的解決方案後，就可以看看接下來會怎麼使用 **SR-IOV**。



## Device Plugin

首先必須要安裝 **Device Plugin** 來管理節點上所有的 **SR-IOV** 裝置，包含總共數量，當前可用數量，狀態等，這些資訊會透過 **ListAndWatch** 傳遞給 **kubelet** 最後就可以到每個 **node** 上觀察到當前系統上的 **SR-IOV** 裝置數量。

關於該 **device plugin** 的詳細資訊，都可以參閱 [GitHub](https://github.com/intel/sriov-network-device-plugin)，這邊有完整的介紹，包含如何與 **Multus** 共同使用。

其中我覺得比較有趣的是該 **Device Plugin** 的設定檔案，因為支援 **SR-IOV** 的裝置並不是只有一款，每款對應的廠商以及驅動程式都不同，這種情況下要如何讓使用者可以很順利的根據需求選擇需要的 **device plugin** 來使用？

為了解決這個問題， **SR-IOV device plugin** 要使用者事先準備一個設定檔案，範例如下
```json=
{
    "resourceList": [{
            "resourceName": "intel_sriov_netdevice",
            "selectors": {
                "vendors": ["8086"],
                "devices": ["154c", "10ed"],
                "drivers": ["i40evf", "ixgbevf"]
            }
        },
        {
            "resourceName": "intel_sriov_dpdk",
            "selectors": {
                "vendors": ["8086"],
                "devices": ["154c", "10ed"],
                "drivers": ["vfio-pci"],
                "pfNames": ["enp0s0f0","enp2s2f1"]
            }
        },
        {
            "resourceName": "mlnx_sriov_rdma",
            "isRdma": true,
            "selectors": {
                "vendors": ["15b3"],
                "devices": ["1018"],
                "drivers": ["mlx5_ib"]
            }
        },
        {
            "resourceName": "infiniband_rdma_netdevs",
            "isRdma": true,
            "selectors": {
                "linkTypes": ["infiniband"]
            }
        }
    ]
}
```

該檔案裡面去描述所有節點中可能會用到的網卡資訊，包含**廠商**, **驅動程式**, **裝置名稱**, **pf 網卡名稱**。
一旦這些資訊準備好後， **SR-IOV** 的 **gRPC** 被啟動後就會去讀取這個資訊，然後開始檢查本系統上所有的網卡資訊，根據上述的條件把所有符合的裝置數量都找出來，並且根據 **resourceName** 的欄位向 **kubelet** 註冊這個資訊。
換句話說 **SR-IOV** 最後產生的資源數量不會只有一個，取決於設定檔案怎麼描述以及系統節點上硬體裝置的配置。


## SR-IOV CNI
完成 **device plugin** 後，接下來就是要處理 **VF** 的配置(實際上 kernel module啟動時就已經配置完畢，但是需要被創建出來使用)

這個解決方案的 [GitHub](https://github.com/hustcat/sriov-cni) 於此，很有趣的是其作者跟 **RDMA** 的是同一個人，是個很專注於網路發展的開發者，非常的厲害!

先來看看開頭的介紹
> PF is used by host.Each VFs can be treated as a separate physical NIC and assigned to one container, and configured with separate MAC, VLAN and IP, etc.
>

針對每個被掛載到 **Container** 的 **Virtual Function(VF)** 都可以設定 **MAC**, **VLAN** 以及 **IP** 地址。

來看一下一個範例的 **CNI** 設定檔案

```yaml=
{
    "name": "mynet",
    "type": "sriov",
    "master": "eth1",
    "ipam": {
        "type": "fixipam",
        "subnet": "10.55.206.0/26",
        "routes": [
            { "dst": "0.0.0.0/0" }
        ],
        "gateway": "10.55.206.1"
    }
}
```

首先 **type** 代表要執行的 **CNI Binary** 檔案，名為 **SRIOV**，而這邊我們透過 **master** 描述目標的 **PF** 是誰，預設情況下該 **CNI** 會自動地從可以用的 **VF**中挑一個可以用的 **VF** 出來匹配改容器使用，並且搭配 **IPEM, fixipam** 來設定相關的 **IP** 資訊。

```golang=
	if args.VF != 0 {
		vfIdx = int(args.VF)
		vfDevName, err = getVFDeviceName(masterName, vfIdx)
		if err != nil {
			return err
		}
	} else {
		// alloc a free virtual function
		if vfIdx, vfDevName, err = allocFreeVF(masterName); err != nil {
			return err
		}
	}
```
從上述 **CNI** 的實作可以看如果今天沒有傳遞一個叫做 **VF** 的參數的話，就會呼叫 **allocFreeVF** 來配置一個可用的 **VF**。如果有傳遞的話則是會根據該參數去得到對應的裝置，而實際上 **allocFreeVF** 的工作就是使用不同的 **VF** 參數後不停的呼叫 **getVFDeviceName** 來處理。

```golang=
func getVFDeviceName(master string, vf int) (string, error) {
	vfDir := fmt.Sprintf("/sys/class/net/%s/device/virtfn%d/net", master, vf)
	if _, err := os.Lstat(vfDir); err != nil {
		return "", fmt.Errorf("failed to open the virtfn%d dir of the device %q: %v", vf, master, err)
	}

	infos, err := ioutil.ReadDir(vfDir)
	if err != nil {
		return "", fmt.Errorf("failed to read the virtfn%d dir of the device %q: %v", vf, master, err)
	}

	if len(infos) != 1 {
		return "", fmt.Errorf("no network device in directory %s", vfDir)
	}
	return infos[0].Name(), nil
}
```

# Summary
最後用一個架構圖來描述 **SR-IOV** 使用後的可能架構
![](https://i.imgur.com/dV4RU1r.png)
該圖節錄自[常見 CNI (Container Network Interface) Plugin 介紹
](https://www.hwchiu.com/cni-compare.html)

首先該 kubernetes cluster 會使用 **Multus** CNI 來提供動態管理解決方案，對於圖中示範的 **Pod** 都會使用三個 **CNI** 分別是呼叫一次 **flannel** 以及兩次 **SR-IOV**。

兩次的 SR-IOV 可以針對不同的網卡給予不同的網路參數，包含 **IP**。更深層的意義在於這些網卡背後的實體網路配置，可以藉此提供不同的 **data plan** 網路拓墣。
這種情況下，這些 **Pod** 裡面就會有多張網卡，同時有多個 **IP** 地址，因此 **Routing** 的規則更為重要，要是沒有弄好可能就會處理錯誤，導致封包走錯網卡出去。

當然前述也有提過，因為封包都不會經過 **Host** 的 **Kernel Network Stack**，因此諸如 **Kubernetes Server (ClusterIP/NodePort)** 等功能對於 **SR-IOV** 的介面都不會生效，需要動腦看看該如何處理，甚至是放棄該功能，畢竟作為 **data-plan** 好像又不是說非常重要。

# 參考
- http://networkingtechprinciples.blogspot.com/2014/05/sr-iov-explained.html
- https://github.com/intel/multus-cni
- https://builders.intel.com/docs/networkbuilders/enabling_new_features_in_kubernetes_for_NFV.pdf
- https://github.com/hustcat/sriov-cni

[Day17] CNI 經驗談
=================

> 本文同步刊登於 [hwchiu.com - CNI 經驗談](https://www.hwchiu.com/cni-experience.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

作為網路系列文的最後一篇，本篇就不會針對特定的主題來進行討論，反而是一些老生常談(碎碎念），畢竟前面每天都寫得落落長，最後一篇讓我偷懶一下應該也合情合理。

本篇想要談談的是目前有這麼多的 **CNI**， 到底哪個適合自己? 以及為什麼有這麼多的 **CNI**，還有到底網路有什麼樣的有趣需求

前面探討了 **OCI** 以及 **CRI** 相關標準以及目前相關的實現解決方案，我們探討了 **Containerd, CRI-O,, Runc**， 基於虛擬環境的 **OCI Runtime** 如 **gVisor, Kata Container**。

那到底 **CNI** 這邊有多少解決方案可以選擇?

從[官方](https://github.com/containernetworking/cni/blob/master/README.md)目前擷取來的收錄清單如下

## 3rd party plugins
- [Project Calico - a layer 3 virtual network](https://github.com/projectcalico/calico-cni)
- [Weave - a multi-host Docker network](https://github.com/weaveworks/weave)
- [Contiv Networking - policy networking for various use cases](https://github.com/contiv/netplugin)
- [SR-IOV](https://github.com/hustcat/sriov-cni)
- [Cilium - BPF & XDP for containers](https://github.com/cilium/cilium)
- [Infoblox - enterprise IP address management for containers](https://github.com/infobloxopen/cni-infoblox)
- [Multus - a Multi plugin](https://github.com/Intel-Corp/multus-cni)
- [Romana - Layer 3 CNI plugin supporting network policy for Kubernetes](https://github.com/romana/kube)
- [CNI-Genie - generic CNI network plugin](https://github.com/Huawei-PaaS/CNI-Genie)
- [Nuage CNI - Nuage Networks SDN plugin for network policy kubernetes support ](https://github.com/nuagenetworks/nuage-cni)
- [Silk - a CNI plugin designed for Cloud Foundry](https://github.com/cloudfoundry-incubator/silk)
- [Linen - a CNI plugin designed for overlay networks with Open vSwitch and fit in SDN/OpenFlow network environment](https://github.com/John-Lin/linen-cni)
- [Vhostuser - a Dataplane network plugin - Supports OVS-DPDK & VPP](https://github.com/intel/vhost-user-net-plugin)
- [Amazon ECS CNI Plugins - a collection of CNI Plugins to configure containers with Amazon EC2 elastic network interfaces (ENIs)](https://github.com/aws/amazon-ecs-cni-plugins)
- [Bonding CNI - a Link aggregating plugin to address failover and high availability network](https://github.com/Intel-Corp/bond-cni)
- [ovn-kubernetes - an container network plugin built on Open vSwitch (OVS) and Open Virtual Networking (OVN) with support for both Linux and Windows](https://github.com/openvswitch/ovn-kubernetes)
- [Juniper Contrail](https://www.juniper.net/cloud) / [TungstenFabric](https://tungstenfabric.io) -  Provides overlay SDN solution, delivering multicloud networking, hybrid cloud networking, simultaneous overlay-underlay support, network policy enforcement, network isolation, service chaining and flexible load balancing
- [Knitter - a CNI plugin supporting multiple networking for Kubernetes](https://github.com/ZTE/Knitter)
- [DANM - a CNI-compliant networking solution for TelCo workloads running on Kubernetes](https://github.com/nokia/danm)
- [VMware NSX – a CNI plugin that enables automated NSX L2/L3 networking and L4/L7 Load Balancing; network isolation at the pod, node, and cluster level; and zero-trust security policy for your Kubernetes cluster.](https://docs.vmware.com/en/VMware-NSX-T/2.2/com.vmware.nsxt.ncp_kubernetes.doc/GUID-6AFA724E-BB62-4693-B95C-321E8DDEA7E1.html)
- [cni-route-override - a meta CNI plugin that override route information](https://github.com/redhat-nfvpe/cni-route-override)
- [Terway - a collection of CNI Plugins based on alibaba cloud VPC/ECS network product](https://github.com/AliyunContainerService/terway)

可以看到滿滿的解決方案，這時候其實沒有每個仔細研究的話，根本不知道彼此的差異性，同時如果自己沒有辦法評估或是描述自己的需求，最後就會變成一個不知道需要什麼解決方案的人再一堆不知道做什麼的解決方案中打轉尋找。

我覺得 **CNI** 有個最有趣的現象就是網路架構太不專一性，每個系統解決方案都有其搭配的網路架構，最後產生出來的解決方案都會彼此不同，所以其實可以看到上面不少 **CNI** 上面都伴隨者服務商的名稱，譬如
1. Amazon
2. VMWare
3. Nuage
4. Juniper
5. Terway (Alibaba 阿里巴巴)
6. ... 等


當然也有一些 CNI 沒有被收錄進來，譬如 [Azure](https://github.com/Azure/azure-container-networking/blob/master/docs/cni.md)


扣除掉服務商之後還是有為數眾多的 **CNI** 解決方案，這時候還是很令人困惑到底該怎麼選擇，目前最多人安裝大概就是 **calico** 以及 **flannel**，我想原因就是因為他們提供了基本的解決方法，已經可以滿足大部分人的需求，同時安裝簡單，一鍵部署輕鬆處理。

如同 **CRI** 有針對安全性提供的解決方案， **CNI** 這邊也有解決方案想要提高封包的安全性，譬如 [cilium](http://docs.cilium.io/en/stable/gettingstarted/#security-tutorials)。
針對與 **OpenvSwith** 整合則有 **OVN**，想要使用 **multicast** 可能會想要採用 **weave net**，對於 **Link Aggregation**也可以考慮使用 **bonding-cni**。

幾乎每個 **CNI** 都有自己要解決的問題，而這些問題到底你的環境有沒有也只有你自己有能力去評估跟評斷。
為了能夠更有能力去處理這類型的需求，我認為加強網路基本概念，對於封包轉發，路由，防火牆甚至是 **Linux Kernel Network Stack** 等各式各樣的領域都會有所幫助，只要目前都還是基於 **TCP/IP** 網路模型來傳輸的話，掌握幾個基本大方向，我認為對於大部分的問題都會有所幫助。

所以基本上我不會推薦一定要用什麼 **CNI**，畢竟不瞭解每個人的需求，不瞭解每個系統的瓶頸，就沒有辦法根據資訊去評斷出一個可行的方案。


此外，我先前也有寫過一篇文章介紹常見的 CNI 解決方案，有興趣的人可以閱讀一下掌握一下基本概念。
[常見 CNI (Container Network Interface) Plugin 介紹](https://www.hwchiu.com/cni-compare.html)


## 開發 CNI 

之前因為一些需求，自己也有嘗試開發 **SDN** 相關的 **CNI** 以及一個跨節點同網段的 **IPAM** 分配，開發的過程中其實遇到很多問題，這些問題仔細思量後發現 **CNI** 是個不歸路，這邊來跟大家分享一些不歸路的經驗。

通常講到系統效能最佳化或是提升的時候，都必須要先進行分析與測試找出系統中真正的瓶頸處，有些可能是系統資源(CPU/Memory)不足，導致處理速度不快，有些可能是儲存系統讀寫太慢，導致所有的處理都卡在IO，也有些可能是網路延遲太高或是頻寬過低，導致封包傳輸變成呈整體的系統瓶頸。

就一般來說網路通常不太會是個瓶頸，況且使用公有雲服務的 **kubernetes service**，使用者/管理者又真的有辦法去動到這些底層網路架構?

所以大部分情況下會比較少看到人在討論 **kubernetes** 內關於網路效能這一塊，比較多的都是網路帶來的功能，譬如 **service discovery**，**service mesh** 等各式各樣堆疊起來的服務。

但是，人生就是有個但是
隨者 **kubernetes** 的火紅與熱門，有些非常在意網路延遲與頻寬的使用場景都在思考是否能夠引入 **kubernetes** 來試試看，甚至是進行應用程式容器化
講白一點，**NFV(網路功能虛擬化)**，**電信商應用** 等相關使用場景的基礎建設，只要談到 **kubernetes**， **網路** 這一塊就會被拿出來探討該怎麼使用，譬如
1. 容器要有多張網卡
2. 容器想要低延遲的傳輸
3. 容器的網路傳輸可以多快
4. 容器是否能銜接原先的網路架構 


上述的這些問題其實目前於 **kubernetes**都有相關的解決方案可以解決，譬如
1. 多張網卡可以透過 **Multus**, **Genie**, **Knitter** 等相關 CNI 去呼叫不同的 **CNI**來創建多張網卡
2. 高速網路目前也有各式各樣的方式可以做，不論是 DPDK, SR-IOV, RDMA, InfiniBand, SmartNIC 等各種不同的網路架構
3. 能否銜接網路就要看本來的網路架構，用什麼樣的路由規則，用什麼樣的方式串接，用什麼樣的方式管理

其中最讓人頭痛且崩潰的就是第二點，高速網路能夠輕鬆取得大家都想要，但是一旦使用後就會發現 **kubernetes** 帶來的優點幾乎少一半。

1. Kubernetes Service/Ingress
2. Configuration/Deployment


### Service/Ingress

我先前曾經寫過四篇文章

[[Kubernetes] What Is Service?](https://www.hwchiu.com/kubernetes-service-i.html)
[[Kubernetes] How to Implement Kubernetes Service - ClusterIP](https://www.hwchiu.com/kubernetes-service-ii.html)
[[Kubernetes] How to Implement Kubernetes Service - NodePort](https://www.hwchiu.com/kubernetes-service-iii.html)
[[Kubernetes] How to Implement Kubernetes Service - SessionAffinity](https://www.hwchiu.com/kubernetes-service-iiii.html)

來探討 **kubernetes service** 本身的實作，預設情況下是如何透過 **Linux Kernel Netfilter** 來完成這些功能，就換切換成 **IPVS** 這種選項，也依然是透過 **Linux kernel** 來滿足的。

**Ingress** 不用說，後面也是依賴 **Service** 來完成後端的轉發。
所以 **kernel** 尤其重要，幾乎是整個 **Service** 功能的核心，但是上面提到那些高速網路解決方案，不是直接跳過 **Linux Kernel Network Stack** 不然就是他根本不是 **IP網路**。
這情況下，整個 **kubernetes service** 完全起不了作用，所謂的 **DNS** 帶來的輕鬆存取功能根本完全消失。

的確必非所有的應用情境都會需要這個功能，但是如果一但需要這個功能的話，就是一個額外的問題要去思考，該怎麼處理跟解決。
從 **CNI** 的角度來看，要解決這個問題還真的很煩，我覺得有些可以解，但是就是很煩，必須要寫程式碼去跟 **K8S API** 做同步，一旦 **Kube-Proxy** 有需求要增加任何規則的時候，該 **CNI** 要有其他的方式去做到一模一樣的功能來滿足這個需求，想到就是覺得很麻煩，整個 **CNI** 的功能就變成完全跟 **kubernetes** 跑，當初希望藉由 **interface** 來降低黏著性結果現在又反其道而行。

### Misc

除此之外，還有很多很有趣的需求，有些應用程式本身的設計是要固定 **IP** 的，造成該容器每次重啟或是 **Pod** 轉移後都需要固定 **IP**，這對於目前的架構來說是個挑戰，但是要解決還是有辦法，重新開發 **IPAM** 根據 **containerID** 來決定配置的 **IP**，或是用上述的 **CNI** 串接起來組合出一個很噁心的用法(Multus + Static IPAM + CRD + Pod Annotation)

也有一些情境是該容器本身的傳輸協定導致其幾乎不能做 **scale out**，永遠都只能有一個 **Pod** 運行，有的甚至連封包送出去的 **Port** 的號碼都被限制，意味單純的 **SNAT** 之類的方式就不能滿足需求，這時候工程師又要開始思考可以怎麼解決這一連串煩悶的問題，而這些問題最後帶來的大多數都只有一個結果，就是網路通了。

這也是我認為為什麼網路這個議題這麼普遍令人枯燥的原因，千辛萬苦只為求得一個 Ping 通...

## Configuration/Deployment
再來談談設定檔案的部分為什麼會讓人煩悶，前面我們已經知道可以透過 **daemonset** 的方式來自動安裝 **CNI** 相關的檔案，但是舉一些不同的 **CNI** 設定為範例

```json=
....
"delegates": [
        {
                "type": "sriov",
                "if0": "ens786f1",
		"if0name": "net0",
		"dpdk": {
			"kernel_driver": "ixgbevf",
			"dpdk_driver": "igb_uio",
			"dpdk_tool": "/path/to/dpdk/tools/dpdk-devbind.py"
		}
	},
....

{
    "cniVersion": "0.3.1",
    "name": "sriov-dpdk",
    "type": "sriov",
    "deviceID": "0000:03:02.0",
    "vlan": 1000,
    "max_tx_rate": 100,
    "spoofchk": "off",
    "trust": "on"
}
```
可以看到上述的設定檔案裡面包含了一些 **device**資訊，譬如 **0000:03:02.0**, **ens786f1** 等跟硬體有關的資訊，其實都會造成部署麻煩，沒有一個統一的 **CNI** 設定檔案可以安裝到所有節點，變成是這些檔案可能還要透過一些運算邏輯去產生，或是所有節點的增減都要人工介入去設定一切資訊。同時硬體資源還要考慮有限制，不能全部的 **Pod** 都使用這些資源，勢必又要有其他的機制譬如 **annotation** 來指名該 **Pod** 想要使用什麼樣的網路。

# Summary

網路的問題百百種，範圍與領域也幾乎沒有邊界可言，所以每次看到有人問網路該怎麼下手學習的時候，其實有時候反而不知道怎麼回答，感覺不論怎麼做都會先嚇跑一些人。

譬如上篇講到的 **overlay network**, 除了 **vxlan** 之外，還有各式各樣的實作，譬如 **GRE**, **Geneve**, **NVGRE** 等不同的東西，有些技術可能使用的廠商解決方案或是你的環境根本不需要，所以也不會有什麼機會去操作來實際了解，這些都造成了網路學習上的困難。

網路還有一些令人討厭的地方不一定所有環節都是可被觀察跟操控的，譬如你使用公有雲的服務，其實底下的節點怎麼互通的，每家廠商的解決方法都不同，有時候單純從一台機器的設定去看還看不出來到底怎麼實作的。

作為網路系列文的最後一篇，碎碎念了一些各式各樣的網路問題，接下來就要探討到儲存篇章了，歷經了 **OCI**, **CRI**, **CNI** 後，要來踏入 **Container Storage Interface (CSI)** 的範圍，儲存本身也是個坑，不同的裝置·不同的備援方式，異地備援。本地備援，快照，分散式儲存，多重讀寫等都是不同的議題，之後再來好好的討論儲存方面的各種有趣議題。

# 參考
- https://github.com/containernetworking/cni/blob/master/README.md
- https://github.com/intel/sriov-cni#using-dpdk-drivers

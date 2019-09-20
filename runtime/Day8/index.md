[Day8] Container Runtime - Security Container
==========================================

> 本文同步刊登於 [hwchiu.com - Container Runtime - Security Container](https://www.hwchiu.com/container-runtime-security-container.html)

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

`Container` 與 `Virtual Machine (VM)` 的比較從來沒有停止過，許多介紹 `Container` 的文章都會將 `Contianer` 與 `ＶM` 進行各種比較，譬如
1. 虛擬化程度
2. 安全性
3. 效能
4. 速度(創建/刪除)
5. 複雜性

根據這些特係的比較， `Container` 與 `VM` 並沒有誰勝誰敗，倒是取決於使用的情境與需求。

然而當 `Kubernetes` 橫空出世後，一開始最大的討論就是 `Kubernetes` 與 `OpenStack` 兩者的角色與地位，從可能競爭到後來互相合作，彼此作為整個架構中不同層級的應用。

然而 `Container` 雖然好用，但是在某些情況一直為人詬病，如隔離程度與安全性。
如同前面曾經談過的 `Container` 的實作(Linux 為例)，透過 `Linux Kernel` 的 `namespace` 來達成各式各樣資源的隔離，藉此完成一個輕量級虛擬化的空間。 一旦 `Linux Kernel` 有任何安全性問題，是不是所有的 `Container` 都可能會受到波及? 反之亦然，若 `Container`  本身實現的機制有問題，是不是有機會從 `Container` 內部攻擊到外面 `Host` 造成安全性問題。

譬如 2019 年初最知名的 `runc` 安全性漏洞
[Runc and CVE-2019-5736](https://kubernetes.io/blog/2019/02/11/runc-and-cve-2019-5736/)

這些情況下，很多人都在思考，到底有沒有辦法結合 `Container` 與 `VM` 彼此的優點，產生一個如 `VM` 強大的隔離與安全性，同時本身又可以夠輕量，速度又夠快如 `Container`.

基於這個設計理念下，有不少的相關專案在努力解決問題，其中我覺得有兩個最知名就是 `kata container` 以及 `gVisor`。

# 介紹

`kata container/gVisor` 這兩個專案都是基於 `OCI Runtime` 標準進行開發，就是一個所謂的 `OCI Runtime` 解決方案，其地位與 `Runc` 是相同的。
根據 [opencontainers/runtime-spec](https://github.com/opencontainers/runtime-spec/blob/master/implementations.md) 的介紹，我們可以看到下面目前被收錄的 `OCI Runtime`

第一種就是單純的 `Container`，沒什麼特別，就是被詬病有安全性隱憂的 `Container`。
>Runtime (Container)
opencontainers/runc - Reference implementation of OCI runtime
projectatomic/bwrap-oci - Convert the OCI spec file to a command line for bubblewrap
containers/crun - Runtime implementation in C
>

這一種特別了，就是基於 `Virtual Machine` 的方式去提供 `Container` 的介面來使用
>Runtime (Virtual Machine)
hyperhq/runv - Hypervisor-based runtime for OCI
clearcontainers/runtime - Hypervisor-based OCI runtime utilising virtcontainers by Intel®.
google/gvisor - gVisor is a user-space kernel, contains runsc to run sandboxed containers.
kata-containers/runtime - Hypervisor-based OCI runtime combining technology from clearcontainers/runtime and hyperhq/runv.
>

這邊看到有四個專案，分別是
- runv
- clearcontainers
- gvisor
- kata-containers

但是實際上目前就是 `gvisor` 以及 `kata-containers`，主要是因為 `kata-container` 是由 `runv` + `clearcontainers` 合併而成。

由於有限的時間，本篇沒有辦法跟各位分享如何安裝及測試這兩種不同的 `runtime`, 但是還是可以探討一下這兩種 `gvisor/kata-containers` 的差異，同時可以學習一下這兩個專案是採取何種不同的設計概念來滿足安全性


# 原先解決方案
## Machine-Based
我們先看一下大家熟悉的 `Virtual Machine` 通常怎麼做到安全隔離，這邊我們使用 `KVM` 的範例來看

![](https://i.imgur.com/vMUO3a3.png)
圖片節錄自[Architecture Guide](https://gvisor.dev/docs/architecture_guide/)

`KVM` 本身基於 `host` 的主機上再創造一個全新的虛擬化環境，該環境中有一個全新的 `Kernel`, 所以名詞上就會有所謂的 `Host Kernel` 以及 `Guest Kernel`. 
當然資訊安全本就沒有絕對，所有的服務都基於 `kvm` 的設計包含 `kvm kernel module`, 這些可能互動的過程中要是有問題也是會造成安全性漏洞。
不過今天討論的範疇在於虛擬化環境與 `Host` 本身是否會互相影響，所以暫時就先忽略其他的因素。

基於這種完全不同 `Kernel` 的架構， `Guest` 有發生任何事情，也都只會影響在 `Guest Kernel` 構築的環境中，不會影響到 `Host Kernel` 上。



## Rule-Based
另外一種安全性的解決方案是則是透過 `system call` 的管理，譬如 [SECure COMPuting (SECCOM)](https://www.kernel.org/doc/Documentation/prctl/seccomp_filter.txt) 這種技術，可以限制目標應用程式能夠呼叫到的 `sysytem call`，藉此確保該應用程式(Application/Container)本身沒有辦法去呼叫其不應該呼叫的 `system call`, 算是一種基於規則的安全性方案。


![](https://i.imgur.com/GSWN8fX.png)
圖片節錄自[Architecture Guide
](https://gvisor.dev/docs/architecture_guide/)



這邊有一個其規則的[範例檔案](https://github.com/moby/moby/blob/master/profiles/seccomp/default.json)


```json=
...
		{
			"names": [
				"get_mempolicy",
				"mbind",
				"set_mempolicy"
			],
			"action": "SCMP_ACT_ALLOW",
			"args": [],
			"comment": "",
			"includes": {
				"caps": [
					"CAP_SYS_NICE"
				]
			},
			"excludes": {}
		},
...
```

然而因其設定複雜，實務上很難可以很準確的產生出各種設定檔案來套用到各式各樣的應用程式。

接下來就來看一下 `gVisor` 以及 `kata Container` 怎麼做出不同於以往的安全性架構


# gVisor


`gVisor` 作為相容於 `OCI Runtime` 的解決方案，`理論`上只要能夠支援 `OCI` 的上層服務應該都要可以直接使用 `gVisor`，所以之前提到的 `containerd` 以及 `cri-o` 都要可以切換 `runtime` 從基本的 `runc` 切換過來。

從其 [官方 Github](https://github.com/google/gvisor) 的介紹

>gVisor is a user-space kernel, written in Go, that implements a substantial portion of the Linux system surface. It includes an Open Container Initiative (OCI) runtime called runsc that provides an isolation boundary between the application and the host kernel. The runsc runtime integrates with Docker and Kubernetes, making it simple to run sandboxed containers.

`gVisor` 最底層的 `OCI Runtime` 叫做 `runsc`，而其達到安全性隔離的手段則是透過所謂的 `user-space kernel` 的手段，接下來將透過介紹到底 `gVisor` 是怎麼
實現高安全性的 `Container`。

如果說 `SECCOMP` 是透過限制的方式禁止應用程式存取特別的 `systel call`, 那 `gVisor` 就是極端的把所有的 `system call` 完全都修改掉，讓你看起來有使用 `system call`，但是其實你使用的 `system call` 根本不是跟真正的 `host kernel` 溝通，而是跟 `gVisor` 所重新打造的 `user-space kernel` 溝通。

這也是為什麼其稱為 `user-space kernel`, 在 `user-space` 重新打造一個仿 `kernel` 的環境，架構如下。

![](https://i.imgur.com/q28fJdY.png)
圖片節錄自[Architecture Guide
](https://gvisor.dev/docs/architecture_guide/)

所有送到 gVisor 的 `system call` 都會被二次處理，接者才會送到真正的 `Host Kernel` 去取得需要的資訊。 官方文章特別表明這些不同的做法沒有明顯的優劣，各有擅長的領域，整句話如下，值得好好思考

>Each of the above approaches may excel in distinct scenarios. For example, machine-level virtualization will face challenges achieving high density, while gVisor may provide poor performance for system call heavy workloads.
 
# Kata Container

與 `gVisor` 一樣，都是基於 `OCI Runtime` 的解決方案，這時候就會覺得有個 `OCI` 的標準真的是讓世界稍微美好了一些，各式各樣的解決方案都能夠專注於自己的開發，就可以很輕鬆地與其他的應用程式結合而不需要各種客製化。

從其 [官網](https://katacontainers.io/) 的介紹
>Kata Containers is an open source container runtime, building lightweight virtual machines that seamlessly plug into the containers ecosystem.

其開宗明義表明建置一個輕量化的 `Virtual Machine` 同時能夠銜接到 `Container` 的系統，接下來我們可以從 [Kata Containers Architecture
](https://github.com/kata-containers/documentation/blob/master/design/architecture.md) 看到更多關於其設計的架構


首先先看一下簡單的使用架構，左邊是基於完全 `docker + runc` 的場景，此架構已經在 [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215) 中跟大家介紹過，而最下面的 `runc` 就是所謂的 `OCI Runtime`，因此 `kata container` 中的 `OCI Runtime` `kata-runtime` 就可以無縫的替換掉 `runc`。
對使用者來說可以繼續使用習慣的  `docker run/exec/attach` 等指令而不會發現底層其實已經完全不同了。

![](https://i.imgur.com/dII0wFL.png)
圖片節錄自[Kata Containers Architecture
](https://github.com/kata-containers/documentation/blob/master/design/architecture.md) 

`kata-container` 的作法完全不同於 `gVisor`, 其就如同過往的 `Virtual Machine` 一樣，真正的去創造一個 `VM` 來隔離所謂的 `Host Kernel` 以及 `Guest Kernel`. 接者會在這個 `VM` 上面去運行使用者所請求的 `Container`，藉此達到一個外表看似 `Container` 實際上是一個運行在 `VM` 上的 `Container.`

相關的架構可以參考下圖
![](https://i.imgur.com/PpzEOae.png)
圖片節錄自[About Kata Containers
](https://katacontainers.io/) 

在此架構下，我們可以想像到如果今天有任何 `container CLI` 想要直接操控該 `Container`的話，問題就在於從 `OCI Runtime` 送出的指令要如何操控到該 `VM` 裡面的 `Container`. 於是你可以看到架構中有所謂的 `Proxy` 以及 `Agent`
這兩個角色就是負責幫忙進行指令交換的，讓整個運作環境操作起來跟熟悉的 `Container` 一致，也符合最上面的專案介紹 **seamlessly plug into the containers ecosystem.**

## Network
當基本的 `Container` 運行起來後，接下來就要思考網路的問題，目前有兩套網路解決方案·分別是 `Docker` 提出的 `Container Network Management (CNM)` 以及 `kubernetes` 開發後提出的 `Container Network Interface (CNI)`。

更多的細節會到之後 `CNI` 的章節再來仔細探討這些，這邊先用一個簡單的流程說明到底 `Kata Container` 遇到什麼問題以及怎麼解決。

1. 大部分的 `CNI` 會透過 `Linux Kernel` 提供的 `veth` 這個功能來串聯不同的 `Network Namespace`，藉此讓封包可以在不同的隔離空間中傳輸
2. `Kata Container` 本身包了一個 `Virtual Machine` 在最外層，使得上述的方法不可行
3. 為了相容所有的 `CNM` 以及 `CNI`, 勢必要找一個 `network namespace` 供這些介面去使用
4. 於是決定先創造一個 `network namespace`(只有單純的網路功能隔離),`CNM/CNI` 會對這個 `network namespace` 進行設定，將相關的網路功能設定好，之後透過 `Linux Bridge` 配合 `Tap` 的方式將該 `network namespace` 上的網路介面與 `VM` 裡面的網路介面給串接起來。
5. 這邊實際上是透過 [MACVTAP](https://virt.kernelnewbies.org/MacVTap) 這個方式來串接, 有興趣的可以自行閱讀

![](https://i.imgur.com/19k2www.png)
圖片節錄自[Kata Containers Architecture
](https://github.com/kata-containers/documentation/blob/master/design/architecture.md) 


![](https://i.imgur.com/xF11rVU.png)
圖片節錄自[Kata Containers Architecture
](https://github.com/kata-containers/documentation/blob/master/design/architecture.md) 


# Summary
本章節跟大家分享並討論了一下基於安全性考量所發展的 `OCI Runtime` 專案,可以清楚地看到 `gVisor` 與 `kata container` 採取了兩種截然不同的方式來發展。
這兩個解決方案都相容於 `OCI Runtime`，所以只要上層的服務也支援 `OCI Runtime`，那就可以很輕鬆的轉移測試，譬如 `containerd` 或是 `cri-o`。

由於最後底層都是 `Container`, 所以使用者部屬的任何服務理論上都不需要修改，可以繼續使用各式各樣的 `Container Image` 以及相關的工具來處理。

下一篇就是 `CRI` 系列文章的最後一篇，到時候將跟大家如何將 `Kubernetes CRI` 與 `Virtual Machine` 給串接起來，這種情況下已經不需要 `Container Image` 了，而是要採用真正的 `VM Image` 並且透過 `Kubernetes` 來管理這些支援 `CRI` 操作但是實際上是完全跟 `Container` 無關的 `Virtual Machine` 解決方案。


# 參考
- https://github.com/kata-containers/runtime
- https://thenewstack.io/how-to-implement-secure-containers-using-googles-gvisor/
- https://github.com/kata-containers/runtime
- https://github.com/google/gvisor
- https://github.com/moby/moby/blob/master/profiles/seccomp/default.json
- https://katacontainers.io/

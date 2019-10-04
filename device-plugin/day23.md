[Day23] Device Plugin
=====================

> 本文同步刊登於 [hwchiu.com - Device Plugin](https://www.hwchiu.com/k8s-device-plugin.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin


有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

探討完畢運算，網路，儲存三大資源的標準介面 **CRI, CNI, CSI** 之後，接下來要探討的是另外一個可以擴充 **kubernetes** 本身功能的框架 **device plugin**。

這邊接下來都會使用 **框架** 來形容，是因為 **device plugin** 本身就是 **kubernetes** 自行實作且專屬於 **kubernetes** 使用的。 不同於上述的 **CRI,CNI,CSI** 這類型的標準其本身是獨立設計，不把 **kubernetes** 當作唯一的使用者，因此設計上就會盡可能彈性與抽象。

而 **device plugin** 框架作為 **kubernetes** 單獨使用，因此之後介紹的開發過程以及運作過程就會與 **kubernetes**，準確的說 **kubelet** 息息相關

# 開發理由

**device plugin** 開發出來的理由與之前提過的各種標準雷同，都是為了將程式碼分離，提供第三方解決方案提供者更靈活與彈性的開發流程，同時如果可以避開 **kubernetes** 本身邏輯的程式碼，專注於自身解決方案去開發的話又更好不過了。

早期的 **kubernetes** 針對運算資源的分配時的資源選擇，只有 **CPU** 以及 **Memory** 兩個最基本的硬體資源可以使用。然而除了這兩種資源之外，過往的各種系統應用場景也發展出了根據不同特性與需求的 **device**。 譬如
1. GPU
2. FPGA
3. Smart NIC
4. ...等

為了能夠提供一個更加方便的方式讓這些 **device** 被加入到 **kubernetes** 的操作邏輯中且能夠讓運算資源**Pod** 可以根據輕易地使用這些 **device**，更重要的是這些第三方解決方案提供者能夠用最簡單的方式來完成這一連串的概念。 於是 **device plugin** 框架因應而生。

該框架希望能夠讓第三方解決方案提供者專注於下列的功能就好，其餘與 **kubernetes** 的整合與使用就交由框架本身處理。
1. 確認相關 **device** 的資訊，譬如數量以及狀態
2. 讓該 **device** 有能夠被 **containers** 存取
3. 定期確認這些 **devices** 的資訊，譬如是否可用，是否運作正常

對於使用者來說，希望可以讓整個使用流程簡單且輕鬆
1. 部署 **device plugin** 解決方案的 **Pod** 去處理這些狀態
譬如 kubectl create -f http://vendor.com/device-plugin-daemonset.yaml
2. 部署運算資源的時候，可以透過 **node selector** 的方式去描述該運算資源需要多少個 **device** 來使用
譬如每個 **node** 上面都會被打上 **vendor-domain/vendor-device** 類似的標籤，這時候就可以透過這些標籤告訴 **scheduler** 要如何挑選符合資格的節點並且透過 **device plugin** 來掛載相關的資源到 **Pod** 裡面。

# 使用情境
什麼情況下使用者會想要使用 **device plugin** ? 官方列舉了三個情境
1. 想要使用特別的 **device** 裝置是官方沒有內建支援的，譬如 **GPU**, **InfiniBand**, **FPGE** 等
2. 可以再不撰寫任何 **kubernetes** 相關程式碼的情況下直接使用這些 **devices**
3. 希望有一個一致且相容的解決方案可以讓使用者於不同的 **kubernetes** 叢集中都能夠順利的使用這些跟硬體有關的 **devices**。

我認為這三種情境就已經充分描述的所有可能使用的情境，事實上大多數人的會使用這些的確是因為業務需求，使用情境而需要這些特別的 **devices**。



# 現存解決方案

如同前述的標準一樣，通常負責維護的相關文件中都會記載目前有被收錄的解決方案，當然也有許多沒有被收錄的，因為這些紀錄並不是官方主動去收集，而是解決方案必須要自己發送請求將自己的解決方案加入到官方的文件之中，所以有些解決方案沒有申請的話就不會顯示於官方資料中。

根據目前[官方文件](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/#examples) 的記載，目前有被收錄的 **device plugin** 如下

- The AMD GPU device plugin
- The Intel device plugins for Intel GPU, FPGA and QuickAssist devices
- The KubeVirt device plugins for hardware-assisted virtualization
- The NVIDIA GPU device plugin
- The NVIDIA GPU device plugin for Container-Optimized OS
- The RDMA device plugin
- The Solarflare device plugin
- The SR-IOV Network device plugin
- The Xilinx FPGA device plugins for Xilinx FPGA devices

看過去就是滿滿特殊用途的 **device**，其中我覺得 **GPU** 應該是近期最熱門的選項，隨者 **AI** 科技的發展，愈來愈多人踏入該領域並且嘗試各式各樣的操作，而 **GPU** 作為強力計算的基本需求，同時考慮到現在 **kubernetes** 這麼熱門，是否有辦法把這兩者結合打造出一個基於 **AI** 開發或是應用環境的 **kubernetes** 叢集也是一個有趣的方向。

之後的篇章會挑幾個有趣的 **plugin** 跟大家介紹一下其用途及用法。


# 使用流程

接下來根據[官方開發文件](https://github.com/kubernetes/community/blob/master/contributors/design-proposals/resource-management/device-plugin.md#vendor-story)，我們可以看一下一個使用情境以及用法會長怎麼樣，

## 開發者

對於開發者來說，基於 **gRPC** 的介面去實現相關功能(詳細的部分下篇文章會探討)，譬如說

```golang=
service DevicePlugin {
	// returns a stream of []Device
	rpc ListAndWatch(Empty) returns (stream ListAndWatchResponse) {}
	rpc Allocate(AllocateRequest) returns (AllocateResponse) {}
}
```

開發者基於這些介面去開發一個應用程式，該程式滿足上述的介面的功能，譬如回報當前 **device** 的狀態，根據需求去分配可用的 **device**。

接者開發者將該應用程式部署到 **kubernetes** 叢集之中，並且透過 **unix socket** 的方式與 **kubelet** 溝通，該路徑通常是 **/var/lib/kubelet/device-plugins/**，這個路徑跟之前研究 **CSI** 時候所觀察到的路徑非常類似，都是給 **kubelet** 使用的。

一但 **device plugin** 部署到節點之中，主動透過 gRPC 通知 **kubelet** 目前有新的 **device plugin** 安裝到系統中，並且準備註冊，一但這個步驟完畢後，整個 kubernetes 叢集中就知道這個 **device plugin** 的存在，並且使用者就可以開始使用了。

舉例來說，假設該開發者開了一個 **hwchiu/test-dev** 的 **device**，則下來都可以透過 **kubelet** 去查看每個節點上 **hwchiu/test-dev** 此 **device** 的總共數量以及當前可用數量。

## 使用者

對於使用者來說，使用起來的方式非常簡單，就是於 **Pod** 格式中透過 **resources** 的方式去定義需要什麼 **device** 且需要多少個

```yaml=
apiVersion: v1
kind: Pod
metadata:
  name: hwchiu-test-dev-pod
spec:
  containers:
    - name: test-pod
      image: hwchiu/netutils:latest
      workingDir: /root
      resources:
        limits:
          hwchiu/test-dev: 1 # requesting a devivce
```

當使用者提交上述的資源描述到 kubernetes 之中時，kubernetes scheduler 搭配 kubelet 就會去詢問所有節點上的 **device plugin**，透過上述的  **gRPC** 介面去詢問當前有多少個可用 **device** 並且找出所有符合該需求的節點。
當 **schedukler** 選定節點之後，就會再度透過該節點的 **kubelet** 透過 **gRPC** 去戳相關的 **device plugin** 應用程式去創立一個資源供目標的 **Pod** 使用。

整理一下流程就是:
1. Pod資源請求
2. Scheduler 搭配 kubelet 去尋找所有符合需求的 節點
3. Scheduler 選定一個節點部署
4. 該節點的 kubelet 呼叫 **device plugin** 解決方案去分配需求數量的 **device plugin** 供 **Pod** 使用。

當然當 **pod** 結束之後會有相對應的函式可以被呼叫來進行資源回收。

# Summary

本篇文章簡單簡述了一下關於 **Device Plugin** 的概念，並且簡單敘述了一下工作流程，
下一篇文章會針對 **device plugin** 本身的運作原理跟架構進行更仔細的討論。

# 參考
- https://medium.com/kokster/kubernetes-mount-propagation-5306c36a4a2d
- https://github.com/kubernetes/community/blob/master/contributors/design-proposals/resource-management/device-plugin.md

[Day25] Device Plugin - RDMA
============================

> 本文同步刊登於 [hwchiu.com - Device Plugin(RDMA)](https://www.hwchiu.com/k8s-device-plugin-rdma.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- [Container Storage Interface](https://ithelp.ithome.com.tw/articles/10224183)
- Device Plugin


有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

前述兩篇探討了 **Device Plugin** 的理念以及其框架的架構，接下來會探討幾個 **device plugin** 的案例。
相對於怎麼使用這些 **device plugin**，我覺得更有趣的是去探討這些 **device** 到底是什麼，能夠提供什麼功能，為什麼會被發展出來以及其應用場景長什麼樣？

而本篇要介紹的 **deivce plugin** 則是一個名為 **RDMA** 的裝置，接下來就來好好的探討這個裝置

# 概念介紹
RDMA (Remote Directly Memory Access)，期望透過記憶體存取技術的改變來大幅提升遠端機器之間溝通的效率。

按照其字面解釋的意思就是**遠端記憶體直接存取**，仔細看其實就是 **DMA** 記憶體直接存取的加強版，但是其實際影響範圍擴大到遠端機器。
簡單來說就是再不牽扯到 **CPU** 運算資源的前提下直接存取遠端機器上的記憶體，其架構可以參考下圖

![](https://i.imgur.com/i4mXe2R.png)
該圖節錄自[TCP BYPASS](https://linuxcluster.files.wordpress.com/2012/10/tcp_bypass_overview.pdf)

預先配置好相關的記憶體於系統中，接下來透過這項技術希望可以做到兩台機器可以直接存取這些記憶體。舉例來說，如果這兩台雞器本身是一個網路連線的程式，平常一些要交換的資訊透過其框架將這些資訊放置到特定的記憶體中，接下來要存取的時候就可以直接存取對方機器上的記憶體而不需要經過 **CPU** 去進行運算處理，對於整個效能提升期盼帶來成長


# 特性

RDMA 這項技術到底能夠帶來什麼優點? 常見的特色有
1. Zero Copy
2. Kernel bypass
3. No CPU involvement
4. Message based transactions
5. Scatter/Gather entries support

## Zero Copy
此特色源自於 **DMA**，目標就是希望能夠減少 **記憶體** 的複製，這邊先思考一個情境，任何的資料想要於 **User Space** 與 **Kernel Space** 中交換的話，並沒有辦法直接交換，因為其使用的記憶體位置是完全切割的，所以才會有一些 **copy_from_user** 之類的函式用來處理。
一個常見的 **Zero Copy** 的範例是，假設今天想要讀取一個檔案，讀取完畢後什麼都不處理就直接輸出，這種情況下其實該筆資料的內容根本沒有再 **User Space** 被處理，實際上可以一直放在 **kernel** 後直接輸出，所以就可以減少資料複製的行為藉此提高整個運算速度。

將這個檔案處理的邏輯套用到網路運算上就是網路應用程式封包的傳輸，能否減少必要的複製行為來降低延遲性。

## Kernel Bypass

另外一個重要的特色就是跳過 Kernel，目前已經有不少的網路技術專案再探討如何透過跳過 **Kenrel** 來達到更快的處理速度，譬如讓 **User Space** 的應用程式直接跟網卡對街，直接處理封包，畢竟 **Kernel** 要處理的事情又多又複雜，並沒有辦法針對網路應用程式最佳化，因此跳過 **kernel** 儼然成為一個可考慮的解決方案之一。

## No CPU Involvement
除了上述的兩個特性外，還有一個有趣的特色就是可以再不使用遠端 **CPU** 的情況下直接讀取遠方的記憶體，這部分要仰賴網卡本身的幫忙以及協定的互助，此外對於 **CPU**來說根本不知道有任何記憶體被讀取，因此對於快取的部分也都不會有任何影響

## Message Based Transactions
基於 RDMA 封裝後的封包傳輸都是基於message 為單位，是一個已經定義好的的格式來處理，想對於單純直接使用 TCP 這種 streaming 的傳輸格式來說，開發者就不需要自己不停的拆解封包來判斷當前的格式與內容


## Scatter/Gather Entries Support
此功能是提供一次性處理多個 message 的能力，不論是發送封包，接受封包，都可以一次性處理多個 **message** 的封包。此特色並不是類似迴圈般呼叫多次，而是一次的呼叫可處理多筆的資料。

# 優勢
看了上述的各種特色後，組合起來能夠為 **RDMA** 這項技術帶來什麼樣的優勢

1. 低延遲性
2. 高傳輸量
3. 低 CPU 使用量

但是世界通常沒有這麼美好，實際上上述的三個優勢並不是同時存在的，會需要根據需求台調整不同的設計以及用法來達成，這部分可以看看 [Tips and tricks to optimize your RDMA code](http://www.rdmamojo.com/2013/06/08/tips-and-tricks-to-optimize-your-rdma-code/) 這篇文章裡面的描述來如何最佳化你的應用程式

稍微節錄一下裡面的四大章節
1.  Improving the Bandwidth
2.  Reducing the latency
3.  Reducing memory consumption
4.  Reducing CPU consumption

根據不同的需求都有不同的方法去設定，甚至包含程式碼撰寫的方式都會影響最後的效能，也因此 **RDMA** 的撰寫難度頗高，整個框架完全不同且使用情境也會影響寫法。

# 效能

這邊擷取自 **Mellanox** 關於 **NFS** 進行 TCP/RDMA 兩者的[效能比較](https://blog.mellanox.com/2018/06/double-your-network-file-system-performance-rdma-networking/)，有興趣的可以自行閱讀看看比較說明，以結果論來說大致上都有兩倍左右的提升，不論是傳輸速度，或是每秒可執行的操作數

![](https://i.imgur.com/tVcb5Sd.png)
以上圖片節錄自[Double Your Network File System (NFS) Performance with RDMA-Enabled Networking
](https://blog.mellanox.com/2018/06/double-your-network-file-system-performance-rdma-networking/)

![](https://i.imgur.com/a4X8NGA.png)
以上圖片節錄自[Double Your Network File System (NFS) Performance with RDMA-Enabled Networking
](https://blog.mellanox.com/2018/06/double-your-network-file-system-performance-rdma-networking/)

![](https://i.imgur.com/mTLCjyh.png)

以上圖片節錄自[Double Your Network File System (NFS) Performance with RDMA-Enabled Networking
](https://blog.mellanox.com/2018/06/double-your-network-file-system-performance-rdma-networking/)

# 架構

接下來使用下列這張圖片來解釋一下 **RDMA** 的架構。

![](https://i.imgur.com/R80AQVx.png)
該圖節錄自[Mobile D2D RDMA CAAP, Cluster As Application Platforma](https://www.slideshare.net/yitzhakbg/5th-generation-cellular-d2d-space-with-clusters)

首先該圖片上半部分成三層，分別是 **Application**, **User Space**, **Kernel Space**，並且透過這三層次的比對來介紹 **RDMA** 與傳統 **TCP/IP** 運作的差異。

下半部分則是介紹當 **RDMA** 的封包離開網路卡後，要如何跟外網的裝置進行溝通，有什麼樣的協定可以採用。

## 上半部分

首先，圖片左半部分則是傳統的 **TCP/IP** 運作流程，網路應用程式會透過 **systel call** 的方式創建一個 **socket**，並且透過這個 **socket** 來進行連線，傳輸，接收等相關操作。

而 **kernel** 部分則是會有一個與上述 **socket** 對應的接口，一旦該接口接收到封包後，就會進行網路相關的處理，從 **TCP** 一路處理到 **ETH** 最後透過相關的驅動程式與網卡對接，讓封包順利送出。

對於 **RDMA** 來說整個運作模式完全不同，首先其使用的介面完全不同於傳統的 **BSD Socket API**，所以程式撰寫的部分是需要完全重寫，可以看到圖上使用的是 **RDMA Verbs API**。

接下來由於 **Kernel Bypass** 的緣故，應用程式會透過 **API** 直接與相關的驅動程式溝通，封包不會經過的 **Kernel Network Stack** 的處理，所以比對起來就會發現其走過的路徑相對較簡單。

## 下半部分

接下來封包到達網卡後若要往外移動，這時候就有不同的選擇可以處理
若今天部署的環境是基於 **InfiniBand** 的環境，這種情況下環境內的 **Swtich** 都要是 **InfiniBand** 的交換機才能夠處理這種格式的封包。

提到右邊的 **iWARP** 以及 **RoCE** 前要先有一些背景介紹，上述提到的 **RDMA** 除了網卡本身支援外，其封包傳遞的格式也就跟 **TCP/IP** 不相容，因此如果沒有特別處理的話，對於採用 **Ethernet** 的網路架構中，是不能用這種應用程式的。

為了解決這個問題，有兩個不同相容於 **Ethernet** 的協議被發展出，分別是 **iWRAP** 以及 **RoCE**。

其中 **iWARP** 基於 **TCP** 去實作，而 **RoCE** 則是基於 **UDP**，所以看到圖
中這兩個協議最後都接上了 **Ethernet** 交換機。


### lossless network
這邊額外提一下 **RoCE** 的架構下，會希望整個網路是所謂的 **lossless network**，因為其協定是基於**UDP**的，所以掉了任何一個封包其實都很麻煩，如果可以讓網路架構本身去確保不會掉封包，這樣整個 **RoCE** 這邊就可以用更少的事情在處理重送之類的機制，反而可以更專注於效能的發送

這篇[文章](https://blog.mellanox.com/2016/07/resilient-roce-relaxes-rdma-requirements/)中提到了三種達到 **lossless network** 的方法，有興趣可以再研究
Ethernet Flow Control (802.3x)
PFC (Priority Flow Control)
ECN (Explicit Congestion Notification)

# kubernetes

前面探討了關於 **RDMA** 的基本介紹，基本上就是一個希望講求高效率網路傳輸的技術，使用上需要安裝相關的 **driver** 以及支援的網卡來處理。

接下來看一下 **kubernetes** 關於 **RDMA** 的 **device plugin**

## Deployment

其安裝的方式非常簡單，幾乎所有的 **device plugin** 都一樣，畢竟是一個要跟每個節點的 **kubelet** 溝通的 **gRPC server**，引此採用 **DaemonSet** 的方式來安裝也是合情合理。


```yaml=
  
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: rdma-device-plugin-daemonset
  namespace: kube-system
spec:
  template:
    metadata:
      # Mark this pod as a critical add-on; when enabled, the critical add-on scheduler
      # reserves resources for critical add-on pods so that they can be rescheduled after
      # a failure.  This annotation works in tandem with the toleration below.
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ""
      labels:
        name: rdma-device-plugin-ds
    spec:
      tolerations:
      # Allow this pod to be rescheduled while the node is in "critical add-ons only" mode.
      # This, along with the annotation above marks this pod as a critical add-on.
      - key: CriticalAddonsOnly
        operator: Exists
      hostNetwork: true
      containers:
      - image: carmark/k8s-rdma-device-plugin:latest
        name: rdma-device-plugin-ctr
        args: ["-log-level", "debug"]
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: ["ALL"]
        volumeMounts:
          - name: device-plugin
            mountPath: /var/lib/kubelet/device-plugins
      volumes:
        - name: device-plugin
          hostPath:
            path: /var/lib/kubelet/device-plugins
```


使用上非常簡單，但是前述提到必續要有相關的應用程式才可以使用這種裝置，並不是任何一個目前使用 **TCP/IP** 的應用程式都可以輕鬆轉換過去，因此為了測試可以使用 **Mellanox** 提供的容器來測試。

### Usage
```yaml=
apiVersion: v1
kind: Pod
metadata:
  name: rdma-pod
spec:
  containers:
    - name: rdma-container
      image: mellanox/mofed421_docker:noop
      securityContext:
        capabilities:
          add: ["ALL"]
      resources:
        limits:
          tencent.com/rdma: 1 # requesting 1 RDMA device
```

使用 **device plugin** 就是這樣簡單，能夠讓容器內部的應用程式看起來跟在實體機器使用上沒有差異，而最大的問題反而是使用情境以及相關的應用程式要如何搭配這些高速的網路設備來使用。


# 參考
- https://github.com/hustcat/k8s-rdma-device-plugin
- https://linuxcluster.files.wordpress.com/2012/10/tcp_bypass_overview.pdf
- http://www.rdmamojo.com/2013/06/08/tips-and-tricks-to-optimize-your-rdma-code/
- https://community.mellanox.com/s/article/docker-rdma-sriov-networking-with-connectx4-connectx5
- https://blog.mellanox.com/2016/07/resilient-roce-relaxes-rdma-requirements/
- https://blog.mellanox.com/2018/06/double-your-network-file-system-performance-rdma-networking/

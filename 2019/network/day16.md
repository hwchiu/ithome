[Day16] CNI - Flannel 封包傳輸原理 - VXLAN分析
===========================================

> 本文同步刊登於 [hwchiu.com - CNI - Flannel - VXLAN分析](https://www.hwchiu.com/cni-flannel-ii.html)

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

前面兩篇文章探討了 **flannel** 的相關事項，包括了
1. 如何安裝 **flannel**，其安裝過程中到底執行了什麼步驟以及如何透過 **daemonset** 來確保設定檔案的一致與自動化安裝
2. **flannel** 如何去分配 **IP** 地址，目前透過官方安裝文件安裝的 **flannel** 都會透過 **kubernetes API** 去取得由 **kubernetes controller manager** 裡面 **node IPAM** 所自行分配的網段，並且將該資訊寫成檔案放到本機上面 **/run/flannel/subnet.ev** 上。 最後 **FlannelCNI** 執行的時候會讀取該資訊並且再次呼叫 **host-local CNI IPAM** 來處理該網段的 **IP**分配問題，最終產生一個可用的 **IP** 地址給 **Pod** 使用。


本篇文章作為 **flannel** 的最後一個章節，想要跟大家來分享基於 **VXLAN** 設定的 **flannel** 本體是怎麼運作的，到底是如何讓不同節點內運行 **Pod** 可以互相溝通的。


# 環境建置
為了搭建一個擁有三個節點的 kubernetes cluster，我認為直接使用 **kubernetes-dind-cluster** 是個滿不錯的選擇，可以快速搭建環境，又有多節點。

或是也可以土法煉鋼繼續使用 **kubeadm** 的方式創建多節點的 kubernetes cluster， 這部分並沒有特別規定，總之能搭建起來即可。

此外相關的版本資訊方面
- kubernetes version:v1.15.4
- flannel: 使用[官方安裝 Yaml](https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml) + 上一點修改
因為 **Vagrant** 預設的環境會有兩張網卡，其中第一張是沒有辦法換 **IP** 的，會導致整個 **flannel** 運作出問題，所以要修改該 **yaml** 讓 **flanneld** 運行的時候加上一個參數，範例如下，請記得根據平臺修改對應的 **daemonset**
```yaml=
        - name: kube-flannel                                                                                                                                                           [363/9057]
        image: quay.io/coreos/flannel:v0.11.0-amd64
        command:
        - /opt/bin/flanneld
        args:
        - --ip-masq
        - --kube-subnet-mgr
        - --iface
        - eth1
```
- kubeadm 安裝過程使用的參數 **--pod-network-cidr=10.244.0.0/16**


# Why Network

探討 **flannel** 的運作原理之前，我們需要先思考一件事情，到底 **flannel** 要解決什麼問題，或是說 **kubernetes cluster** 預設沒有 **CNI** 的情況下，可能會有什麼樣的網路問題需要仰賴 **CNI** 來處理。

# Before CNI

再 **CNI** 安裝到 **kubernetes cluster** 前，我們可以先假想一個環境，假如今天 **kubernetes cluster** 上的每個節點都有自己的 **IP** 地址，且彼此互通。
現在要開始運行多個 **Pod** 於各個節點上，這時候有幾個事情要考慮
1. 這些 **Pod** 的 **IP** 到底怎麼來，是跟本來的網路架構用相同網段? 還是重新再分配一個私有網段?
2. 不同節點上面的 **Pod** 如果彼此要可以透過網路互相溝通，要怎麼封包傳輸才會通?

這兩個問題沒有標準解答，隨者應用場景其答案也都不同，這也是為什麼會有這麼多 **CNI** 的解決方案的原因之一，因為網路的世界太大太廣，沒有辦法一言而諭找到一個通解。

不同的使用場景，對於網路的要求也不同，有的講求能通就好，有的講求要低延遲，有的希望有各式各樣的輔助功能，所以對於 **CNI** 的選擇，很多時候反而要先問，自己的需求是什麼，再來挑選適合的 **CNI** 解決方案。

上述的問題如下圖，這時候 **CNI** 都還沒有涉入，要思考的就是 **IP** 到底網段哪來，以及如何溝通

![](https://i.imgur.com/MVQMaql.png)


## IP 分配
**IP** 分配問題的話，有些情況會希望所有的 **Pod** 跟外面的節點與現存服務使用相同的網段，有些情況則覺得沒有關係，分配一些私有網段即可。

舉一個範例，如果今天系統中已經運行了大量的服務，這時候希望導入 **kubernetes** 作為部署工具，但是基於現實考量，譬如測試，容器化等因素，並不是所有的服務都可以一次就直上 **kubernetes**。 同時本來的系統架構中，會有類似防火牆等安全機制，會根據 **來源IP/目的IP** 進行一些檢查與過濾，這種情況下，使用者可能就會希望 **kubernetes** 內的 **pod** 可以跟本來環境中的網路使用相同網段的 **IP** 甚至是使用 **dhcp** 等方式來獲取 **IP**。

但是對於部分的使用者來說，其實不太需要在乎這一塊議題，主要是在意的點只有 **能不能方便存取**, **kubernetes service** 能不能滿足需求，你裡面的 **Pod** 到底是什麼 **IP** 很多時候根本不重要。

如果是公有雲的解決方案，有些也會希望能夠同網段，這樣可以跟公有雲其他的資源進行整合，不論是 **IP**的發放，**防火牆**的設定等都希望能夠只用公有雲一套規則滿足全部。

這部分我之前有一篇文章在介紹 [Azure - AKS](https://www.hwchiu.com/aks-cni-i.html)是怎麼實現其 **CNI** 來達到上述需求的。有興趣的讀者可以再額外閱讀。 

## Overlay Network
網路串連的方法百百種，每種方法都有其價值以及使用場景，這次要來討論的則是 **VXLAN**，這個 **flannel** 預設的網路實現方式。

以下圖為一個基本範例，根據前篇文章我們知道每個節點都會分配到不同網段，這個案例中分別是
![](https://i.imgur.com/jhHkgVH.png)
1. 10.244.0.0/24
2. 10.244.1.0/24
3. 10.244.2.0/24

所以這三個節點所創造的 **Pod** 都會基於上述所描述的網段
```bash=
# kubectl get pods -o wide
NAME                             READY   STATUS    RESTARTS   AGE     IP           NODE        NOMINATED NODE   READINESS GATES
k8s-udpserver-6576555bcb-4dc77   1/1     Running   0          2m11s   10.244.0.3   k8s-dev     <none>           <none>
k8s-udpserver-6576555bcb-4wl9n   1/1     Running   0          2m11s   10.244.1.8   k8s-dev-1   <none>           <none>
k8s-udpserver-6576555bcb-7rvnj   1/1     Running   0          24h     10.244.2.2   k8s-dev-2   <none>           <none>
k8s-udpserver-6576555bcb-949wp   1/1     Running   0          2m11s   10.244.2.4   k8s-dev-2   <none>           <none>
k8s-udpserver-6576555bcb-9mwcv   1/1     Running   0          2m11s   10.244.0.5   k8s-dev     <none>           <none>
k8s-udpserver-6576555bcb-b7nbx   1/1     Running   0          2m11s   10.244.2.6   k8s-dev-2   <none>           <none>
k8s-udpserver-6576555bcb-bt94h   1/1     Running   0          2m11s   10.244.2.5   k8s-dev-2   <none>           <none>
k8s-udpserver-6576555bcb-c9v9w   1/1     Running   0          24h     10.244.1.4   k8s-dev-1   <none>           <none>
k8s-udpserver-6576555bcb-d6lqp   1/1     Running   0          2m11s   10.244.2.3   k8s-dev-2   <none>           <none>
k8s-udpserver-6576555bcb-dhmw9   1/1     Running   0          2m11s   10.244.1.5   k8s-dev-1   <none>           <none>
k8s-udpserver-6576555bcb-jlc45   1/1     Running   0          2m11s   10.244.1.6   k8s-dev-1   <none>           <none>
k8s-udpserver-6576555bcb-nwfbl   1/1     Running   0          24h     10.244.0.2   k8s-dev     <none>           <none>
k8s-udpserver-6576555bcb-rtrq9   1/1     Running   0          2m11s   10.244.2.7   k8s-dev-2   <none>           <none>
k8s-udpserver-6576555bcb-v9cwz   1/1     Running   0          2m11s   10.244.0.4   k8s-dev     <none>           <none>
k8s-udpserver-6576555bcb-xwdbv   1/1     Running   0          2m11s   10.244.1.7   k8s-dev-1   <none>           <none>
```

這個情況下，我們希望讓 **10.244.0.0/24** 網段可以與 **10.244.1.0/24** 網段溝通，這時候 
**flannel** 會怎麼做。

先假設一個情境, **10.244.0.5** 想要與 **10.244.2.7** 溝通，由於牽扯到跨網段的問題，所以會有 **gateway** 的涉入，更麻煩的是這些網段都是私有網段，一旦封包從該節點出去後，要怎麼確保外面的所有網路架構都知道該如何轉送這些封包？

舉例來說，假設 **10.244.0.5** 的封包很順利的從節點出去了，接下來整個外網的網路要怎麼知道原來目的 **10.244.2.7** 是屬於 **172.17.8.103** 這台機器上的?
只要外部網路裡面有一個環節不通，整個封包就送不到 **172.17.8.103**，就沒有辦法送進去到 **Pod**，更不要提假如今天外部網路已經有一個一模一樣的 **IP** 或是網段，是不是會造成 **IP** 衝突的問題，導致網路存取出問題？

此外這些外部的網路機器交換機大部分 **kubernetes cluster** 也不會去操控去管理，所以就會變成根本沒有一條合適的路由規則來轉發封包。

為了解決這個問題，我們決定使用基於 **overlay network** 的技術 **VXLAN** 來解決這個問題。

### Overlay Network
**overlay**  顧名思義就是基於原先 **underlay network** 上在疊一層封包，**flannel** 採用的是基於 **VXLAN** 的封包協定來實現 **overlay network**。

一個簡單的概念，**VXLAN** 會在本來的傳輸封包上再重新開放疊加 Layer 2/3/4 總共三層全新的封包，我們先定義最原始傳輸的目標叫做 **Original Packet**， 而新疊加的則叫做 **Outer Packet**。

所以上述的封包傳輸 **10.244.0.5** -> **10.244.2.7** 為範例
![](https://i.imgur.com/jhHkgVH.png)

**10.244.0.5** -> **10.244.2.7** 傳輸的封包就是所謂的 **original packet**。
因為 **10.244.0.5** 位於機器 **172.17.8.101**，**10.244.2.7** 位於機器 **172.17.8.103**。
因此會再額外包一層
**172.17.8.101** 與 **172.17.8.103** 的傳輸的封包就是所謂的 **outer packet**。

下面來看一下 **VXLAN** 的封包格式
![](https://i.imgur.com/npK0WX6.png)
該圖截取自[Configuration Guide - VXLAN
](https://support.huawei.com/enterprise/en/doc/EDOC1100004365/f95c6e68/vxlan-packet-format)

所以其實基於 **VXLAN** 傳輸的封包再網路上傳送的時候，其內部其實會有兩層傳送的資料，一層是透過 **underlay** 搞定的，也就是 **outer packet**，而另外一層則是真正要傳送的，也就是 **original packet**。

搭配上圖的格式圖可以發現， **VXLAN** 本身也會額外再 **Original** 與 **Outer** 中間塞一個 **VXLAN Header** 去標注一些相關功能，其中的 **VNI** 是做到類似 **VLAN** 相同的效果，相同 **VNI** 的兩端點才有能力溝通。
眼尖的人會發現上述 **Outer Packet** 裡面有 **UDP Packet** 裡面有一個 **DestPort(VXLAN) Port**，這就意味者其實收端(172.17.8.103)會有一個網路程式聽在該 Port上面去幫忙處理這些封包。
當該程式看到這些封包後，會將這些的外皮剝掉然後看到最裡面的 **Original Packet**，最後幫忙轉發。

### 流程


重新整理一下整個流程，如何透過 **VXLAN** 來解決 **10.244.0.5** -> **10.244.2.7** 的傳輸問題
1. 10.244.0.5 往 10.244.2.7 發送封包
2. 這些封包再離開節點之前會先被本地上的 **VXLAN** 應用程式處理，首先加上 **VXLAN Header**
3. 接者填補 **UDP Header**
4. 接者根據某些方式知道 **10.244.2.7** 位於 **172.17.8.103**，所以補上一個 **IP Header**，其中將來源設定成本機**172.17.8.101**，目的設定成 **172.17.8.103**
5. 封包送出去
6. 外面的所有機器都是看到 **172.17.8.101** -> **172.17.8.103** (這個傳輸本來就應該要可以運作，不然 **kubernetes cluster** 沒辦法建立)
7. 當封包到達 **172.17.8.103** 收到封包後，一路拆解最後被 **VXLAN** 應用程式收到封包，並且看到裡面是 10.244.0.5 往 10.244.2.7 送的封包，於是將該封包往下轉發
8. 最後 **10.244.2.7** 就可以順利地收到 **10.244.0.5** 的封包。

上面的流程看似簡單合理，但是其中隱藏些許問題
1. **VXLAN** 的應用程式是什麼
2. 上述的應用程式怎麼知道 **10.244.2.7** 位於 **172.17.8.103**，反之亦然，目標端的要知到 **10.244.0.5** 位於 **172.17.8.101**


### 實作

接下來我們來探討上述的兩個問題是怎麼處理的，先說結論

**Linux Kernel** + **flannel pod** + **Kubernetes API server** 一起合力完成上述的所有流程。

先來看一個有趣的東西，仔細再看一次每個 **node** 上面的 **annotation**，會發現一些有趣的東西
```bash=
$ kubectl get node k8s-dev -o=json | jq -r .metadata.annotations
{
  "flannel.alpha.coreos.com/backend-data": "{\"VtepMAC\":\"0a:72:64:c9:50:f4\"}",
  "flannel.alpha.coreos.com/backend-type": "vxlan",
  "flannel.alpha.coreos.com/kube-subnet-manager": "true",
  "flannel.alpha.coreos.com/public-ip": "172.17.8.101",
  "kubeadm.alpha.kubernetes.io/cri-socket": "/var/run/dockershim.sock",
  "node.alpha.kubernetes.io/ttl": "0",
  "volumes.kubernetes.io/controller-managed-attach-detach": "true"
}

$ kubectl get node k8s-dev -o=json | jq -r .spec
{
  "podCIDR": "10.244.0.0/24"
}
```
1. backend-type: vxlan， 代表其用到的類型
2. backend-data: 有 **VtepMac**, 還有一些 **MAC Address**。
3. public-ip: "172.17.8.101"
4. podCIDR: "10.244.0.0/24"

是不是只要把(3)跟(4)的資訊給合併起來，就完全解決上述的問題(2)？
這其實也反應到為什麼最上面的環境建置的時候，要透別加入 **--iface eth1** 的參數到 **flannel** 的環境中，因為需要讓 **flannel** 知道真正的對外 **IP** 是使用哪張網卡，他才有辦法擷取到相關的 **IP** 並且寫入到 **Node** 之中。

由於這些資訊是每個節點都要知道每個節點的，所以其實 **flanneld** 本身有實作 **List/Watch Node** 相關的流程，一旦 **Node** 本身的資訊有更動，就會去抓取這些資訊來更新當前節點的知識

如果還記得前兩天的文章，是否還記得 **Flannel** 創建的 **RBAC** 裡面會特別允許 **Node List/Watch** ，目的就是為了這個。

所以現在的流程是
1. **flannel pod** 會知道本地端用的各種資訊，譬如 **subnet**，**publicIP**，接者把這些資訊都會打到 **Node** 裡面
2. 所有節點的 **flannel pod** 都會去監聽相關事件，聽取到之後就會將該資訊存放在本地端的記憶體內，知道每個網段對應的節點資訊。



接下來我們來看一下最後幾個步驟，這幾個步驟就不會描述太多，細節比較複雜，稍微帶過相關的資訊，知道所有的資訊在哪邊即可。


首先上述提到 **Linux Kernel** 現在都有支援 **VXLAN** 的實作，這意味我們可以透過 **Kernel** 內建的功能來幫忙處理
1. VXLAN 的應用程式
2. VXLAN 封包的封裝與解封裝

我們先來觀察到底實際上系統被加料了什麼來處理這些資訊
```bash
$ ip -d addr show dev flannel.1
5: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default
    link/ether 0a:72:64:c9:50:f4 brd ff:ff:ff:ff:ff:ff promiscuity 0
    vxlan id 1 local 172.17.8.101 dev eth1 srcport 0 0 dstport 8472 nolearning ttl inherit ageing 300 udpcsum noudp6zerocsumtx noudp6zerocsumrx numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
    inet 10.244.0.0/32 scope global flannel.1
       valid_lft forever preferred_lft forever
    inet6 fe80::872:64ff:fec9:50f4/64 scope link
       valid_lft forever preferred_lft forever
```
透過 **ip link** 指令可以看到系統上被創建了一個新的網卡，這個網卡有一些資訊很重要
1. flannel.1 這個 **.1** 是有意思的，代表其 VNI 是 1
2. vxlan id 1 (該介面是屬於特殊型態 VXLAN)
3. nolearning (本身不會主動去學習該怎麼轉送，代表要有人教)
4. local 172.17.8.101 dev: 對應到本地的對外介面
5. 10.244.0.0/32: flannel.1 的 IP 地址，這意味所有送到 10.244.0.0 的封包都會送到給 flannel.1 處理

接下來我們來看一下會怎麼轉送
```bash=
$ route -n | grep flannel
10.244.1.0      10.244.1.0      255.255.255.0   UG    0      0        0 flannel.1
10.244.2.0      10.244.2.0      255.255.255.0   UG    0      0        0 flannel.1

$ arp -na | grep 10.244
? (10.244.2.0) at ee:8a:1f:f7:96:c7 [ether] PERM on flannel.1
? (10.244.1.0) at 8e:79:a7:a7:bd:1c [ether] PERM on flannel.1

$ bridge fdb show | grep 172
8e:79:a7:a7:bd:1c dev flannel.1 dst 172.17.8.102 self permanent
ee:8a:1f:f7:96:c7 dev flannel.1 dst 172.17.8.103 self permanent
```

1. 路由表中表示，如果今天封包要送給 10.244.2.0/24，則把 **gateway** 設定成 **10.244.2.0**，並且透過 **flannel.1** 這張網卡傳輸
2. 由於封包中的目標 **MAC** 是 **next hop** 的地址，所以此情況需要填入 **10.244.2.0** 的 **MAC** 地址，該地址可以在 **kubernetes node** 上找到。
3. 最後會被 **flannel pod** 透過 **arp** 的方式寫死在系統內，可以由上述的 **arp -n** 看到相關資料
4. 有了上述資料後，我們已經可以把 **Original Packet**填寫完畢，接下來就剩下 **outer pakcet** 要填寫
5. 最後透過 **bridge forward database** 去查看，對於 **flannel.1**來說，看到裡面封包的目標地址是 **ee:8a:1f:f7:96:c7** 的，請於 **outer packet** 轉發到 **172.17.8.103**。

透過上述流程就可以組合出一個合法的 **VXLAN** 封包格式，並且送到不同節點去。

另外每台機器上面都會被創造一個 **flannel.1** 的介面，該介面其實就會作為每個節點的 **VXLAN** 處理程式，封包收到相關的封包後，會透過 **vni** 的方式與 **mac** 比對的規則找到對應的介面去進行處理，然後解封裝後再次轉發。

最後補上一個流程，這些 **flannel.1** 的介面都是由 **flannel pod (flanneld)** 這個應用程式創造的，同時當該應用程式從 **kubernetes API server** 學習到不同的節點資訊的時候，就會把上述看到的 **route**, **arp**, **bridfge fdb** 等資訊都寫一份到 **kernel** 內，藉此打通所有的傳送可能性。


# Summary

最後就用一張圖來解釋上述的所有流程。
![](https://i.imgur.com/dqfVlGK.png)


# 參考
- https://vincent.bernat.ch/en/blog/2017-vxlan-linux
- https://www.slideshare.net/Ciscodatacenter/vxlan-introduction
- https://support.huawei.com/enterprise/en/doc/EDOC1100004365/f95c6e68/vxlan-packet-format

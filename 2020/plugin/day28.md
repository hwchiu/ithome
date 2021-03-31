Day  28 - Kubernetes 第三方好用工具介紹
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



今天則要來介紹一些其他關於 kubernetes 操作的好工具，每個工具都有自己適合的地方與場景，每個人就根據自己的習慣選擇



# Stern/Kail

第一個要分享的工具是跟觀看 log 有關的， Kubernetes 由於提供很多個副本，同時透過 deployment/replicaset 創建出來的 Pod 名稱上面都會有一些不好閱讀的亂數，舉例來說

```bash
$ kubectl get pods
NAME                      READY   STATUS    RESTARTS   AGE
ithome-6564f65698-947rv   1/1     Running   0          84s
ithome-6564f65698-fglr9   1/1     Running   0          84s
ithome-6564f65698-k5wtg   1/1     Running   0          84s
ithome-6564f65698-rrvk4   1/1     Running   0          84s
ithome-6564f65698-zhwlj   1/1     Running   0          84s
```

這種情況下我們如果使用 kubectl 來觀察個別 Pod 的 log 就必須要於不同的 pod 之間來回切換，可時候有時候要除錯問題時，就希望可以同時觀看這些 Pod 的 log。

因此今天要介紹的工具就是再處理這方面的需求，主要是針對多個 Pod 同時存取相關的 log 並且整理後顯示出來，這方面的工具滿多的，譬如 Stern, Kube-tail, Kail 等都可以。 而今天則是會介紹 Stern 的用法

從其官網上可以看到說明

> Stern allows you to `tail` multiple pods on Kubernetes and multiple containers within the pod. Each result is color coded for quicker debugging.
>
> The query is a regular expression so the pod name can easily be filtered and you don't need to specify the exact id (for instance omitting the deployment id). If a pod is deleted it gets removed from tail and if a new pod is added it automatically gets tailed.

特別的是你可以透過正規表達式的方式來選擇你想要符合的 Pod

## 安裝

直接到官方 [Github Release Page](https://github.com/wercker/stern/releases) 抓去每個平台的 binary 版本

## 使用

舉例來說，上述範例會有五個 pod，而且這五個pod的名稱都是 ithome開頭，因此我可以直接用 `stern ithom` 的方式來抓取這些 pod 的資訊，結果如下圖

```bash
$ stern ithome
...
ithome-6564f65698-zhwlj netutils Hello! 369 secs elapsed...
ithome-6564f65698-fglr9 netutils Hello! 369 secs elapsed...
ithome-6564f65698-947rv netutils Hello! 367 secs elapsed...
ithome-6564f65698-k5wtg netutils Hello! 368 secs elapsed...
ithome-6564f65698-rrvk4 netutils Hello! 369 secs elapsed...
ithome-6564f65698-zhwlj netutils Hello! 370 secs elapsed...
ithome-6564f65698-fglr9 netutils Hello! 370 secs elapsed...
ithome-6564f65698-947rv netutils Hello! 368 secs elapsed...
ithome-6564f65698-k5wtg netutils Hello! 370 secs elapsed...
ithome-6564f65698-rrvk4 netutils Hello! 370 secs elapsed...
ithome-6564f65698-zhwlj netutils Hello! 371 secs elapsed...
ithome-6564f65698-fglr9 netutils Hello! 371 secs elapsed...
ithome-6564f65698-947rv netutils Hello! 369 secs elapsed...

ithome-6564f65698-k5wtg netutils Hello! 371 secs elapsed...
ithome-6564f65698-rrvk4 netutils Hello! 371 secs elapsed...
ithome-6564f65698-zhwlj netutils Hello! 372 secs elapsed...
ithome-6564f65698-fglr9 netutils Hello! 372 secs elapsed...
^C
```

實際上觀看的時候，不同 Pod 的名稱還會有不同的顏色標註，幫助使用者更快的區別這些文字。



# K9S

過往總是透過 kubectl 指令於各個資源，各 namespace 間切來切去，特別是要使用 `exec, get, describe, logs, delete` 等指令時，常常打的手忙腳亂或是覺得心累，有這種困擾的人可以考慮使用看看 k9s 這個工具

K9s 官網介紹

> K9s provides a terminal UI to interact with your Kubernetes clusters. The aim of this project is to make it easier to navigate, observe and manage your applications in the wild. K9s continually watches Kubernetes for changes and offers subsequent commands to interact with your observed resources.

基本上就是基於 Terminal 去提供一個友善的操作畫面，讓你可以透過鍵盤來輕鬆的完成上面提到的事情，不論是切換 namespace, 砍掉資源，執行 Shell, 觀看 log 等都可以輕鬆達成。

## 使用

上述五個 pod 的範例透過 k9s 執行後可以得到下面的畫面，畫面中可以清楚地看到

1. Pod 的名稱
2. 有沒有開 Port-Forward
3. 當前 Continers's READY 狀態
4. 當前 Pod 狀態
5. 當前 IP
6. 運行節點資訊
7. 存活時間
   這些指令其實都可以用 kubectl 獲得，但是操作起來可能就相對繁瑣，需要比較多的指令

![](https://i.imgur.com/eOMBFcw.png)



此外畫面上方還會有一些基本資訊，譬如 Context/Cluster/User 等 Kubeconfig 內的資訊，右邊還有可以使用的快捷鍵，除了上述提到的功能之外，還可以透過 `port-forward` 來使用，個人覺得相當不錯。

![](https://i.imgur.com/yNScI5K.png)



一路往下點選後，還可以看到每個 Pod 裡面每個 Container 各自的 log, 使用上非常方便，過往有多個 containers 的時候都要於 `kubectl logs -f $Pod_name -c $container_name` 來讀取，特別是沒有仔細去看 Pod 的設定都會忘記 Container Name，這時候又要再跑別的指令查詢一次。

![](https://i.imgur.com/GetTetQ.png)



透過 k9s 這工具可以提供一個滿不錯的視窗管理工具，讓你一目了然 kubernetes 當前的狀態，並且提供基本功能讓你進行操作



# Ksniff

接下來要介紹的是一個抓取網路封包的工具，過往我們分析封包的時候都會使用 tcpdump 或是 wireshark 這些工具來輔助，而 Ksniff 就是一個將這些工具整合到 Kubernetes 系統內的工具

Ksniff 的介紹如下

> A kubectl plugin that utilize tcpdump and Wireshark to start a remote capture on any pod in your Kubernetes cluster.
>
> You get the full power of Wireshark with minimal impact on your running pods.

基本上本身也是一個 kubectl 的 plugin ，所以也是可以透過前述的 krew 來安裝管理。這邊就不再贅述其安裝過程



## 使用

其使用上的概念是，選擇一個想要觀察的 Pod，然後 Ksniff 這個工具會嘗試幫你將 tcpdump 的執行檔案給複製到該 Pod的某個 Container 裡面(預設是第一個)，接下來根據你的參數幫你運行 tcpdump，最後將結果複製出來到本機上面的 wireshark 來呈現。

但是假如系統中沒有 wireshark 可以呈現這些結果，可以改用命令列的工具，譬如 tshark 來取代

```bash
$ sudo apt install tshark
$ kubectl sniff ithome-6564f65698-947rv -o - | tshark -r -
$ kubectl sniff ithome-6564f65698-947rv -o - | tshark -r -
INFO[0000] sniffing method: upload static tcpdump
INFO[0000] using tcpdump path at: '/home/ubuntu/.krew/store/sniff/v1.4.2/static-tcpdump'
INFO[0000] no container specified, taking first container we found in pod.
INFO[0000] selected container: 'netutils'
INFO[0000] sniffing on pod: 'ithome-6564f65698-947rv' [namespace: 'default', container: 'netutils', filter: '', interface: 'any']
INFO[0000] uploading static tcpdump binary from: '/home/ubuntu/.krew/store/sniff/v1.4.2/static-tcpdump' to: '/tmp/static-tcpdump'
INFO[0000] uploading file: '/home/ubuntu/.krew/store/sniff/v1.4.2/static-tcpdump' to '/tmp/static-tcpdump' on container: 'netutils'
INFO[0000] executing command: '[/bin/sh -c ls -alt /tmp/static-tcpdump]' on container: 'netutils', pod: 'ithome-6564f65698-947rv', namespace: 'default'
INFO[0000] command: '[/bin/sh -c ls -alt /tmp/static-tcpdump]' executing successfully exitCode: '0', stdErr :''
INFO[0000] file found: '-rwxr-xr-x 1 root root 2696368 Jan  1  1970 /tmp/static-tcpdump
'
INFO[0000] file was already found on remote pod
INFO[0000] tcpdump uploaded successfully
INFO[0000] output file option specified, storing output in: '-'
INFO[0000] start sniffing on remote container
INFO[0000] executing command: '[/tmp/static-tcpdump -i any -U -w - ]' on container: 'netutils', pod: 'ithome-6564f65698-947rv', namespace: 'default'

```

從上面可以觀察到這些資訊就代表系統開始運行了，這時候我們可以開啟第二個視窗，進入到該 Container 內透過 `ping 8.8.8.8` 往外送封包，並且觀察上述的輸出

```bash
$ kubectl exec ithome-6564f65698-947rv -- ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=97 time=9.42 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=97 time=9.44 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=97 time=9.36 ms
...
------
$ kubectl sniff ithome-6564f65698-947rv -o - | tshark -r -
...
    2  38.393757   10.244.1.8 → 8.8.8.8      ICMP 100 Echo (ping) request  id=0x04f5, seq=1/256, ttl=64
    3  38.403163      8.8.8.8 → 10.244.1.8   ICMP 100 Echo (ping) reply    id=0x04f5, seq=1/256, ttl=97 (request in 2)
    4  39.394274   10.244.1.8 → 8.8.8.8      ICMP 100 Echo (ping) request  id=0x04f5, seq=2/512, ttl=64
    5  39.403697      8.8.8.8 → 10.244.1.8   ICMP 100 Echo (ping) reply    id=0x04f5, seq=2/512, ttl=97 (request in 4)
    6  40.395882   10.244.1.8 → 8.8.8.8      ICMP 100 Echo (ping) request  id=0x04f5, seq=3/768, ttl=64
    7  40.405230      8.8.8.8 → 10.244.1.8   ICMP 100 Echo (ping) reply    id=0x04f5, seq=3/768, ttl=97 (request in 6)
    8  41.397387   10.244.1.8 → 8.8.8.8      ICMP 100 Echo (ping) request  id=0x04f5, seq=4/1024, ttl=64
...
```

可以看到另外一個視窗很及時地將相關的封包內容都給顯示出來。

我認為這個工具最方便的地方就是幫你上傳 tcpdump 的檔案，因為大部分的 Container 內建都沒有這個執行檔案，甚至也不好安裝，所以要錄製封包的時候都不太方便，然而透過這個工具可以幫忙解決這個問題

除此之外還有很多有趣好用的工具，就留待大家自己挖掘囉
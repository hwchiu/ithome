[Day4] 淺談 Container 實現原理, 以 Docker 為例(III)
==================================================

> 本文同步刊登於 [hwchiu.com - 淺談 Container 設計原理(III)](https://www.hwchiu.com/container-design-iii.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- Container & Open Container Initiative
- Container Runtime Interface
- Container Network Interface
- Container Storage Interface
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

前一天的文章中，我們探討了如何透過現有的工具來創造出滿足 `OCI` 標準的 `Container` 並且稍微介紹了一下 `Docker` 內的架構，理解一下 `Docker Client`, `Docker Engine`, `Containerd` 以及 `Containered-shim`

相對於前幾天都在觀察 `OCP` 以及 `Docker` 創建容器的過程，今天則是會更細部的針對底層資源進行研究，譬如 `Networking` 與 `Storage`.

在前述的文章中有提到`Linux` 環境中是透過了 `Namespace` 來提供各式各種不同資源隔離，而其中有兩個之後再 `kubernetes` 中也會頻繁出現的分別是 `Networking` 以及 `Storage`.

所以今天的文章就要來探討一些關於上述兩種資源是如何完成隔離化的。

# Networking
## Namespace
`Network` namespace 本身隔離了 `Network Stack`, 這意味包含了 `interface`, `ip address`, `iptagbles`, `route` 等各式各樣跟網路有關的資源都被隔離。



接下來我們可以做一個簡單的操作來看看，再操作上我們都會使用 `ip netns` 的指令來使用

```bash=
#create network namespace ns1
ip netns add ns1
##exec in ns1
ip netns exec ns1 bash
#check interface
ifconfig -a
```

這時候你應該會看到類似下面的畫面。

```bash=
lo: flags=8<LOOPBACK>  mtu 65536
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

因為該新創建的 `network namespace` 是完全空的，所以裡面除了最基本的 `loopback` 之外不會有任何其他的網卡。

此外，這時候前往 `/var/run/netns` 你會觀察到有一個名為 `ns1` 的檔案，上述`ip netns` 相關的指令則會根據這個檔案進行處理。


# docker
接下來嘗試創建一個 `docker container`, 並且觀察看看是否有辦法透過 `ip netns` 的方式來觀察該 `container`.

```bash=
sudo docker run -d hwchiu/netutils
```

這時候按照上述的方法去觀察
```bash=
sudo ip netns ls
sudo ls /var/run/netns
```
會發現完全沒有看到其他的資訊，依然只有先前創立的 `ns1`，原因是
 `docker` 創建 `network namespace` 後會將該檔案從 `/var/run/netns/` 中移除，所以導致沒有辦法用 `ip netns` 相關的指令去檢視。
 
但是其實這些檔案一直都在系統之中，畢竟系統要運行，資訊也必須存在，所以我們可以透過一些方法把該檔案重新找回來，最後重新放回 `/var/run/netns` 中，最後就可以透過 `ip netns` 的方式來操作。

0. 先取得待觀察之 `container` 的 `containerID`
2. 先取得該 `Container Process` 於 `Host` 上的 `PID`
3. 前往該 `PID` 於 `/proc/xxxx/ns` 底下找到所有的 `namespace`
4. 將上述發現的 `namespace` 建立連結到 `/var/run/ns`
5. 可以使用 `ip netns` 等指令來操作

```bash=
sudo docker ps
```

```bash
hwchiu@k8s-dev:/var/run$ sudo docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
2be547d81b69        hwchiu/netutils     "/bin/bash ./entrypo…"   6 minutes ago       Up 6 minutes                            priceless_cray
```

```bash=
container_id=2be547d81b69
pid=$(sudo docker inspect -f '{{.State.Pid}}' ${container_id})
sudo ln -sfT /proc/$pid/ns/net /var/run/netns/${container_id}
sudo ls /proc/19265/ns
sudo ls /proc/19265/ns/
sudo ip netns ls
sudo ip netns exec ${container_id} ifconfig
```

這時候你應該會看到類似下面的輸出

```bash=
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.18.0.2  netmask 255.255.0.0  broadcast 172.18.255.255
        ether 02:42:ac:12:00:02  txqueuelen 0  (Ethernet)
        RX packets 14  bytes 1116 (1.1 KB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

```

這時候可以嘗試使用 `docker` 系列的指令來觀察看到的資訊是否一致

```bash=
sudo docker exec -it ${container_id} bash
ifconfig
```

理論上我們先前透過 `ip netns` 操作的對象就是該 `container` 的 `network namespace`, 所以看到的資訊必須要一致且一樣的。

除了這個基本概念之外，在 `docker` 與 `kubernetes` 裡面都有一個網路選項是 `net=hostnetwork`, 這個的意思就是`請不要創建額外的 network namespace`,請使用與 `host` 相同的 `network namespace`. 這個情物下，你就可以在 `container` 內外都看到相同的網路資源 `NIC, Route, IP, IPtables..etc`


# Storage

常常使用 `docker` 的人一定對於 `volume mount` 這個概念不陌生，不論是 `docker volume` 更上層的抽象化或是單純運行時期掛載上去的 `docker run -v xxx:xxx` 等都能夠用來解決部分的 `Container` 內的需要的儲存問題

於 `linux` 底下，通常我們都會使用 `mount` 來處理檔案的掛載問題

首先我們先啟動一個簡單的 `Container` 來掛載一個外部的資料夾到 `Container` 內使用

```bash=
sudo docker run -d -v /home/:/outside-home hwchiu/netutils
```

這時候透過本機的指令去檢查 `host mount namespace` 會完全看不到跟 `/home` 有關的任何資料

```bash=
mount | grep home
sudo cat /proc/self/mountinfo | grep home
```

這是因為該容器的 `mount` 相關資訊也都被 `mount namespace` 隔離了，就如同 `networking` 一樣，我們其實也可以在該 `container process` 的相關檔案中找到該資訊
```bash=
#change the id to your container id
container_id=b9428568d3ff
pid=$(sudo docker inspect -f '{{.State.Pid}}' ${container_id})
sudo cat /proc/$pid/mountinfo | grep home
sudo docker exec $container_id cat /proc/self/mountinfo | grep home
```

這時候就會看到相關的資訊，譬如

```bash=
478 459 8:1 /home /outside-home rw,relatime - ext4 /dev/sda1 rw,data=ordered
```

反過來說，如果今天你知道目標的 `ContainerID`，你就可以透過類似的方式找到當初創建該 `Container` 時設定的相關 `Mount` 資訊

`Mount` 相關的概念非常龐大也非常複雜，我非常推薦有興趣的可以把[這篇文章](https://www.kernel.org/doc/Documentation/filesystems/sharedsubtree.txt)看完。
除了基本的 `mount` 的使用方法外，其實在 `kubernetes` 裡面還有一個 `mount propagation` 的設定可以使用，但是這個設定其實本身背後的概念並不簡單，一般的使用者基本上都不會碰到這個設定，但是一旦遇到的時候就會需要了。

此外對於 `Container` 來說，我們也可以觀察到其實 `Contianer` 本身不太去管到底怎麼跟外界的 `Storage` 串連的， 一切就是依賴 `Mount Namespace` 將這些儲存空間掛進去，至於你要採用什麼檔案系統，背後有什麼備援機制，都是 `host` 本身去管理， `Container` 本身不處理。


# Summary
今天透過一些基本的 `linux` 工具帶大家稍微過了一下 `docker container` 底下關於 `networking` 以及 `storage` 的一些冷知識，跟大家分享平常在使用 `docker container` 時到底背後有哪些機制撐起了這複雜的 `container` 系統，同時藉由理解這些資訊，未來想要做更進一步的除錯也都可以有其他的工作來幫忙輔助ㄡ

除了 `networking` 以及 `mount` 外，還有其他的如 `user`, `uts` 等不同的 `namespace` 幫忙隔離其餘的系統資源以完成所謂的 `container` 虛擬化。
有興趣的人都可以針對其他的資源去研究看看要如何再 `host` 端存取相關的資訊並且學習更多底層的實作。

# Reference
- http://man7.org/linux/man-pages/man5/proc.5.html

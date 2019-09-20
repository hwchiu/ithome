[Day3] 淺談 Container 實現原理, 以 Docker 為例(II)
==================================================

> 本文同步刊登於 [hwchiu.com - 淺談 Container 設計原理(II)](https://www.hwchiu.com/container-design-ii.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215/)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- Container Network Interface
- Container Storage Interface
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言

前一天的文章中，我們探討了關於 `Open Container Initiatives(OCI)` 的概念，並且探討了關於 `Runtime Spec` 以及 `Image Spec` 的規範與規格。

今天則是要探討對於一個開發者來說，如果要開發一個能夠滿足 `OCI` 標準的解決方案，則有什麼相關的函式庫，工具可以使用來減少重複打造輪子的情況。
一旦我們可以掌握這方便的概念，之後再研究 `Docker`, `Kubernetes` 等解決方案時就會有更清晰的輪廓。

# OCI - Implementation

如同前言所述， `OCI` 本身包含了 `Runtime` 以及 `Image` 兩個規範，而 `Runtime` 尤其重要，畢竟其規範了 `Container` 的生命週期操作以及相關的設定。

## Runtime
`OCI` 官方基於 `Runtime 規範` 實現了一個解決方案，稱為 [RunC](https://github.com/opencontainers/runc), 根據其官方文件的說明

>runc is a CLI tool for spawning and running containers according to the OCI specification.

這意味者藉由這套工具，並且搭配適宜的設定，就可以輕鬆的創建出一個符合`OCI` 標準的 `Container` 運行。 但是單純的 `CLI` 工具並不一定適合所有的開發者，部分的開發者可能只希望擁有一套能夠符合 `OCI` 標準的相關函示庫可以使用，這時候要可以使用 [libcontainer](https://github.com/opencontainers/runc/tree/master/libcontainer)這套由官方維護並且以 `golang` 撰寫的函示庫，根據其說明文件

>Libcontainer provides a native Go implementation for creating containers with namespaces, cgroups, capabilities, and filesystem access controls. It allows you to manage the lifecycle of the container performing additional operations after the container is created.
>

透過這個函式庫，開發者可以輕鬆的撰寫出滿足整個 `container` 的生命週期，同時也能夠創建相關的 `namespace/cgroups` 等的程式碼，並且將心力專注在更上層的服務提供。


除了 `runC` 這套實現方案之外，官方
[GitHub](https://github.com/opencontainers/runtime-spec/blob/master/implementations.md) 可以看到目前官方收錄的所有 `Runtime Spec` 的實現方案，這些方案有些由 `OCI` 組織本身維護，有些由其他組織維護。

其中特別有趣的就是這些實現方案目前分為兩大類，分別是 `Runtime (Container)` 以及 `Runtime (Virtual Machine)`. 

其中 `Container` 就是我們一直在探討的 `Container` 而 `Virtual Machine` 這類型則是透過 `Virtual Machine` 相關的技術去完成虛擬化的環境，但是同時又符合 `OCI` 的標準。 這意味者使用者可以創建 `Contaienr` 來使用，但是其底層是以 `Virtual Machine` 的技術創建出來的。

這相關的概念其實不難想像，畢竟 `Container` 一直以來被認為不夠安全，畢竟其部分功能都是依賴 `Host` 上的 `Kernel` 來實現，其隔離能力沒有 `Virtual Machine` 這麼明確。
所以如何打造一個速度又快，安全度又高的虛擬化環境一直以來都是一個探討的議題。

該清單中的 `google/gvisor` 以及 `kata-containers` 都算是滿知名的專案
有興趣的讀者可以自行研究這些技術底層並看看各大專案是希望如何實現`高效能,高安全` 的虛擬化環境。


## Image
`Image` 的部分也有相對應的工具可以使用，一樣由[官方 GitHub](https://github.com/opencontainers/image-tools) 進行維護,該文件中會介紹如何搭配 `skopeo` 等工具來完成一個關於 `Image` 相關的案例。
此外，也有其他的專案如 [buildah](https://github.com/containers/buildah) 也針對 `OCI Image` 的部分提供一些解決方案

>Buildah - a tool that facilitates building Open Container Initiative (OCI) container images
>

# Docker
對於 `Open Container Initiative (OCI)` 有基本概念之後，接下來就要探討作為 `OCI` 重大貢獻者的 `docker` (libcontainer, image spec...etc)，是如何在其架構中透過何種方式跟來創建基於 `OCI` 介面的 `Container`.

下圖是一個滿棒的架構圖，當有了 `OCI` 的概念後再來看這張圖會覺得親切許多。

![](https://i.imgur.com/WL7hKSD.png)
(圖片擷取自：[blod.docker.com - docker-engine-1-11-runc](https://blog.docker.com/2016/04/docker-engine-1-11-runc/))

這張圖片的右半部分標出了四個不同層級的概念，分別是
- Docker UI/Commands
- Docker Engine
- Containerd
- Runc

## Docker UI/Commands
大家最為熟悉的 `docker` 指令其實在整個 `Docker` 的架構中扮演了所謂了 `client` 的角色，負責將使用者的需求(指令)打包，並且與後方的 `server` 溝通

這邊除了常用的 `docker run/build/image/exec/attach...etc` 等直接使用的 CLI 工具外，也是有相關的函式庫可以供開發者使用，將自己的應用程式直接與 `Docker Server` 連動來溝通。

在預設的情況下，`docker` 指令都會透過 `unix socket` 與本地的 `docker engine` 溝通，這個部分可以透過環境變數來描述，譬如

```
export DOCKER_HOST=tcp://192.168.0.123:2376
docker run
```

## Docker Engine
當系統內安裝 `Docker` 後，你可以透過系統指令 `ps` 觀察到系統上會有一個名為 `dockerd` 的程序

```bash=
root      2487  0.6  2.2 694888 90000 ?        Ssl  22:26   0:11 dockerd -G docker --exec-root=/var/snap/docker/384/run/docker --data-root=/var/snap/docker/common/var-lib-docker --pidfile=/var/snap/docker/384/run/docker.pid --config-file=/var/snap/docker/384/config/daemon.json --debug
```

這個 `server` 就是所謂的 `docker engine`, 所有的 `docker client` 都會將指令送到這個 `engine` 進行相關整理。這一層級相對於 `OCI` 的層級還是算高，偏向上層的應用，所以特色還是以 `Docker` 自己的特色為主。

## Containerd

當 `Docker Engine` 收到指令後就會將指令往後傳送到 `containerd` 進行處理。

相對於 `Docker Engine`, `containerd` 則更面向 `OCI` 標準，向上提供 `gRPC` 接口供 `Docker  Engine` 使用，向下則是根據需求創建符合 `OCI` 標準的 `Container`.

就如同昨天所述， `Runtime spec` 目前有眾多的實現方案可以選擇，而最知名且由 `OCI` 組織維護的就是 `runc`.

所以 `Containerd` 本身也會透過這些現有的解決方案來創建符合 `OCI` 標準的 `Container`.


```bash=
root      2571  0.6  0.8 558432 35808 ?        Ssl  Sep12   0:39 docker-containerd --config /var/snap/docker/384/run/docker/containerd/containerd.toml
```

## Containerd-Shim
此外，為了滿足一些軟體設計上的需求，`containerd` 並沒有直接呼叫 `runc`，反而是中間會在填補一層所謂的 `containerd-shim`, `containerd` 會創建一個獨立的 process `containerd-shim` 並由其呼叫 `runc` 來真正創建 `container`.


根據下列 [dockercon-2016](https://github.com/crosbymichael/dockercon-2016/blob/master/Creating%20Containerd.pdf) 相關的演講，我們可以歸納出下列為什麼需要 `containerd-shim` 的理由

- daemonless
    - 將 `container` 運行與 `docker` 分開，這意味者 `docker` 升級的過程中這些運行的 `container` 並不會被影響，可以繼續使用。 因為 `docker engine/containerd` 目前都是屬於 `docker` 套件的程式。
- re-parenting
    - 當 `runc` 創建出 `container` 後可以直接讓 `runc` 離開，並且把其程序的 `process` 交由更上層的祖父去管理，這個情況中我們就可以讓 `containerd-shim` 去管理。此外假設當 `containerd` 意外重啟後，則新的 `containerd-shim` 可以交由 `init` 去管理，藉此做到系統更新而不影響現存的 `container`

- tty/stdin 為了處理 `container` 本身的輸入問題，則會用 `FIFO` 這種 `IPC`的方式再 `parent & child process` 中溝通。所以我們將 `parent` 的重責大任就交給了 `containerd-shim` 上

關於 `re-parenting` 的演變可以直接參閱該份投影片，如下
![](https://i.imgur.com/yYRFdUK.png)
(圖片擷取自：[dockercon-2016](https://github.com/crosbymichael/dockercon-2016/blob/master/Creating%20Containerd.pdf))
![](https://i.imgur.com/Nxzr0Tn.png)
(圖片擷取自：[dockercon-2016](https://github.com/crosbymichael/dockercon-2016/blob/master/Creating%20Containerd.pdf))


由上面的概念可以知道，每個 `containerd-shim` 都會對應到一個 `container`, 因此當透過 `docker run` 的方式來運行容器後，系統就會產收一個 `container-shim` 相關的應用程式. 可以使用以下範例創建多個容器，然後觀察相關的 `containerd-shim` 的狀態
 
```bash=
sudo docker run -d hwchiu/netutils
sudo docker run -d hwchiu/netutils
sudo docker run -d hwchiu/netutils
sudo docker run -d hwchiu/netutils
ps auxw | grep docker-containerd-shim | wc -l
ps auxw | grep docker-containerd-shim 
```


```bash=
root     11732  0.0  0.1   7380  4420 ?        Sl   18:17   0:00 docker-containerd-shim -namespace moby -workdir /var/snap/docker/common/var-lib-docker/containerd/daemon/io.containerd.runtime.v1.linux/moby/a12e5594d0d666759c51b2420db0e361649a39b43aa6b5e928382c69381be0a0 -address /var/snap/docker/384/run/docker/containerd/docker-containerd.sock -containerd-binary /snap/docker/384/bin/docker-containerd -runtime-root /var/snap/docker/384/run/docker/runtime-runc -debug
```


## Summary
此外，上述所有的元件在最後於 `docker` 的環境中都有重新命名，包含了
1. containerd -> docker-containerd
2. containerd-shim -> docker-containerd-shim

用下列架構圖來重新說明一次 `Docker` 內部的構造以及是如何創建出符合 `OCI` 標準的容器
 ![](https://i.imgur.com/wDbs54G.png)


# Reference
- https://blog.docker.com/2017/08/what-is-containerd-runtime/
- http://alexander.holbreich.org/docker-components-explained/
- https://github.com/crosbymichael/dockercon-2016/blob/master/Creating%20Containerd.pdf
- https://ops.tips/blog/run-docker-with-forked-runc/#forking-runc
- https://medium.com/tiffanyfay/docker-1-11-et-plus-engine-is-now-built-on-runc-and-containerd-a6d06d7e80ef

[Day5] Kubernetes & CRI (Container Runtime Interface)(I)
=====================================================

> 本文同步刊登於 [hwchiu.com - Kubernetes & CRI (I)](https://www.hwchiu.com/kubernetes-cri-i.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215/)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- Container Storage Interface
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論

# 前言
前幾天探討了關於 `Container` 的一些基本概念，譬如相關的開放標準 `Open Container Initiative` 以及 `Linux` 下的實現方式 `Namespace ..etc`

接下來我們要正式的走到 `kubernetes` 的架構中，來探討 `kubernetes` 再 `container` 這一塊是怎麼處理與設計的。

雖然 `kubernetes` 已發展數年，其火紅程度也席捲整個產業，然而我自己的觀察結果還是滿多人對 `kubernetes` 有一些誤解，認為 `kubernetes` 是 `docker container` 的管理工具，事實上從 [kubernetes 官網](https://kubernetes.io) 中就直接明確說明

> Kubernetes (K8s) is an open-source system for automating deployment, scaling, and management of containerized applications.

`kubernetes` 是用來管理 `containerized applications` 並不是專屬於 `docker` 獨享，作為一個 `container orchestrator` 的角色， `kubernetes` 希望能夠管理所有容器化的應用程式。

看到這邊大概就可以想到就如同 `Open Container Initiative (OCI)` 一樣，為了能夠有效地銜接各式各樣不同的 `Container Runtime` 解決方案，勢必也需要推出相關的標準，就如同 `OCI` 一樣，符合標準的解決方案就能夠輕鬆的整合到 `kubernetes` 之中。於是 `Container Runtime Interface(CRI)` 標準就被設計且開發來

接下來我們將針對這個概念來細細訴說，到底什麼是 `Container Runtime Interface(CRI)` 以及其如何運作。

# Container Runtime Interface (CRI)
對於 `kubernetes` 來說，希望能夠透過一個標準介面與各個 `contaienr rumtime` 解決方案銜接，這個銜接的接口標準就是所謂的 `Container Runtime`

為了更加清楚理解 `CRI` 的定位，我們用下列的表格來解釋
表格列出了 `kubernetes` 與 `CRI Runtime` 各自的責任

| Kubernetes | CRI Runtime |
| -------- | -------- | 
| Kubernetes Resources/API | Pod Life Cycle (Add/Delete)     | 
| Storage  (CSI)   | Image management| 
| Networking (CNI)     | Status     | 
| Dispatcher     | Container Operations (attatch/exec)     | 

基本上 `CRI Runtime` 很類似前述的 `Containerd` 一樣，能夠根據需求產生出符合 `OCI` 標準的容器應用程式，但是基本單位不再是 `Container` 而是 `Pod`。
而 `kubernetes` 本身建築在這些基礎之上，提供更豐富的應用與 API 供使用者使用。

這兩者之間的溝通橋樑就是所謂的 `CRI`。

`CRI` 所謂的標準其實非常簡單，就是所謂的 `protobuf` 的 [API 介面](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/cri-api/pkg/apis/runtime/v1alpha2/api.proto)，

從官方擷取該介面資訊如下，仔細觀察你可以裡面有 `Pod` 也有 `Container`，同時也涵蓋了各式各樣的操作，如 `Run`, `Stop`, `List`, `Remove`, `Start`, 

```go=
// Runtime service defines the public APIs for remote container runtimes
service RuntimeService {
    // Version returns the runtime name, runtime version, and runtime API version.
    rpc Version(VersionRequest) returns (VersionResponse) {}

    // RunPodSandbox creates and starts a pod-level sandbox. Runtimes must ensure
    // the sandbox is in the ready state on success.
    rpc RunPodSandbox(RunPodSandboxRequest) returns (RunPodSandboxResponse) {}
    // StopPodSandbox stops any running process that is part of the sandbox and
    // reclaims network resources (e.g., IP addresses) allocated to the sandbox.
    // If there are any running containers in the sandbox, they must be forcibly
    // terminated.
    // This call is idempotent, and must not return an error if all relevant
    // resources have already been reclaimed. kubelet will call StopPodSandbox
    // at least once before calling RemovePodSandbox. It will also attempt to
    // reclaim resources eagerly, as soon as a sandbox is not needed. Hence,
    // multiple StopPodSandbox calls are expected.
    rpc StopPodSandbox(StopPodSandboxRequest) returns (StopPodSandboxResponse) {}
    // RemovePodSandbox removes the sandbox. If there are any running containers
    // in the sandbox, they must be forcibly terminated and removed.
    // This call is idempotent, and must not return an error if the sandbox has
    // already been removed.
    rpc RemovePodSandbox(RemovePodSandboxRequest) returns (RemovePodSandboxResponse) {}
    // PodSandboxStatus returns the status of the PodSandbox. If the PodSandbox is not
    // present, returns an error.
    rpc PodSandboxStatus(PodSandboxStatusRequest) returns (PodSandboxStatusResponse) {}
    // ListPodSandbox returns a list of PodSandboxes.
    rpc ListPodSandbox(ListPodSandboxRequest) returns (ListPodSandboxResponse) {}

    // CreateContainer creates a new container in specified PodSandbox
    rpc CreateContainer(CreateContainerRequest) returns (CreateContainerResponse) {}
    // StartContainer starts the container.
    rpc StartContainer(StartContainerRequest) returns (StartContainerResponse) {}
    // StopContainer stops a running container with a grace period (i.e., timeout).
    // This call is idempotent, and must not return an error if the container has
    // already been stopped.
    // TODO: what must the runtime do after the grace period is reached?
    rpc StopContainer(StopContainerRequest) returns (StopContainerResponse) {}
    // RemoveContainer removes the container. If the container is running, the
    // container must be forcibly removed.
    // This call is idempotent, and must not return an error if the container has
    // already been removed.
    rpc RemoveContainer(RemoveContainerRequest) returns (RemoveContainerResponse) {}
    // ListContainers lists all containers by filters.
    rpc ListContainers(ListContainersRequest) returns (ListContainersResponse) {}
    // ContainerStatus returns status of the container. If the container is not
    // present, returns an error.
    rpc ContainerStatus(ContainerStatusRequest) returns (ContainerStatusResponse) {}
    // UpdateContainerResources updates ContainerConfig of the container.
    rpc UpdateContainerResources(UpdateContainerResourcesRequest) returns (UpdateContainerResourcesResponse) {}
    // ReopenContainerLog asks runtime to reopen the stdout/stderr log file
    // for the container. This is often called after the log file has been
    // rotated. If the container is not running, container runtime can choose
    // to either create a new log file and return nil, or return an error.
    // Once it returns error, new container log file MUST NOT be created.
    rpc ReopenContainerLog(ReopenContainerLogRequest) returns (ReopenContainerLogResponse) {}

    // ExecSync runs a command in a container synchronously.
    rpc ExecSync(ExecSyncRequest) returns (ExecSyncResponse) {}
    // Exec prepares a streaming endpoint to execute a command in the container.
    rpc Exec(ExecRequest) returns (ExecResponse) {}
    // Attach prepares a streaming endpoint to attach to a running container.
    rpc Attach(AttachRequest) returns (AttachResponse) {}
    // PortForward prepares a streaming endpoint to forward ports from a PodSandbox.
    rpc PortForward(PortForwardRequest) returns (PortForwardResponse) {}

    // ContainerStats returns stats of the container. If the container does not
    // exist, the call returns an error.
    rpc ContainerStats(ContainerStatsRequest) returns (ContainerStatsResponse) {}
    // ListContainerStats returns stats of all running containers.
    rpc ListContainerStats(ListContainerStatsRequest) returns (ListContainerStatsResponse) {}

    // UpdateRuntimeConfig updates the runtime configuration based on the given request.
    rpc UpdateRuntimeConfig(UpdateRuntimeConfigRequest) returns (UpdateRuntimeConfigResponse) {}

    // Status returns the status of the runtime.
    rpc Status(StatusRequest) returns (StatusResponse) {}
}
```

由於 `CRI` 的標準就是一些相關的介面，這意味只要任何 `CRI Runtime` 有實作這些介面，都可以跟 `kubernetes` 銜接來處理所有跟 `Pod` 有關的操作。

剩下的一個問題就是， 之前所探討過的 `docker` 運作流程

> `docker client` -> `docker engine` -> `docker-containerd` -> `docker-containerd-shim` -> `runc` -> `container`
> 

這個架構要怎麼跟 `kubernetes & CRI` 整合? 

## Docker & Kubernetes

解釋 `Docker` 與 `kubernetes` 的最好方法就是閱讀官方部落格的文章 [kubernetes-containerd-integration-goes-ga](https://kubernetes.io/blog/2018/05/24/kubernetes-containerd-integration-goes-ga/)。 為了節省讀者的時間，接下來就幫大家導讀一下這篇文章，以下的圖片都來自於上述的[官方部落格]((https://kubernetes.io/blog/2018/05/24/kubernetes-containerd-integration-goes-ga/))

上面提到 `CRI` 本身是個溝通介面，這代表溝通的兩方都需要根據這個界面去實現與滿足。 對於 `kubernetes` 來說，`kubelet` 自己維護與開發的，要支援 `CRI` 本身就不是什麼困難的事情。

但是另外一端如果要使用 `docker` 的話，那到底要怎麼辦?
`docker` 背後也是有公司再經營，也不是說改就改，這種情況下到底要如何將 `docker` 給整合進來？

最直觀的想法就是如果沒有辦法使得 `docker`  本身支援 `CRI` 的標準，那就額外撰寫一個轉接器，其運作在 `kubelet` 與 `Docker`，該應用程式上承 `CRI` 與 `kubernetes` 溝通，下承 `Docker API` 與 `Docker Engine` 溝通

早期的 `kubernetes` 採取了這種做法，`kuberlet` 內建相關了 `dockershim` 的程式碼來處理這段邏輯。這種做法可行，但是其實效能大大則扣，同時也把整體架構帶到了更複雜的境界，引進愈來愈多的元件會對開發與除錯帶來更大的成本。

可以參考下圖中的上半部份，而圖中的下半部分則是後來的改變之處

![](https://i.imgur.com/2XQwc9B.png)
(圖片擷取自：[kubernetes blog kubernetes-containerd-integration-goes-ga](https://kubernetes.io/blog/2018/05/24/kubernetes-containerd-integration-goes-ga/))

反正最後都是透過 `containerd` 進行操作，而本身也不太需要 `docker` 自己的功能，那是否就直接將 `dockershim` 溝通的角色從 `docker engine` 轉移到 `containerd` 即可。 因此後來又有所謂的 `CRI-Containerd` 的出現。

到這個階段，已經減少了一個溝通的 `Daemon`, 也就是 `docker engine`。 但是這樣並不能滿足想要最佳化的心情。

伴隨者 `Containerd` 本身的功能開發，提供了 `Plugin` 這種外掛功能的特色後，將 `CRI-Containerd` 的功能直接整合到該 `Plugin` 內就可以直接再次減少一個元件，直接讓 `kubelet` 與 `containerd` 直接溝通來創建相關的 `container`.

相關的演進可以參考下圖
![](https://i.imgur.com/wjxTNU9.png)
(圖片擷取自：[kubernetes blog kubernetes-containerd-integration-goes-ga](https://kubernetes.io/blog/2018/05/24/kubernetes-containerd-integration-goes-ga/))



同時根據該篇文章內關於效能的評比，可以看到目前這個整合的版本不論是 `CPU` 或是 `Memory` 等系統資源的消耗都遠比過往還來得少。

![](https://i.imgur.com/ZVC8Qoa.png)
(圖片擷取自：[kubernetes blog kubernetes-containerd-integration-goes-ga](https://kubernetes.io/blog/2018/05/24/kubernetes-containerd-integration-goes-ga/))

![](https://i.imgur.com/GteIewU.png)
(圖片擷取自：[kubernetes blog kubernetes-containerd-integration-goes-ga](https://kubernetes.io/blog/2018/05/24/kubernetes-containerd-integration-goes-ga/))

這種架構下，使用者可以在一台伺服器中同時安裝 `kubernetes` 與 `docker`, 同時彼此會共用 `containerd` 來管理自己所需要的 `container`.

架構如下圖，有趣的一點在於這種情況下要如何確保 `docker` 的指令不會看到 `kubernetes` 所要求創建的 `container`, 反之亦然。
兩者都是透過 `containerd` 來創建 `Container`, 幸好有鑒於 `containerd` 本身提供的 `namespace` 的功能，可以確保不同的客戶端 `docekrd, CRI-plugin` 都可以有自己的 `namespace`，所以用 `docker ps` 就不會互相影響到彼此的運作。
![](https://i.imgur.com/IChs25N.png)
(圖片擷取自：[kubernetes blog kubernetes-containerd-integration-goes-ga](https://kubernetes.io/blog/2018/05/24/kubernetes-containerd-integration-goes-ga/))

不過上述的假設是 `啟用 containerd` 於 `kubernetes cluster` 內才會有這個效果。

根據 這篇官方文章 [install-kubeadm](
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-runtime)，目前預設的情況下都還是採用第一種方案, `dockershim` 的方式來使用，若需要使用 `containerd` 則必須要先安裝 `containerd` 到系統之中並且安裝 `kubernetes` 時設定特定的參數來切換過去。

下一篇文章就會跟大家分享要如何透過創建一個可以使用 `containerd` 的 `local kubernetes cluster`, 並且使用 `CRI` 的工具 `crictl` 來操作相關的容器創建。


# 參考
- https://kubernetes.io
- https://kubernetes.io/blog/2018/05/24/kubernetes-containerd-integration-goes-ga/
- https://www.slideshare.net/PhilEstes/lets-try-every-cri-runtime-available-for-kubernetes
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-runtime

Day 7 - 本地開發 Kubernetes 應用程式流程
===============================

本文同步刊登於筆者[部落格](https://hwchiu.com)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者
歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



前篇介紹了如何透過 `k3d` 以及 `kind` 等不同工具來架設一個本地的 Kubernetes 叢集，當然除了這些工具外，最初介紹的 Kubeadm/Minikube 也都可以使用，工具的選擇往往沒有最好，只有適合當下的工作流程與環境而已，隨者時間改變，很多工具可能也會變得不適用，所以困難的地方還是在於如何抓分析出目前的情境，從眾多工具中挑選一個適合的。



有了 Kubernetes 叢集之後，我們接下來看一下對一個需要 Kubernetes 的本地開發者來說，他的工作流程可能會長什麼樣子

首先由於 Kubernetes 預設的情況下是一個容器管理平台，裡面的運算資源都必須要容器化，本文我們都假設我們使用 Docker 作為我們的容器解決方案。

> 實際上透過 CRI 的更動，要讓 Kubernetes 支援 Virtual Machine 也是可以的， Docker 只是容器化的選項之一，切換成別的容器解決方案都是選項



# 工作流程

為了讓應用程式可以部署到 Kubernetes 裡面，開發者準備下列步驟將應用程式給部屬進去

1. 修改應用程式原始碼
2. 借助 Dockerfile 的幫助產生一個 Docker Container Image
3. 部署新版本應用程式到 Kubernetes
4. Kubernetes 根據新版本的 Docker Container Image 來產生新的運算資源



這四個步驟中比較需要探討的流程是 (4), 到底 Kubernetes 要如何獲取這個新版本的 Docker Container Image.

最簡單的做法就是準備一個遠方的 Container Registry，每次(2)完畢後，都將該 Container Image 給推到遠方 Container Registry

功能面上完全沒有問題，唯一的問題就是等待時間，畢竟時間就是金錢，就是一個開發者的成本。

對於一些高達數 GB 的 Container Image, 每次測試都要送到遠方，接者本地的 Kubernetes Cluster 再抓取下來，實際上會非常花費時間也沒有效率。

因此接下來探討兩種不同的作法與架構來看看如何改善這塊工作流程



## Kubeadm

如果今天採用的是 Kubeadm 這個部署方式，由於 Kubadm 預設創立的是一個單節點的 Kubernetes 叢集，這種情況下只要開發者跟 Kubernetes 是同一台機器，那基本上 Docker Container Image 就可以共用。

架構如下圖所示

![](https://i.imgur.com/64xkIPt.jpg)

開發者產生的 Container Image 可以直接給同台機器上面的 Kubernetes 使用，開發者唯一要處理的就只有部署過程中 (Yaml/Helm) 所描述的 Image Name 而已。



上述的便利性是建立在開發者使用的環境與 Kubeadm 架設的環境是同個機器上，如果 Kubeadm 本身也建立多節點叢集，那這種便利性就不存在，必須要用額外的方法來處理。



## KIND/K3D

如果今天採用的是 KIND/K3D 這類型基於 Docker 而部署的 Kubernetes 架構，那整個架構就會有點不同，如下圖。

![](https://i.imgur.com/FzFOPtq.jpg)



當開發者建立起 Container Image 後，這些 Image 是屬於本地端，然而 KIND/K3D 的環境都是基於 Docker，這意味者如果要在 KIND/K3D 的環境中跑起開發者的 Container Image, 勢必要把這些 Contaienr Image 給複製到 Kubernetes Node 中，也就是那些 Docker，所以其實背後使用到的是 Docker in Docker 的技術，基於 Docker 所創建立的 Kubernests 裡面再根據 Docker Image 去創建 Pod(Containers)。



這部分如果使用的是 `KIND` 指令的話，其本身有特別提供一個功能來幫助使用者把本地端的 Image 給快速地送到 `KIND` 建立的叢集裡面

```bash
$ kind load
Loads images into node from an archive or image on host

Usage:
  kind load [command]

Available Commands:
  docker-image  Loads docker image from host into nodes
  image-archive Loads docker image from archive into nodes

Flags:
  -h, --help   help for load

Global Flags:
      --loglevel string   DEPRECATED: see -v instead
  -q, --quiet             silence all stderr output
  -v, --verbosity int32   info log verbosity

Use "kind load [command] --help" for more information about a command.
```

可以看到 kind 支援兩種格式的 container image, 一種是直接從當前節點已知的 comtainer image，另外一種則是從被打包壓縮過的 image 格式。 KIND 可以將這兩種格式的 container 給送到 KIND 裡面。



首先，我們先來觀察一下預設情況下， KIND 架構中的 `docker` 有哪些 `contaienr image`

```bash
$ docker exec -it kind-worker crictl image
IMAGE                                      TAG                 IMAGE ID            SIZE
docker.io/kindest/kindnetd                 0.5.4               2186a1a396deb       113MB
docker.io/rancher/local-path-provisioner   v0.0.11             9d12f9848b99f       36.5MB
k8s.gcr.io/coredns                         1.6.5               70f311871ae12       41.7MB
k8s.gcr.io/debian-base                     v2.0.0              9bd6154724425       53.9MB
k8s.gcr.io/etcd                            3.4.3-0             303ce5db0e90d       290MB
k8s.gcr.io/kube-apiserver                  v1.17.0             134ad2332e042       144MB
k8s.gcr.io/kube-controller-manager         v1.17.0             7818d75a7d002       131MB
k8s.gcr.io/kube-proxy                      v1.17.0             551eaeb500fda       132MB
k8s.gcr.io/kube-scheduler                  v1.17.0             09a204f38b41d       112MB
k8s.gcr.io/pause                           3.1                 da86e6ba6ca19       746kB
```

這邊要特別注意的是， KIND 其實並不是在 docker 內使用 dockerd 作為 Kubernetes 的 container runtime，而是採用 containerd ，因此系統上並沒有 `docker` 指令可以使用，取而代之的是我們要使用 `crictl` (container runtime interface control) 這個指令來觀察 container 的資訊。

透過 `crictl image` 可以觀察到預設情況下有的都是 `kubernetes` 會使用到的 container image 以及二個由 KIND 所安裝的 image,  `kindnetd`(CNI) 以及 `local-path-provisioner` (storageclass for hostpath).



接下來假設本機上面有一個 `postgres:10.8` 的 container image, 我們透過 `kind load` 的指令將其傳送到 `KIND` 叢集裡面

```bash=
$ kind load docker-image postgres:10.8
Image: "postgres:10.8" with ID "sha256:83986f6d271a23ee6200ee7857d1c1c8504febdb3550ea31be2cc387e200055e" not present on node "kind-worker2"
Image: "postgres:10.8" with ID "sha256:83986f6d271a23ee6200ee7857d1c1c8504febdb3550ea31be2cc387e200055e" not present on node "kind-control-plane"
Image: "postgres:10.8" with ID "sha256:83986f6d271a23ee6200ee7857d1c1c8504febdb3550ea31be2cc387e200055e" not present on node "kind-worker"
```

上述的指令描述說，因為系統上目前不存在，所以要開始複製，當一切就緒後再次透過 `crictl` 指令來觀察，就可以看到這時候 `postgres:10.8` 這個 container image 已經放進去了。

```bash
$ docker exec -it kind-worker crictl image
IMAGE                                      TAG                 IMAGE ID            SIZE
docker.io/kindest/kindnetd                 0.5.4               2186a1a396deb       113MB
docker.io/library/postgres                 10.8                83986f6d271a2       237MB
docker.io/rancher/local-path-provisioner   v0.0.11             9d12f9848b99f       36.5MB
k8s.gcr.io/coredns                         1.6.5               70f311871ae12       41.7MB
k8s.gcr.io/debian-base                     v2.0.0              9bd6154724425       53.9MB
k8s.gcr.io/etcd                            3.4.3-0             303ce5db0e90d       290MB
k8s.gcr.io/kube-apiserver                  v1.17.0             134ad2332e042       144MB
k8s.gcr.io/kube-controller-manager         v1.17.0             7818d75a7d002       131MB
k8s.gcr.io/kube-proxy                      v1.17.0             551eaeb500fda       132MB
k8s.gcr.io/kube-scheduler                  v1.17.0             09a204f38b41d       112MB
k8s.gcr.io/pause                           3.1                 da86e6ba6ca19       746kB
```



透過上述的流程我們就可以很順利的將本地開發的 Image 給快速的載入到 KIND 建立的 Kubernetes 叢集中，又不需要將 Container Image 給傳送到遠方 Registry 花費如此冗長的傳輸時間，整個開發效率上會提升不少。


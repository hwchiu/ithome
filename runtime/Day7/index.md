[Day7] Container Runtime - CRI-O
=====================================================

> 本文同步刊登於 [hwchiu.com - Container Runtime - CRI-O](https://www.hwchiu.com/container-runtime-crio.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- Container Runtime Interface
- Container Network Interface
- Container Storage Interface
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論


# 前言

前兩篇文章我們探討了關於 `kubernetes` 中 `Container Runtime` 的概念，並且架設一個 `kubernetes cluster` 來使用 `containerd` 而非常見的 `docker` 作為其背後 `Container Runtime` 的解決方案。

然而如果你嘗試搜尋過關於 `CRI` 的文章·除了 `kubernetes`,`OCI` 等相關概念關鍵字會出現外，你可能也有看過一個名為 `cri-o` 的關鍵字。

今天就要來跟大家聊聊 `CRI-O` 這個完全針對 `kubernetes` 環境開發的`Container Runtime` 解決方案。

# 介紹
我想直接透過一張圖來解釋 `CRI-O` 的角色與地位是最快且簡單的，透過與 `docker`, `containerd` 等相關的比較，

![](https://i.imgur.com/nUAYZiq.png)

該圖片從縱軸來看，有兩條主要的黑線，代表的是不同的標準架構，分別是 `CRI` 以及 `OCI`。
`kubelet` 本身透過 `CRI` 的介面與各式各樣相容於 `CRI` 的解決方案溝通，而這些解決方案最後都會透過符合 `OCI` 標準的 `OCI runtime` 去創造出真正的 `Container` 供使用者使用。

從上而下分別是之前介紹過 `kubernetes` 內與 `docker` 以及 `contained` 的架構演進圖。
1. `kubelet` 透過 `Dockershim` 與 `docker engine` 連接，最後一路串接到 `containerd` 來創建 `container`。
2. 繞過 `Docker` 直接與後端的 `Containerd` 溝通，為了滿足這個需求也需要一個額外的應用程式 `CRI-Containerd` 來作為中間溝通的橋樑
3. 隨者 `containerd` 1.1 版本的發行， `CRI-Containerd` 本身的功能已經可以透過 `plugin` 的方式實現於 `containerd` 中，可以再少掉一層溝通的耗損，這也是上一篇所介紹的安裝環境。 
4. 則是本篇所要介紹的重點 `cri-o`, 一個完全針對 `kubernetes` 需求的解決方案，讓整體的溝通變得更快速與簡單。

看完上述比較後會對 `cri-o` 有個初步的理解，知道其被設計出來的目的就是要提供更好地整合，減少多餘的 `IPC` 溝通，並且作為一個針對 `kubernetes` 設計的解決方案。

# 特色

`CRI-O` 的標題開宗明義直接闡明
> CRI-O - OCI-based implementation of Kubernetes Container Runtime Interface
> 

作為一個滿足 `CRI` 標準且能夠產生出相容於 `OCI`  標準 `container` 的解決方案，從整個設計到特色全部都是針對 `kubernetes` 來打造

1. 本身的軟體版本與 `kubernetes` 一致，同時所有的測試都是基於 kubernetes 的使用去測試，確保穩定性。
2. 目標是支援所有相容於 `OCI Runtime` 的解決方案，譬如 `Runc, Kata Containers`
3. 支援不同的 `container image`，譬如 `docker` 自己本身就有 [schema 2/version 1](https://docs.docker.com/registry/spec/manifest-v2-1/) 與 [schema 2/version 2](https://docs.docker.com/registry/spec/manifest-v2-2/)
4. 使用 `Container Network Interface CNI` 來管理 `Container` 網路


# 運作流程
整體的運作流程可以由下面這張圖片來說明

![](https://i.imgur.com/AeciXUs.png)
本圖擷取自[cri-o](https://cri-o.io/#container-images)
1. kubelet 決定要創建一個 `Pod`，於是透過 `gRPC` 的方式發送基於 `CRI` 標準的請求到 `cri-o`
2. `cri-o` 基於 `containerts/image` 的函式庫去該 `Pod` 裡面描述的 `Container Image Registry` 抓取該 `container image`
3. 下載下來的 `container image` 會被解開，接下來會透過 `containers/storage` 相關的函式庫去處理 `container` 本身的 `root filesystem`。
4. `CRI-O` 接者會使用 `OCI` 提供的工具去產生一個用來描述該 `container` 要如何運行的 `json` 檔案。
5. 接者會根據設定去運行相容於 `OCI Runtime` 的解決方案來執行該 `container`.
6. 每一個 `container` 都會被獨立的 process `conmon (container monitor)` 給監控，處理者關於 pseudotty, log, 以及 exit code。
7. 接下來會透過 `CNI` 的介面來幫該 `Pod` 建立網路
> 實際上 CNI 操作的對象是所謂的 infra container (pause container), 而非任何使用者請求的 container. 這部分會到 CNI 的章節在仔細介紹


整個 `OCI` 的概念相對於 `docker, containerd` 來得簡單，因為其目標就是支援 `kubernetes`，不相干的功能不實作，專心提供更好的相容性與穩定性。

此外近來可以陸陸續續看到相關新聞在講述 `CRI-O` 的導入，譬如 OpenSuse/RedHat 都幫自家的產品導入 `cri-o` 並且作為預設的運行環境，就是希望能夠讓 `kubernetes` 的效能更好更穩定。
[kubic.opensuse: CRI-O is now our default container runtime interface](https://kubic.opensuse.org/blog/2018-09-17-crio-default/) 
[Red Hat OpenShift Container Platform 4 now defaults to CRI-O as underlying container engine](https://www.redhat.com/en/blog/red-hat-openshift-container-platform-4-now-defaults-cri-o-underlying-container-engine)

看完了 `cri-o` 的概念介紹後，接下來我們仿造上篇 `containerd` 的概念一樣打造一樣的環境試試看，並且觀察相關的 `process` 運作。

# 安裝測試

## 安裝 CRI-O
基本上安裝的過程跟 `containerd` 大同小異，只是安裝的套件不同，同時最後設定 `kubelet` 的方式不同。

### 設定系統相關資訊
```bash=
modprobe overlay
modprobe br_netfilter
echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables  
echo 1 > /proc/sys/net/ipv4/ip_forward                 
echo 1 > /proc/sys/net/bridge/bridge-nf-call-ip6tables 
```


### 安裝套件
```bash=
apt-get update
apt-get install software-properties-common

add-apt-repository ppa:projectatomic/ppa
apt-get update
apt-get install cri-o-1.15
systemctl start cri-o
```

如果執行錯誤發現因為找不到相關的 `/usr/local/libexec/crio/crio-wipe/crio-wipe.bash` 這個檔案的話，可以手動幫忙建立個 `soft link`

```bash=
sudo ln -s /usr/libexec /usr/local/libexec
```

這個問題在 [github](https://github.com/cri-o/cri-o/issues/2779
) 上面已經被回報，但是不確定是什麼時候會修復到打包的 `deb` 之中，至少我`2019/09/18`測試的時候還是壞掉的。

最後透過指令確認 cri-o 有正確運行
```bash=
vagrant@k8s-dev:~$ sudo systemctl status cri-o
● crio.service - Container Runtime Interface for OCI (CRI-O)
   Loaded: loaded (/usr/lib/systemd/system/crio.service; disabled; vendor preset: enabled)
   Active: active (running) since Thu 2019-09-19 03:31:32 UTC; 20min ago
     Docs: https://github.com/cri-o/cri-o
 Main PID: 28333 (crio)
    Tasks: 16
   Memory: 870.2M
      CPU: 28.468s
   CGroup: /system.slice/crio.service
           └─28333 /usr/bin/crio

Sep 19 03:31:32 k8s-dev systemd[1]: Starting Open Container Initiative Daemon...
Sep 19 03:31:32 k8s-dev systemd[1]: Started Open Container Initiative Daemon.
Sep 19 03:31:57 k8s-dev systemd[1]: Started Open Container Initiative Daemon.
Sep 19 03:32:10 k8s-dev systemd[1]: Started Container Runtime Interface for OCI (CRI-O).
```




## 安裝 kubernetes
### 安裝套件
安裝 `kubeadm/kubelet/kubectl` 相關檔案工具，不再撰述其過程
```bash=
apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
```

接下來要使用 `kubeadm` 進行安裝·安裝步驟與之前 `containerd` 大同小異

由於部分需要的設定只能透過 `config` 的方式來修改，並不能像之前 `containerd` 的方式去改 systemd 裡面的環境變數，因此請增加 `/etc/default/kubelet` 這個檔案，內容如下
```bash=
vagrant@k8s-dev:~$ cat /etc/default/kubelet
KUBELET_EXTRA_ARGS=--feature-gates="AllAlpha=false,RunAsGroup=true" --container-runtime=remote --cgroup-driver=systemd --container-runtime-endpoint='unix:///var/run/crio/crio.sock' --runtime-request-timeout=5m
```

### 建立叢集

透過下列指令依序建立叢集
```bash=
sudo swapoff -a && sudo sysctl -w vm.swappiness=0
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
kubectl taint nodes --all node-role.kubernetes.io/master-
```


如果 `cri-o` 沒有正確安裝的話，會因為找不到相關的 `unix socket`，使得 `kubelet` 會嘗試去找 `docker` 來使用，但是因為我系統上面沒有 `docker`，因此會使得安裝失敗，訊息如下。

```bash=
vagrant@k8s-dev:~$ sudo kubeadm init --pod-network-cidr=10.244.0.0/16

[init] Using Kubernetes version: v1.16.0
[preflight] Running pre-flight checks
[preflight] WARNING: Couldn't create the interface used for talking to the container runtime: docker is required for container runtime: exec: "docker":
 executable file not found in $PATH
```

## 測試
因為 `cri-o` 就是完全針對 `cri` + `kubernetes` 打造的，所以前述的 `crictl` 相關的工具都還是可以繼續使用

```bash=
vagrant@k8s-dev:~$ sudo crictl images
IMAGE                                TAG                 IMAGE ID            SIZE
k8s.gcr.io/coredns                   1.6.2               bf261d1579144       44.2MB
k8s.gcr.io/etcd                      3.3.15-0            b2756210eeabf       248MB
k8s.gcr.io/kube-apiserver            v1.16.0             b305571ca60a5       219MB
k8s.gcr.io/kube-controller-manager   v1.16.0             06a629a7e51cd       165MB
k8s.gcr.io/kube-proxy                v1.16.0             c21b0c7400f98       87.9MB
k8s.gcr.io/kube-scheduler            v1.16.0             301ddc62b80b1       88.8MB
k8s.gcr.io/pause                     3.1                 da86e6ba6ca19       747kB
quay.io/coreos/flannel               v0.11.0-amd64       ff281650a721f       55.4MB

vagrant@k8s-dev:~$ sudo crictl ps
CONTAINER ID        IMAGE                                                              CREATED             STATE               NAME                      ATTEMPT             POD ID
72d22f82eca39       ff281650a721f46bbe2169292c91031c66411554739c88c861ba78475c1df894   29 minutes ago      Running             kube-flannel              0                   8c7db4df0ae25
bf7f4886d1a59       c21b0c7400f988db4777858edd13b6d3930d62d7ccf026d2415485a52037f384   38 minutes ago      Running             kube-proxy                0                   ead4354c566f9
fa3d24cb95896       b2756210eeabf84f3221da9959e9483f3919dc2aaab4cd45e7cd072fcbde27ed   39 minutes ago      Running             etcd                      0                   b219a7e8b9d52
983924dffa404       301ddc62b80b16315d3c2653cf3888370394277afb3187614cfa20edc352ca0a   39 minutes ago      Running             kube-scheduler            0                   6d1c2c8035d10
a04f0f3b253a6       06a629a7e51cdcc81a5ed6a3e6650348312f20c954ac52ee489a023628ec9c7d   39 minutes ago      Running             kube-controller-manager   0                   5fa8e74c08bac
a48e40de9a05b       b305571ca60a5a7818bda47da122683d75e8a1907475681ee8b1efbd06bff12e   39 minutes ago      Running             kube-apiserver            0                   014ba57340bf8

```

這時候透過 `ps` 等指令觀察一下系統中運行的指令
```bash
vagrant@k8s-dev:~$ sudo ps -x -awo command | grep cri             
/usr/bin/crio                                                      
/usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/config.yaml --container-runtime=remote --container-runtime-endpoint=/var/run/crio/crio.sock --feature-gates=AllAlpha=false,RunAsGroup=true --container-runtime=remote --cgroup-driver=systemd --container-runtime-endpoint=unix:///var/run/crio/crio.sock --runtime-request-timeout=5m
/usr/libexec/crio/conmon -s -c 014ba57340bf8afd3b2ce6982b760ffac82ce1bc2861a2b02f8069c8becde304 -n k8s_POD_kube-apiserver-k8s-dev_kube-system_b00230a3af5f91e5d10118aee4d054c4_0 -u 014ba57340bf8afd3b2ce6982b760ffac82ce1bc2861a2b02f8069c8becde304 -r /usr/lib/cri-o-runc/sbin/runc -b /var/run/containers/s
torage/overlay-containers/014ba57340bf8afd3b2ce6982b760ffac82ce1bc2861a2b02f8069c8becde304/userdata -p /var/run/containers/storage/overlay-containers/014ba57340bf8afd3b2ce6982b760ffac82ce1bc2861a2b02f8069c8becde304/userdata/pidfile -l /var/log/pods/kube-system_kube-apiserver-k8s-dev_b00230a3af5f91e5d10118aee4d054c4/014ba57340bf8afd3b2ce6982b760ffac82ce1bc2861a2b02f8069c8becde304.log --exit-dir /var/run/crio/exits --socket-dir-path /var/run/crio --log-level error --runtime-arg --root=/run/runc
```

可以觀察到
1. 有一個名為 `crio` 的 daemon 運行
2. kubelet 的參數都修改為去取 `cri-o` 配合
3. `crio` 本身會 `fork/exec` 一個名為 `conmon` 的 process ，也因為這個 跟 `kubernetes` 是直接配合的，可以看到很多參數都直接跟 `kubernetes` 有關，譬如名稱是 `k8s_POD_kube-apiserver-k8s-dev_kube-system_b00230a3af5f91e5d10118aee4d054c4_0`，裡面描述了其 `pod` 的名稱，還有`namespace`。

# Summay

到這邊為止，我們已經架設過基於 `containerd` 與 `cri-o` 等不同相容於 `CRI` 的解決方案，唯一可惜的就是我們的背後都是基於 `runc` 這套純 `container` 的運行方式。

因此接下來的數天我們將針對這一塊去探討其他滿足 `OCI Runtime` 卻不同於 `runc` 的解決方案，特別會開始跟 `Virtual Machine` 牽扯到一起。



# 參考
- https://cri-o.io
- https://github.com/cri-o/cri-o/blob/master/tutorials/kubeadm.md
- https://www.opencontainers.org/blog/2018/06/20/cri-o-how-standards-power-a-container-runtime
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#configure-cgroup-driver-used-by-kubelet-on-master-node
- https://kubernetes.io/docs/setup/production-environment/container-runtimes/

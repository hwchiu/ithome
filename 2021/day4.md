Day 4 - 透過 RKE 架設第一套 Rancher(上)
====================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
本篇文章將會示範如何使用 Rke + Helm 來搭建一個基於 RKE 叢集的 Rancher 服務。
該 RKE 叢集會有三個節點，因此環境方面就會準備三台 VM，這三台 VM 前面就會架設一個 Load-Balancer 來幫忙將流量導向後方服務。
同時也會準備一個 rancher.hwchiu.com 的 DNS 紀錄，這樣之後存取時會更為簡單與方便。

# 環境準備
接下來的環境都會基於 Azure 雲端環境來使用，包含了 VMs 與 LoadBalancer 的設定
本文章不會探討 Azure 雲端該如何使用，事實上讀者可以使用任意的公有雲服務，甚至是地端機器都可。
下述為相關的軟體版本資訊

- VM: Azure VM
- OS: Ubuntu 20.04.2 LTS
- Rke: v1.2.11

整個架構如圖下

![Imgur](https://imgur.com/TSO7fHf.png)

整個環境的概念如下
1. 準備三個 VM，這些 VM 本身都沒有任何 Public IP，同時這三個 VM 會作為 RKE 叢集裡面的節點。
2. 準備一個 Load-Balancer，該 Load-Balancer 未來會將流量都導向前述三個 VM，包含 Rancher UI/API 等相關流量
3. 為了方便安裝 RKE 到前述三個節點，會額外準備一個 management server，該伺服器可以透過 ssh 存取前述三台 VM
4. 我們會於 Management server 上透過 RKE 指令來安裝 RKE 叢集。

# 建置 Rancher
整個安裝步驟會分成下列步驟，如
1. 環境檢查並且於 Management server 下載安裝 rke 指令
2. 於 Management server 透過 rke 指令來安裝 rke 叢集到 Server{1,2,3}
3. 透過 Helm 將 Rancher 安裝到該 RKE 叢集中
4. 嘗試透過瀏覽器存取 Rancher 服務


# 環境檢查並且於 Server1 下載安裝 rke

這個步驟一開始我準備了下列環境
1. Management Server 以及 Server{1,2,3}
    - Management Server 能夠透過 ssh 存取 server{1,2,3}
2. LoadBalancer
    - backend pool 設定 server{1,2,3}
    - 轉發 80/443
3. Domain Name (rancher.hwchiu.com)
    - 該 domain name 指向該 LoadBalancer 的 public IP。


透過 SSH 登入到 Management Server 之後，我們要來安裝 rke 這個指令。
官方 [Github](https://github.com/rancher/rke/releases) 上面有針對不同平台的安裝檔案，我的環境需要使用的 rke_linux-amd64

```
wget https://github.com/rancher/rke/releases/download/v1.2.11/rke_linux-amd64
sudo install -m755 rke_linux-amd64 /usr/local/bin/rke
```

安裝完畢後可以直接嘗試使用看看 rke 這個指令
```
azureuser@server1:~$ rke
NAME:
   rke - Rancher Kubernetes Engine, an extremely simple, lightning fast Kubernetes installer that works everywhere

USAGE:
   rke [global options] command [command options] [arguments...]

VERSION:
   v1.2.11

AUTHOR:
   Rancher Labs, Inc.

COMMANDS:
     up       Bring the cluster up
     remove   Teardown the cluster and clean cluster nodes
     version  Show cluster Kubernetes version
     config   Setup cluster configuration
     etcd     etcd snapshot save/restore operations in k8s cluster
     cert     Certificates management for RKE cluster
     encrypt  Manage cluster encryption provider keys
     util     Various utilities to retrieve cluster related files and troubleshoot
     help, h  Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --debug, -d    Debug logging
   --quiet, -q    Quiet mode, disables logging and only critical output will be printed
   --trace        Trace logging
   --help, -h     show help
   --version, -v  print the version
```

同時確認該 management server 可以使用 ssh 連結到上述 Server{1,2,3}
```
azureuser@rke-management:~$ ssh 10.0.0.10 "hostname"
rke-serve000004
azureuser@rke-management:~$ ssh 10.0.0.8 "hostname"
rke-serve000002
azureuser@rke-management:~$ ssh 10.0.0.7 "hostname"
rke-serve000001
```

接者也要確認上述 server{1,2,3} 都安裝好 docker 並且當前非 root 使用者可以執行，因為 rke 會需要透過 docker 去創建基本服務。
```bash
azureuser@rke-management:~$ ssh 10.0.0.7 "docker ps "
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
azureuser@rke-management:~$ ssh 10.0.0.8 "docker ps "
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
azureuser@rke-management:~$ ssh 10.0.0.10 "docker ps "
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

# 透過 rke 於 Server1 安裝 rke 叢集

接下來使用 rke 的指令來創建 rke 創建叢集，首先要讓 rke 指令知道我們有三台伺服器，同時這些伺服器要登入的 IP/SSH Uername 以及相關的 k8s 角色，我們需要準備一個 cluster.yaml 作為設定檔案。

首先透過 rke 指令確認當前支援的 kubernetes 版本
```bash
azureuser@rke-management:~$ rke config --list-version --all
v1.17.17-rancher2-3
v1.19.13-rancher1-1
v1.18.20-rancher1-2
v1.20.9-rancher1-1
```

當前支援最高的版本是 v1.20.9-rancher1-1，所以準備一個下列的 cluster.yaml，其描述了
1. 三台伺服器的 IP 以及 ssh 角色名稱
2. 每個角色都要扮演 k8s controlplane, k8s worker 以及 etcd.
3. network 使用 calico 作為 CNI
4. 啟動 etcd 並且啟動自動備份

```yaml
cluster_name: ithome-rancher
kubernetes_version: "v1.20.9-rancher1-1"
nodes:
  - address: 10.0.0.7
    user: azureuser
    role: [controlplane,worker,etcd]
  - address: 10.0.0.8
    user: azureuser
    role: [controlplane,worker,etcd]
  - address: 10.0.0.10
    user: azureuser
    role: [controlplane,worker,etcd]
services:
  etcd:
    backup_config:
      enabled: true
      interval_hours: 6
      retention: 60
network:
  plugin: flannel
```


準備好上述檔案後，透過 `rke up` 來創建 cluster
```bash
azureuser@rke-management:~$ rke up --config cluster.yaml
INFO[0000] Running RKE version: v1.2.11
INFO[0000] Initiating Kubernetes cluster
INFO[0000] [certificates] GenerateServingCertificate is disabled, checking if there are unused kubelet certificates
INFO[0000] [certificates] Generating admin certificates and kubeconfig
INFO[0000] Successfully Deployed state file at [./cluster.rkestate]
INFO[0000] Building Kubernetes cluster
INFO[0000] [dialer] Setup tunnel for host [10.0.0.8]
INFO[0000] [dialer] Setup tunnel for host [10.0.0.10]
INFO[0000] [dialer] Setup tunnel for host [10.0.0.7]
INFO[0000] [network] Deploying port listener containers
INFO[0000] Pulling image [rancher/rke-tools:v0.1.77] on host [10.0.0.7], try #1
INFO[0000] Pulling image [rancher/rke-tools:v0.1.77] on host [10.0.0.8], try #1
INFO[0000] Pulling image [rancher/rke-tools:v0.1.77] on host [10.0.0.10], try #1
....
INFO[0284] [dns] DNS provider coredns deployed successfully
INFO[0284] [addons] Setting up Metrics Server
INFO[0284] [addons] Saving ConfigMap for addon rke-metrics-addon to Kubernetes
INFO[0284] [addons] Successfully saved ConfigMap for addon rke-metrics-addon to Kubernetes
INFO[0284] [addons] Executing deploy job rke-metrics-addon
INFO[0301] [addons] Metrics Server deployed successfully
INFO[0301] [ingress] Setting up nginx ingress controller
INFO[0301] [addons] Saving ConfigMap for addon rke-ingress-controller to Kubernetes
INFO[0301] [addons] Successfully saved ConfigMap for addon rke-ingress-controller to Kubernetes
INFO[0301] [addons] Executing deploy job rke-ingress-controller
INFO[0306] [ingress] ingress controller nginx deployed successfully
INFO[0306] [addons] Setting up user addons
INFO[0306] [addons] no user addons defined
INFO[0306] Finished building Kubernetes cluster successfully
```

RKE已經正式創建完畢，當前目錄下會產生一個 KUBECONFIG 的目錄，檔案名稱為 "kube_config_cluster.yaml"

```bash=
azureuser@rke-management:~$ mkdir .kube
azureuser@rke-management:~$ install -m400 kube_config_cluster.yaml ~/.kube/config
azureuser@rke-management:~$ kubectl get nodes
azureuser@rke-management:~$ sudo chmod 400 .kube/config
azureuser@rke-management:~$ kubectl get nodes
NAME        STATUS   ROLES                      AGE   VERSION
10.0.0.10   Ready    controlplane,etcd,worker   10m   v1.20.9
10.0.0.7    Ready    controlplane,etcd,worker   10m   v1.20.9
10.0.0.8    Ready    controlplane,etcd,worker   10m   v1.20.9
azureuser@rke-management:~$ kubectl get pods -A
NAMESPACE       NAME                                       READY   STATUS      RESTARTS   AGE
ingress-nginx   default-http-backend-6977475d9b-xrmv9      1/1     Running     0          9m34s
ingress-nginx   nginx-ingress-controller-bl7p9             1/1     Running     0          9m34s
ingress-nginx   nginx-ingress-controller-g476g             1/1     Running     0          9m34s
ingress-nginx   nginx-ingress-controller-nqlqv             1/1     Running     0          9m34s
kube-system     calico-kube-controllers-7ddcfb748f-tvnkp   1/1     Running     0          10m
kube-system     calico-node-f42dt                          1/1     Running     0          10m
kube-system     calico-node-gsn8f                          1/1     Running     0          10m
kube-system     calico-node-p98tx                          1/1     Running     0          10m
kube-system     coredns-55b58f978-7j85f                    1/1     Running     0          9m36s
kube-system     coredns-55b58f978-l4smb                    1/1     Running     0          10m
kube-system     coredns-autoscaler-76f8869cc9-t2s6f        1/1     Running     0          9m58s
kube-system     metrics-server-55fdd84cd4-m96ql            1/1     Running     0          9m43s
kube-system     rke-coredns-addon-deploy-job-7l8zs         0/1     Completed   0          10m
kube-system     rke-ingress-controller-deploy-job-pjvns    0/1     Completed   0          9m36s
kube-system     rke-metrics-addon-deploy-job-ddct7         0/1     Completed   0          9m55s
kube-system     rke-network-plugin-deploy-job-gprzz        0/1     Completed   0          10m
```

到這個環節，我們已經正式的將 RKE 叢集給創建完畢了，下一章節我們就要來透過 Helm 的方式將 Rancher 給安裝到該 RKE 中。

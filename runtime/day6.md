[Day6] Kubernetes & CRI (Container Runtime Interface)(II)
=====================================================

> 本文同步刊登於 [hwchiu.com - Kubernetes & CRI (II)](https://www.hwchiu.com/kubernetes-cri-ii.html)

2020 IT邦幫忙鐵人賽 Kubernetes 原理分析系列文章

- [kubernetes 探討](https://ithelp.ithome.com.tw/articles/10215384/)
- [Container & Open Container Initiative](https://ithelp.ithome.com.tw/articles/10216215)
- [Container Runtime Interface](https://ithelp.ithome.com.tw/articles/10218127)
- [Container Network Interface](https://ithelp.ithome.com.tw/articles/10220626)
- Container Storage Interface
- Device Plugin
- Container Security

有興趣的讀者歡迎到我的網站 https://hwchiu.com 閱讀其他技術文章，有任何錯誤或是討論歡迎直接留言或寄信討論


# 前言

前篇文章中跟大家探討了 `kubernetes` 內關於容器運行標準化的架構，透過 `Container Runtime Interface` 與各式各樣的 `Container Runtime` 解決方案溝通，可以讓 `kubernetes` 本身只需要專注於 `kubelet` 以及 `CRI 標準` 的互動，第三方開發者則可以根據需求開發出各式各樣不同的產品，只要能夠滿足 `CRI 標準` 即可。

就我所知，目前相容於 `CRI` 的解決方案可根據其架構分成三大類，分別是
- 真的是輕量級虛擬化的容器
- 背後是虛擬機器，但是卻運作起來像輕量級虛擬化的容器
- 真的是傳統虛擬機器

接下來的數篇文章會根據每個類別詳細介紹一種解決方案，並探討設計理念與架構，與此同時大家也可以思考自己的環境是不是有可能可以搭載其他的解決方案，而非永遠使用 `Docker` ?

本篇會先透過一個簡單的環境實驗來帶過如何建置一個使用 `containerd` 的 `kubernetes` 環境，可以體驗到不安裝 `docker` 也可以運行的 `kubernetes` 叢集， 同時之後若安裝了 `docker` 也可以觀察到是否真的如上篇文章所說， `docker` 與 `kubernetes` 本身創造出來的 `container` 是互相不干涉的。

# 環境建置
接下來的建置環境與步驟是參考 [Containerd GitHub](https://github.com/containerd/cri/tree/master/contrib/ansible
) 濃縮的。

## 環境需求
- OS: Ubuntu 16.04
    - 18.04 會因為 `kubernetes deb` 相關的問題導致套件更新失敗，建議先基於 `16.04` 測試即可
- Python: 2.7+
- Ansible: 2.4+
    - 有沒有使用 `ansible` 都無所謂，因為我們會拆解裡面的步驟，去看看全部的安裝步驟
    - 

## 環境安裝
環境的部分只有包括 `containerd` 的相依套件，並不包含 `kubernetes` 叢集本身，但是有包含 `kubeadm`, `kubectl`, `kubelet` 相關套件。

### Ansible 版本
基本上官方文件已經將相關的步驟都建置完畢，本身只需要準備 `hosts` 的檔案即可，該 `ansible playbook` 支援 `Ubuntu` 以及 `CentOS` 兩套發行版本。

首先在 `ansible host` 執行下列指令抓取相關的 `ansible-playbook`
``` bash=
git clone https://github.com/containerd/cri
cd ./cri/contrib/ansible
```

接下來根據需求產生對應的 `hosts` 檔案，裡面放置要被安裝的機器，或是直接採用 `localhost` 的方式再本機運行該 `playbook` 即可。
這部分比較屬於 `ansible` 的方式，不熟悉的讀者可以自行尋找資源看看如何運行，或是放棄採用 `ansible`, 而是逐條逐條的自行安裝
```bash=
ansible-playbook -i hosts cri-containerd.yaml
```

順利跑完應該會看到類似下圖的結果

```bash=
...
TASK [Create a directory for cni binary] ***********************************************************************************************************************************$
changed: [localhost]

TASK [Create a directory for cni config files] *****************************************************************************************************************************$
changed: [localhost]

TASK [Create a directory for containerd config] ****************************************************************************************************************************$
changed: [localhost]

TASK [Start Containerd] ****************************************************************************************************************************************************$changed: [localhost]

TASK [Load br_netfilter kernel module] *************************************************************************************************************************************$
changed: [localhost]

TASK [Set bridge-nf-call-iptables] *****************************************************************************************************************************************$
changed: [localhost]

TASK [Set ip_forward] ******************************************************************************************************************************************************$
changed: [localhost]

TASK [Check kubelet args in kubelet config] ********************************************************************************************************************************$
changed: [localhost]

TASK [Add runtime args in kubelet conf] ************************************************************************************************************************************$
skipping: [localhost]

TASK [Start Kubelet] *******************************************************************************************************************************************************$
changed: [localhost]

TASK [Pre-pull pause container image] **************************************************************************************************************************************$
changed: [localhost]

PLAY RECAP ******************************************************************************************************************************************************************
...

```
### 手動安裝版本
如果不想透過 `ansible` 一鍵安裝完畢，接下來透過拆解該 `ansible playbook` 就可以知道實際上要做哪些步驟來建置 `containerd` 的環境。

1. 讀取下列變數 `var/vars.yaml`
    - containerd_release_version: 1.1.0-rc.0
    - cni_bin_dir: /opt/cni/bin/
    - cni_conf_dir: /etc/cni/net.d/
第一個指明 `containerd` 的版本後，後續兩個變數則是 `CNI (Container Network Interface)` 會用到的路徑，之後的文章會細部探討 `CNI` 的設計與使用。
2. 根據發行版本讀取不同的檔案來安裝相關套件 (Ubuntu 為範例)
    - unzip
    - tar
    - apt-transport-https
    - btrfs-tools
    - libseccomp2
    - socat
    - util-linux
3. 安裝 `kubernetes` 會用到的相關工具
    - kubelet
    - kubeadm
    - kubectl
5. 安裝 `containerd` 會用到的相關工具
    - cri-containerd
    - 來源網址是 https://storage.googleapis.com/cri-containerd-release, 點進去可以看到各種不同版本的 `cri-containerd`.
    - 解壓縮該安裝檔案後可以看到有下列內容，包含了 `systemd` 的設定，相關的執行檔案。
``` bash=
./
./opt/
./opt/containerd/
./opt/containerd/cluster/
./opt/containerd/cluster/gce/
./opt/containerd/cluster/gce/cloud-init/
./opt/containerd/cluster/gce/cloud-init/node.yaml
./opt/containerd/cluster/gce/cloud-init/master.yaml
./opt/containerd/cluster/gce/configure.sh
./opt/containerd/cluster/gce/env
./opt/containerd/cluster/version
./opt/containerd/cluster/health-monitor.sh
./usr/
./usr/local/
./usr/local/sbin/
./usr/local/sbin/runc
./usr/local/bin/
./usr/local/bin/crictl
./usr/local/bin/containerd
./usr/local/bin/containerd-stress
./usr/local/bin/critest
./usr/local/bin/containerd-release
./usr/local/bin/containerd-shim
./usr/local/bin/ctr
./etc/
./etc/systemd/
./etc/systemd/system/
./etc/systemd/system/containerd.service
./etc/crictl.yaml
```
7. 透過 `systemd` 啟動 `containerd`
8. 設定 `netfilter` 相關設定，讓 `kernel` 啟動相關功能
    - br_netfilter -> bridge 層級啟動 netfilter (ebtables)
    - bridge-nf-call-iptables -> bridge 層級也會去呼叫 iptables 處理
    - ip_forward -> 轉發 ip 封包
這些功能基本上以前安裝 `docker` 的時候都會幫忙處理，所以基本上都不會特別注意到
9. 接下來就是重頭戲了，如何讓 `kubernetes` 知道要使用 `containerd` 作為其 `Container Runtime` 而非使用 `dockershim` 來銜接 `docker`.
根據 [官方文件](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/)， `kubelet` 裡面有下列的參數可以設定
> --container-runtime string
The container runtime to use. Possible values: 'docker', 'remote', 'rkt(deprecated)'. (default "docker")
  --container-runtime-endpoint string
[Experimental] The endpoint of remote runtime service. Currently unix socket is supported on Linux, and tcp is supported on windows.
>

其中 `container-runtime` 可以使用三種來處理，分別是內建的 `docker`, `rkt` 以及客製化的 `remote`.
當上述選擇了 `remote` 後，也必須要一起設定 `container-runtime-endpoint` 告訴 `kubelet` 這時候要怎麼跟非內建的 `container runtime` 溝通。

因此安裝過程中，該 `ansible playbook` 就會嘗試修改 `kubelet` 的啟動參數，這部分因為整個安裝過程都是透過 `kubeadm` 去架設 `kubernetes cluster`, 所以最後是修改 `/etc/systemd/system/kubelet.service.d/10-kubeadm.conf` 這個檔案. 關於 `kubeadm` 與 `kubelet` 彼此之間的設定過程可以參考下列文章 [kubeadm/kubelet-integration](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/#the-kubelet-drop-in-file-for-systemd)

```bash=
vagrant@k8s-dev:~$ sudo cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_EXTRA_ARGS= --runtime-cgroups=/system.slice/containerd.service --container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/default/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
```

當我們實際觀察這個檔案，可以發現裡面關於環境變數的部分加入了下列選項，這時候我們就明瞭到底 `kubernetes` 之後是如何跟 `containerd` 溝通的
`--container-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock"`

10. 最後就是啟動 `kubelet` 將基本的服務起來
## Kubernetes Cluster
一切都準備就緒後，接下來非常簡單的透過 `kubeadm` 的方式來創建 `kubernetes cluster`.
這個範例中我採用 `flannel` 作為 CNI, 之後也會有文章詳細介紹 `Flannel` 的運作原理。

依序執行下列指令將 `kubernetes cluster` 給建立起來，並安裝 `CNI` 同時也打開
`taint` 讓 `master node` 也可以部署 `Pod`.


```bash=
sudo swapoff -a && sudo sysctl -w vm.swappiness=0
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml
kubectl taint nodes --all node-role.kubernetes.io/master-
```

這時候使用簡單的工具確認 `kubernetes` 有正常起來即可
```bash=
vagrant@k8s-dev:~/cri/contrib/ansible$ kubectl get pods --all-namespaces
NAMESPACE     NAME                          READY   STATUS    RESTARTS   AGE
kube-system   coredns-5c98db65d4-ghzpl      0/1     Running   0          26s
kube-system   coredns-5c98db65d4-thsdq      0/1     Running   0          26s
kube-system   kube-flannel-ds-amd64-ztqgs   1/1     Running   0          14s
kube-system   kube-proxy-jfs66              1/1     Running   0          26s
```

# 觀察
## Containerd
接下來我們要透過不同的工具來觀察當使用 `containerd` 作為部署時有什麼不同

由於此時我們不是透過 `docker` 來管理整個 `kubernetes` 底層需要的 `container`，而是透過 `kubelet & CRI & containerd` 來管理。
所以這時候就不能透過 `docker ps` 或是 `docker images` 等指令來看相關的 `container` 資源，取而代之的是 `crictl` 這個在前面步驟伴隨 `containerd` 一起安裝到系統內的工具。

```bash=
vagrant@k8s-dev:~/cri/contrib/ansible$ crictl
NAME:
   crictl - client for CRI

USAGE:
   crictl [global options] command [command options] [arguments...]

VERSION:
   1.0.0-beta.0

COMMANDS:
     attach        Attach to a running container
     create        Create a new container
     exec          Run a command in a running container
     version       Display runtime version information
     images        List images
     inspect       Display the status of one or more containers
     inspecti      Return the status of one ore more images
     inspectp      Display the status of one or more pod sandboxes
     logs          Fetch the logs of a container
     port-forward  Forward local port to a pod sandbox
     ps            List containers
     pull          Pull an image from a registry
     runp          Run a new pod sandbox
     rm            Remove one or more containers
     rmi           Remove one or more images
     rmp           Remove one or more pod sandboxes
     pods          List pod sandboxes
     start         Start one or more created containers
     info          Display information of the container runtime
     stop          Stop one or more running containers
     stopp         Stop one or more running pod sandboxes
     update        Update one or more running containers
     config        Get and set crictl options
     stats         List container(s) resource usage statistics
     completion    Output bash shell completion code
     help, h       Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --config value, -c value            Location of the client config file (default: "/etc/crictl.yaml") [$CRI_CONFIG_FILE]
   --debug, -D                         Enable debug mode
   --image-endpoint value, -i value    Endpoint of CRI image manager service [$IMAGE_SERVICE_ENDPOINT]
   --runtime-endpoint value, -r value  Endpoint of CRI container runtime service (default: "unix:///var/run/dockershim.sock") [$CONTAINER_RUNTIME_ENDPOINT]
   --timeout value, -t value           Timeout of connecting to the server (default: 10s)
   --help, -h                          show help
   --version, -v                       print the version

```

說明非常簡單，就是 `CRI` 命令列，其預設的設定檔案位於 `/etc/crictl.yaml`
```bash=
vagrant@k8s-dev:~/cri/contrib/ansible$ cat /etc/crictl.yaml
runtime-endpoint: /run/containerd/containerd.sock
```

所以接下來呼叫的任何 `crictl` 指令都會跟 `containerd` 互動來取得回應，我們就根據上面的提示來試試看各種指令

基於 `kubernetes POD` 概念的資源顯示
```bash=
vagrant@k8s-dev:~/cri/contrib/ansible$ sudo crictl pods                                                                                                PODSANDBOX ID       CREATED             STATE               NAME                              NAMESPACE           ATTEMPT
4ed054a456e96       17 minutes ago      SANDBOX_READY       coredns-5c98db65d4-ghzpl          kube-system         0                                    c5209a01e0936       17 minutes ago      SANDBOX_READY       coredns-5c98db65d4-thsdq          kube-system         0
0a771e9912232       18 minutes ago      SANDBOX_READY       kube-flannel-ds-amd64-ztqgs       kube-system         0
0642c904298c8       18 minutes ago      SANDBOX_READY       kube-proxy-jfs66                  kube-system         0
46039553a0fcc       18 minutes ago      SANDBOX_READY       kube-scheduler-k8s-dev            kube-system         0
ec6d7cde198cc       18 minutes ago      SANDBOX_READY       kube-controller-manager-k8s-dev   kube-system         0
be0bc17da244d       18 minutes ago      SANDBOX_READY       etcd-k8s-dev                      kube-system         0
490d8b240d8ca       18 minutes ago      SANDBOX_READY       kube-apiserver-k8s-dev            kube-system         0
```

相關的 `container images`, 這些 `images` 再之前都是透過 `docker pull` 等方式安裝，如今我們系統內完全不裝 `docker` 也是可以使用，這一切都是仰賴 `OCI` 標準的制定外加 `containerd` 的幫忙。

```bash=
vagrant@k8s-dev:~/cri/contrib/ansible$ sudo crictl images
IMAGE                                TAG                 IMAGE ID            SIZE
k8s.gcr.io/coredns                   1.3.1               eb516548c180f       12.3MB
k8s.gcr.io/etcd                      3.3.10              2c4adeb21b4ff       76.2MB
k8s.gcr.io/kube-apiserver            v1.15.3             5eb2d3fc7a44e       49.3MB
k8s.gcr.io/kube-controller-manager   v1.15.3             e77c31de55475       47.8MB
k8s.gcr.io/kube-proxy                v1.15.3             232b5c7931462       30.1MB
k8s.gcr.io/kube-scheduler            v1.15.3             703f9c69a5d57       29.9MB
k8s.gcr.io/pause                     3.1                 da86e6ba6ca19       317kB
quay.io/coreos/flannel               v0.11.0-amd64       8a9c4ced3ff92       16.9MB
vagrant@k8s-dev:~/cri/contrib/ansible$ sudo crictl ps
```

接下來看看運行的 `container`, 其結果跟 `docker ps` 非常相似，使用起來幾乎沒有任何違和感，我覺得設定 `alias docker=crictl` 都不會有什麼錯覺?

```bash=
vagrant@k8s-dev:~/cri/contrib/ansible$ sudo crictl ps
CONTAINER ID        IMAGE                                                                     CREATED             STATE               NAME
         ATTEMPT
1cf00f473d03a       sha256:eb516548c180f8a6e0235034ccee2428027896af16a509786da13022fe95fe8c   19 minutes ago      CONTAINER_RUNNING   coredns
         0
221b815ca1f56       sha256:eb516548c180f8a6e0235034ccee2428027896af16a509786da13022fe95fe8c   19 minutes ago      CONTAINER_RUNNING   coredns
         0
f35552b98abc1       sha256:8a9c4ced3ff92c63c446d55c2353c42410c78b497a0483d4048e8d30ebe37058   19 minutes ago      CONTAINER_RUNNING   kube-flannel
         0
8eafd7980b1d3       sha256:232b5c79314628fbc788319e2dff191f4d08e38962e42ebd31b55b52fecd70ec   19 minutes ago      CONTAINER_RUNNING   kube-proxy
         0
feb2ed1caa423       sha256:2c4adeb21b4ff8ed3309d0e42b6b4ae39872399f7b37e0856e673b13c4aba13d   20 minutes ago      CONTAINER_RUNNING   etcd
         0
00be90f2a7ac0       sha256:703f9c69a5d578378a022dc75d0c242d599422a1b7cc9cf5279b49d39dc7ca08   20 minutes ago      CONTAINER_RUNNING   kube-scheduler
         0
e16c5a24ff09d       sha256:e77c31de554758f3f03e78e124a914b7d86de7d7cf3d677c9b720efb90a833f9   20 minutes ago      CONTAINER_RUNNING   kube-controller-m
anager   0
fbe374eb60712       sha256:5eb2d3fc7a44e3a8399256d4b60153a1a59165e70334a1c290fcbd33a9a9d8a7   20 minutes ago      CONTAINER_RUNNING   kube-apiserver
         0
```

除了 `container` 本身的管理外，我們來看一下系統內運行的應用程式, 可以觀察到系統上有一個 `containerd` 正在運行，同時 `kuberlet` 內關於 `container-runtime` 的參數有被修改。

此外對於每個運作的 `container`, `containetd` 都會產生一個 `containerd-shim` 來運作。

```bash=
vagrant@k8s-dev:~/cri/contrib/ansible$ ps -axo command | grep containerd
/usr/local/bin/containerd

/usr/bin/kubelet --bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf --config=/var/lib/kubelet/conf
ig.yaml --container-runtime=remote --container-runtime-endpoint=/run/containerd/containerd.sock --runtime-cgroups=/system.slice/containerd.service --co
ntainer-runtime=remote --runtime-request-timeout=15m --container-runtime-endpoint=unix:///run/containerd/containerd.sock

containerd-shim -namespace k8s.io -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/k8s.io/490d8b240d8ca4c0df7d8440c5002ca795bddb989fb8bc6de2
0da78394eb8ce6 -address /run/containerd/containerd.sock -containerd-binary /usr/local/bin/containerd
...
.....
```

## Docker
為了驗證之前說明是否 `dockerd` 與 `kubelet` 共用 `containerd` 但是彼此資源是互相隔離的，這時候我們來安裝一下 `docker` 並且於背景運行一個 `container` 試試看

```bash=
sudo docker run -d hwchiu/netutils
```
接下來我們使用 `docker` 指令針對上述的操作都進行一次，來比較看看
```bash=
vagrant@k8s-dev:~$ sudo docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
hwchiu/netutils     latest              a0d1dad34d58        13 months ago       222MB
vagrant@k8s-dev:~$ sudo docker ps
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS               NAMES
320b653e39d8        hwchiu/netutils     "/bin/bash ./entrypo…"   15 minutes ago      Up 15 minutes                           inspiring_haslett
```
非常乾淨簡單，完全看不到任何 `kubernetes` 用到的容器資源，此外我們再度透過 ｀`ps` 觀察

```bash=
/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock

containerd-shim -namespace moby -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/moby/320b653e39d8164e3033f1eec079c7772a10e703d24bb7f39f7bdf26fe084fe5 -address /run/containerd/containerd.sock -containerd-binary /usr/local/bin/containerd -runtime-root /var/run/docker/runtime-runc

```
首先，可以看到 `dockerd` 這時候也透過參數的方式去連接 `containerd`, 另外可以看到針對我上述的 `docker image` 所產生的 `containerd-shim` 與 `kubernetes` 產生的 `containerd-shim` 有明顯的參數不同
1. -namespace moby v.s k8s.io
2. workdir 不同
3. -runtime-root /var/run/docker/runtime-runc

此外我們也可以透過 `containerd cli(ctr) and containerd` 來觀察更多有趣的資訊

首先可以看到對於 `containerd` 的確有不同的 `namespace`，也的確如上面所觀察到的是 `moby` 與 `k8s.io`
```bash=
vagrant@k8s-dev:~$ sudo ctr namespaces ls
NAME   LABELS
k8s.io
moby
```

此外我們也可以看到不少關於 containerd 預設的設定，預設情況下 `linux` 環境中都是採用 `runc` 作為 `OCI Runtime Spec` 的解決方案。
而 `kubelet` 透過 `CRI` 與 `docker` 最後選擇都是會採取 `plugin.linux` 的設定，所以兩者背後最後都是透過 `runc` 來創建 `Container`。

```bash=
sudo containerd config default
...
  [plugins.cri]
    stream_server_address = ""
    stream_server_port = "10010"
    enable_selinux = false
    sandbox_image = "k8s.gcr.io/pause:3.1"
    stats_collect_period = 10
    systemd_cgroup = false
    [plugins.cri.containerd]
      snapshotter = "overlayfs"
      [plugins.cri.containerd.default_runtime]
        runtime_type = "io.containerd.runtime.v1.linux"
        runtime_engine = ""
        runtime_root = ""
      [plugins.cri.containerd.untrusted_workload_runtime]
        runtime_type = ""
        runtime_engine = ""
        runtime_root = ""
...
  [plugins.linux]
    shim = "containerd-shim"
    runtime = "runc"
    runtime_root = ""
    no_shim = false
    shim_debug = false
...

```


# Summary
本文中我們簡述了如何建置一套基於 `containerd` 而非 `docker` 的 `kubernetes cluster`, 並且透過相關指令與工具來觀察在此設定下，`kubernetes`,`containerd`, `dockerd` 等彼此的交互關係，可以更加深對於 `CRI, OCI` 等概念的理解。

kubelet -> containerd -> containetrd-shin(k8s.io) -> runc

docker client -> docker enginer -> containerd -> containerd-shim(moby) -> runc 



# 參考
- https://github.com/containerd/cri/tree/master/contrib/ansible
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/#installing-runtime 
- https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/kubelet-integration/#the-kubelet-drop-in-file-for-systemd
- https://gist.github.com/mcastelino/35c221a81c70afc12f8b0929774b60a3

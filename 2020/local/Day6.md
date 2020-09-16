Day 6 - K3D與KIND 的部署示範
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)https://www.facebook.com/technologynoteniu)



上篇文章中，我們探討了本地開發對於 Kubernetes 的需求，一般來說不一定會需要 Kubernetes，使用 Docker 或是 Docker-compose 就可以滿足大部分人開發的需求。假設真的有 Kubernetes 的需求，也列出了四個常見的部署方式以及各自的基本介紹

本篇則會從中擷取 KIND 以及 K3D 帶來基本的操作範例



# K3D



上篇文章中有提到 K3D 是由 Rancher 所維護且開發的技術，其目的是將 Rancher 維護的輕量級 Kubernetes 版本 `k3s` 以 Docker 的形式建立起來，透過 Docker Container 的創建就可以輕鬆的建立多個 Kubernetes 節點

更多詳細介紹請參閱[官方Repo](https://github.com/rancher/k3d)



## 安裝

安裝過程非常簡單，一行指令就可以

```bash
sudo curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
```

```bash
$ k3d
Usage:
  k3d [flags]
  k3d [command]

Available Commands:
  cluster     Manage cluster(s)
  completion  Generate completion scripts for [bash, zsh, powershell | psh]
  help        Help about any command
  image       Handle container images.
  kubeconfig  Manage kubeconfig(s)
  node        Manage node(s)
  version     Show k3d and default k3s version

Flags:
  -h, --help      help for k3d
      --verbose   Enable verbose output (debug logging)
      --version   Show k3d and default k3s version

Use "k3d [command] --help" for more information about a command.
```

整個指令非常簡單，比較常見會使用的就是 cluster, kubeconfig 以及 node



## 創建 Cluster

創建上也是非常簡單，輸入 `k3d cluster` 可以看到一些跟 cluster 相關的指令，實際上使用的時候都要描述你希望的 cluster 名稱，這邊我就不輸入，一律採用預設值 `k3s-default`

```bash
$ k3d cluster
Manage cluster(s)

Usage:
  k3d cluster [flags]
  k3d cluster [command]

Available Commands:
  create      Create a new cluster
  delete      Delete cluster(s).
  list        List cluster(s)
  start       Start existing k3d cluster(s)
  stop        Stop existing k3d cluster(s)

Flags:
  -h, --help   help for cluster

Global Flags:
      --verbose   Enable verbose output (debug logging)

Use "k3d cluster [command] --help" for more information about a command
```

我們可以透過 `k3d cluster create`  來創建一個 k3s 的叢集，預設情況下是一個節點，我們可以透過 `-s` 的方式來指定要有多少個 node.

```bash
$ k3d cluster create -s 3
INFO[0000] Created network 'k3d-k3s-default'
INFO[0000] Created volume 'k3d-k3s-default-images'                                                                                                                           INFO[0000] Creating initializing server node
INFO[0000] Creating node 'k3d-k3s-default-server-0'
INFO[0009] Creating node 'k3d-k3s-default-server-1'
INFO[0010] Creating node 'k3d-k3s-default-server-2'
INFO[0011] Creating LoadBalancer 'k3d-k3s-default-serverlb'
INFO[0018] Cluster 'k3s-default' created successfully!
INFO[0018] You can now use it like this:
kubectl cluster-info
```

創建完畢後，我們馬上透過 `docker` 指令來觀察，可以觀察到的確有 docker container 被創立起來，不過數量卻是比 server 還要多一個，主要是用來當作 load-balancer 使用

```bash
$ docker ps
CONTAINER ID        IMAGE                      COMMAND                  CREATED             STATUS              PORTS                             NAMES
b5903d159c73        rancher/k3d-proxy:v3.0.1   "/bin/sh -c nginx-pr…"   42 minutes ago      Up 42 minutes       80/tcp, 0.0.0.0:44429->6443/tcp   k3d-k3s-default-serverlb
aaa0cd077a51        rancher/k3s:v1.18.6-k3s1   "/bin/k3s server --t…"   42 minutes ago      Up 42 minutes                                         k3d-k3s-default-server-2
636968375fd2        rancher/k3s:v1.18.6-k3s1   "/bin/k3s server --t…"   42 minutes ago      Up 42 minutes                                         k3d-k3s-default-server-1
5bfb8b1c64bb        rancher/k3s:v1.18.6-k3s1   "/bin/k3s server --c…"   43 minutes ago      Up 43 minutes                                         k3d-k3s-default-server-0
```



## 存取 Kubernetes 

為了存取 Kubernetes，我們都會需要準備一份 `KUBECONFIG` 裡面描述 API Server 的位置，以及使用到的 Username 等資訊，這部分 `k3d` 也有提供相關的指令來處理 KUBECONFIG

```bash
$ k3d kubeconfig
Manage kubeconfig(s)

Usage:
  k3d kubeconfig [flags]
  k3d kubeconfig [command]

Available Commands:
  get         Print kubeconfig(s) from cluster(s).
  merge       Write/Merge kubeconfig(s) from cluster(s) into new or existing kubeconfig/file.

Flags:
  -h, --help   help for kubeconfig

Global Flags:
      --verbose   Enable verbose output (debug logging)

Use "k3d kubeconfig [command] --help" for more information about a command.
```

為了簡單測試，我們可以直接使用 `k3d kubeconfig merge` 讓他產生一個全新的檔案

```bash
$ k3d kubeconfig merge
/home/ubuntu/.k3d/kubeconfig-k3s-default.yaml
$ KUBECONFIG=~/.k3d/kubeconfig-k3s-default.yaml kubectl get nodes
NAME                       STATUS     ROLES    AGE     VERSION
k3d-k3s-default-server-2   Ready      master   50m     v1.18.6+k3s1
k3d-k3s-default-server-1   Ready      master   50m     v1.18.6+k3s1
k3d-k3s-default-server-0   Ready      master   50m     v1.18.6+k3s1
```

創建完畢後透過 KUBECONFIG 這個環境變數指向該檔案，就可以利用 kubectl 指令來操作創建起來的 k3s 叢集



## 動態新增節點

如果今天想要動態新增節點，也可以透過 `k3d node create` 指令來操作

```bash
$ k3d node create --role server hwchiu-test
$ k3d node list
NAME                       ROLE           CLUSTER       STATUS
k3d-hwchiu-test-0          server         k3s-default   running
k3d-k3s-default-server-0   server         k3s-default   running
k3d-k3s-default-server-1   server         k3s-default   running
k3d-k3s-default-server-2   server         k3s-default   running
k3d-k3s-default-serverlb   loadbalancer   k3s-default   running
$ KUBECONFIG=~/.k3d/kubeconfig-k3s-default.yaml kubectl get nodes
NAME                       STATUS     ROLES    AGE     VERSION
k3d-k3s-default-server-0   Ready      master   51m     v1.18.6+k3s1
k3d-k3s-default-server-2   Ready      master   51m     v1.18.6+k3s1
k3d-k3s-default-server-1   Ready      master   51m     v1.18.6+k3s1
k3d-hwchiu-test-0          Ready      master   9s      v1.18.6+k3s1
```



整個使用上的介紹就到這邊，基本上不會太困難，而且指令簡單，想要快速架起多節點的 Kubernetes，可以嘗試使用看看這套軟體



# KIND

接下來我們來看另外一套也是基於 Docker 為基礎的多節點建置工具 KIND, 相對於 K3D， KIND 是完整版本的 Kubernetes，由 Kubernetes 社群維護，使用上也是非常簡單，詳細的介紹可以參閱 [官方Repo](https://github.com/kubernetes-sigs/kind)



# 安裝

安裝過程非常簡單，也是一些 script 的行為就可以處理完畢，跟 `k3d` 一樣，所有的操作過程都是在本地的 binary 完成的

```bash
curl -Lo ./kind "https://github.com/kubernetes-sigs/kind/releases/download/v0.7.0/kind-$(uname)-amd64"
chmod a+x ./kind
sudo mv ./kind /usr/local/bin/kind
```

```bash
$ kind
kind creates and manages local Kubernetes clusters using Docker container 'nodes'

Usage:
  kind [command]

Available Commands:
  build       Build one of [base-image, node-image]
  completion  Output shell completion code for the specified shell (bash or zsh)
  create      Creates one of [cluster]
  delete      Deletes one of [cluster]
  export      Exports one of [kubeconfig, logs]
  get         Gets one of [clusters, nodes, kubeconfig]
  help        Help about any command
  load        Loads images into nodes
  version     Prints the kind CLI version

Flags:
  -h, --help              help for kind
      --loglevel string   DEPRECATED: see -v instead
  -q, --quiet             silence all stderr output
  -v, --verbosity int32   info log verbosity
      --version           version for kind

Use "kind [command] --help" for more information about a command.
```

測試上最常用到的指令就是 `create`, `delete` 以及 `load` ，這兩者可以幫忙創建與刪除 kubernetes cluster, 後者則可以將一些 container image 送到 docker container 中，這樣你的 kubernetes cluster 如果要抓取 image 就可以直接從本地抓取。



## 創建 Cluster

接下來我們要用 `kind create cluster` 來創建一個基於 docker 的 Kubernetes 叢集，預設情況下只會創建出一個單一節點，如果想要創建更多節點，我們要透過 config 的方式告知 KIND 我們需要的拓墣形狀

因此事先準備好下列檔案 kind.yaml

```yaml
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
nodes:
- role: control-plane
- role: worker
- role: worker
```

裡面描述我們需要三個 node, 其中一個代表 control-plane, 另外兩個則是單純的 worker, 然後將該 config 傳入 KIND 一起使用

```bash
$ kind create cluster --config kind.yaml
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.17.0) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind"
You can now use your cluster with:

kubectl cluster-info --context kind-kind

Have a question, bug, or feature request? Let us know! https://kind.sigs.k8s.io/#community 🙂
```

創建完畢後，直接使用 `docker ps` 來觀察結果

```bash
$ docker ps
CONTAINER ID        IMAGE                  COMMAND                  CREATED             STATUS              PORTS                       NAMES
97d7d804ea75        kindest/node:v1.17.0   "/usr/local/bin/entr…"   4 minutes ago       Up 4 minutes                                    kind-worker2
9085118d47b3        kindest/node:v1.17.0   "/usr/local/bin/entr…"   4 minutes ago       Up 4 minutes        127.0.0.1:32768->6443/tcp   kind-control-plane
b9eedb6d5f38        kindest/node:v1.17.0   "/usr/local/bin/entr…"   4 minutes ago       Up 4 minutes                                    kind-worker
```



可以觀察到的確有相對應數量的 docker container 被叫起來，不同於 `k3d`， `kind` 並不會幫忙準備額外的 load-balancer，所以數量就是我們指定的數量

不同於 `k3d`, `kind` 本身創建完畢後就會直接把相關的 KUBECONFIG 給寫入到 `$home/.kube/config` 裡面，因此使用者可以直接使用預設的位置來進行使用

```bash
$ kubectl get nodes
NAME                 STATUS   ROLES    AGE   VERSION
kind-control-plane   Ready    master   13m   v1.17.0
kind-worker          Ready    <none>   12m   v1.17.0
kind-worker2         Ready    <none>   12m   v1.17.0
```



KIND 本身並沒有辦法動態增加節點，這個是使用上的限制，不過我認為這個功能不會影響太多，畢竟作為一個本地測試的節點，有任何問題就砍掉重建就好，花費的時間也不會太長。






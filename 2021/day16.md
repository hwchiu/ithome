Day 16 - Rancher 指令工具的操作
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言
之前曾經探討過如何透過 Terraform 來管理 Rancher，為了完成這個步驟必須要於 Rancher UI 中去取得相關的 Access Token/Secret Key。實際上該 Access Token 除了給 Terraform 去使用外，也可以讓 Rancher 自行開發維護的 CLI 工具來使用。
本篇文章就來介紹一下 Rancher CLI 可以怎麼用，裡面有什麼好用值得注意的功能

# CLI

基本上 Rancher CLI 的功用跟網頁沒差多少，最主要的目的是讓使用者可以透過指令列的方式去操作 Rancher 而非透過網頁操作，這個概念跟 Terraform 是完全一致的。
因此實務上我會推薦都使用 Terraform 工具來管理 Rancher 而非使用 CLI 這個工具，那這樣還有必要學習 CLI 的用法嗎?

答案是肯定的，因為學得愈廣，當問題出現時腦中就會有更多的候選工具供你選擇去思考該如何解決面前的問題。
Rancher CLI 有一個好用的功能我認為是 Terraform 比不上的，這點稍後會來探討。

首先如同先前操作一樣，到 Rancher UI 去取得相關的 Access Token/Secret Key，不過這一次因爲 CLI 會透過 HTTP 進行授權存取，所以會用到的是下方的 Bearer Token，其實就是把 Access Key 跟 Secret Key 給合併而已。

![](https://i.imgur.com/Q2OEqPy.png)
![](https://i.imgur.com/R7PFk3e.png)

取得這些資訊之後就來去 [Rancher CLI](https://github.com/rancher/cli/releases) 官網下載相對應的 CLI 版本，這邊要注意的是 Rancher CLI 的版本不會完全跟 Rancher 對齊。
Rancher 本身的 Release Note 都會描述當前版本對應的 CLI 與 RKE 的版本。
對應到 Rancher v2.5.9 的 CLI 版本是 v.2.4.11

![](https://i.imgur.com/D0ZQKw0.png)

安裝完畢後可以執行看看確認版本是否符合
```bash=
╰─$ rancher --version
rancher version v2.4.11

╰─$ rancher --help
Rancher CLI, managing containers one UTF-8 character at a time

Usage: rancher [OPTIONS] COMMAND [arg...]

Version: v2.4.11

Options:
  --debug                   Debug logging
  --config value, -c value  Path to rancher config (default: "/Users/hwchiu/.rancher") [$RANCHER_CONFIG_DIR]
  --help, -h                show help
  --version, -v             print the version

Commands:
  apps, [app]                                       Operations with apps. Uses helm. Flags prepended with "helm" can also be accurately described by helm documentation.
  catalog                                           Operations with catalogs
  clusters, [cluster]                               Operations on clusters
  context                                           Operations for the context
  globaldns                                         Operations on global DNS providers and entries
  inspect                                           View details of resources
  kubectl                                           Run kubectl commands
  login, [l]                                        Login to a Rancher server
  multiclusterapps, [multiclusterapp mcapps mcapp]  Operations with multi-cluster apps
  namespaces, [namespace]                           Operations on namespaces
  nodes, [node]                                     Operations on nodes
  projects, [project]                               Operations on projects
  ps                                                Show workloads in a project
  server                                            Operations for the server
  settings, [setting]                               Show settings for the current server
  ssh                                               SSH into a node
  up                                                apply compose config
  wait                                              Wait for resources cluster, app, project, multiClusterApp
  token                                             Authenticate and generate new kubeconfig token
  help, [h]                                         Shows a list of commands or help for one command

Run 'rancher COMMAND --help' for more information on a command.
```

從上述的 Help 可以看到該 CLI 有滿多子指令可以使用的，包含了 clusters, context, nodes, projects, ssh 等各種功能。

為了使用這些功能，必須要使用 login 來獲得與目標 Rancher 溝通的能力，這時候前述獲得的 Bearer Token 就派上用場了


```bash
╰─$ rancher login --name test -t token-8s72l:b425shbg49l7rs9mwlqzk89z6tr472qj94wx6vrm9pwh5r6mklsxf6 https://rancher.hwchiu.com/v3                                                                                                130 ↵
NUMBER    CLUSTER NAME   PROJECT ID        PROJECT NAME    PROJECT DESCRIPTION
1         rke-it         c-9z2kx:p-5gdg9   System          System project created for the cluster
2         rke-it         c-9z2kx:p-lxsz6   Default         Default project created for the cluster
3         rke-qa         c-p4fmz:p-fccdb   System          System project created for the cluster
4         rke-qa         c-p4fmz:p-r8wvz   Default         Default project created for the cluster
5         ithome-dev     c-z8j6q:p-p6xrd   myApplication
6         ithome-dev     c-z8j6q:p-q46q5   System          System project created for the cluster
7         ithome-dev     c-z8j6q:p-vblmb   Default         Default project created for the cluster
8         local          local:p-6knqb     System          System project created for the cluster
9         local          local:p-hgjqp     Default         Default project created for the cluster
Select a Project:5
INFO[0121] Saving config to /Users/hwchiu/.rancher/cli2.json
```

登入完畢後，系統會要求你選擇一個 Project 做為預設操作的 Project，選擇完畢後就可以透過 CLI 進行操作了。

CLI 基本上可以完成 UI 所能達到的功能，譬如可以使用 cluster 子指令來觀察 Cluster 的狀態，知道目前有哪些 Cluster，上面的名稱與資源又分別有多少。

```bash=
╰─$ rancher clusters
CURRENT   ID        STATE     NAME         PROVIDER                    NODES     CPU         RAM             PODS
          c-9z2kx   active    rke-it       Azure Container Service     3         1.25/5.70   1.61/13.38 GB   18/330
          c-p4fmz   active    rke-qa       Rancher Kubernetes Engine   2         0.42/4      0.24/7.49 GB    14/220
*         c-z8j6q   active    ithome-dev   Rancher Kubernetes Engine   5         5.97/10     3.37/38.39 GB   110/550
          local     active    local        Imported                    3         0.53/6      0.31/11.24 GB   22/330
```

如果採用的是舊版本的 catalog 的安裝方式的話，也可以透過 apps 子指令觀察安裝的所有資源，當然也可以透過 Rancher CLI 來安裝 application， 所以也會有團隊嘗試使用 Rancher CLI 搭配 CI/CD 流程來安裝 Rancher 服務，不過實務上會推薦使用 Terraform, 因為更有結構同時使用更為容易。

```bash=
╰─$ rancher apps
ID                            NAME                  STATE     CATALOG               TEMPLATE               VERSION
p-p6xrd:dashboard-terraform   dashboard-terraform   active    dashboard-terraform   kubernetes-dashboard   4.5.0
```

那到底有什麼功能是值得使用 Rancher CLI 的? 我認為有兩個，分別是
1. Node SSH
2. Kubernetes KUBECONFIG

前述安裝的 Kubernetes 叢集有一個是採用動態節點的方式，Rancher 透過 Azure 創造這些節點的時候都會準備一把連接用的 SSH Key，這把 Key 是可以透過 UI 的方式下載，不過使用上我認為不太方便。而 Rancher CLI 就有實作這功能，可以讓使用者很方便的透過 CLI 進入到節點中。

指令的使用非常簡單，透過 rancher ssh 搭配節點名稱即可使用。
如果節點本身有兩個 IP 時，透過 -e 可以選擇使用 external 的 IP 地址來使用，否則預設會使用 internal 的 IP 地址。


```bash=
╰─$ rancher ssh -e node1
The authenticity of host '40.112.223.2 (40.112.223.2)' can't be established.
ECDSA key fingerprint is SHA256:dqMCUUC4iZk/gZealQ+Ck3VhG/KaLaCVdkuLYwZfgsE.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '40.112.223.2' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04.5 LTS (GNU/Linux 5.4.0-1055-azure x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Wed Aug 25 22:00:22 UTC 2021

  System load:  0.39               Users logged in:        0
  Usage of /:   33.9% of 28.90GB   IP address for eth0:    192.168.0.5
  Memory usage: 44%                IP address for docker0: 172.17.0.1
  Swap usage:   0%                 IP address for cni0:    10.42.2.1
  Processes:    244

 * Super-optimized for small spaces - read how we shrank the memory
   footprint of MicroK8s to make it the smallest full K8s around.

   https://ubuntu.com/blog/microk8s-memory-optimisation

13 updates can be applied immediately.
To see these additional updates run: apt list --upgradable


*** System restart required ***
Last login: Wed Aug 11 07:28:47 2021 from 52.250.127.84
docker-user@node1:~$
```

因此如果今天有需求想要進入到這些節點進行除錯時，透過 CLI 可以大大的簡化整個過程。

另外一個好用的功能就是 kubeconfig 的存取，試想今天一個系統管理員想要透過指令的方式去管理數十個由 Rancher 維護的 Kubernetes 叢集，最簡單的做法透過網頁的方式將每個叢集的 Kubeconfig 一個又一個的抓下來並且自行處理 kubeconfig 的格式。

透過 CLI 的方式可以讓上述的行為更加簡單甚至自動化。

```bash=
╰─$ rancher cluster kf
Return the kube config used to access the cluster

Usage:
  rancher clusters kubeconfig [CLUSTERID CLUSTERNAME]
```

透過 rancher clusters kf 的指令加上 cluster 名稱就可以取得該叢集的 KUBECONFIG 內容，譬如
```bash=
╰─$ rancher cluster kf rke-it
apiVersion: v1
kind: Config
clusters:
- name: "rke-it"
  cluster:
    server: "https://rancher.hwchiu.com/k8s/clusters/c-9z2kx"

users:
- name: "rke-it"
  user:
    token: "kubeconfig-user-qr5lq:v7htf5kcz2s5nv7b5fzjz68ntlxf2978d5rrgxbrjhz2zv7vjhq9h7"


contexts:
- name: "rke-it"
  context:
    user: "rke-it"
    cluster: "rke-it"

current-context: "rke-it"
```

同時搭配 rancher cluster ls 的指令，我們就可以撰寫一個 for 迴圈來依序取得這些內容，並且將這些內容抓下來處理，譬如

```bash=
╰─$
for c in $(rancher clusters ls --format  '{{.Cluster.Name}}');
do
        rancher cluster kf $c    ;
done

```

上述功能如果與 kubectl 的 plugin, kconfig 整合就可以更順利的將多個 KUBECONFIG 整合成一個檔案，並且將此功能撰寫成一個 shell function, 這樣就可以隨時隨地的去更新當前環境的 Kubeconfig.
譬如


```bash=
function update_k8s_config {
    mv ~/.kube/configs ~/.kube/configs-`date +%Y-%m-%d-%H%M%S`
    mkdir ~/.kube/configs


    for c in $(rancher clusters ls --format  '{{.Cluster.Name}}'); do
        rancher cluster kf $c > ~/.kube/configs/$c
    done

    kubectl konfig merge ~/.kube/configs/* > ~/.kube/config
}

```

剩下 CLI 的功能就留給大家自己去嘗試看看囉。

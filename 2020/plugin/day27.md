Day27  - Kubernetes plugin 範例
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



上篇文章中我們介紹了 kubectl plugin 的系統與生態系，後來我們使用 krew 這個工具來管理各式各樣的 kubectl plugin

因此本篇就從裡面挑選一些 plugin 試試看。


# View Allocations

我們這邊可以隨便挑一些 plugin 來玩看看

```bash
$ kubectl krew install view-allocations
Updated the local copy of plugin index.
Installing plugin: view-allocations
Installed plugin: view-allocations
\
 | Use this plugin:
 |      kubectl view-allocations
 | Documentation:
 |      https://github.com/davidB/kubectl-view-allocations
/
WARNING: You installed plugin "view-allocations" from the krew-index plugin repository.
   These plugins are not audited for security by the Krew maintainers.
   Run them at your own risk.
   
```

這邊要注意，因為我們安裝的都是 `kubectl plugin` 所以最後執行的時候不需要補上 `krew` ，譬如我們上面安裝 `view-allocations`，安裝完畢後直接執行 `kubectl view-allocations`來看



View-allocations 是一個用來顯示系統上所有 `有設定 resource 限定的資源` 數量都列出來，可以幫助你評估當前每個節點上總共有多少 CPU/Memory，然後上面運行的資源目前總共要求多少，百分比多少。

> 要注意的是，如果你的 Pod 沒有用 resource limited 去限制，就不會出現在系統上

```bash
$ kubectl view-allocations
 Resource                                           Requested  %Requested    Limit  %Limit  Allocatable     Free
  cpu                                                 1050.0m          9%   300.0m      2%         12.0     10.9
  ├─ kind-control-plane                                850.0m         21%   100.0m      2%          4.0      3.1
  │  ├─ coredns-6955765f44-l4z47                       100.0m                  0.0
  │  ├─ coredns-6955765f44-zb5xx                       100.0m                  0.0
  │  ├─ kindnet-czpsv                                  100.0m               100.0m
  │  ├─ kube-apiserver-kind-control-plane              250.0m                  0.0
  │  ├─ kube-controller-manager-kind-control-plane     200.0m                  0.0
  │  └─ kube-scheduler-kind-control-plane              100.0m                  0.0
  ├─ kind-worker                                       100.0m          2%   100.0m      2%          4.0      3.9
  │  └─ kindnet-sbqxd                                  100.0m               100.0m
  └─ kind-worker2                                      100.0m          2%   100.0m      2%          4.0      3.9
     └─ kindnet-sw5mq                                  100.0m               100.0m
  ephemeral-storage                                       0.0          0%      0.0      0%      581.5Gi  581.5Gi
  ├─ kind-control-plane                                   0.0          0%      0.0      0%      193.8Gi  193.8Gi
  ├─ kind-worker                                          0.0          0%      0.0      0%      193.8Gi  193.8Gi
  └─ kind-worker2                                         0.0          0%      0.0      0%      193.8Gi  193.8Gi
  memory                                              290.0Mi          1%  490.0Mi      1%       46.9Gi   46.4Gi
  ├─ kind-control-plane                               190.0Mi          1%  390.0Mi      2%       15.6Gi   15.3Gi
  │  ├─ coredns-6955765f44-l4z47                       70.0Mi              170.0Mi
  │  ├─ coredns-6955765f44-zb5xx                       70.0Mi              170.0Mi
  │  └─ kindnet-czpsv                                  50.0Mi               50.0Mi
  ├─ kind-worker                                       50.0Mi          0%   50.0Mi      0%       15.6Gi   15.6Gi
  │  └─ kindnet-sbqxd                                  50.0Mi               50.0Mi
  └─ kind-worker2                                      50.0Mi          0%   50.0Mi      0%       15.6Gi   15.6Gi
     └─ kindnet-sw5mq                                  50.0Mi               50.0Mi
  pods                                                    0.0          0%      0.0      0%        330.0    330.0
  ├─ kind-control-plane                                   0.0          0%      0.0      0%        110.0    110.0
  ├─ kind-worker                                          0.0          0%      0.0      0%        110.0    110.0
  └─ kind-worker2                                         0.0          0%      0.0      0%        110.0    110.0
```

這個工具我個人認為還滿好用的，畢竟可以幫你顯示出當前系統上運算資源所使用的 CPU/Memory 等使用量，這些使用量可以用來幫助開發者判斷要如何設定相關的資源限制。



# change-ns

這套工具相對簡單，就是幫你切換預設的 namespace，減少每次輸入指令的時候都要一直透過 `-n|--namespace` 來指定特定的 namespace。

```bash
$ kubectl krew install change-ns
Updated the local copy of plugin index.
Installing plugin: change-ns
Installed plugin: change-ns
\
 | Use this plugin:
 |      kubectl change-ns
 | Documentation:
 |      https://github.com/juanvallejo/kubectl-ns
/
WARNING: You installed plugin "change-ns" from the krew-index plugin repository.
   These plugins are not audited for security by the Krew maintainers.
   Run them at your own risk.
$ kubectl change-ns kube-system
namespace changed to "kube-system"
$ kubectl get pods
NAME                                         READY   STATUS    RESTARTS   AGE
coredns-6955765f44-l4z47                     1/1     Running   0          2d13h
coredns-6955765f44-zb5xx                     1/1     Running   0          2d13h
etcd-kind-control-plane                      1/1     Running   0          2d13h
kindnet-czpsv                                1/1     Running   0          2d13h
kindnet-sbqxd                                1/1     Running   0          2d13h
kindnet-sw5mq                                1/1     Running   0          2d13h
kube-apiserver-kind-control-plane            1/1     Running   0          2d13h
kube-controller-manager-kind-control-plane   1/1     Running   0          2d13h
kube-proxy-4b5rl                             1/1     Running   0          2d13h
kube-proxy-nrspx                             1/1     Running   0          2d13h
kube-proxy-skfm5                             1/1     Running   0          2d13h
kube-scheduler-kind-control-plane            1/1     Running   0          2d13h
```



類似的工具還有`ctx` ，可以幫切換不同的 `kubeconfig context`，讓你更方便的於多個 Kubernetes Cluster 中切換



# Status

這個工具算是幫你把 description 的資訊再次整理，舉例來說我們準備了一個 `pull image` 會失敗的案例，這時候我們用 `status` 這個指令來試試看

```bash
$ kubectl krew install status
Updated the local copy of plugin index.
Installing plugin: status
Installed plugin: status
\
 | Use this plugin:
 |      kubectl status
 | Documentation:
 |      https://github.com/bergerx/kubectl-status
/
WARNING: You installed plugin "status" from the krew-index plugin repository.
   These plugins are not audited for security by the Krew maintainers.
   Run them at your own risk.
```



安裝完畢後我們針對一個失敗的 pod 來使用 `kubectl status pod xxxx`

```bash
$ kubectl status pod pull-fail

Pod/pull-fail -n default, created 2m ago Pending Burstable
  PodScheduled -> Initialized -> Not ContainersReady -> Not Ready
    Ready ContainersNotReady, containers with unready status: [getting-started] for 2m
    ContainersReady ContainersNotReady, containers with unready status: [getting-started] for 2m
  Standalone POD.
  Containers:
    getting-started (hwchiu/netutils-qq) Waiting ErrImagePull: rpc error: code = Unknown desc = failed to pull and unpack image "docker.io/hwchiu/netutils-qq:latest": failed to resolve reference "docker.io/hwchiu/netutils-qq:latest": pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
  Events:
    Scheduled 2m ago from default-scheduler: Successfully assigned default/pull-fail to kind-worker
    Pulling 28s ago (x4 over 1m) from kubelet,kind-worker: Pulling image "hwchiu/netutils-qq"
    Failed 28s ago (x4 over 1m) from kubelet,kind-worker: Failed to pull image "hwchiu/netutils-qq": rpc error: code = Unknown desc = failed to pull and unpack image "docker.io/hwchiu/netutils-qq:latest": failed to resolve reference "docker.io/hwchiu/netutils-qq:latest": pull access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed
    Failed 28s ago (x4 over 1m) from kubelet,kind-worker: Error: ErrImagePull
    BackOff 13s ago (x6 over 1m) from kubelet,kind-worker: Back-off pulling image "hwchiu/netutils-qq"
    Failed 13s ago (x6 over 1m) from kubelet,kind-worker: Error: ImagePullBackOff
```



上面可以看到一些資訊，譬如說

1. PodScheduled -> Initialized -> Not ContainersReady -> Not Ready
   Pod 失敗是因為卡在 `ContainersReady` 這個狀態會失敗，導致最後整個 Pod 沒有成功
2. Standalone POD
   這個 Pod 本身沒有任何的 StatefulSet/ReplicaSet，而是獨立的 Pod
3. Containers: 底下就是一些詳細訊息，譬如為什麼會失敗
4. Events: 這個 Pod 的一些事件資訊



除了 Pod 之外， Status 也可以用來看其他的資源，有興趣可以玩看看



# access-matrix

接下來這個工具主要是用來`列出當前使用者對於系統上的全部 Resource的權限資訊`，主要是該使用者對於特定資源上的不同動詞 (Get/Update/List/Delete) 等是否可以執行

```bash
$ kubectl krew install access-matrix
Updated the local copy of plugin index.
Installing plugin: access-matrix
Installed plugin: access-matrix
\
 | Use this plugin:
 |      kubectl access-matrix
 | Documentation:
 |      https://github.com/corneliusweig/rakkess
 | Caveats:
 | \
 |  | Usage:
 |  |   kubectl access-matrix
 |  |   kubectl access-matrix for pods
 | /
/
WARNING: You installed plugin "access-matrix" from the krew-index plugin repository.
   These plugins are not audited for security by the Krew maintainers.
   Run them at your own risk.
```



此外也可以透過 `--sa` 等指令來切換不同的 `service account`，所以可以看到下列的範例，用不同的使用者去看權限，我預設的使用者有幾乎無敵的權限，什麼都可以執行。如果是系統上 `kube-system:namespace-controller` 則只能 LIST/DELETE。

除了這四個動詞之外，其實還有很多動詞可以用，只是預設情況下只會列出這四個

```bash
$ kubectl access-matrix --sa kube-system:namespace-controller
NAME                                                          LIST  CREATE  UPDATE  DELETE
apiservices.apiregistration.k8s.io                            ✔     ✖       ✖       ✔
bindings                                                            ✖
certificatesigningrequests.certificates.k8s.io                ✔     ✖       ✖       ✔
clusterrolebindings.rbac.authorization.k8s.io                 ✔     ✖       ✖       ✔
clusterroles.rbac.authorization.k8s.io                        ✔     ✖       ✖       ✔
componentstatuses                                             ✔
configmaps                                                    ✔     ✖       ✖       ✔
controllerrevisions.apps                                      ✔     ✖       ✖       ✔
cronjobs.batch                                                ✔     ✖       ✖       ✔
csidrivers.storage.k8s.io                                     ✔     ✖       ✖       ✔
.....
$ kubectl access-matrix
NAME                                                          LIST  CREATE  UPDATE  DELETE
apiservices.apiregistration.k8s.io                            ✔     ✔       ✔       ✔
bindings                                                            ✔
certificatesigningrequests.certificates.k8s.io                ✔     ✔       ✔       ✔
clusterrolebindings.rbac.authorization.k8s.io                 ✔     ✔       ✔       ✔
clusterroles.rbac.authorization.k8s.io                        ✔     ✔       ✔       ✔
componentstatuses                                             ✔
configmaps                                                    ✔     ✔       ✔       ✔
controllerrevisions.apps                                      ✔     ✔       ✔       ✔
cronjobs.batch                                                ✔     ✔       ✔       ✔
csidrivers.storage.k8s.io                                     ✔     ✔       ✔       ✔
```



#  starboard

最後來看一個跟安全性有關的 plugin

> Starboard integrates security tools into the Kubernetes environment, so that users can find and view the risks that relate to different resources in a Kubernetes-native way. Starboard provides [custom security resources definitions](https://github.com/aquasecurity/starboard#custom-security-resources-definitions) and a [Go module](https://github.com/aquasecurity/starboard/blob/master/pkg) to work with a range of existing security tools, as well as a `kubectl`-compatible command-line tool and an Octant plug-in that make security reports available through familiar Kubernetes tools.



接下來示範怎麼用(假設已經安裝完畢)

```bash
$ kubectl starboard init
$ kubectl create deployment nginx --image nginx:1.16
```

先透過 `starboard` 去初始化相關資源，接者我們部署一個 `nginx:1.16` 的容器到系統中



```bash
$ kubectl starboard find vulnerabilities deployment/nginx 
$ kubectl starboard get vulnerabilities deployment/nginx
....
    summary:
      criticalCount: 0
      highCount: 4
      lowCount: 93
      mediumCount: 34
      noneCount: 0
      unknownCount: 0
    vulnerabilities:
    - description: Missing input validation in the ar/tar implementations of APT before
        version 2.1.2 could result in denial of service when processing specially
        crafted deb files.
      fixedVersion: 1.8.2.1
      installedVersion: 1.8.2
      layerID: ""
      links:
      - https://bugs.launchpad.net/bugs/1878177
      - https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2020-3810
      - https://github.com/Debian/apt/issues/111
      - https://github.com/julian-klode/apt/commit/de4efadc3c92e26d37272fd310be148ec61dcf36
      - https://lists.debian.org/debian-security-announce/2020/msg00089.html
      - https://lists.fedoraproject.org/archives/list/package-announce@lists.fedoraproject.org/message/U4PEH357MZM2SUGKETMEHMSGQS652QHH/
      - https://salsa.debian.org/apt-team/apt/-/commit/dceb1e49e4b8e4dadaf056be34088b415939cda6
      - https://salsa.debian.org/jak/apt/-/commit/dceb1e49e4b8e4dadaf056be34088b415939cda6
      - https://tracker.debian.org/news/1144109/accepted-apt-212-source-into-unstable/
      - https://usn.ubuntu.com/4359-1/
      - https://usn.ubuntu.com/4359-2/
      - https://usn.ubuntu.com/usn/usn-4359-1
      - https://usn.ubuntu.com/usn/usn-4359-2
      resource: apt
      severity: MEDIUM
      title: ""
      vulnerabilityID: CVE-2020-3810
...
```



可以看到上面有很多訊息，列出當前 image 上有哪些潛在的 CVE，如果覺得這樣看起來實在不討喜，可以使用 [starboard-octant-plugin](https://github.com/aquasecurity/starboard-octant-plugin) 這個整合專案，把上述的報告用 UI 的方式視覺話呈現出來，譬如說下圖(下圖節錄自 [starboard-octant-plugin](https://github.com/aquasecurity/starboard-octant-plugin) 官方 Repo)

![img](https://github.com/aquasecurity/starboard-octant-plugin/raw/master/docs/images/deployment_vulnerabilities.png)

到這邊為止，我們介紹了一些有趣的 Kubectl plugin，當然這些 plugin 本身也都是一個獨立的執行檔案，所以其實就算不透過 kubectl 來執行也是沒問題的，所有個工具都可以獨立使用。透過 krew 只是我們可以更方便的搜尋到有哪些 plugin 可以用，實務上要怎麼執行都是個人喜歡，方便，操作順暢即可。



Krew 上面的工具非常多，使用上可以都可以嘗試看看，也因為這樣才有辦法找到真的對自己日常工作有幫助的好幫手
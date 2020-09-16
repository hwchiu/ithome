Day26  - kubelet Plugin 介紹
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



最後幾天，我們就來介紹一些操作 Kubernetes 上可能會使用到的工具，這些工具對於開發者，對於叢集管理者都可能會有一些便利的好處，畢竟在操作上如果可以用更快的時間做出需要的事情，找出需要的事情，其實整體工作效率會更高



今天要來介紹的 kubectl plugin 的生態，有興趣瞭解更多的可以到 [Extend kubectl with plugins](https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/) 去瞭解更多



# 架構

Kubectl plugins 的生態非常簡單，基本上就是用一堆執行檔組合再一起即可，只要將該執行檔放到一個你當前系統上 `$PATH`

可以執行到的位置，並且將該檔案命名為 `kubectl-` 即可



## 示範

接下來用一個快速範例來示範，準備一個 kubectl-ithome 的檔案

```bash
$ cat kubectl-ithome
#!/bin/bash

# optional argument handling
if [[ "$1" == "version" ]]
then
    echo "1.0.0"
    exit 0
fi

# optional argument handling
if [[ "$1" == "post" ]]
then
    echo "day 26"
    exit 0
fi

echo "I am a plugin named kubectl-ithome"
```

接下來將該檔案設定為可執行並且放到一個 `$PATH` 指向的位置

```bash
$ chmod 755 kubectl-ithome
$ sudo mv kubectl-ithome /usr/local/bin/
$ kubectl ithome version
1.0.0
$ kubectl ithome post
day 26
```

可以看到使用上非常簡單，就是準備一個執行檔案並且設定相關的權限與位置就好



## 探索

因為其架構非常簡單，所以只要執行 `kubectl plugin list`，預設情況下會因為沒有安裝任何的東西，執行結果就不會找到任何東西

```bash
$ kubectl plugin list
Unable read directory "/home/ubuntu/go/bin" from your PATH: open /home/ubuntu/go/bin: no such file or directory. Skipping...
error: unable to find any kubectl plugins in your PATH
```

但是如果每次要安裝這些 plugin 都要自己想辦法去找這些執行檔，並且放到系統環境下其實滿累的。

所以這時候我們就可以使用 `krew` 這套系統來幫忙管理整個 kubectl plugin, 等等就來試試看相關功能



## 限制

要注意的是因為 kubectl 本身已經有很多子指令可以使用了，因此這些 Plugin 不能覆蓋這些子指令，譬如不能創造一個 `kubectl-get` 來取代 `kubectl get` 之類的，不過對於非開發者來說，這些限制可以忽略，專注於如何找尋現存的 plugin 並且使用到日常工作中即可



# Krew 

Krew 的官方說明如下

> Krew is the package manager for kubectl plugins.

> Krew is a tool that makes it easy to use [kubectl plugins](https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/). Krew helps you discover plugins, install and manage them on your machine. It is similar to tools like apt, dnf or [brew](http://brew.sh/). Today, over [70 kubectl plugins](http://sigs.k8s.io/krew-index/plugins.md) are available on Krew.

根據說明目前已經超過 70 個以上的 plugin, 因此我們接下來就從中挑幾個有趣的來玩看看



## 安裝

首先我們要先安裝 Krew, 基本上 Krew 也會變成一個 kubectl plugin ，之後會透過 `kubectl krew` 來管理

```bash
$ (
  set -x; cd "$(mktemp -d)" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.tar.gz" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" &&
  "$KREW" install krew
)
$ export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
```



```bash
$ kubectl krew
krew is the kubectl plugin manager.
You can invoke krew through kubectl: "kubectl krew [command]..."

Usage:
  kubectl krew [command]

Available Commands:
  help        Help about any command
  index       Manage custom plugin indexes
  info        Show information about an available plugin
  install     Install kubectl plugins
  list        List installed kubectl plugins
  search      Discover kubectl plugins
  uninstall   Uninstall plugins
  update      Update the local copy of the plugin index
  upgrade     Upgrade installed plugins to newer versions
  version     Show krew version and diagnostics

Flags:
  -h, --help      help for krew
  -v, --v Level   number for the log level verbosity

Use "kubectl krew [command] --help" for more information about a command.
```

Krew 底下滿多指令的，我們等等會透過 `search` 來探索全部 plugins 並且透過 `install` 來安裝



## 使用

搜尋上非常簡單，透過 `kubectl krew search` 去列出目前

```bash
$ kubectl krew search
NAME                            DESCRIPTION                                         INSTALLED
access-matrix                   Show an RBAC access matrix for server resources     no
advise-psp                      Suggests PodSecurityPolicies for cluster.           no
apparmor-manager                Manage AppArmor profiles for cluster.               no
auth-proxy                      Authentication proxy to a pod or service            no
bd-xray                         Run Black Duck Image Scans                          no
bulk-action                     Do bulk actions on Kubernetes resources.            no
ca-cert                         Print the PEM CA certificate of the current clu...  no
capture                         Triggers a Sysdig capture to troubleshoot the r...  no
cert-manager                    Manage cert-manager resources inside your cluster   no
change-ns                       View or change the current namespace via kubectl.   no
cilium                          Easily interact with Cilium agents.                 no
cluster-group                   Exec commands across a group of contexts.           no
config-cleanup                  Automatically clean up your kubeconfig              no
cssh                            SSH into Kubernetes nodes                           no
ctx                             Switch between contexts in your kubeconfig          no
custom-cols                     A "kubectl get" replacement with customizable c...  no
datadog                         Manage the Datadog Operator                         no
debug                           Attach ephemeral debug container to running pod     no
debug-shell                     Create pod with interactive kube-shell.             no
deprecations                    Checks for deprecated objects in a cluster          no
df-pv                           Show disk usage (like unix df) for persistent v...  no
doctor                          Scans your cluster and reports anomalies.           no
duck                            List custom resources with ducktype support         no
edit-status                     Edit /status subresources of CRs                    no
eksporter                       Export resources and removes a pre-defined set ...  no
emit-event                      Emit Kubernetes Events for the requested object     no
evict-pod                       Evicts the given pod                                no
example                         Prints out example manifest YAMLs                   no
exec-as                         Like kubectl exec, but offers a `user` flag to ...  no
exec-cronjob                    Run a CronJob immediately as Job                    no
fields                          Grep resources hierarchy by field name              no
flame                           Generate CPU flame graphs from pods                 no
fleet                           Shows config and resources of a fleet of clusters   no
fuzzy                           Fuzzy and partial string search for kubectl         no
gadget                          Gadgets for debugging and introspecting apps        no
get-all                         Like `kubectl get all` but _really_ everything      no
gke-credentials                 Fetch credentials for GKE clusters                  no
gopass                          Imports secrets from gopass                         no
graph                           Visualize Kubernetes resources and relationships.   no
grep                            Filter Kubernetes resources by matching their n...  no
gs                              Handle custom resources with Giant Swarm            no
iexec                           Interactive selection tool for `kubectl exec`       no
images                          Show container images used in the cluster.          no
ingress-nginx                   Interact with ingress-nginx                         no
ipick                           A kubectl wrapper for interactive resource sele...  no
konfig                          Merge, split or import kubeconfig files             no
krew                            Package manager for kubectl plugins.                yes
kubesec-scan                    Scan Kubernetes resources with kubesec.io.          no
kudo                            Declaratively build, install, and run operators...  no
kuttl                           Declaratively run and test operators                no
kyverno                         Kyverno is a policy engine for kubernetes           no
match-name                      Match names of pods and other API objects           no
modify-secret                   modify secret with implicit base64 translations     no
mtail                           Tail logs from multiple pods matching label sel...  no
neat                            Remove clutter from Kubernetes manifests to mak...  no
net-forward                     Proxy to arbitrary TCP services on a cluster ne...  no
node-admin                      List nodes and run privileged pod with chroot       no
node-restart                    Restart cluster nodes sequentially and gracefully   no
node-shell                      Spawn a root shell on a node via kubectl            no
np-viewer                       Network Policies rules viewer                       no
ns                              Switch between Kubernetes namespaces                no
oidc-login                      Log in to the OpenID Connect provider               no
open-svc                        Open the Kubernetes URL(s) for the specified se...  no
operator                        Manage operators with Operator Lifecycle Manager    no
oulogin                         Login to a cluster via OpenUnison                   no
outdated                        Finds outdated container images running in a cl...  no
passman                         Store kubeconfig credentials in keychains or pa...  no
pod-dive                        Shows a pod's workload tree and info inside a node  no
pod-logs                        Display a list of pods to get logs from             no
pod-shell                       Display a list of pods to execute a shell in        no
podevents                       Show events for pods                                no
popeye                          Scans your clusters for potential resource issues   no
preflight                       Executes application preflight tests in a cluster   no
profefe                         Gather and manage pprof profiles from running pods  no
prompt                          Prompts for user confirmation when executing co...  no
prune-unused                    Prune unused resources                              no
psp-util                        Manage Pod Security Policy(PSP) and the related...  no
rbac-lookup                     Reverse lookup for RBAC                             no
rbac-view                       A tool to visualize your RBAC permissions.          no
resource-capacity               Provides an overview of resource requests, limi...  no
resource-snapshot               Prints a snapshot of nodes, pods and HPAs resou...  no
restart                         Restarts a pod with the given name                  no
rm-standalone-pods              Remove all pods without owner references            no
rolesum                         Summarize RBAC roles for subjects                   no
roll                            Rolling restart of all persistent pods in a nam...  no
schemahero                      Declarative database schema migrations via YAML     no
score                           Kubernetes static code analysis.                    no
service-tree                    Status for ingresses, services, and their backends  no
sick-pods                       Find and debug Pods that are "Not Ready"            no
snap                            Delete half of the pods in a namespace or cluster   no
sniff                           Start a remote packet capture on pods using tcp...  no
sort-manifests                  Sort manifest files in a proper order by Kind       no
split-yaml                      Split YAML output into one file per resource.       no
spy                             pod debugging tool for kubernetes clusters with...  no
sql                             Query the cluster via pseudo-SQL                    no
ssh-jump                        A kubectl plugin to SSH into Kubernetes nodes u...  no
sshd                            Run SSH server in a Pod                             no
ssm-secret                      Import/export secrets from/to AWS SSM param store   no
starboard                       Toolkit for finding risks in kubernetes resources   no
status                          Show status details of a given resource.            no
sudo                            Run Kubernetes commands impersonated as group s...  no
support-bundle                  Creates support bundles for off-cluster analysis    no
tail                            Stream logs from multiple pods and containers u...  no
tap                             Interactively proxy Kubernetes Services with ease   no
tmux-exec                       An exec multiplexer using Tmux                      no
topology                        Explore region topology for nodes or pods           no
trace                           bpftrace programs in a cluster                      no
tree                            Show a tree of object hierarchies through owner...  no
unused-volumes                  List unused PVCs                                    no
view-allocations                List allocations per resources, nodes, pods.        no
view-secret                     Decode Kubernetes secrets                           no
view-serviceaccount-kubeconfig  Show a kubeconfig setting to access the apiserv...  no
view-utilization                Shows cluster cpu and memory utilization            no
virt                            Control KubeVirt virtual machines using virtctl     no
warp                            Sync and execute local files in Pod                 no
who-can                         Shows who has RBAC permissions to access Kubern...  no
whoami                          Show the subject that's currently authenticated...  no
```



如果覺得上面資訊太多，也可以傳遞第二個參數來過濾，譬如

```bash
$ kubectl krew search pod
NAME                DESCRIPTION                                         INSTALLED
evict-pod           Evicts the given pod                                no
pod-dive            Shows a pod's workload tree and info inside a node  no
pod-logs            Display a list of pods to get logs from             no
pod-shell           Display a list of pods to execute a shell in        no
podevents           Show events for pods                                no
rm-standalone-pods  Remove all pods without owner references            no
sick-pods           Find and debug Pods that are "Not Ready"            no
support-bundle      Creates support bundles for off-cluster analysis    no
```



下一篇我們就來從中挑選一些有趣的 plugin 玩看看




Day 18 - GitOps - ArgoCD 介紹 
===============================

本文同步刊登於筆者[部落格](https://hwchiu.com)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者
歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)





前篇文章介紹了 GitOps 的概念以及 GitOps & Kubernetes 的一些參考實作，本篇文章則是會透過玩耍 ArgoCD 這套 GitOps 的開源軟體，來跟大家展示一下 GitOps 實際上的運作流程以及操作起來的樣子。可以比較看看跟過往我們熟悉的 Push-Mode 這種由 CD pipeloine 去觸發的 CD 流程有什麼不同



# 介紹

[ArgoCD](https://argoproj.github.io/argo-cd/) 的官網是這樣介紹自己的

> Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes.

簡單明確，說明自己就是為了 GItOps & Kubernetes 而生的工具



## 應用程式

之前有提到如何包裝與管理 Kubernetes 的應用程式，實際上有非常多種用法
ArgoCD 支援以下類型

1. Helm
2. kustomize
3. jsoonet
4. ksonnet
5. 原生 Yaml
6. 客製化的設定檔案 (自行實現相關 Plugin)



支援度非常強大，基本上 Kubernetes 會用到的格式他都支援



## 架構

下圖節錄自[ArgoCD](https://argoproj.github.io/argo-cd/) 的架構介紹，我們用這張圖來大概看一下 ArgoCD 的運作模式



![Argo CD Architecture](https://argoproj.github.io/argo-cd/assets/argocd_architecture.png)

1. ArgoCD 的 API Server 支援多種控制，譬如使用 UI 操作，使用 CLI 操作，甚至可以透過 gRPC/REST 等方式控制

2. 當開發者完成 Git 程式碼的合併後， Git 可以觸發 webhook 的事件通知 ArgoCD Git 有新的版本，可以來準備更新

   1. 除了 web hook 外， ArgoCD 也支持定期詢問與手動的方式來更新

3. ArgoCD 可以用來管理多套 Kubernetes 叢集，對於測試環境來說，是可以用一套 ArgoCD 的服務，控管多套叢集，但是如果有生產環境的時候，基於權限也是可以考慮分開不同的 ArgoCD，這部分就沒有唯一解答。

4. ArgoCD 也提供相對應的時間 Hook, 譬如當同步完成後就可以觸發不同的事件，譬如通知 Slack 等

   

接下來我們來看一下要如何使用 ArgoCD

# 安裝

接下來的操作中我們會使用 ArgoCD 的 UI 與 CLI 兩個介面來操作，因此安裝過程就會包含 ArgoCD 本身以及相關的工具

首先安裝 ArgoCD 的服務，透過 `kubectl` 給安裝到叢集中即可，非常簡單

```bash
$ kubectl create namespace argocd
namespace/argocd created
$ kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io created
serviceaccount/argocd-application-controller created
serviceaccount/argocd-dex-server created
serviceaccount/argocd-server created
role.rbac.authorization.k8s.io/argocd-application-controller created
role.rbac.authorization.k8s.io/argocd-dex-server created
role.rbac.authorization.k8s.io/argocd-server created
clusterrole.rbac.authorization.k8s.io/argocd-application-controller created
clusterrole.rbac.authorization.k8s.io/argocd-server created
rolebinding.rbac.authorization.k8s.io/argocd-application-controller created
rolebinding.rbac.authorization.k8s.io/argocd-dex-server created
rolebinding.rbac.authorization.k8s.io/argocd-server created
clusterrolebinding.rbac.authorization.k8s.io/argocd-application-controller created
clusterrolebinding.rbac.authorization.k8s.io/argocd-server created
configmap/argocd-cm created
configmap/argocd-gpg-keys-cm created
configmap/argocd-rbac-cm created
configmap/argocd-ssh-known-hosts-cm created
configmap/argocd-tls-certs-cm created
secret/argocd-secret created
service/argocd-dex-server created
service/argocd-metrics created
service/argocd-redis created
service/argocd-repo-server created
service/argocd-server-metrics created
service/argocd-server created
deployment.apps/argocd-application-controller created
deployment.apps/argocd-dex-server created
deployment.apps/argocd-redis created
deployment.apps/argocd-repo-server created
deployment.apps/argocd-server created
```



可以看到其實 ArgoCD 安裝的東西還不少，前面一大部分都是針對使用者帳號進行控制，因為 ArgoCD 本身要可以對 Kubernetes 進行操控，所以會幫他創立一個 ServiceAccount 並且配上相對應的權限。

後面則是相關的服務，譬如用來管理帳號登入機制的 OIDC 伺服器 (Dex)，跟 Git Repo 連動的 repo-server, 以及最重要的邏輯處理中心 Application-controller。

預設情況下， ArgoCD 會將服務裝成 ClusterIP，這意味者不方便存取，除非你有 Ingress Controller 等，為了方便 Demo 我們可以

1. 將其修改成 NodePort
2. 透過 kubectl port-forward 的方式來存取

如果是基於測試的環境，那這兩種方式我覺得都沒有問題，但是如果是正式環境，最好還是有一個 Ingress Controller 在前面幫忙管理。

```bash
$ kubectl port-forward svc/argocd-server -n argocd 8080:443
```



打開瀏覽器後會出現下方畫面

![](https://i.imgur.com/8LnVJnP.png)

登入帳號是 admin, 預設的登入密碼可以透過下列指令獲得

```bash
$ kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2
```



接下來我們來安裝 ArgoCD 的 CLI

```bash
$ wget https://github.com/argoproj/argo-cd/releases/download/v1.7.4/argocd-linux-amd64
$ sudo chmod 755
$ ./argocd-linux-amd64
argocd controls a Argo CD server

Usage:
  argocd [flags]
  argocd [command]

Available Commands:
  account     Manage account settings
  app         Manage applications
  cert        Manage repository certificates and SSH known hosts entries
  cluster     Manage cluster credentials
  completion  output shell completion code for the specified shell (bash or zsh)
  context     Switch between contexts
  gpg         Manage GPG keys used for signature verification
  help        Help about any command
  login       Log in to Argo CD
  logout      Log out from Argo CD
  proj        Manage projects
  relogin     Refresh an expired authenticate token
  repo        Manage repository connection parameters
  repocreds   Manage repository connection parameters
  version     Print version information
Flags:
      --auth-token string               Authentication token
      --client-crt string               Client certificate file
      --client-crt-key string           Client certificate key file
      --config string                   Path to Argo CD config (default "/home/ubuntu/.argocd/config")
      --grpc-web                        Enables gRPC-web protocol. Useful if Argo CD server is behind proxy which does not support HTTP2.
      --grpc-web-root-path string       Enables gRPC-web protocol. Useful if Argo CD server is behind proxy which does not support HTTP2. Set web root.
  -H, --header strings                  Sets additional header to all requests made by Argo CD CLI. (Can be repeated multiple times to add multiple headers, also supports comma separated headers)
  -h, --help                            help for argocd
      --insecure                        Skip server certificate and domain verification
      --logformat string                Set the logging format. One of: text|json (default "text")
      --loglevel string                 Set the logging level. One of: debug|info|warn|error (default "info")
      --plaintext                       Disable TLS
      --port-forward                    Connect to a random argocd-server port using port forwarding
      --port-forward-namespace string   Namespace name which should be used for port forwarding
      --server string                   Argo CD server address
      --server-crt string               Server certificate file

Use "argocd [command] --help" for more information about a command.
```



接下來我們使用一樣的帳號密碼來登入

```bash
$ ./argocd-linux-amd64 login localhost:8080
WARNING: server certificate had error: x509: certificate signed by unknown authority. Proceed insecurely (y/n)? y
Username: admin
Password:
'admin' logged in successfully
Context 'localhost:8080' updated
```



這邊準備就緒後，我們就可以開始來使用囉

# 使用

如同前述提到，GitOps 本身的一個重點是透過 Git 來管理所有部署的檔案，因此這邊我們會使用 ArgoCD 所準備的一個示範 Git Repo，[argocd-example-apps](https://github.com/argoproj/argocd-example-apps.git)

可以看到該 Repo 內有滿滿的使用不同方式管理 Kubernetes 應用的方法

![](https://i.imgur.com/2AnE3sb.png)



接下來我們就要告訴 ArgoCD，我想要部署一個新的應用程式，這個應用程式的來源是哪個 Git 以及部署上要注意的一些小設定

這部分可以透過 UI 操作，也可以使用 CLI 來操作

![](https://i.imgur.com/7SYynMF.png)



我們來嘗試使用 CLI 操作看看

```bash
$ ./argocd-linux-amd64 app create guestbook --repo https://github.com/argoproj/argocd-example-apps.git --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default
application 'guestbook' created
```

上述的指令基本上跟 UI 描述的內容差不多，有些沒有填寫的就是預設值，這種情況下我們會創立一個新的 app，目標是上述提到的 GitRepo，並且詳細的安裝檔案請使用 `guestbook`這個資料夾內的檔案

![](https://i.imgur.com/Pf6A8eI.png)

該資料夾內的資源非常簡單，就是一個 Deployment 配上一個 Service。



這時候就可以回到 UI 去看，就會看到一個全新的 Application 已經產生了

![](https://i.imgur.com/dVpmXa1.png) 但是可以觀察到畫面中相關的應用程式其實還沒有正式被部署出來，主要是我們只是告訴 `ArgoCD` 我們要建立一個新的 Application，但是還沒有要同步。

同時透過指令的方式(UI也可以)觀察到，我們的 Application 目前是沒有開啟 `Auto Sync` (Sync Policy: None)

```bash
$ ./argocd-linux-amd64 app get guestbook
Name:               guestbook
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          default
URL:                https://localhost:8080/applications/guestbook
Repo:               https://github.com/argoproj/argocd-example-apps.git
Target:
Path:               guestbook
SyncWindow:         Sync Allowed
Sync Policy:        <none>
Sync Status:        OutOfSync from  (6bed858)
Health Status:      Missing

GROUP  KIND        NAMESPACE  NAME          STATUS     HEALTH   HOOK  MESSAGE
       Service     default    guestbook-ui  OutOfSync  Missing
apps   Deployment  default    guestbook-ui  OutOfSync  Missing
```



接下來我們就透過 CLI 的方式(UI也可以) 要求 ArgoCD 幫我們同步 Guestbook 這個應用程式

```bash
$ ./argocd-linux-amd64 app sync guestbook
TIMESTAMP                  GROUP        KIND   NAMESPACE                  NAME    STATUS    HEALTH        HOOK  MESSAGE
2020-09-13T17:25:41+00:00            Service     default          guestbook-ui  OutOfSync  Missing
2020-09-13T17:25:41+00:00   apps  Deployment     default          guestbook-ui  OutOfSync  Missing
2020-09-13T17:25:41+00:00            Service     default          guestbook-ui    Synced  Healthy

Name:               guestbook
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          default
URL:                https://localhost:8080/applications/guestbook
Repo:               https://github.com/argoproj/argocd-example-apps.git
Target:
Path:               guestbook
SyncWindow:         Sync Allowed
Sync Policy:        <none>
Sync Status:        Synced to  (6bed858)
Health Status:      Progressing

Operation:          Sync
Sync Revision:      6bed858de32a0e876ec49dad1a2e3c5840d3fb07
Phase:              Succeeded
Start:              2020-09-13 17:25:41 +0000 UTC
Finished:           2020-09-13 17:25:41 +0000 UTC
Duration:           0s
Message:            successfully synced (all tasks run)

GROUP  KIND        NAMESPACE  NAME          STATUS  HEALTH       HOOK  MESSAGE
       Service     default    guestbook-ui  Synced  Healthy            service/guestbook-ui created
apps   Deployment  default    guestbook-ui  Synced  Progressing        deployment.apps/guestbook-ui created
```

這時候 UI 上的呈現就馬上改變

![](https://i.imgur.com/E8T4GfE.png) 相關的服務都被部署到 Kubernetes 內，透過 `kubectl` 也可以觀察到部署的結果。

ArgoCD 的 UI 也提供了一些簡單的操作，包含觀察 Log，觀察部署資源的狀態，其中有一個非常好的功能就是幫你比對狀態的差異

。舉例來說，如果今天有人透過指令的方式手動修改正在運行的資源狀態，我們將 deployment 的數量從 1個變成 4個

```bash
$ kubectl scale --replicas=4 deployment guestbook-ui
$ kubectl get pods
NAME                            READY   STATUS    RESTARTS   AGE
guestbook-ui-65b878495d-7fthl   1/1     Running   0          15s
guestbook-ui-65b878495d-hw9mt   1/1     Running   0          15s
guestbook-ui-65b878495d-trsmz   1/1     Running   0          15s
guestbook-ui-65b878495d-ts8cg   1/1     Running   0          4m39s
```

這時候可以從 UI 觀察到相關的應用程式被標上了 `OutOfSync` ，因為我們沒有開啟 `auto-sync` , 所以不會自動修復回來

![](https://i.imgur.com/AsBeFTC.png)



同時我們也可以透過 UI 的方式來瞭解到底當前`期望狀態`與`運行狀態` 的差異是什麼，我們的範例就是複本數量有差

![](https://i.imgur.com/r7d6Hcg.png)



到這邊我們簡單玩轉了一下 ArgoCD 的功能，實際上其內部有更多有趣且有效率的功能，如果對於 GitOps 有興趣的人都歡迎嘗試看看這個工具，如果還有時間也一定要試試看 Flux 另外一套不同的 GitOps 實現工具。
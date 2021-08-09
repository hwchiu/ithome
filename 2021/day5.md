Day 5 - 透過 RKE 架設第一套 Rancher(下)
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

# Rancher
前篇文章中已經透過 rke 的指令創建了一個基於三節點的 Kubernetes 叢集，接下來我們要透過 Helm 指令將 Rancher 給安裝到我們的 RKE 之中。

    再次提醒，針對 Rancher v2.5 與之後的版本請使用 Helm v3 來安裝，官方已經不再支援使用 Helm v2，如果你舊版的 Rancher 是使用 Helm v2 安裝然後想要將其升級到 Rancher v2.5 系列，則必須要先針對 Helm v2 -> Helm v3 進行轉移。
    轉移的方式可以參考 [Helm Plugin helm-2to3](https://github.com/helm/helm-2to3)，官方頁面有介紹詳細的用法，注意使用前先對所有 helm 的檔案進行備份以免不熟悉釀成不可恢復的情況

第一步先將 Rancher 官方的 Helm Repo 給加入到 Helm 清單中，官方提供三種不同的 Helm Repo 供使用者使用，包含
1. Latest: https://releases.rancher.com/server-charts/latest
2. Stable: https://releases.rancher.com/server-charts/stable
3. Alpha: https://releases.rancher.com/server-charts/alpha

根據不同的需求採用不同的版本，如果不是 Rancher 開發者的話，我認為 Alpha 沒有使用的需求，而 Latest 則是讓你有機會可以嘗試目前最新的版本，看看一些新功能或是一些舊有 Bug 是否有被移除。大部分情況下推薦穩穩地使用 stable 版本，遇到問題也比較有機會被解決。

本次安裝將採用 stable 作為來源版本
```bash
azureuser@rke-management:~$ helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
"rancher-stable" has been added to your repositories
azureuser@rke-management:~$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "rancher-stable" chart repository
Update Complete. ⎈Happy Helming!⎈
```

要安裝 Rancher 之前，有一個要處理的東西就是所謂的 SSL 憑證，[官網有提供不同選項的教學](https://rancher.com/docs/rancher/v2.5/en/installation/install-rancher-on-k8s/#3-choose-your-ssl-configuration)，主要可以分成
1. Rancher 自簽憑證
2. 自行準備憑證
3. 透過 Let's Encrypt 獲得的憑證

為了後續連線順利與方便，大部分都不會考慮使用自簽憑證而是會採用(2)/(3)兩個選項，而 Let's Encrypt 使用上還是相對簡單與輕鬆。
Kubernetes 生態系中針對 Let's Encrypt 來產生憑證的專案也不少，其中目前最熱門且最多人使用的非 cert-manager 莫屬。
同時 Rancher 官方也推薦使用 cert-manager 來使用，因此接下來就會使用 cert-manager 來輔助 Let's Encrypt 的處理。

    這邊要注意的是， Rancher 官網有推薦使用的 Cert-Manager 版本，該版本通常都會比 Cert-Manager 慢一些，因此使用上請以 Rancher 推薦的為主，不要自行的升級 cert-manager 到最新版本，以免 Rancher 沒有進行測試整合而發生一些不預期的錯誤，到時候除錯起來也麻煩。

如同前述環境指出，本範例會使用的域名是 rancher.hwchiu.com，該域名會事先指向 Load-Balancer，並且將 HTTP/HTTPS 的連線都導向後方的三台伺服器 server{1,2,3}。

接者透過 helm 安裝 cert-manager 到環境中，整個步驟跟 Rancher 非常雷同，準備相關的 repo 並且透過 helm 安裝。
```bash
azureuser@rke-management:~$ helm repo add jetstack https://charts.jetstack.io
"jetstack" has been added to your repositories
azureuser@rke-management:~$ helm repo update
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "jetstack" chart repository
...Successfully got an update from the "rancher-stable" chart repository
Update Complete. ⎈Happy Helming!⎈
azureuser@rke-management:~$
azureuser@rke-management:~$ kubectl create namespace cert-manager
azureuser@rke-management:~$ helm install   cert-manager jetstack/cert-manager   --namespace cert-manager   --version v1.0.4 --set installCRDs=true
```

確認 cert-manager 的 pod 都起來後，下一步就是繼續安裝 Rancher
```bash
azureuser@rke-management:~$ kubectl -n cert-manager get pods
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-6d87886d5c-fr5r4              1/1     Running   0          2m
cert-manager-cainjector-55db655cd8-2xfhf   1/1     Running   0          2m
cert-manager-webhook-6846f844ff-8l299      1/1     Running   0          2m
```

首先於 rke 叢集中創立個給 rancher 使用的 namespace，接者透過 helm 指令加上一些參數，這些參數主要是告訴 Rancher 我們的 Ingress 想要使用 letsEncrypt 來產生相關的 SSL 憑證，希望指向的域名是 rancher.hwchiu.com.

Rancher Helm Chart 就會針對這些參數去產生 cert-manager 需要的物件，如 Issuer，接者 cert-manager 就會接替後續行為來透過 ACME 產生一組合法的 TLS 憑證。

```bash
azureuser@rke-management:~$ kubectl create namespace cattle-system
azureuser@rke-management:~$ helm install rancher rancher-stable/rancher \
   --namespace cattle-system \
   --set hostname=rancher.hwchiu.com \
   --set replicas=3 \
   --set ingress.tls.source=letsEncrypt \
   --set letsEncrypt.email=hwchiu@hwchiu.com  \
   --version 2.5.9
NAME: rancher
LAST DEPLOYED: Sun Aug  8 20:14:03 2021
NAMESPACE: cattle-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
Rancher Server has been installed.

NOTE: Rancher may take several minutes to fully initialize. Please standby while Certificates are being issued and Ingress comes up.

Check out our docs at https://rancher.com/docs/rancher/v2.x/en/

Browse to https://rancher.hwchiu.com

Happy Containering!
```

註: 預設情況下 ACME 會採用 HTTP 挑戰的方式來驗證域名的擁有權，所以 load-balancer 記得要打開 80/443 的 port，將這些服務導向後端的 rke 叢集。Rancher 會使用 cert-manager + ingress 等相關資源自動處理憑證。

安裝完畢後，等待相關的服務被部署，確認 cattle-system 這個 namespace 下的服務都呈現 running 後，打開瀏覽器連上 https://rancher.hwchiu.com 就會看到下述的登入畫面

![](https://i.imgur.com/jddVbhD.png)

因為是第一次登入，系統會要求你更新密碼，同時可以選擇預設的瀏覽模式，由於我們想要使用 Rancher 去管理多個 Cluster，因此我們選擇左邊的格式。接者下一步再次確認要存取的 URL
![](https://i.imgur.com/e5DJbIu.png)

一切順利的話，就可以正式進入到 Rancher 的主要介面，這時候可以看到如下畫面
![](https://i.imgur.com/iIHlbp9.png)

Rancher Server 安裝完畢後，會把 **用來部署 Rancher 的 Kubernetes 叢集** 也加入到 Rancher 的管理視角中，並且使用 local 這個名稱來表示這個 cluster。
其中可以注意到的是該叢集的 Provider 是顯示為 Imported，這意味者這個 Kubernetes 叢集並不是由 Rancher 幫你創造，而是把一個已經運行的叢集給匯入到 Rancher 中。

網頁可以順利存取就意味我們第一個 Rancher 服務順利的架設起來，下一篇文章就會來仔細介紹對於一個 IT Team 的管理人員來說，從系統層面來看 Rancher 的設定有哪些，每個設定對團隊有什麼益處與好處。

最後來看一下 kubernetes 的相關服務，觀察一下一個基本的 Rancher 服務有哪些一些 Pod，未來要除錯時才有概念應該要去哪個 namespace 看哪些服務。
cattle-system 與 kube-system 內都有相關的服務，這邊要注意的是 kube-system 放的是我們最初安裝 RKE 時部署的資源，而 cattle-system 則是我們透過 helm 部署 Rancher 用的。所以基本上就是三個 rancher Pod 以及一個 webhook。
```
azureuser@rke-management:~$ kubectl get pods -A  | awk '{print $1"\t"$2}'
NAMESPACE       NAME
cattle-system   helm-operation-56h22
cattle-system   helm-operation-bjvmx
cattle-system   helm-operation-jtwf6
cattle-system   helm-operation-stv9x
cattle-system   helm-operation-ttxt4
cattle-system   helm-operation-xtznm
cattle-system   rancher-745c97799b-fqfsw
cattle-system   rancher-745c97799b-ls8wc
cattle-system   rancher-745c97799b-nhlz6
cattle-system   rancher-webhook-6cccfd96b5-grd4q
cert-manager    cert-manager-6d87886d5c-fr5r4
cert-manager    cert-manager-cainjector-55db655cd8-2xfhf
cert-manager    cert-manager-webhook-6846f844ff-8l299
fleet-system    fleet-agent-d59db746-hfbcq
fleet-system    fleet-controller-79554fcbf5-b7ckf
fleet-system    gitjob-568c57cfb9-ncpf5
ingress-nginx   default-http-backend-6977475d9b-hk2br
ingress-nginx   nginx-ingress-controller-8rtpv
ingress-nginx   nginx-ingress-controller-bv2lq
ingress-nginx   nginx-ingress-controller-mhfm6
kube-system     coredns-55b58f978-545dx
kube-system     coredns-55b58f978-qznqj
kube-system     coredns-autoscaler-76f8869cc9-hrlqq
kube-system     kube-flannel-44hvn
kube-system     kube-flannel-rhw7v
kube-system     kube-flannel-thrln
kube-system     metrics-server-55fdd84cd4-wqdkw
kube-system     rke-coredns-addon-deploy-job-pjdln
kube-system     rke-ingress-controller-deploy-job-m7sj2
kube-system     rke-metrics-addon-deploy-job-vtnfk
kube-system     rke-network-plugin-deploy-job-mv8nr
rancher-operator-system rancher-operator-595ddc6db9-tfgp8
```

一但使用 Helm 安裝 Rancher，未來的升級大部分都可以透過 Helm 這個指令繼續升級，升級的概念也非常簡單
1. 檢查當前版本的 release note，看看有什麼升級需要注意的事項
2. 更新 helm repo
3. 透過 helm 更新 rancher 這個 release，並且透過 --version 指名使用新的版本
4. 如果不想要每次都輸入前述一堆關於 SSL 的參數，可以把哪些參數變成一個 values.yaml 給傳入

詳細資訊建議參閱[官網文章](https://rancher.com/docs/rancher/v2.5/en/installation/install-rancher-on-k8s/upgrades/)來看看更詳細的升級策略。
如果不想要透過 rke 來維護 Rancher 的話，官網也有如何使用 [EKS](https://rancher.com/docs/rancher/v2.5/en/installation/install-rancher-on-k8s/amazon-eks/)/[AKS](https://rancher.com/docs/rancher/v2.5/en/installation/install-rancher-on-k8s/aks/)/[GKE](https://rancher.com/docs/rancher/v2.5/en/installation/install-rancher-on-k8s/gke/) 等公有雲 kubernetes 服務維護 Rancher 的相關教學。
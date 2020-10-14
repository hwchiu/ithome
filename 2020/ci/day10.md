Day 10 - CI 與 Kubernetes 的整合	
===============================

 

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)https://www.facebook.com/technologynoteniu)



上文中我們介紹了流水線系統的取捨，最後也決定要使用 GitHub Action 來使用，而接下來這篇文章則要介紹到底於該 Pipeline 系統中，如果我們的應用程式跟 Kubernetes 有整合，又希望 CI 系統可以幫忙測試，那系統該怎麼做?



這篇文章的前提就是，我們的應用程式本身需要 Kubernetes 來進行測試，至於要如何測試之後的文章會跟大家介紹，今天就專注於探討如果需要 Kubernetes 來測試，那我們的 Pipeline(GIthub Action) 系統要怎麼使用，以及有什麼相關點要注意



# 架構

首先，我們的應用程式需要一個 Kubernetes 來測試，這個 Kubernetes 則有兩種架構

1. 遠方架設一個固定的 Kubernetes 叢集供 CI 流水線測試

2. CI 架構中動態產生 Kubernetes 叢集來給你測試

   

這兩種架構都有各自的優缺點，現在來看一下彼此的差異



## 遠方固定一個 Kubernetes 叢集



架構概念如下，這情境下會有一個遠方的 Kubernetes 叢集，我們希望所有的 CI 測試都會使用這個遠方的 Kuberentes 叢集。

同時，我們系統中會有兩個 Job(假設多個開發者同時開發，各自的修改都會觸發 Pipeline 去執行)，每個  Job 中都會有很多個 Stage 要執

行，其中最重要的 `Testing` 我們會希望將應用程式部署到 Kubernetes 內去測試。

![](https://i.imgur.com/vQoYbYj.jpg)



這種狀況下就會有一些問題產生，譬如

1. 每次的測試是否有完整的清理資源，確保系統資源測試前後一致(我認為這是很重要的一點，任何的測試都不應該殘留資源於系統上，導致二次測試失敗)
2. 如果有多個工作同時要使用該 Kubernetes，是否會有衝突? 雖然可以透過 namespace 來區分，但是 Kubernetes 內有些資源是沒有 namespace 概念的，譬如 PV
3. 為了讓 Pipeline 有能力存取 Kubernetes，勢必要把 KUBECONFIG 等資訊存放到 pipeline 系統中，這對很多人來說是個安全性的隱憂，畢竟只要讓 KUBECONFIG 流出去，其他人就有能力操控你的 Kubernetes，如果權限弄得不好甚至可以搞壞整個 Kubernetes 叢集。

這種架構的好處就是， pipeline 系統內只要專注處理如何測試，這些 pipeline 到底是運行在 VM 或是 Container 上都沒有關係，只要能夠透過 kubectl/helm 等指令存取遠方 Kubernetes 叢集即可。

此外，如果測試過程中發現任何錯誤，我們都可以直接到遠方的 Kubernetes 去檢查失敗後的環境，來釐清到底為什麼會測試失敗

## CI 過程動態產生 Kubernetes 叢集



這種架構與上述不同，主要的差異是該 Kubernetes 叢集並非固定的，而是於 pipeline 過程中動態產生

![](https://i.imgur.com/ocPdkKH.jpg)

這種架構下來我們來看看到底有什麼樣的好壞

1. 由於 Kuberentes 都是獨立產生，每個 Job 都會有自己的 Kubernetes，所以彼此環境不衝突，甚至也不用擔心資源沒有清理乾淨，因為每次測試都是全新的環境
2. 也因為 Kubernetes 是獨立且動態的， KUBECONFIG 是動態產生，所以不用擔心會有額外的安全性問題



但是這種架構下也會有其他的缺點

1. 如果今天測試失敗時，可能這個 Kubernetes Cluster 就被移除了，導致沒有相關的環境可以用來釐清出錯的原因，變得更難除錯
2. 有些測試需要一些前置作業，這些前置作業會不會不好處理，譬如需要一個額外的檔案系統，額外的環境架設
3. pipeline 環境中要思考如何架設 Kuberentes，如果你的 pipeline 環境是基於 docker, 那就要思考如何在 docker上創建 kubernetes，這部分還要考慮使用的 pipeline 系統有沒有辦法做到這些事情。



這兩種架構各自有其優缺點，並沒有絕對的對錯，接下來我們會嘗試使用第二種架構，於 GitHub Action 中去創建一個 Kuberentres Clsuter，並且透過 Kubectl 指令來確認該 Kubernetes 叢集是運作正常的





## GitHub Action & Kubernetes

Github Action 中有非常豐富的 Plugin，其實可以查到有非常多的 action 再幫忙創建 Kubernetes 叢集，譬如

1.[action-k3s](https://github.com/marketplace/actions/actions-k3s)

2.[kind](https://github.com/marketplace/actions/kind-kubernetes-in-docker-action)

3.[setup-minikube](https://github.com/marketplace/actions/setup-minikube)



可以直接到 [Github Action Marketplace](https://github.com/marketplace) 去搜尋就可以看到滿多跟 Kubernetes 相關的範例。

由於之前的章節中我們介紹過用 KIND 與 K3D 來部署本地的 Kubernetes，那這次我們就嘗試使用 K3S 來部署看看 Kubernetes。



## 使用

這邊不會介紹太多關於 GitHub Action 的詳細用法，有興趣可以參考官網教學，其實非常簡單，每個 GitHub Repo 只要準備一個檔案就可以設定。

於專案中的下列資料夾中 `.github/workflows` ，準備一個名為 `main.yml` 的檔案，其內容如下

```yaml
# This is a basic workflow to help you get started with Actions

name: CI

# Controls when the action will run. Triggers the workflow on push or pull request
# events but only for the master branch
on:
  push:
    branches: [ master ]
  pull_request:
    branches: [ master ]

# A workflow run is made up of one or more jobs that can run sequentially or in parallel
jobs:
  # This workflow contains a single job called "build"
  build:
    # The type of runner that the job will run on
    runs-on: ubuntu-latest

    # Steps represent a sequence of tasks that will be executed as part of the job
    steps:
      # Checks-out your repository under $GITHUB_WORKSPACE, so your job can access it
      - uses: actions/checkout@v2
      - uses: debianmaster/actions-k3s@master
        id: k3s
        with:
          version: 'v1.18.2-k3s1'
      - run: |
          kubectl get nodes
          kubectl version
```

基本就是一個最基本的 GitHub Action 範例，只是最後我們改成使用 `k3s` 的 `GitHub Action` ，根據 [action-k3s](https://github.com/marketplace/actions/actions-k3s) 的描述，我們只要指定 `k3s` 的版本就可以獲得對應的 Kubernetes 版本，因此我們指定 `v.18.2-k3s1`。

最後我們補上兩個指令 `kubectl get nodes` 以及 `kubectl version` 來確保我們有在 GitHub Action 中獲得一個 Kubernetes 叢集並且可以操控。

這邊要注意的`GitHub Action`預設都是提供 `Virtual Machine` 供所有測試任務使用，所以我們可以相對簡單的於這個 VM 上面去運行相關的操作。反之如果今天提供的是 Container 為基底的環境，那要在上面再次安裝 Kubernetes 就不是這麼簡單了。



## 執行過程

下圖是執行過程，可以看到最上面是執行 `actions-k3s` 的內容，透過 `docker` 指令創建相關的 `k3s` Cluster，最後透過	`kubectl` 來觀看相關的內容，包含節點資訓以及對應的版本

![](https://i.imgur.com/cWiDU0g.png)

到這邊為止我們就有辦法於 GitHub Action 中動態創立 Kubernetes 叢集了，如果有什麼測試都可以把這些部分整合到 GitHub action 中了。
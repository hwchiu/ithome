Day 30 - Summary
================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

Rancher x Fleet 系列文到此告一個段落，這系列文中探討四大概念，包含
1. Rancher 基本知識
2. Rancher 管理指南
3. Rancher 應用程式部署
4. GitOps 部署

# Rancher 基本知識
Kubernetes 作為一個容器管理平台，這幾年的聲勢不減反升，愈來愈多的團隊想要嘗試導入 Kubernetes 來替換應用程式部署的底層架構。Kubernetes 不是萬靈丹，並不是所有的情境與環境都適合使用 Kubernetes，但是一旦經過評估確認想要使用 Kubernetes 後就會面臨到下一個重大問題，就是該 Kubernetes 叢集要怎麼安裝與管理?

從 On-Premise 到雲端環境，從手工架設到使用付費 Kubernetes 服務都是選項之一，這種情況下團隊需要花更多心力與時間去思考到底要走哪一個方式，畢竟每個方式都有不同的優缺點。

Rancher Labs 是一個針對 Kubernetes 生態系開發許多工具的強大團隊，譬如
1. Rancher Kubernetes Engine (RKE): 客製化的 Kubernetes 環境
2. K3s: 輕量級的 Kubernetes 叢集，適合物聯網環境
3. Fleet: 針對 Kubernetes 的 GitOps 解決方案
4. Longhorn: 持久性儲存的解決方案

除了可以將現存的 Kubernetes 叢集讓 Rancher 託管，更多的使用方式是讓 Rancher 直接創造基於 RKE 版本的 Kubernetes 叢集，因為 RKE 叢集才可以真正發揮 Rancher 內的所有功能。

官方文章有專門的文章 [Best Practices Guide](https://rancher.com/docs/rancher/v2.5/en/best-practices/) 探討如何針對生產環境部署一個最適當的 Rancher，接者如何透過這套 Rancher 來託管與創建不同的 Kubernetes 叢集。

透過 docker 可以很輕鬆的部署一個 Rancher，該環境非常適合測試與評估使用，但是如果要將 Rancher 給導入到正式環境的話，就會希望能夠透過一套 RKE 叢集來維護 Rancher 服務。

# Rancher 管理

Rancher 本身是個 Kubernetes 管理平台，因此其系統架構的設計有非常多層級的概念
1. 管理 Rancher 服務本身的功能
2. 管理 Kubernetes 叢集本身的功能
3. 管理 Kubernetes Project 的功能

有了這些基本概念後去閱讀官方文件就會更加理解到底官方文件的編排與含義。
此外，Rancher 基於 RBAC 的方式針對不同的使用者可以設定不同的權限。
使用者的認證除了預設的內建資料庫外，也支援不同的外部服務，如 Azure/GSuite/Keycloak 等不同機制
因此使用 Rancher 時也要特別注意 RBAC 的設定，避免所有 Rancher 的使用者都共享一套 admin 的帳號來操作。

# IaC
Rancher 本身除了透過 UI 大量操作外，也可以透過 Terraform/Pulumi 這些 IaC 工具來設定，因此一個比較好的模式是推薦使用這類型的工具來操作與管理 Rancher 本身，同時將這些操作與系統中的 CI/CD pipeline 給結合，這樣所有的變更可會更加透明且也能夠透過 CI/CD 的入口當作 Single Source of Truth 的概念

# 應用程式部署

透過 Rancher 準備好一套可用的 Kubernetes(RKE) 叢集後，接下來可以透過很多種方式去管理叢集上的應用程式。
譬如直接取得 Kubernetes 的 KUBECONFIG，擁有該檔案的任何人都可以直接使用 helm/kubectl 等指令進行操作來安裝各種 Kubernetes 的資源到目標叢集內。

如果想要妥善利用 Rancher 的設計的話，就可以考慮使用 Rancher 內的機制 (Catalog/App) 來安裝應用程式，透過 Rancher 的機制來安裝應用程式會於 UI 方面有更好的呈現與整合，同時使用上可以避免 Kubeconfig 的匯出，可以統一都使用 Rancher API Token 進行存取即可。

如果對於這種手動部署感到厭煩的，也可以嘗試看看 Rancher v2.5 正式推出的 GitOps 解決方案， Rancher Fleet。
透過 Rancher Fleet 的幫助，管理者可以講所有要部署的資源都存放到一個 Git 專案，同時 Fleet 支援數種不同的應用程式客製化。
除了常見的 Helm 及 Kustomize 外， Fleet 還支援將 Helm 與 Kustomize 一起使用，針對使用外部 Helm Chart 的情境特別好用。

不過 Rancher Fleet 目前還在茁壯發展中，因此使用上難免會遇到一些 Bug，這部分都非常歡迎直接到官方 Github 去回報問題，透過社群的幫忙官方才更有機會將這些問題給修復。

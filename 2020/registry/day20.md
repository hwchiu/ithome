Day  20 - Container Registry 的方案介紹
===============================

本文同步刊登於筆者[部落格](https://hwchiu.com)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者
歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



本篇文章要來跟大家分享其他 Contaienr Registry 的選擇及相關議題，這些議題包含(包含但不限於)

1. 使用者登入權限控管與整合

2. 硬碟空間處理機制

   > Registry 的空間處理問題非常重要，處理不好很容易造成使用者沒有辦法繼續推送 Image

3. UI 介面的操作
4. 潛在漏洞與安全性檢查
5. SSL 憑證的支援性



此外這邊要特別注意，自架 Container Registry 不一定是免費的，有時候自架的會需要有相關授權等花費。 SaaS 不一定要錢，只是免費的通常都會有一些限定



接下來我們就來看一下方案介紹與比較

# Docker Registry 2.0

Docker Registry 2.0 是由 `Docker` 所維護的開源專案，提供開發者一個自架 Docker Registry 的選項，使用上非常簡單，透過 Docker Container 的方式就可以輕鬆創建出一個 docker registry 2.0 的服務器。

舉例來說，下列指令就可以創建完畢

```bash
$ docker run -d -p 5000:5000 --restart always --name registry registry:2
```

不過我個人對於 docker registry 沒有很愛，主要是其預設情況下並沒有提供任何 UI 的支援，一切的操控都只能透過 docker 指令或是 curl 等指令來處理，對於多人控管以及操作上非常不便利。

網路上也有相關的專案，譬如 [docker-registry-ui](https://github.com/Joxit/docker-registry-ui) 這些第三方專案在幫忙實作 UI，讓使用者有一個比較好的方式可以管理，但是這種情況下會變成 UI 與 Server 兩個程式是由不同的維護團隊在維護，功能上的整合， Issue 的問題等都不一定夠順暢，所以如果不是為了本地簡單測試的情況下，我通常不會採用 Docker Registry 作為一個長期的解決方案。

儲存方面， [Customize the storage location](https://docs.docker.com/registry/deploying/#support-for-lets-encrypt) 以及 [Customize the stoage back-end](https://docs.docker.com/registry/deploying/#customize-the-storage-back-end) 等來自官方的文章再介紹相關的設定

對於外部存取的話，其也有支援 [Let's Encrypt](https://docs.docker.com/registry/configuration/#letsencrypt) 等機制，讓其自動幫你 renew 快過期的憑證，使用上相對方便。

 權限認證方面我認為功能比較少，滿多的認證方式都需要自行透過額外的伺服器幫忙處理，可以參考  [restricting-access](https://docs.docker.com/registry/deploying/#restricting-access) 或是 [reverse proxy + SSL + LDAP for Docker Registry](https://medium.com/@two.oes/reverse-proxy-ssl-ldap-for-docker-registry-805539daaa94)

# Harbor 

Harbor 是由 VMWare 所開源的 Container Registry 專案，我認為 Harbor 一個很值得推薦的原因是該專案是 [CNCF 畢業專案](https://www.cncf.io/projects/)，要成為 CNCF 畢業專案必須要滿足一些條件，雖然沒有一個專案可以完美的適合所有情形，但是就社群使用程度與社群貢獻程度來看， Harbor 算是滿優良的，這部分至少可以證明其本身是不少使用者在使用，而不是一個乏人問津的專案。

Harbor 的目標很簡單，源自期[官網](https://goharbor.io/)的介紹

> Our mission is to be the trusted cloud native repository for Kubernetes

Harbor 本身使用上不會太困難，可以透更 docker-compose 的方式去安裝，同時本身也有提供簡單的 UI 供使用操作，

詳細的架構可以參考這個 [Architecture Overview of Harbor](https://github.com/goharbor/harbor/wiki/Architecture-Overview-of-Harbor), 大概條列一下幾個重點功能

1. 登入授權方式支援 LDAP/AD 以及 OIDC(OpenID Connect)，基本上銜接到 OIDC 就可以支援超多種登入，譬如 google, microsoft, saml, github, gitlab 等眾多方式都有機會整合進來
2. Harbor v2.0 架構大改，成為一個 OCI (Open Container Initiative) 相容的 Artifacct Registry, 這意味者 Harbor 不單純只是一個 Container Image Registry，而是只要符合 OCI 檔案格式的產物都可以存放，影響最大的就是 Helm3 的打包內容。 未來是有機會透過一個 Harbor 來同時維護 Container Image 以及 Helm Charts
3. 支援不同的潛在安全性掃描引擎
4. 本身可跟其他知名的 Container Registry 進行連動，譬如複製，或是中繼轉發都可以
5. 除此之外還有很多特性，有興趣的點選上方連結瞭解更多

![arch](https://github.com/goharbor/harbor/raw/release-2.0.0/docs/img/architecture/architecture.png)



# Cloud Provider Registry

三大公有雲 Azure, AWS, GCP 都有針對自己的平台提供基於雲端的 Container Registry，使用這些 Registry 的好處就是他們與自家的運算平台都會有良好的整合，同時服務方面也會有比較好的支援。

當然這些 SaaS 服務本身都會有免費與收費版本，就拿 [AWS(ECR)](https://aws.amazon.com/ecr/pricing/) 為範例，一開始會有一個嚐鮮方案，大概是每個月有 500GB 的容量使用，但是接下來更多的容量就會開始計費，計費的方式則是用(1)容量計費，每多少 GB 多少錢，(2)流量計費，流量的價錢是一個區間價格，使用愈高後的單位平均價格愈低。

![](https://i.imgur.com/BcaLHvk.png)

就如同之前提過，使用 SaaS 服務有很多的優點，包含不需要自行維護伺服器，從軟體到硬體都可以全部交由服務供應商去處理，自己只要專心處理應用的邏輯即可，但是成本考量就是一個需要注意的事項。



# Others

除此之外還有不少專案有提供 Self-Hosted 的服務，譬如由 SUSE 所維護的開源專案 [Portus](http://port.us.org/) ，其專注整合 Docker Registry 並提供友善的介面與更多進階的功能，譬如 LDAP 控管，更進階的搜尋等。

> ### [Portus](https://github.com/SUSE/Portus) is an open source authorization service and user interface for the next generation Docker Registry.

不過觀察該專案的[Github](https://github.com/SUSE/Portus) 顯示已經數個月沒有更新，甚至其最新的 Issue 都在探討是否該專案已經被放棄，[Is Portus no longer being worked on](https://github.com/SUSE/Portus/issues/2313)， 有其他網友發現 SUSE 後來開了一個新的專案 [harbor-helm](https://github.com/SUSE/registry/tree/master/harbor-helm)，大膽猜測可能 SUSE 也在研究採用 Harbor 作為其容器管理平台而放棄自主研發的 Portus。

如果本身已經是使用 Gitlab 的團隊，可以考慮直接使用 [GItlab Container Registry](https://docs.gitlab.com/ee/administration/packages/container_registry.html#enable-the-container-registry)，其直接整合 Gitlab 與 Docker Registry 提供了良好的介面讓你控管 Container Registry，好處是可以將程式碼的管理與 Image 的管理都同時透過 Gitlab 來整合。




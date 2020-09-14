Day  29 - Summary 
===============================

本文同步刊登於筆者[部落格](https://hwchiu.com)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者
歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



過去的 28 篇文章我們從頭到尾探討了以下這張圖片的種種議題，包含了

1. 如何管理 Kubernetes 應用程式，Helm/Kustomize/原生 Yaml

2. 本地開發者如果有 Kubernetes 使用的需求，那可以怎麼做

3. Pipeline 該怎麼選擇， SaaS 與自架各自的優劣

4. CI Pipeline 可以怎麼做，如果有 Kubernetes 的需求，那可以怎麼設計

5. CI pipeline 要如何對 Kubenretes 應用程式進行測試， Yaml 可以測試針對語法，語意等進行測試

6. CD pipeline 有哪一些做法，配上 Kubernetes 之後有哪些參考作法

7. GitOps 是什麼，相對於過往的部署方式，有什麼優劣

8. GitOps 與 Kubernetes 的整合，有哪些解決方案可以使用

9. Container Registry 的選擇，SaaS 與自架各自的優劣

10. 自架的 Container Registry 要怎麼與 Kubernetes 整合，有哪些點要注意

11. Secret 機密資訊於自動部署上要怎處理

12. Secret 機密部署與 Kubernetes 要如何處理

    

![img](https://i.imgur.com/MhJGAMt.jpg)

事實上，上面每個議題都有跳不完的坑，每個議題都有好多的解決方案，不論是開源解決方案，或是商業付費方案，每個都有不同的場景，以及不同的時機去使用。

踏入一個新技術想要嘗試導入時，往往最困難的就是要如何在包山包海的選擇中，挑出一個最後的答案。

這部分吃的除了是技術的洞察力，透過觀察不同軟體的架構來判斷問題外，還有對於自己團隊工作流程的掌握力，一時之間選不出來的時

候，可能還需要針對不同專案進行嘗試，透過實際操作去觀察實際運用的情況，再加以輔佐來進行判斷。

就如同 CNCF End User Technology Radar 關於 Continuouse Delivery 調查報告中所說，很多人使用 Jenkins 是因為舊系統已經正在使用，實在是沒有什麼理由硬要把它拔掉，優劣權衡之後就決定舊系統繼續使用 Jenkins，但是對於很多全新的專案，因為是全新的環境，

就可以開始嘗試不同的解決方法。

該文章也提到，很多公司都嘗試過至少10個以上的解決方案在評估，最後就收斂到 3-4 個繼續穩定使用的專案，幾乎沒有公司是一個專案打天下，甚至很多大公司發現解決方案解決不了問題的時候，就會自己動手實作符合自己工作情境的軟體，甚至將其開源貢獻。
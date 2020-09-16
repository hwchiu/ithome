Day 19  - Container Registry 的介紹及需求
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)





本篇開始要來介紹一些 CI/CD 過程中都一定會用到的一個元件， Container Registry

Container Registry 顧名思義就是用來保存 Container Image 的一個倉庫，我認為 Container Registry 也有一些有趣的議題可以探討，譬如說

1. 要使用 SaaS 服務還是自己架設
2. 是否支持 Private registry
3. 多人合作下是否支持權限控管
4. 是否有 web hook 可以與後續的 pipeline 或是其他系統連動
5. 跟 Git 等相關專案是否有自動連動與處理
6. 是否支援弱點掃描，可以用來檢查當前 Registry 內的 image 是否有潛在安全性的問題



上述的每個議題也都滿有趣的，我們可以先來聊聊 (1) 這個議題到底有什麼要探討的地方

我認為近8年大部分踏入容器化世界的開發者或使用者，第一個接觸的解決方案基本上都是 Docker Container，後續開始使用時通常都會使用 Docker Hub 這個由 Docker 所提供的 Container Registry 作為第一個接觸的 Contaienr Registry 解決方案。

Docker Hub 使用起來，我認為算是非常方便，特別是跟 GitHub/Bitbucket 的連動非常輕鬆設定，通常只要在專案內準備一個 Dockerfile 的檔案，就可以讓 Docker Hub 自動地幫你部署相關的 Image 並且存放到 Docker Hub 上。

這種情況下對於一些要準備自己 Image 的開發者來說非常便利，都不需要額外的 CI Pipeline 系統來處理，只要將程式碼合併，等待一段時間後相關的 Image 就出現了。 

然而隨者專案的擴大，使用環境的改變， Docker Hub 並不一定可以適合所有情境

舉例來說，很多落地的工作環境中，會基於保密，機密等安全性要求，不希望運行的 Contianer Image 放置雲端，這時候就會思考是否有辦法自架一個本地端的 Container Registry。

此外更多的情境是網路問題，因為 Container Image 的容量說大不大，說小不小，幾百 MB 到幾 GB 都有，如果遇到網路速度瓶頸問題，就會發生抓一個 Image 花上長時間等待。 這部分的問題其實常常看到，舉例來說

[Extremely Slow Image Pulls](https://github.com/docker/hub-feedback/issues/1675)

[hub-feedback issue about slow](https://github.com/docker/hub-feedback/issues?q=is%3Aissue+is%3Aopen+slow)

這些連結都可以看到滿滿的關於下載速度的問題，有時候還會牽扯到 docker hub CDN 的問題，問題發生的時候還真的什麼都不能做，只能祈禱 docker hub 快點修復。



# Docker Hub 方案比較

此外，部分工作團隊也會有一些 contaienr image 的需求，但是又不想要公開相關的內容，這時候會需要 private registry 的支援，可惜的是對於 Docker Hub 來說，這部分會取決於方案的選擇，譬如下圖的[方案比較](https://www.docker.com/pricing)



免費方案只能有一個 Private，付費又會取決於你是個人用戶還是一個團隊，對於團隊來說，其價格還會根據使用者數量而有所增加，

所以如果今天團隊內會希望根據架構有不同的權限控管，因此使用者的數量可能會有不少的時候，整個成本又會大幅度增加。

![](https://i.imgur.com/u6lWBKU.png)



總總考量之下，自架 Container Registry 的需求就會逐漸出現，不論是為了成本，為了功能或是其他因素， SaaS 與 自架的選擇從來沒有

停止過，就如同之前探討 pipeline 系統一樣，每個系統都會有 SaaS 與自架的需求比較，但是哪一種比較適合貴團隊就沒有答案

此外，不同的開源專案提供的 container registry 的功能也都不盡相同，這種情況下就需要有人去針對每套軟體進行評估，找出一套適合自己團隊的服務，或是最後轉回使用 SaaS 商用解決方案都有可能。



# DockerHub 使用者條款

最後要提的是，使用 SaaS 服務也不是就沒有完全痛點，譬如 2020 八月份 Docker Hub 的[使用者條款更新](https://www.docker.com/legal/docker-terms-service)，該更新中有幾個更動令很多無付費使用者都在思考該怎麼處理，是否要轉換到其他的 SaaS 服務或是都要改成自架來處理。主要更新有

1. 當一個 Image repository 六個月內沒有任何動作(push/pull)，則該 image repository 會被自動刪除
2. 針對無認證用戶或是免費版本用戶有下載量的限制。
   1. 無認證用戶每六小時只能 Pull Image 100 次
   2. 認證的免費用戶每六小時只能 pull 200 次

對於很多使用者或是開發者來說，這兩個問題都會造成一些使用上的困擾，特別是 (2) 的限制，因此不少人開始思考要如何於不花錢的情況下解決這些問題，譬如 [avoiding the docker hub retention limit](https://poweruser.blog/avoiding-the-docker-hub-retention-limit-e18cdcacdfde), 或是轉戰到其他的 SaaS。

只能說天下沒有白吃的午餐，享受免費方案的同時，也要多注意所謂的使用者條款，如果發現這些條款的修正會影響自己的使用情境，可能就要開始考慮搬移，自架或是付費等選擇

接下來的文章，我們就會探討自架 Contaienr Registry 的各種選擇與示範，最後會在展示如何將自架 Contianer Registry 與 Kubernetes 結合，讓你的 Kubernetes 叢集能夠接受 Docker Hub 以外的 Contaeinr Registry.






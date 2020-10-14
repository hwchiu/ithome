Day  23 - Secret 的部署問題與參考解法(上)
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



本篇文章要來探討 CI/CD 部署的最後一個環節，來探討機密資訊的部署問題。 

CI/CD pipeline 的設計，讓管理員可以手動觸發這些部署工作流，或是透過其他機制去觸發，最後都可以讓 pipeline 自動化的去完成 CI 

與 CD 的動作。

然而就是這些自動化的步驟，帶來了一些額外的隱憂，對於一個基於自動化運行的程式，要如何將機密資訊，如應用程式帳號密碼，存取

的 Key/Token 給套入到每個環節，又不希望這些資訊外流實屬一個挑戰。同時也要避免這些機密資訊被存放到 log 之中，盡可能地減少

任何會曝光這些機密資訊的機會。

此外，除了 pipeline 系統的架構外，如何包裝應用程式也會是一個問題，譬如使用原生的 Yaml, Kustomize 或是 Helm，不同的工具都有不同的解法。



就我個人的瞭解，至少有三種參考架構可以解決這些問題(不一定完美，但是可以稍微處理)



# 前提

開始探討架構前，我們先來假設幾個部署情境，接下來的架構都會去思考是否可以滿足這個應用

### Helm

試想一個範例，我們的應用程式由 Helm 組成，會透過讀取檔案(Kubernetes Secret)的方式來獲取遠方資料庫的密碼。 

今天要透過 Helm 部署這個應用程式的時候，我們會透過準備自己的 values.yaml 或是透過 `--set dbpassword=xxx` 等方式來客製化這個 secret 檔案，最後把全部的內容送到 Kubernetes 裡面。

### 原生 Yaml

如果是原生 Yaml 的情況下，我們沒有 `--set` 這類型的東西可以使用，變成我們要透過腳本的方式自行實現類似 Go-Template 的方法，或是動態產生一個 Secret 來使用。這部分不會太困難，只是就會讓人覺得有沒有更好的解決方案

### Kustomize

基本上 Kustomize 是基於 overlay 的概念去組合出最後的 Yaml 檔案，所以作法跟原生 Yaml非常類似，好加在 Kustomize 本身有提供 `secretGenerator` 的語法，讓你更輕鬆的產生 Kubernetes Secret 物件檔案

```bash
cat <<'EOF' > ./kustomization.yaml
secretGenerator:
- name: mysecrets
  envs:
  - foo.env
  files:
  - longsecret.txt
  literals:
  - FRUIT=apple
  - VEGETABLE=carrot
EOF
```



# Pipeline System

第一種架構是 Pipeline 系統本身有提供一些機密資訊的保護，譬如 Jenkins, Github Action, CircleCI..等。 系統中有一塊特別的資訊，讓使用者可以填入想要的 key:value 的數值，然後於 Pipeline 運作過程中，可以透過一些該平台限定的語法來取得。舉例來說



### Github Action

使用者先在專案列表中，把你想要用到的 key:value 加進去，接下來於 Github Action workflow 中使用 `{{ secrets.xxxxx }} `的方式可以取出這些數值，然後這類型的數值再運行的 log 中會被系統給過濾掉，以 `****` 的方式呈現。

```yaml
steps:
  - name: Hello world action
    with: # Set the secret as an input
      super_secret: ${{ secrets.SuperSecret }}
    env: # Or as an environment variable
      super_secret: ${{ secrets.SuperSecret }}
```

其他的如 Jenkins/CircleCI 等不同系統都有一樣的機制可以使用，但是這種用法對於我們的 Kubernetes 應用程式來說要怎麼整合?



接下來我們嘗試將上述三種情境套入到這個架構中，看看會怎麼執行

### Helm

1. CI/CD pipeline 運行到後面階段後，從系統中取出資料庫的帳號密碼，假設這個變數叫做 `$password`
2. 接下來要透過 `helm` 的方式來安裝我們的應用程式，因此會執行 `helm upgrade --install --set dbpassword=$password .` 等類似這樣的指令產生出最後的 secret 以及 pod，然後一起部署到 Kubernetes 裡面

### Kustomize

1. CI/CD pipeline 運行到後面階段後，從系統中取出資料庫的帳號密碼，假設這個變數叫做 `$password`
2. 接下來透過腳本的方式，產生對應的 `secretGenerator` 寫入到相關的 Yaml 之中，之後呼叫 `kubectl -k` 以及 `kustomize ` 這兩個指令最後去部署

### 原生 Yaml

1. CI/CD pipeline 運行到後面階段後，從系統中取出資料庫的帳號密碼，假設這個變數叫做 `$password`
2. 接下來透過 `kubectl create secret ...... -o yaml` 的方式產生對應的 Yaml 檔案，然後跟剩餘的內容一起部署到 kubernetes 內部



這樣的流程看起來似乎沒有問題，但是我認為有幾個地方要注意

1. 假設今天應用程式需要用到的機密資訊很多，譬如 db_table, db_username, db_password, 甚至一些連接其他服務的帳號密碼，可能需要設定的東西就會非常多，變成你的 pipeline 那邊的設定變得非常多，同時大部分的 pipeline 系統都不會讓你編輯，有要修改就要整條換掉，同時通常也不會顯示明碼給你。
2. 呈上，當你要使用一個 pipeline 系統對應多個環境，譬如 dev/QA/staging/production 等多環境，你上述的變數量就會直接翻倍，然後那邊的數量就愈來愈多
3. 上述 `helm upgrade --install ...` 的部分一定是於 shell 去執行，這時候如果有些應用程式需要的機密資料本身就有雙引號，單引號等討人厭字元，就要特別注意跳脫的問題。我過往還遇過某些機密資訊本身是由一個 JSON 檔案組成的，裡面可說是雙引號滿天下，這時候的處理就變得非常頭疼
4. 今天這個作法是將機密資訊於 pipeline 系統來處理，但是如果採用的 GitOps 的做法，那就不會有 CD pipeline，因此這種解法也不可行。
5. 如果今天因為一些需求，需要替換整個 pipeline 系統，那管理人員會覺得很崩潰，因為整個系統要大搬移。



整個流程如下圖

![](https://i.imgur.com/aTv5vpx.jpg)



今天我們就先探討這個架構，下一篇文章我們再來探討別的架構會如何解決這個問題




Day  22 - 自架 Registry 與 Kubernetes 的整合
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



上篇講述了如何透過 Harbor 來架設屬於自己的 Container Registry，而本篇我們就要將其與之前部署的 Kubernetes 整合

基本上官方文件 [Pulling Image Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) 有清楚的描述要執行哪些步驟，因此本篇文章就來將這些步驟詳細的跑一次

但是這邊要注意的，如果你的 `Container Registry` 使用的是自簽的憑證，甚至是根本沒有 HTTPS 保護，那整個步驟會變得非常麻煩。

假設你的 Kubernetes 叢集預設使用的都是 `docker container` 作為你的容器解決方案，你必須要讓你的 `dockerd` 信賴這些 `不知道能不`

`能信賴的 container registry`。 docker 官方也有頁面 [use-self-signed-certificates](https://docs.docker.com/registry/insecure/#use-self-signed-certificates) 專門介紹要如何讓你的 `dockerd` 去處理這些動作。

如果今天只有一台機器的話，這些步驟都還算簡單，還可以處理，但是當這些機器數量很多，同時有可能是動態創建的，那我們就必須要

想辦法去設定這些機器上的 `dockerd`，這樣這些機器加入到 Kubernetes 叢集後，才有辦法去連接到你自行架設但是`沒有可信賴憑證的 `

`container registry`。

接下來的步驟都是基於你的 Container Registry 本身有一個可信賴的憑證，同時所有的容器解決方案都是基於 `docker`。



# Kubernetes

如果今天要從本地端去抓取一個 private container registry，我們第一件要做的事情就是 `docekr login`，可以參閱 Docker 官方[docker login](https://docs.docker.com/engine/reference/commandline/login/)來看更多說明與使用。



對於 Kubernetes 來說，其會使用 `secret` 的特殊型態 `docker-registry` 作為登入任何 private container registry 的帳號密碼來源。

這邊有兩種方式可以使用

第一種是先透過 docker login 登入，之後將登入後的設定檔案送給 Kubernetes secret 物件

第二種則是創建 Kubernetes secret 時使用明碼的帳號密碼

接下來的範例會針對(1)去使用，對第二種範例有興趣可以參閱 [Create a Secret by providing credentials on the command line](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#create-a-secret-by-providing-credentials-on-the-command-line)

```bash
$  docker login --username admin --password Harbor12345  https://registry.hwchiu.com
WARNING! Using --password via the CLI is insecure. Use --password-stdin.
WARNING! Your password will be stored unencrypted in /home/ubuntu/.docker/config.json.
Configure a credential helper to remove this warning. See
https://docs.docker.com/engine/reference/commandline/login/#credentials-store

Login Succeeded
$ cat ~/.docker/config.json
{
        "auths": {
                "registry.hwchiu.com": {
                        "auth": "YWRtaW46SGFyYm9yMTIzNDU="
                }
        },
        "HttpHeaders": {
                "User-Agent": "Docker-Client/19.03.12 (linux)"
        }
```

接下來把這個檔案，送給 Kubernetes 去使，這邊要注意的是我們使用的是基於 `dockerconfigjson` 這個類型

```
kubectl create secret generic regcred \
    --from-file=.dockerconfigjson=~/.docker/config.json> \
    --type=kubernetes.io/dockerconfigjson
```



如果想要使用 Yaml 去維護的話，可以透過 base64 去編碼該config，譬如

```bash
$ cat harbor_secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: myregistrykey
data:
  .dockerconfigjson: ewoJImF1dGhzIjogewoJCSJyZWdpc3RyeS5od2NoaXUuY29tIjogewoJCQkiYXV0aCI6ICJZV1J0YVc0NlNHRnlZbTl5TVRJek5EVT0iCgkJfQoJfSwKCSJIdHRwSGVhZGVycyI6IHsKCQkiVXNlci1BZ2VudCI6ICJEb2NrZXItQ2xpZW50LzE5LjAzLjEyIChsaW51eCkiCgl9Cn0=
type: kubernetes.io/dockerconfigjson
```



如果想要驗證到底自己的 secret 是否正確，我們可以將 secret 的內容抓出來，重新用 base64 解編碼，並且跟本來的 ~/.docker/config.json 進行比較

```bash
$ kubectl get secret regcred --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode
{
        "auths": {
                "registry.hwchiu.com": {
                        "auth": "YWRtaW46SGFyYm9yMTIzNDU="
                }
        },
        "HttpHeaders": {
                "User-Agent": "Docker-Client/19.03.12 (linux)"
        }
$ kubectl get myregistrykey --output="jsonpath={.data.\.dockerconfigjson}" | base64 --decode
{
        "auths": {
                "registry.hwchiu.com": {
                        "auth": "YWRtaW46SGFyYm9yMTIzNDU="
                }
        },
        "HttpHeaders": {
                "User-Agent": "Docker-Client/19.03.12 (linux)"
        }
```

確認資料都沒有正確後，我們就可以來準備部署的我們的 Pod 運算資源了!

```bash
$ cat deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ithome-private-1
  namespace: default
  labels:
      name: "ithome-private-1"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ithome-private-1
  template:
    metadata:
      name: ithome-private-1
      labels:
        app: ithome-private-1
    spec:
      containers:
        - image: registry.hwchiu.com/ithome/netutils:latest
          name: ithome
      imagePullSecrets:
        - name: regcred
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ithome-private-2
  namespace: default
  labels:
      name: "ithome-private-2"
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ithome-private-2
  template:
    metadata:
      name: ithome-private-2
      labels:
        app: ithome-private-2
    spec:
      containers:
        - image: registry.hwchiu.com/ithome/netutils:latest
          name: ithome
      imagePullSecrets:
        - name: myregistrykey
```

這邊只有一個要注意，就是在 `imagePullSecrets` 這邊指定你要使用的 secret 即可，我們上述的範例有 `regcred` 以及 `myregistrykey` 兩個，所以我們就創造兩個 deployment 但是使用不同的 secret 來試試看



```bash
$ kubectl apply -f deployment.yaml
deployment.apps/ithome-private-1 created
deployment.apps/ithome-private-2 created
$ kubectl get pods
NAME                                READY   STATUS    RESTARTS   AGE
ithome-private-1-765997748-2gttp    1/1     Running   0          4s
ithome-private-1-765997748-c8fdz    1/1     Running   0          4s
ithome-private-1-765997748-mgpfx    1/1     Running   0          4s
ithome-private-2-84c74f8c6d-5tws8   1/1     Running   0          4s
ithome-private-2-84c74f8c6d-cz6rq   1/1     Running   0          4s
ithome-private-2-84c74f8c6d-xkvjt   1/1     Running   0          4s
```



到這邊就順利的讓 Kubernetes 連接到剛剛架設的 Harbor Registry 了。

這邊要特別注意，如果今天 secret 有一些問題，要除錯的話除了透過 `kubectl describe` 去看之外，另外一種方式就是到 Kubernetes 節點上面去看相關的 container log，裡面會有更詳細為什麼會 pull image 失敗，看是憑證問題，帳號密碼認證失敗等。有些太底層的原因 kubectl 是看不到了。



# Helm Chart 3

最後我們來示範如何將 Helm Chart (v3) 與 Harbor 整合，並且讓其推向到遠方的 Kubernetes 叢集中，整個流程是

1. 讓 Helm Chart 登入到遠方 Harbor Registry
2. 創建一個測試用的 nginx Helm Chart.
3. 打包 nginx Helm Chart
4. 將 nginx Helm Chart 推到 Harbor Registry
5. 砍掉本地的 nginx Helm Chart 資料夾，並且移動到其他資料夾
6. 將遠方的 charts 複製一份到本地端並且使用 helm 工具將其安裝到  Kubernetes

```bash
$ export HELM_EXPERIMENTAL_OCI=1
$ helm registry login -u admin registry.hwchiu.com
Password:
Login succeeded
$ helm create nginx
$ cd nginx
$ helm chart save . registry.hwchiu.com/ithome/nginx:ithome
ref:     registry.hwchiu.com/ithome/nginx:ithome
digest:  477087f52e48bcba75370928b0895735bc0c3c1d7612d82740dd69c2b70bbba4
size:    3.5 KiB
name:    nginx
version: 0.1.0
$ helm chart push registry.hwchiu.com/ithome/nginx:ithome
The push refers to repository [registry.hwchiu.com/ithome/nginx]
ref:     registry.hwchiu.com/ithome/nginx:ithome
digest:  477087f52e48bcba75370928b0895735bc0c3c1d7612d82740dd69c2b70bbba4
size:    3.5 KiB
name:    nginx
version: 0.1.0
ithome: pushed to remote (1 layer, 3.5 KiB total)

```

當上述指令執行完畢後，可以看到 Harbor 內多出了相關的 repo, 名稱跟我們剛剛透過 Helm 去打包的名稱一致

![](https://i.imgur.com/0pyplqg.png)

進去到裡面觀看細節，可以看到裡面現在顯示的資訊包含了 Charts 的資料，還有其相關的 values.yaml 都有，實實在在的透過 Harbor 這套 registry 來保存我們的 Helm Charts。

![](https://i.imgur.com/KNJlJyf.png)



接下來我們就嘗試把遠方的 charts 給複製到本地，並且用 helm install 來安裝。

```bash
$ cd ../
$ rm -rf nginx
$ helm chart export registry.hwchiu.com/ithome/nginx:ithome
ref:     registry.hwchiu.com/ithome/nginx:ithome
digest:  477087f52e48bcba75370928b0895735bc0c3c1d7612d82740dd69c2b70bbba4
size:    3.5 KiB
name:    nginx
version: 0.1.0
Exported chart to nginx/
$ helm install ithome nginx/
$ helm ls
NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART           APP VERSION
ithome  default         1               2020-09-13 23:49:47.200022078 +0000 UTC deployed        nginx-0.1.0     1.16.0
```



到這邊就有一個簡易的展示，如何將 Helm3 & Harbor & Kubernetes 進行整合，透過這個功能我們可以只需要用一個伺服器就滿足 Helm & Container Image。我個人認為這個在未來應該會變成主流，畢竟只要夠穩定，能夠減少要維護的伺服器數量可以更少，和樂不為？


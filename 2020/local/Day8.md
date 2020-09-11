Day 8 - Skaffold 本地開發與測試
===============================

本文同步刊登於筆者[部落格](https://hwchiu.com)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者
歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)





上篇文章中我們探討了本地開發應用程式與 Kubernetes 整合的測試流程，透過不同的 Kubernetes 部署工具會有不同的結果，如果採用

的是 KIND 這種工具，本身就有提供額外的指令幫助開發者將本地測試的 Contianer Image 給載入到 KIND 叢集中，可以提升整體開發效

率，但是如果採用的不是 KIND 的話，那該怎麼辦？



因此本篇就要來介紹另外一個開源工具 `Skaffold`，看看我們可以如何使用這套工具來提升本地開發 Kubernetes 應用的效率 (前提是你有需要一個 Kubernetes 來測試)



# Skaffold 介紹

Skaffold 官方是這樣介紹自己工具的

> Skaffold is a command line tool that facilitates continuous development for Kubernetes-native applications. Skaffold handles the workflow for building, pushing, and deploying your application, and provides building blocks for creating CI/CD pipelines. This enables you to focus on iterating on your application locally while Skaffold continuously deploys to your local or remote Kubernetes cluster.

簡單來說 Skaffold 是一個幫助開發 Kubernetes-natvie 應用程式的工具，其會幫你建置你的 Container Image, 推送 Container Image 到 部署你的應用程式到 Kubernetes 叢集，將這些動作一次整合，讓開發者能夠專心於應用程式開發，而應用程式最後如何跑到 Kubernetes 上則全部交給 Skaffold 來處理。



與之前的議題相比之下， Skaffold 除了支援本地的 Kubernetes 外，也支援遠方的 Kuberentes 叢集，我們來看一下其支援哪些類型的 Kuberentes 吧

下表節錄自[官方文件](https://skaffold.dev/docs/environment/local-cluster/), 可以看到對於本地的 Kubernetes 叢集支援不少，包含了 `minikube`, `kind` `k3d` 之前提過的都有支援，此外 `docker-desktop` 這類型也有支援。

Remote 的話則是以 Google 為主，由於本章節探討的都是本地的部署，所以接下來還是會以本地的 Kuberentes 叢集為範例去介紹與使用

| Kubernetes context | Local cluster type                                           | Notes                                  |
| ------------------ | ------------------------------------------------------------ | -------------------------------------- |
| docker-desktop     | [`Docker Desktop`](https://www.docker.com/products/docker-desktop) |                                        |
| docker-for-desktop | [`Docker Desktop`](https://www.docker.com/products/docker-desktop) | This context name is deprecated        |
| minikube           | [`minikube`](https://github.com/kubernetes/minikube/)        |                                        |
| kind-(.*)          | [`kind`](https://github.com/kubernetes-sigs/kind)            | This pattern is used by kind >= v0.6.0 |
| (.*)@kind          | [`kind`](https://github.com/kubernetes-sigs/kind)            | This pattern was used by kind < v0.6.0 |
| k3d-(.*)           | [`k3d`](https://github.com/rancher/k3d)                      | This pattern is used by k3d >= v3.0.0  |



# 架構

下圖節錄自[官方文件](https://skaffold.dev/docs/design/)



![architecture](https://skaffold.dev/images/architecture.png)

圖片中藍色基底就是 Skaffold 中最常使用到的功能，接下來我們就一個一個介紹每個區塊在做什麼事情



## Detecting Source Code

如同前言所述， Skaffold 希望開發者可以專注於程式碼的開發，而後續的流程都讓其來幫忙搞定，因此其內建一個偵測系統，當目標目錄內的程式碼有所更動時，就會自動地執行相關工作流程，這樣對於使用者來說，只需要存擋，等待一點時間就可以於 Kubernetes 叢集中看到最新的程式碼

## Bulding Artifacts

當程式碼被偵測到更動後， Skaffold 就會開始建置相關產物，這邊支援多種類型，譬如 Dockerfile, Bazel, Jib Maven 甚至是其他自定義的腳本。除了本地的產物產生之外， Skaffold 也有跟 Google Cloud Build 有所整合，這部分我認為跟 Skaffold 是 Google 開源有很大的關係，所以目前只有 Google 家的服務有支援。

## Test Artifacts

當產物產生後，會對這個產物進行測試，這個階段能做的選擇比較少，目前是基於 [Container-structure-test](https://github.com/GoogleContainerTools/container-structure-test) 這套開源軟體來進行測試，有興趣瞭解這個專案做什麼的可以點選前述連結或是到[官方頁面](https://skaffold.dev/docs/pipeline-stages/testers/)瞭解更多

## Tagging Artifacts

當產物產生也測試完畢之後，接下來會對產物進行 Tag 的動作，該 Tag 會打到 Container Image 上，目前有支援四種選項，包含

1. Git Commit IDs
2. Sha256 Hash
3. Go Tempate with Environment Variable Support
4. Date & Time

四者詳細的差異可以觀看[官方頁面](https://skaffold.dev/docs/pipeline-stages/taggers/) 來瞭解更多，基本上就是讓你選擇不同的 image tag 

## Pushing Artifac

這個步驟就是想辦法將上述的產物給送到 Kubernetes 裡面，這部分如果 Kubernetes 是本地機器，可以忽略這個步驟直接使用，就如同前述的 Kubeadm 的環境一樣。 如果是遠方的環境的話，這邊就會根據遠方 Kubernetes Cluster 不同種類而採用的方式來處理，其判斷準則則是依據 KUBECONFIG  CURRENT-CONTEXT 的名稱，就以最上面的支援環境來說

| Kubernetes context | Local cluster type                                           | Notes                                  |
| ------------------ | ------------------------------------------------------------ | -------------------------------------- |
| docker-desktop     | [`Docker Desktop`](https://www.docker.com/products/docker-desktop) |                                        |
| docker-for-desktop | [`Docker Desktop`](https://www.docker.com/products/docker-desktop) | This context name is deprecated        |
| minikube           | [`minikube`](https://github.com/kubernetes/minikube/)        |                                        |
| kind-(.*)          | [`kind`](https://github.com/kubernetes-sigs/kind)            | This pattern is used by kind >= v0.6.0 |
| (.*)@kind          | [`kind`](https://github.com/kubernetes-sigs/kind)            | This pattern was used by kind < v0.6.0 |
| k3d-(.*)           | [`k3d`](https://github.com/rancher/k3d)                      | This pattern is used by k3d >= v3.0.0  |

可以看到不同版本的 `KIND` 產生的 kubernetes context 名稱不同，但是只要有符合這兩個規則， Skaffold 都會視為是 KIND 並且用 KIND 的方式幫你推上 KIND 叢集

## Deploying Artifacts

最後則是將應用程式部署到 Kuberentes 裡面，這邊支援三種工具來部署，分別是

1. kubectl
2. helm
3. kustomize



我認為這三種基本上已經涵蓋了大部分人的使用情境， Skaffold 會將檔案內的 ImageTag 換成前面步驟產生的 Tag 並且將內容推到 Kubernetes 內部去更新



想要瞭解更多關於 Skaffold 的介紹可以參閱[官網](https://skaffold.dev/)

# 安裝

安裝指令也非常簡單，整個 Skaffold 的運作核心都在其 Binary，所以也只有一個軟體需要下載與安裝

```bash
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64 && \
sudo install skaffold /usr/local/bin/
```



安裝完畢後可以看到該指令有非常多的用法可以使用，接下來將會介紹本地開發時可能會使用的指令及相關用法。

```bash
$ skaffold
A tool that facilitates continuous development for Kubernetes applications.

  Find more information at: https://skaffold.dev/docs/getting-started/

End-to-end pipelines:
  run               Run a pipeline
  dev               Run a pipeline in development mode
  debug             [beta] Run a pipeline in debug mode

Pipeline building blocks for CI/CD:
  build             Build the artifacts
  deploy            Deploy pre-built artifacts
  delete            Delete the deployed application
  render            [alpha] Perform all image builds, and output rendered Kubernetes manifests

Getting started with a new project:
  init              [alpha] Generate configuration for deploying an application
  fix               Update old configuration to a newer schema version

Other Commands:
  completion        Output shell completion for the given shell (bash or zsh)
  config            Interact with the Skaffold configuration
  credits           Export third party notices to given path (./skaffold-credits by default)
  diagnose          Run a diagnostic on Skaffold
  schema            List and print json schemas used to validate skaffold.yaml configuration
  survey            Opens a web browser to fill out the Skaffold survey
  version           Print the version information

Usage:
  skaffold [flags] [options]

Use "skaffold <command> --help" for more information about a given command.
Use "skaffold options" for a list of global command-line options (applies to all commands).
```



# Demo

這邊我們直接使用官方的範例 Repo 來測試

```bash
git clone https://github.com/GoogleContainerTools/skaffold
cd skaffold/examples/getting-started
```



此外，我的系統中目前有之前由 KIND 所建立的 Kuberentes 叢集



前述講到整個 Skaffold 的架構，裡面有些階段都會有些不同的選擇，實際上這些選擇都是依賴一個 yaml 的設定檔案來處理，該資料夾內就有一個這樣的檔案

```bash
$ cat skaffold.yaml
apiVersion: skaffold/v2beta7
kind: Config
build:
  artifacts:
  - image: skaffold-example
deploy:
  kubectl:
    manifests:
      - k8s-*
```

這裡面設定幾個部分

1. 產物的部分，會把 image 叫做 skafoold-example
2. 部署的部分會把所有符合 `k8s-*` 字眼的檔案都用 kubectl 給部署進去



預設的情況下都會使用 Dockerfile 來建置產物

```bash
$ cat Dockerfile
FROM golang:1.12.9-alpine3.10 as builder
COPY main.go .
RUN go build -o /app main.go

FROM alpine:3.10
# Define GOTRACEBACK to mark this container as using the Go language runtime
# for `skaffold debug` (https://skaffold.dev/docs/workflows/debug/).
ENV GOTRACEBACK=single
CMD ["./app"]
COPY --from=builder /app .
```

下方則是相關的 Kubernetes yaml, 非常乾淨與單純

```bash
$ cat k8s-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: getting-started
spec:
  containers:
  - name: getting-started
    image: skaffold-example
```



接下來我們可以呼叫 `skaffold` 這個指令來執行 `一次完整的 workflow`, 包含建置 image, push image 以及 deploy 到 kubernetes 裡面。

```bash
$ skaffold dev
Listing files to watch...
 - skaffold-example
Generating tags...
 - skaffold-example -> skaffold-example:v1.14.0-7-g677d665c3
Checking cache...
 - skaffold-example: Not found. Building
Found [kind-kind] context, using local docker daemon.
Building [skaffold-example]...
Sending build context to Docker daemon  3.072kB
Step 1/7 : FROM golang:1.12.9-alpine3.10 as builder
1.12.9-alpine3.10: Pulling from library/golang
9d48c3bd43c5: Pull complete
7f94eaf8af20: Pull complete
9fe9984849c1: Pull complete
cf0db633a67d: Pull complete
0f7136d71739: Pull complete
Digest: sha256:e0660b4f1e68e0d408420acb874b396fc6dd25e7c1d03ad36e7d6d1155a4dff6
Status: Downloaded newer image for golang:1.12.9-alpine3.10
 ---> e0d646523991
Step 2/7 : COPY main.go .
 ---> afab364bca27
Step 3/7 : RUN go build -o /app main.go
 ---> Running in 7ac080c720c1
 ---> cbcc0f655527
 Step 4/7 : FROM alpine:3.10
3.10: Pulling from library/alpine
21c83c524219: Already exists
Digest: sha256:f0e9534a598e501320957059cb2a23774b4d4072e37c7b2cf7e95b241f019e35
Status: Downloaded newer image for alpine:3.10
 ---> be4e4bea2c2e
Step 5/7 : ENV GOTRACEBACK=single
 ---> Running in 3336c2434250
 ---> f7da9bb5a8f4
Step 6/7 : CMD ["./app"]
 ---> Running in ad83b9fb99e8
 ---> c18d1a41c91d
Step 7/7 : COPY --from=builder /app .
 ---> 4dec7885d19b
Successfully built 4dec7885d19b
Successfully tagged skaffold-example:v1.14.0-7-g677d665c3
Tags used in deployment:
 - skaffold-example -> skaffold-example:4dec7885d19bcf6a6fef2bc62c609390787a73be61501ad0bdaffd3b229fd9a5
Loading images into kind cluster nodes...
 - skaffold-example:4dec7885d19bcf6a6fef2bc62c609390787a73be61501ad0bdaffd3b229fd9a5 -> Loaded
Images loaded in 1.629866454s
Starting deploy...
 - pod/getting-started created
Waiting for deployments to stabilize...
Deployments stabilized in 13.655262ms
Press Ctrl+C to exit
Watching for changes...
[getting-started] Hello world!
[getting-started] Hello world!
[getting-started] Hello world!
[getting-started] Hello world!
[getting-started] Hello world!
[getting-started] Hello world
```



上述的範例可以觀察到

1. Push 的規則, 偵測到使用的是 KIND，所以就呼叫 KIND 的方式把 Image 送進去

   ```
   Loading images into kind cluster nodes...
    - skaffold-example:4dec7885d19bcf6a6fef2bc62c609390787a73be61501ad0bdaffd3b229fd9a5 -> Loaded
   ```

   

2. Deploy 的部分則是用 Kubectl 的方式將 Yaml 送進去，然後自動輸出相關的 Log.



## 修改程式碼

接下來我們開兩個視窗，一個視窗透過 `skaffold dev` 來偵測並處理整個流程，另一個視窗則是用來修改 `main.go`

接下來我們修改 `main.go` 改成下列內容

```go
package main

import (
        "fmt"
        "time"
)

func main() {
        for {
                fmt.Println("Hello world!-hwchiu-ithome")

                time.Sleep(time.Second * 1)
        }
}
```

當檔案存下去之後，馬上觀察另外一個視窗，會發現很快就偵測到程式碼的更動，並且馬上將修改的內容直接送到 Kubernetes 裡面

```bash
[getting-started] Hello world!-hwchiu
[getting-started] Hello world!-hwchiu
[getting-started] Hello world!-hwchiu
[getting-started] Hello world!-hwchiu

Generating tags...
 - skaffold-example -> skaffold-example:v1.14.0-7-g677d665c3-dirty
Checking cache...
 - skaffold-example: Not found. Building
Found [kind-kind] context, using local docker daemon.
Building [skaffold-example]...
Sending build context to Docker daemon  3.072kB
Step 1/7 : FROM golang:1.12.9-alpine3.10 as builder
 ---> e0d646523991
Step 2/7 : COPY main.go .
 ---> 5a9d1bded1b1
Step 3/7 : RUN go build -o /app main.go
 ---> Running in 0b71f1abe4e7

 ---> bcc350de6d46
Step 4/7 : FROM alpine:3.10
 ---> be4e4bea2c2e
Step 5/7 : ENV GOTRACEBACK=single
 ---> Using cache
 ---> f7da9bb5a8f4
Step 6/7 : CMD ["./app"]
 ---> Using cache
 ---> c18d1a41c91d
Step 7/7 : COPY --from=builder /app .
 ---> a73f3a1b761b
Successfully built a73f3a1b761b
Successfully tagged skaffold-example:v1.14.0-7-g677d665c3-dirty
Tags used in deployment:
 - skaffold-example -> skaffold-example:a73f3a1b761b040dfab47ba89b145da88c517ec7d031c32e5d61cb5e3bf205d3
Loading images into kind cluster nodes...
 - skaffold-example:a73f3a1b761b040dfab47ba89b145da88c517ec7d031c32e5d61cb5e3bf205d3 -> Loaded
Images loaded in 1.327803742s
Starting deploy...
 - pod/getting-started configured
 Waiting for deployments to stabilize...
Deployments stabilized in 2.156854ms
Watching for changes...
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
[getting-started] Hello world!-hwchiu-ithome
```

這時候用 kubectl 去觀察系統上的資源

```bash
$ kubectl get pods
NAME              READY   STATUS    RESTARTS   AGE
getting-started   1/1     Running   1          111s
```

可以發現這個 Pod 的 `Restart` 次數有增加，這是因為 Container Image 更新後，Pod 重啟，載入新的 Image 最後顯示出新的 log 資訊 *Hello world!-hwchiu-ithome*



到這邊我們就基本介紹了 Skaffold 的操作流程跟一個簡單 Demo, 如果對於這個工具有興趣的話可以嘗試玩玩看，將其整合到 Helm 或是 Kustomize 等不同部署方式，看看是否真的能夠提升自己的開發效率。


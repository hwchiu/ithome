Day 11 - Kubernetes 應用測試
===============================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀
更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



今天我們來探討到底在 CI 過程中，我們可以對 Kubernetes 應用做哪些測試?

我認為這個測試包含了

1. 應用程式是否於 Kuberentes 內運作如預期
2. 使用 Yaml 的話，則 Yaml 本身格式是否正確
3. 使用 Helm 的話，則 Helm 要求的內容與格式是否正確



而今天這篇文章主要會針對 (2),(3) 兩個部分來進行研究。

題外話，(2)(3) 這些格式檢查的部分不一定要 CI 階段才檢查，甚至可以跟 Git 整合， Pre-commit 階段就進行檢查，確保所有開發者提交的 Commit 都已經通過這些測試



# Yaml 測試

接下來探討一下 Yaml 這格式本身的驗證，這部分有兩個概念

1. Yaml 格式的正確性

2. Yaml 內容的合理性



(1) 因為確認的是格式的正確性，會針對 Yaml 的格式檢查，譬如縮排，雙引號，單引號等進行檢查，這部分可以透過 lint 等工具幫忙檢查，同時也可以確保團隊內的人擁有一致撰寫 Yaml 的習慣與格式。 基本上任何 Yaml 都可以進行這方面檢查，不論是 Kubernetes Yaml, Helm 或是其他的內容，譬如給 pipeline 系統的 yaml, 放設定檔案的 Yaml 都可以這麼做。

(2) 因為確認的是合理性，所以其實會需要有前後文的概念，舉例來說，今天要部署 Kubernetes Yaml，我們就可以針對 Yaml 的內容去確認是否符合 Kubernetes 的用法。

舉例來說，下列是一個合法的 Yaml 檔案，但是並不是一個合法的 Kubernetes Yaml。

```yaml
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```



所以我們需要一些方法來幫我們驗證所有的 Yaml 是否可以滿足 (1) 與 (2) 兩種情況，因此接下來我們列出幾個可能使用的工具，看看這些工具怎麼使用，以及使用上的效果



## Yamllint

[yamllint](https://github.com/adrienverge/yamllint) 官網介紹如下

> A linter for YAML files.
>
> yamllint does not only check for syntax validity, but for weirdnesses like key repetition and cosmetic problems such as lines length, trailing spaces, indentation, etc.

這個工具就是幫忙檢查一些寫法，但是並沒有語意的檢查，不過會針對一些 key 重複的問題也指證出來，以下有一些範例

這邊是一個完整沒錯誤的 Yaml 檔案

```yaml
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```



接下來我們對其修改，譬如加入一個重複的 Key, 然後讓底下的縮排格式不一致，長這樣

```yaml
kind: Cluster
apiVersion: kind.sigs.k8s.io/v1alpha3
nodes:
  - role: control-plane
  - role: worker
- role: worker
nodes: test
```



這種情狂下我們使用 yamllint 針對這個檔案檢查

```bash
$ yamllint kind.yaml
kind.yaml
  1:1       warning  missing document start "---"  (document-start)
  6:1       error    syntax error: expected <block end>, but found '-'
  7:1       error    duplication of key "nodes" in mapping  (key-duplicates)
```

第一行主要是警告，提醒要有文件的描述，但是不影響運行。

後面兩行則是不同的錯誤，分別是因為 第六行的縮排有問題，以及第七行產生一個重複 key 而導致的錯誤。



此外譬如字串雙引號/單引號沒有成雙等類型錯誤也都可以找到，有興趣的人可以去玩玩看這個工具



## Kubeeval

[kubeval](https://github.com/instrumenta/kubeval) 官方介紹如下

> `kubeval` is a tool for validating a Kubernetes YAML or JSON configuration file. It does so using schemas generated from the Kubernetes OpenAPI specification, and therefore can validate schemas for multiple versions of Kubernetes.

下列一個合法的 Kubernetes Yaml 檔案

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: getting-started
spec:
  containers:
  - name: getting-started
    image: hwchiu/netutils
```



我們可以先用 kubeeval 跑看看，接下來我們在修改這個檔案來試試看會有什麼樣的錯誤

```bash
$ ./kubeval pod.yaml
PASS - pod.yaml contains a valid Pod (getting-started)
```

接下來我們修改 Yaml 檔案，來進行一些修改讓他不合格，譬如少給一些欄位，或是多給一些欄位

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: getting-started
spec:
  ithome: ironman
```

以上就是一個不合格的 Pod Yaml, 首先多一個 `ithome` 的欄位，同時又少了 `containers` 這個資訊

首先我們透過 `kubeeval` 去跑一次，發現有得到一個警告，告知我們 `containers` 這個欄位是必須的，但是卻沒有給。

但是多出來的 ithome 卻沒有警告？

```bash
$ ./kubeval pod.yaml
WARN - pod.yaml contains an invalid Pod (getting-started) - containers: containers is required
$ ./kubeval -h
Validate a Kubernetes YAML file against the relevant schema

Usage:
  kubeval <file> [file...] [flags]

Flags:
      --additional-schema-locations strings   Comma-seperated list of secondary base URLs used to download schemas
  -d, --directories strings                   A comma-separated list of directories to recursively search for YAML documents
      --exit-on-error                         Immediately stop execution when the first error is encountered
  -f, --filename string                       filename to be displayed when testing manifests read from stdin (default "stdin")
      --force-color                           Force colored output even if stdout is not a TTY
  -h, --help                                  help for kubeval
      --ignore-missing-schemas                Skip validation for resource definitions without a schema
  -i, --ignored-filename-patterns strings     A comma-separated list of regular expressions specifying filenames to ignore
      --insecure-skip-tls-verify              If true, the server's certificate will not be checked for validity. This will make your HTTPS connections insecure
  -v, --kubernetes-version string             Version of Kubernetes to validate against (default "master")
      --openshift                             Use OpenShift schemas instead of upstream Kubernetes
  -o, --output string                         The format of the output of this script. Options are: [stdout json tap]
      --quiet                                 Silences any output aside from the direct results
      --reject-kinds strings                  Comma-separated list of case-sensitive kinds to prohibit validating against schemas
  -s, --schema-location string                Base URL used to download schemas. Can also be specified with the environment variable KUBEVAL_SCHEMA_LOCATION.
      --skip-kinds strings                    Comma-separated list of case-sensitive kinds to skip when validating against schemas
      --strict                                Disallow additional properties not in schema
      --version                               version for kubeval

```

從上面可以觀察到我們需要加入 `--strict` 這個參數，才會去檢查多出來不存在原本 schema 內的欄位，因此我們再跑一次看看

```bash
$ ./kubeval --strict pod.yaml
WARN - pod.yaml contains an invalid Pod (getting-started) - containers: containers is required
WARN - pod.yaml contains an invalid Pod (getting-started) - voa: Additional property voa is not allowed
```

這時候就可以順利的看到兩個錯誤都被抓出來了！



## Conftest

[conftest](https://github.com/open-policy-agent/conftest) 的官網說明如下

> Conftest is a utility to help you write tests against structured configuration data. For instance you could write tests for your Kubernetes configurations, or Tekton pipeline definitions, Terraform code, Serverless configs or any other structured data.



Conftest 這個工具可以幫助開發者去測試來驗證不同類型的設定檔案，譬如 Kubernetes, Tekton 甚至是 Terraform 的設定。

不過使用上必須要先撰寫相關的 Policy 去描述自己期望的規則，最後會幫你的設定檔案與相關的 Policy 去比對看看你的設定檔案是否破壞你的 Policy。



相對於前面的工具去針對 yaml 格式， kubernetes 資源的 schema 的比較， contest 更像是針對 policy 去比對，舉例來說，我們有一下列一個 pod yaml.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: getting-started
spec:
  containers:
  - name: getting-started
    image: hwchiu/netutils
  restartPolicy: Always
```



然後團隊今天有個要求，所有 `Pod` 的 Yaml 都必須要符合兩個規範

1. restartPolicy 只能是 Never
2. runAsNonRoot 這個欄位必須要設定是 True，希望可以以非 root 執行

只要有符合任何一個條件，我們希望 conftest 能夠找出來，並且告知錯誤，於是我們準備了下列檔案

```bash
$ cat policy/pod.rego
package main

deny[msg] {
  input.kind = "Pod"
  not input.spec.securityContext.runAsNonRoot = true
  msg = "Containers must not run as root"
}

deny[msg] {
  input.kind = "Pod"
  not input.spec.restartPolicy = "Never"
  msg = "Pod never restart"
}
```



我們使用了 `deny` 去描述兩個 policy, 只要符合這些 policy 的都會判錯

接下來我們用 conftest 去執行看看

```bash
$ conftest test pod.yaml  -p policy/
FAIL - pod.yaml - Containers must not run as root
FAIL - pod.yaml - Pod never restart

2 tests, 0 passed, 0 warnings, 2 failures, 0 exceptions
```

可以發現 conftest 認為系統中有兩個測試要跑，而這兩個測試都失敗

接下來我們修改檔案讓他符合我們的規則後再跑一次

```bash
$ cat pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: getting-started
spec:
  containers:
  - name: getting-started
    image: hwchiu/netutils
  restartPolicy: Never
  securityContext:
    runAsNonRoot: true
    
$ conftest test pod.yaml  -p policy/

2 tests, 2 passed, 0 warnings, 0 failures, 0 exceptions    
```



這時候就可以發現已經通過測試了，所以如果團隊中有這些需求的人可以考慮導入這個工具看看



# Helm 測試



Helm 的測試分成幾個面向，分別是

1. Helm Chart 的撰寫內容是否正確
2. Helm Chart 搭配 Config 後是否安裝會失敗



其中(2)這點不是什麼大問題，因為我們可以先透過 `helm template` 的方式讓它渲染出最後產生的 Kubernetes Yaml 檔案，而因為現在

是原生的 Kubernetes yaml 檔案了，所以就可以使用上述的三個工具來進行測試。



而 (1) 的部分主要會牽扯到 Helm 本身的資料夾跟架構，這邊我們可以使用原生的工具 `helm lint` 來進行或是透過 `helm install --dry-run` 的方式來嘗試裝裝看，一個簡單的範例如下

```bash
$ helm create nginx
Creating nginx
$ cd nginx/
$ helm lint
==> Linting .
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

我們透過 helm 指令創建了一個基本範例的結構，這時候用 helm lint 是沒有任何問題的，然後我們嘗試修改 template 裡面的內容，譬如 針對 go template 的格式進行一些修改，讓其錯誤。

```bash
$ echo "{}" >> templates/deployment.yaml
ubuntu@dex-test:~/nginx$ helm lint
==> Linting .
[INFO] Chart.yaml: icon is recommended
[ERROR] templates/deployment.yaml: unable to parse YAML: error converting YAML to JSON: yaml: line 45: did not find expected key
[ERROR] templates/deployment.yaml: object name does not conform to Kubernetes naming requirements: ""

Error: 1 chart(s) linted, 1 chart(s) failed
```

上述只是一個範例，有興趣的都可以到 Helm 官網去看更多關於 Helm lint 的討論與用法。



# 結論

本篇介紹了很多關於 Yaml 相關的工具，每個工具都會有自己的極限，沒有一個工具可以檢查出所有問題，這部分就是需要花時間去評估看看每個工具，看看哪些工具適合自己團隊，是否方便導入以及功能是否滿足

除了上述之外還有很多工具，譬如 kube-score, config-lint..等，有興趣的人都可以搜尋來玩耍看看
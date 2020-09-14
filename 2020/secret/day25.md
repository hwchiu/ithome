Day 25 - Secret 使用範例: sealed-secrets
===============================

本文同步刊登於筆者[部落格](https://hwchiu.com)
有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者
歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)



上篇文章中我們介紹了不同參考架構的解決方案，而本篇我們將使用 sealed-secrets 這個開源專案來實現其中一種架構，也就是最後一種基於加解密的解決方案。透過這個方案我們可以將機密資訊加密後存放到 Git 保存，但內容被部署到 Kubernetes 內部後則是會被自動解密



# 安裝

[Sealed-secrets](https://github.com/bitnami-labs/sealed-secrets) 本身有是由兩個元件組成，一個是 Kubernetes 內的 controller，而另外一個則是操作使用的 CLI。

等等我們會需要借助這兩個工具來處理，其中透過 Controller 來解密，而 CLI 要先跟 Controller 溝通取得憑證，最後加密



安裝 Controller 的方法很多種，可以使用原生 Yaml, Kustomize 或是 Helm 都可以

以下我們使用 Helm 來安裝，我們將服務安裝到 default namespace，並且取名為 ithome。

```bash
 $ helm repo add stable https://kubernetes-charts.storage.googleapis.com
 $ helm repo update
 $ helm install --namespace default ithome stable/sealed-secrets
```



接下來我們要安裝 CLI 的工具，這部分可以直接安裝編譯好的版本

```bash
 $ wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.12.5/kubeseal-linux-amd64
 $ chmod 755 kubeseal-linux-amd64
 $ sudo mv kubeseal-linux-amd64 /usr/local/bin
 $ kubeseal  --help
Usage of kubeseal:
      --add_dir_header                   If true, adds the file directory to the header
      --allow-empty-data                 Allow empty data in the secret object
      --alsologtostderr                  log to standard error as well as files
      --as string                        Username to impersonate for the operation
      --as-group stringArray             Group to impersonate for the operation, this flag can be repeated to specify multiple groups.
      --cert string                      Certificate / public key file/URL to use for encryption. Overrides --controller-*
      --certificate-authority string     Path to a cert file for the certificate authority
      --client-certificate string        Path to a client certificate file for TLS
      --client-key string                Path to a client key file for TLS
      --cluster string                   The name of the kubeconfig cluster to use
      --context string                   The name of the kubeconfig context to use
      --controller-name string           Name of sealed-secrets controller. (default "sealed-secrets-controller")
      --controller-namespace string      Namespace of sealed-secrets controller. (default "kube-system")
      --fetch-cert                       Write certificate to stdout. Useful for later use with --cert
  -o, --format string                    Output format for sealed secret. Either json or yaml (default "json")
      --from-file strings                (only with --raw) Secret items can be sourced from files. Pro-tip: you can use /dev/stdin to read pipe input. This flag tries to fol
low the same syntax as in kubectl
......
$ kubeseal
(tty detected: expecting json/yaml k8s resource in stdin)
error: cannot fetch certificate: services "sealed-secrets-controller" not found
```

這邊執行會失敗是因為預設情況下， kubeseal 會嘗試跟 `sealed-secrets-controller` 這個 service 去溝通，取得相關資訊，但是因為我們透過 helm 安裝的關係，名稱不會一致，所以執行的時候要透過 --controller-name 以及 --controller-namespace 兩個來替換掉到我們安裝的名稱與 namespace。

```bash
$ kubeseal --controller-name=ithome-sealed-secrets --controller-namespace=default
(tty detected: expecting json/yaml k8s resource in stdin)
^C
```

改成上述執行就不會有獲取憑證失敗的問題了，這時候可以按下 CTRL+C 給跳出。因為 kubeseal 的工作很簡單，給我 kubernetes secret 檔案，我給你加密後的結果。預設情況是從 STDIN 輸入。



# 使用

接下來的示範流程如下

1. 準備一個 kubernetes secret，決定使用 docker login 後產生的 login.json
2. 將該 kubernetes secret 透過 kubeseal 產生出一個 sealedsecret 的物件，該物件的內容是加密，不是 secret 的編碼
3. 將 sealedsecret 這個物件部署到 kubernetes 內，觀察是否有產生全新的 secret 內容
4. 檢查該 secret 的內容，與(1)產生的一樣
5. 透過反解 base64 編碼，確認內容與 login.json 一致





```bash
$ kubectl create secret generic ithome-example --from-file=.dockerconfigjson=/home/ubuntu/.docker/config.json --type=kubernetes.io/dockerconfigjson --dry-run=client -o yaml > secret.yaml
$ kubeseal --controller-name=ithome-sealed-secrets --controller-namespace=default -o yaml < secret.yaml  > sealedsecret.yaml
$ cat sealedsecret.yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: ithome-example
  namespace: default
spec:
  encryptedData:
    .dockerconfigjson: AgBOq/FUB4OSIjOfua8vikrosi9R6uFROuAeT0rV3myf4memo+Y3LwP9mDGsswcUhFk5N29BS1V76ycLX31a8IbzON40AWJAnclSn9qWoj+ZDZmD1p+1OSPCdjV5FjDhVnGNwi49DAvr+L+WLREGdD2fgizVWq+Ebk7acFjmI2uGq7J2yoocH+/qpX/13e2kj36J7+Rwd+RBhnkKTImlQJsXjKsBYENxjsRnc+UzNjkXjBcXEYihHq9MIXdtElPG1Kur27pIC+urj9FkWnQ4lO2tUoI3NDIuQFCvKaeAwEP0cu+3wlY0F2Ax2/CT0SQ9WB0VM8iyrNaccFDuItGnqRksya0WtXLV4fYafbxR4+itzCpt8sH0VOUouoDml9FqAgLfWrqld74VnEpSJybdf/Wfea3PYLFTDScHClWDW7qBTvZmkCIWDS44/HNcQdflpnrmLJk2sxO20T6aJPYDK9M7V5iD0b7Ch8OHNmL/8e/kDhaCTVqUcUXw2qtx7LBJhaxalSoYfhzvwFIDG9AbRe95d2oQJpXl6mHviNqJkOqNiU5M6Byt3YXR+YaFV+A9n0aj6Rl0Bw8y4s9+0LoXrTdv2t3opSe26xOJhmgfOxuxELKY+kaATNpLYez3+S3QaTgDZ0n7tgTzFg041brOL3SkUa+UZ9MqUG9XKMPGXQY0lFf5DhB1FIjWiCOWfOS+JAJsG38izjd8iYZ8wIWIoe983exo2AaCcLS+4cB18ftwoDmlYn8Y+WqmEtzhZA8OMsk4KTSsWPakWFc8rbxRt6aHTER0enXof86B2V/TwxDuPzN4OWmcO7mSMUgdXxbAnRLKVfmuVwYEYTW91wZN5+IQWZVTHwZnXS+ahHzV7TS+zFF74F06yz7Tx6YRQUmnWUH8HJiuxPTNeZbKkvcD7Q==
  template:
    metadata:
      creationTimestamp: null
      name: ithome-example
      namespace: default
    type: kubernetes.io/dockerconfigjson
```

首先透過 `kubectl create secret` 就如同之前 harbor 的範例一樣，產生出一個 secret.yaml，其內容其實是編碼後的 config.json

接下來，透過 kubeseal 的指令，把剛剛的 secret.yaml 傳進去，然後最後產生出一個 sealedsecret.yaml 檔案。我們可以觀察到這個檔案裡面的內容跟 kubernetes secret 很類似，多了一個 `encryptedData` 的欄位，下面的資訊都是加密後，並不是編碼。這個物件`就是我們可以放在 Git`內保存的。



接下來我們把這個物件送到 kubernetes 內，然後我們馬上觀察 `SealedSecret` 以及 `Secret`，的確有一個全新的 `Secret` 產生了，名稱就是我們前面用的 `ithome-example`。

```bash
$ kubectl apply -f sealedsecret.yaml
sealedsecret.bitnami.com/ithome-example created
$ kubectl get SealedSecret
NAME             AGE
ithome-example   12s
$ kubectl get secret ithome-example
NAME             TYPE                             DATA   AGE
ithome-example   kubernetes.io/dockerconfigjson   1      16s
```

現在來觀察產生出來的 `secret` 跟我們最原始的 `secret` 內容是否一致，主要觀察 `data` 內部的資料，可以發現 `.dockerconfigjson` 的編碼結果是完全一致的

```bash
$ kubectl get secret ithome-example -o yaml
apiVersion: v1
data:
  .dockerconfigjson: ewoJImF1dGhzIjogewoJCSJyZWdpc3RyeS5od2NoaXUuY29tIjogewoJCQkiYXV0aCI6ICJZV1J0YVc0NlNHRnlZbTl5TVRJek5EVT0iCgkJfQoJfSwKCSJIdHRwSGVhZGVycyI6IHsKCQkiVXNlci1BZ2VudCI6ICJEb2NrZXItQ2xpZW50LzE5LjAzLjEyIChsaW51eCkiCgl9Cn0=
kind: Secret
metadata:
  creationTimestamp: "2020-09-14T05:31:36Z"
  name: ithome-example
  namespace: default
  ownerReferences:
  - apiVersion: bitnami.com/v1alpha1
    controller: true
    kind: SealedSecret
    name: ithome-example
    uid: a6fa91c0-eb90-403b-baea-5aabc979212c
  resourceVersion: "1025425"
  selfLink: /api/v1/namespaces/default/secrets/ithome-example
  uid: 8546ec86-6e51-4a20-883f-f403ac2b450a
type: kubernetes.io/dockerconfigjson
$ cat secret.yaml
apiVersion: v1
data:
  .dockerconfigjson: ewoJImF1dGhzIjogewoJCSJyZWdpc3RyeS5od2NoaXUuY29tIjogewoJCQkiYXV0aCI6ICJZV1J0YVc0NlNHRnlZbTl5TVRJek5EVT0iCgkJfQoJfSwKCSJIdHRwSGVhZGVycyI6IHsKCQkiVXNlci1BZ2VudCI6ICJEb2NrZXItQ2xpZW50LzE5LjAzLjEyIChsaW51eCkiCgl9Cn0=
kind: Secret
metadata:
  creationTimestamp: null
  name: ithome-example
type: kubernetes.io/dockerconfigjson
```



最後再來檢查反編碼後的結果，這邊我使用了 view-secret 這個 kubectl plugin 來自動幫忙反編碼，同時也比對最原始的 ~/.docker/config.json，最後確認兩者內容一致。

```bash
$ kubectl view-secret ithome-example
Choosing key: .dockerconfigjson
{
        "auths": {
                "registry.hwchiu.com": {
                        "auth": "YWRtaW46SGFyYm9yMTIzNDU="
                }
        },
        "HttpHeaders": {
                "User-Agent": "Docker-Client/19.03.12 (linux)"
        }
}
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
}
```



到這邊我們的 Demo 就告了一個段落，我們透過 kubeseal 來幫忙加密，加密後的結果是一個名為 SealedSecret 的物件，其內容都是加密後的樣式，我們可以直接存放於 Git 裡面，這樣的話 GitOps 的模式也可以套用上去。

[SealedSecret](https://github.com/bitnami-labs/sealed-secrets) 官網上面還有更多關於 Key 的操作，包含 Renew, 更新等各種進階用法，如果對這個開源軟體有興趣的人歡迎玩耍看看


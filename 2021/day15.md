Day 15 - Rancher 與 Infrastructure as Code
==========================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)

# 前言

前篇探討了各式各樣透過 Rancher UI 來管理 Rancher, Kubernetes 的各種方式，所有的操作基本上都是基於 UI 點擊而完成的。

試想下列情境，是否會覺得某些情況還是有點卡?
1. 公司想要有針對不同環境有不同的 Rancher 叢集，譬如 Production 跟其他要分開
2. 希望能夠減少管理員透過 UI 管理的頻率，畢竟透過 UI 點選創建有時並不會有太完善的稽核性
3. 有快速重複部署 RKE 叢集的需求，某些情況還需要刪除重建

上述這些要求全部都可以用之前分享的方式慢慢處理，不過會不會有更好的方式處理?
這幾年流行的 IaC 架構， Infrastructure as Code 的概念能不能套用到 Rancher 身上?
試想一下如果可以透過程式碼的方式定義 Rancher，對於開發者與管理者來說可以達到什麼樣的好處
1. 當 Rancher 整個損毀，需要重新安裝或是需要部署類似環境時，可以非常快的部署，不需要重新透過手動的方式去重新設定所有細節
2. 所有重大操作都以程式碼為基礎去設定，減少任何人為操作的可能性，同時有任何出錯時可以基於程式碼重新部署來修復環境。
3. 複製程式碼就可以複製環境，修改一些變數就可以創建出類似的叢集

更重要的是，如果將這些 IaC 的概念與 CI/CD 流程整合，還可以透過 Code Review 的方式來合作檢視所有 Rancher 上的修改，同時透過自動化的方式去維護 Rancher 服務。
有任何不適當的修改想要復原也可以透過 Git Revert 的方式來回復到之前的狀態。
這種狀況下 Rancher 會變得更加容易維護與管理。


# IaC

IaC 的工具非常的多，當人們講到跟 Cloud Infrastructure 有關時，大部分人都會提到 Terraform 這套解決方案，而近年 Pulumi 的聲勢也漸漸提昇，愈來愈多人嘗試使用 Pulumi 來取代 Terraform，兩者最大的差別在於撰寫方式。
Terraform 有自己設計一套語法，意味使用 Terraform 就要使用該語法，而 Pulumi 則是基於不同的程式語言提供不同的 API 來使用ㄓ，所以開發者可以使用自己習慣的程式語言去撰寫。

本篇文章將介紹如何透過 Terraform 來管理我們的 Rancher，之後的章節有機會的話也會順便展示一下使用 Terraform 的寫法。

# Terraform

關於 Terraform 的使用方式推薦參閱我好朋友 [David 所撰寫的 Terraform 系列文章]
(xxx)

本篇文章就不會探討太多 Terraform 的基本概念與使用方式，會更加專注於如何透過 Terraform 來管理 Rancher。

Terraform 官網中有非常詳細的資訊探討 Rancher 所有 API 的使用方式，有興趣可以參閱[Rancher2 Provider](https://registry.terraform.io/providers/rancher/rancher2/latest/docs)

為了要能夠跟 Rancher 溝通，必須要先獲得一組 Access/Secrey Key 來存取 Rancher，這組 Key 可以從 Rancher 的使用者帳號去取得。

首先用一個可以管理 Rancher 的帳號登入到 Rancher UI，接者於右上方使用者那邊去點選 API & Keys，如下圖。

![](https://i.imgur.com/KgJ6v60.png)

進去之後可以看到系統預設有一些 Key，這些忽略即可。
要注意的是，每組 Key 產生後都會得到一組對應的 Secret Key，該 Key 是沒有辦法透過 UI 找回來的，這意味如果你當下忘了儲存或是之後不見了，那這把 secret key 就再也沒有辦法找回。

點選右上方的 Add Key 可以看到如下的畫面，該畫面可以先設定該 Key 會不會自動過期的時間，以及使用範圍。

![](https://i.imgur.com/Xip7yz6.png)


設定名稱後就會看到如下圖的畫面，畫面中有四種相關不同的資訊，分別是
1. Access Endpoint: 存取的 API 位置
2. Access Key
3. Secret Key(只有這邊會出現，一但按下 Close 就再也拿不回來了)
4. 針對 HTTP 需求譬如 kubectl 是有機會直接使用最後一個 Bearer Token 使用

![](https://i.imgur.com/gBJ7sKJ.png)

這次的 Terraform 要使用前三組資訊，這邊不考慮任何 Terraform 的撰寫技巧與 Style，單純用最簡單的風格來介紹如何將 Terraform 與 Rancher 整合。

以下示範是基於 Terraform 1.0 與 Rancher Provider 1.17.0 的版本

首先準備一個 main.tf 的檔案，內容如下
```bash
╰─$ cat main.tf
terraform {
  required_providers {
    rancher2 = {
      source = "rancher/rancher2"
      version = "1.17.0"
    }
  }
}

provider "rancher2" {
  api_url    = "https://rancher.hwchiu.com"
  access_key = "token-ng6df"
  secret_key = "l8kjh7w5mdb5s5nzmp56c5rctpt59p9bcq9wbw2g8b66wsdchrkdv2"
}
```

接者透過 Terraform init 先初始化相關模組
```bash
╰─$ terraform init
Initializing the backend...

Initializing provider plugins...
- Finding rancher/rancher2 versions matching "1.17.0"...
- Installing rancher/rancher2 v1.17.0...
- Installed rancher/rancher2 v1.17.0 (signed by a HashiCorp partner, key ID 2EEB0F9AD44A135C)

Partner and community providers are signed by their developers.
If you'd like to know more about provider signing, you can read about it here:
https://www.terraform.io/docs/cli/plugins/signing.html

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

一切都準備完畢後，接下來示範一下如何透過 Rancher 來創造一些 Rancher 的資源，譬如說來創造一個 [RKE Template](https://registry.terraform.io/providers/rancher/rancher2/latest/docs/resources/cluster_template)。

這邊直接參考範例將下列內容寫入到 main.tf 中
該範例會創建一個 RKE Template 並且針對 etcd 以及一些更新策略進行設定。

```
$ cat main.tf
terraform {
  required_providers {
    rancher2 = {
      source = "rancher/rancher2"
      version = "1.17.0"
    }
  }
}

provider "rancher2" {
  api_url    = "https://rancher.hwchiu.com"
  access_key = "token-ng6df"
  secret_key = "l8kjh7w5mdb5s5nzmp56c5rctpt59p9bcq9wbw2g8b66wsdchrkdv2"
}

resource "rancher2_cluster_template" "foo" {
  name = "ithome_terraforn"
  template_revisions {
    name = "V1"
    cluster_config {
      rke_config {
        network {
          plugin = "canal"
        }
        services {
          etcd {
            creation = "6h"
            retention = "24h"
          }
        }
        upgrade_strategy {
          drain = true
          max_unavailable_worker = "20%"
        }
      }
    }
    default = true
  }
  description = "Terraform cluster template foo"
}
```

接者透過 terraform apply 去更新
```bash
$ terraform apply
...
              + rke_config {
                  + addon_job_timeout     = 0
                  + ignore_docker_version = true
                  + kubernetes_version    = (known after apply)
                  + prefix_path           = (known after apply)
                  + ssh_agent_auth        = false
                  + ssh_cert_path         = (known after apply)
                  + ssh_key_path          = (known after apply)
                  + win_prefix_path       = (known after apply)

                  + network {
                      + mtu     = 0
                      + options = (known after apply)
                      + plugin  = "canal"
                    }

                  + services {
                      + etcd {
                          + ca_cert    = (known after apply)
                          + cert       = (sensitive value)
                          + creation   = "6h"
                          + extra_args = (known after apply)
                          + gid        = 0
                          + image      = (known after apply)
                          + key        = (sensitive value)
                          + path       = (known after apply)
                          + retention  = "24h"
                          + snapshot   = false
                          + uid        = 0
                        }
                    }

                  + upgrade_strategy {
                      + drain                        = true
                      + max_unavailable_controlplane = "1"
                      + max_unavailable_worker       = "20%"
                    }
                }
            }
        }
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

rancher2_cluster_template.foo: Creating...
rancher2_cluster_template.foo: Creation complete after 2s [id=cattle-global-data:ct-rtd4f]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

一切創造完畢後就可以移動到 Rancher UI 中，從 RKE Template 可以看到多出了一個新的 RKE Template，名稱為 ithome_terraform，與我們前述 main.tf 中描述的一樣。

![](https://i.imgur.com/VISDJn9.png)

點進去該 RKE Template 就可以看到詳細的設定，這邊要補充一下， Rancher 大部分的物件都提供兩種閱覽模式，一種是友善的 UI 介面另一種則是純 YAML 的描述檔案。
按照下方的方式點選 View as a Form 來看看基於 YAML 的內容。

![](https://i.imgur.com/o8W7jBz.png)

從 YAML 內就可以看到 Terraform 描述的設定都有正確的寫進來。

![](https://i.imgur.com/LUrbVVN.png)

透過這樣簡單的方式，就可以使用程式碼的方式來管理 Rancher，除了 RKE Template 之外， Cloud Credential, Node Template, Cluster 也都可以透過 Terraform 的方式來管理，這樣有另外一個好處就是系統管理員只要撰寫好這些資源後，接下來的使用者就不需要接觸到這些太細節的機密資訊，能夠專心的目標資源與邏輯去描述與創造即可。

最後這邊要再補充一個使用 API 溝通 Rancher 的好處，事實上， Rancher UI 沒有辦法展現 Rancher 100% 的能力， RKE 內有非常多的設定可以處理，但是有些處理實際上沒有辦法透過 UI 去設定，譬如說想要針對 Kubelet 給一些額外參數的話，這些設定是沒有辦法從 Rancher UI 完成的，但是如果是透過 Rancher API 來設定的話就沒有問題。

Rancher API 有很多方式可以處理，不論是直接撰寫應用程式溝通 Rancher 或是使用 Terraform/Pulumi 等工具都可以，透過這類型工具去描述 Rancher 實際上可以將 Rancher 使用的更靈活與更強大，設定的東西也更多元化。

如果團隊有意願長期使用 Rancher，會非常推薦使用 IaC 的工具來維護與管理 Rancher，期帶來得好非常的多。
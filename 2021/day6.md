Day 6 - Rancher 系統管理指南 - 使用者登入管理
========================================

本文將於賽後同步刊登於筆者[部落格](https://hwchiu.com/)

有興趣學習更多 Kubernetes/DevOps/Linux 相關的資源的讀者，歡迎前往閱讀

更多相關科技的技術分享，歡迎追蹤 [矽谷牛的耕田筆記](https://www.facebook.com/technologynoteniu)

對於 Kubernetes 與 Linux Network 有興趣的可以參閱筆者的[線上課程](https://course.hwchiu.com/)


# 前言
前篇文章透過 rke / helm 成功的搭建了一個 Rancher 服務，並且於第一次登入時按照系統要求創建了一組給 admin 使用的密碼，並且使用該 admin 的帳號觀察到了第一組創建被 Rancher 管理的 Kubernetes 叢集。

    複習: 該 K8s 叢集並不是 Rancher 創造的，而是我們事先透過 rke 創造用來部署 Rancher 服務的 k8s 叢集。

對於 IT 管理人員來說，看到一個新的服務通常腦中會閃過的就是該服務的使用者管理權限該怎麼處理? 最直觀也簡單的方式就是透過該服務創建眾多的本地使用者，每個使用者給予不同的權限與帳號密碼。但是這種使用方式實務上會有太多問題
1. 團隊內員工通常不喜歡每一個服務都有獨立的密碼，最好能夠用一套密碼去存取公司內所有服務
2. 員工數量過多時，通常團隊也很懶得幫每個員工都獨立創造一份帳號密碼，更常發生的事情是一套帳號密碼多人共同使用。
3. 多人共同使用的問題就是會喪失了稽核性，沒有辦法知道是誰於什麼時間點進行什麼操作，未來要除錯與找問題時非常困難
4. 如果權限還想要用群組來管理時，整個要處理的事情就變得又多又複雜
5. 由於帳號密碼都是服務本地管理，這意味團隊內的帳號密碼是分散式的架構，因此有人想要改密碼就需要到所有系統去改密碼，這部分也是非常不人性化，特別如果員工離職時，要是有服務忘了刪除可能會造成離職員工還有能力去存取公司服務。

因此大部分的 IT 都不喜歡使用本地帳號，更喜歡使用混合模式來達到靈活的權限管理。
1. 服務想辦法整合外部的帳號密碼系統，常見的如 Windows AD, LDAP, GSuite, SMAL, OpenID, Crowd 等。
2. 每個服務都維持一個本地使用者，該使用者是管理員的身份，作為一個緊急備案，當外部帳號密碼系統出問題導致不能使用時，就必須要用本地使用者來存取。

混合模式的架構下，所有員工的帳號與密碼都採用集中式管理，任何第三方服務都要與該帳號系統整合，因此
1. 員工只需要維護一套帳號密碼即可登入團隊內所有服務，如果員工需要改密碼，也只需要改一個地方即可
2. IT 人員可以統一管理群組，每個第三方服務針對群組去進行權限控管即可。
3. 這種架構下不會有共享帳號密碼的問題，每個使用者登入任何系統都會有相關的日誌，未來除錯也方便

因此本篇文章就來探討 Rancher 提供何種使用者登入與權限控管，系統管理員架設維護時可以如何友善的去設定 Rancher

# Authorization 授權

Rancher 的世界中將權限分成三大塊，由大到小分別是
1. Global Permission
2. Cluster Role
3. Project Role

其中 Cluster/Project 這個概念要到後面章節探討如何用 Rancher 去架設與管理 Kubernetes 叢集時才會提到，因此這邊先專注於第一項，也就是 Global Permission。

Global Permission 代表的是 Rancher 服務本身的權限，本身跟任何 Kubernetes 叢集則是沒有關係。
Rancher 本身採用 RBAC (Role-Based Access Control) 的概念來控制使用者的權限，每個使用者會依據其使用者名稱或是所屬的群組被對應到不同Role。

Global Permission 預設提供多種身份，每個身份都有不同的權限，以下圖來看(Security->Roles)
![](https://i.imgur.com/iyafxS0.png)

圖中是預設的不同 Role，每個 Role 都有各自的權限，同時還可以去設定說當一個新的外部使用者登入時，應該要賦予何種 Role
權限部分是採取疊加狀態的，因此設計 Role 的時候都是以 "該 Role 可以針對什麼 API 執行什麼指令"，沒有描述到的就預設當作不允許。
因此 Role 是可以互相疊加來達到更為彈性的狀態，當然預設 Role 也可以有多個。

註: 本圖片並不是最原始的 Rancher 設定，預設狀態有被我修改過，請以自己的環境為主。


Role 這麼多種對於初次接觸 Kubernetes 與 Rancher 的管理員來說實在太複雜與太困難，因此 Rancher 又針對這些 Role 提供了四種好記的名稱，任何使用者與群組都可以基於這四種 Role 為基礎去添加不同的 Role 來達到靈活權限。

這四種好記的 Role 分別為

1. Administration
超級管理員，基本上什麼都可以操作，第一次登入時所使用的 admin 帳號就屬於這個權限

2. Restricted Admin
能力近乎於超級管理員，唯一不能管理的就是 Rancher 本身所在的 kubernetes 叢集，也就是前篇文章看到的 local 叢集。

3. Standard User: 可以透過 Rancher 創建 Kubernetes 叢集 並且使用的使用者，大部分情況下可以讓非管理員角色獲得這個權限，不過因為創建過多的 Kubernetes 叢集有可能會造成成本提高，所以賦予權限時也要注意到底什麼樣的人可以擁有創造 kubernetes 叢集的權限。

4. User-Base: 基本上就是一個 read-only 的使用者，同時因為本身權限很低，能夠看到的資訊非常少，更精準的來說就是一個只能登入的使用者。

# Authentication 認證

前述探討如何分配權限，接下來要探討的就是要如何幫使用者進行帳號密碼的驗證，這部分 Rancher 除了本地使用者之外也支援了各式各樣的第三方服務，譬如
1. Microsoft Active Directory
2. GitHub
3. Microsoft Azure AD
4. FreeIPA
5. OpenLDAP
6. Microsoft AD FS
7. PingIdentity
8. Keycloak
9. Okta
10. Google OAuth
11. Shibboleth

Rancher v2.6 的其中一個目標就是支援基於 OIDC 的 Keycloak ，因此如果團隊使用的是基於 OIDC 的 Keycloak 服務，讀者不仿可以期待一下 v2.6 的新功能。

使用者可以於 security->authentication 頁面看到如下的設定頁面
![](https://i.imgur.com/VCEGFwD.png)

[官方網站中](https://rancher.com/docs/rancher/v2.5/en/admin-settings/authentication/)有針對上述每個類別都提供一份詳細的教學文件，要注意的是因為 Rancher 版本過多，所以網頁本身的內容有可能你會找到的是舊的版本，因此閱讀網頁時請確保你當前看到的版本設定方式與你使用的版本一致。

預設情況下，管理者只能針對一個外部的服務進行認證轉移，不過這只是因為 UI 本身的設定與操作限制，如果今天想要導入多套機制的話是可以從 Rancher API 方面去進行設定，對於這功能有需求的可以參考這個 Github Issue [Feature Request - enabling multiple authentication methods simultaneously #24323
](https://github.com/rancher/rancher/issues/24323)

# 實戰演練
上述探討完了關於 Rancher 基本的權限管理機制後，接下來我們就來實際試試看到底用起來的感覺如何。
由於整個機器都是使用 Azure 來架設的，因此第三方服務我就選擇了 Azure AD 作為背後的使用者權限，之後的系列文章也都會基於這個設定去控制不同的使用者權限。


下圖是一個想要達到的設定狀況
![](https://i.imgur.com/V4ltM3u.png)

Rancher 本身擁有一開始設定的本地使用者之外，還要可以跟 Azure AD 銜接
而 Azure AD 中所有使用者都會分為三個群組，分別是
1. IT
2. QA
3. DEV

我希望 IT 群組的使用者可以獲得 Admin 的權限，也就是所謂整個 Rancher 的管理員。
而 QA/DEV 目前都先暫時給予一個 User-Base 的權限，也就是只能單純登入然後實際上什麼都不能做。
這兩個群組必須要等到後面探討如何讓 Rancher 創建叢集時才會再度給予不同的權限，因此本篇文章先專注於 Rancher 與 AD 的整合。

本篇文章不會探討 Azure AD 的使用方式與概念，因此我已經於我的環境中創建了相關的使用者以及相關的群組。

整合方面分成兩大部分處理
1. Azure AD 與 Rancher 的整合
2. Rancher 內的 Roles 設定

Azure AD 的部分可以參考[官方教學](https://rancher.com/docs/rancher/v2.5/en/admin-settings/authentication/azure-ad/)，裡面有非常詳細的步驟告知要如何去 Azure 內設定，這邊要特別注意就是千萬不要看錯版本，以及最後填寫 Azure Endpoints 資訊時版本不要寫錯。

下圖是 Rancher 內的設定，其中 Endpoints 部分要特別小心
![](https://i.imgur.com/ax64iqp.png)
1. Graph 要使用 https://graph.windows.net/ 而不是使用 Azure UI 內顯示的 https://graph.microsoft.com
2. Token/Authorization 這兩個要注意使用的是 OAUTH 2.0 (V1) 而不是 V2

下圖是 Azure 方面的設定，所以使用時要使用 V1 的節點而不是 V2，否則整合時候會遇到各種 invalid version 的 internal error.
![](https://i.imgur.com/IuUKY2c.png)

當這一切整合完畢後重新登入到 Rancher 的畫面，應該要可以看到如下圖的畫面
![](https://i.imgur.com/D2e966r.png)

畫面中告知 Rancher 的登入這時候分成兩種方式，分別是透過 Azure AD 以及使用本地使用者登入。

# 權限控制

當與 Azure AD 整合完畢後，首先要先透過本地使用者進行權限設定，因為本地使用者本身也是 Admin 的關係，因此可以輕鬆地去修改 Rancher。

如同前面所提，希望整體權限可以是
1. IT 群組的人為超級使用者
2. DEV/QA 群組的人為只能登入的使用者 (User-Base)。

同時這邊也要注意，因為 Rancher 的使用者與群組兩個權限是可以分別設定且疊加的，因此設定的時候必須要這樣執行
1. 將所有第一次登入的外部使用者的預設使用者都改為 (User-Base)
2. 撰寫群組的相關規則，針對 IT/DEV/QA 進行處理。

預設情況下， Rancher 會讓所有第一次登入的使用者都給予 Standard-User 的權限，也就是能夠創建 k8s 叢集，這部分與我們的需求不同。

所以第一步驟，移動到 security->roles 裡面去修改預設使用者身份，取消 User 並且增加 User-Base
![](https://i.imgur.com/iyafxS0.png)

第二步驟則是移動到 security-groups 內去針對不同 Group 進行設定

針對 IT 群組，給予 Administrator 的權限
![](https://i.imgur.com/0eGU3wk.png)

針對 Dev 群組給予 User-Base 的權限
![](https://i.imgur.com/mS7KGRR.png)

最後看起來會如下
![](https://i.imgur.com/FuOr5fU.png)

到這邊為止，我們做了兩件事情
1. 所有新登入的使用者都會被賦予 User-Base 的權限
2. 當使用者登入時，會針對其群組添加不同權限
如果是 IT，則會添加 Administrator 的權限，因此 IT 群組內的人就會擁有 User-Base + Administrator 的權限
如果是 DEV/QA 的群組，則會添加 Base-User 的權限，因此該群組內的人就會擁有 User-Base + User-Base 的權限，基本上還是 User-Base。

設定完畢後就可以到登入頁面使用事先創立好的使用者來登入。

當使用 Dev 群組的使用者登入時，沒有辦法看到任何 Cluster
![](https://i.imgur.com/Tnje1fo.png)

相反的如果使用 IT 群組的使用者登入時，則因為屬於 Administrator 的權限，因此可以看到系統上的 RKE 叢集。
![](https://i.imgur.com/lHegkUC.png)


本篇文章探討了基本權限控管的概念並且展示了使用 Azure AD 後的使用範例，一旦瞭解基礎知識後，接下來就是好好研究 Rancher 內有哪些功能會使用到，哪些不會，針對這部分權限去進行設定，如果系統預設的 Role 覺得不夠好用時，可以自行創立不同的 Roles 來符合自己的需求，並且使用使用者與群組的概念來達到靈活的設定。

下篇文章將會使用 IT 的角色來看看到底 Rancher 上還有什麼設定是橫跨所有 Kubernetes 叢集，以及這些設定又能夠對整個系統帶來什麼樣的好處。

# manifest-template

ArgoCD と GitHub Actions での検証を始めるための GitOps manifest template です。

参照: [infra-template](https://github.com/gmo-media/infra-template)

## ディレクトリ構造

ArgoCD の "root" Application は `./dev/.applications` ディレクトリを読み込みます。
ApplicationSet は `./dev/*` 配下のアプリケーションを検出し、ディレクトリ名が
アプリケーション名と namespace 名に対応します。

```plaintext
manifest
├── dev
│   ├── .applications
│   │   ├── application-set.yaml
│   │   └── kustomization.yaml
│   └── my-app
│       ├── resource-1.yaml
│       ├── resource-2.yaml
│       └── kustomization.yaml
└── prod
    ├── .applications
    │   ├── application-set.yaml
    │   └── kustomization.yaml
    └── my-app
        ├── resource-1.yaml
        ├── resource-2.yaml
        └── kustomization.yaml
```

## セットアップ

### Kubernetes クラスタのセットアップ

このリポジトリは、すでに Kubernetes クラスタを所有していることを前提としています。
開始するには [infra-template](https://github.com/gmo-media/infra-template) を参照してください。
初期リソースをデプロイするために `kubectl apply` が実行できることを確認してください。

### このテンプレートからリポジトリを作成

開始するには、このページの右上にある "Use this template" ボタンを押してください。

リポジトリに [recommended-ruleset.json](.github/recommended-ruleset.json) をインポートすることをお勧めします
(Settings -> Rules -> Rulesets -> Import a ruleset)。
ruleset は必要に応じて調整してください。

意図的に "Deploy keys" が ruleset をバイパスできるようにしています。
これは、他の CI/CD システムがこのリポジトリの `main` ブランチに直接 push できるようにするためです。

### sops / age のセットアップ

1. [sops](https://github.com/getsops/sops) と [age](https://github.com/FiloSottile/age) をローカルにインストールします。
2. `age-keygen -o key.txt` を実行して鍵ペアを生成します。
    - `key.txt` は秘密鍵なので、安全に保管してください。
    - 公開鍵は標準出力に表示されます。これを `.sops.yaml` に設定してください。
3. `argocd` namespace に `age-key` という名前の Secret を作成します。
    - `kubectl create ns argocd && kubectl create secret generic age-key -n argocd --from-file=key.txt`
    - これは `./dev/argocd` manifest から参照されます。
4. `key.txt` を安全な場所に保管するか、不要であれば削除してください。
    - macOS での推奨保存先: `$HOME/Library/Application Support/sops/age/keys.txt`
    - https://github.com/getsops/sops?tab=readme-ov-file#23encrypting-using-age

### secret の扱い方

sops で暗号化されたファイルを操作するための各種ユーティリティスクリプトについては、`scripts/secret-*.sh` を参照してください。

最も基本的なもの:
- `scripts/secret-encrypt.sh`: ファイルを暗号化します。
- `scripts/secret-set-key.sh`: 暗号化されたファイルに key-value ペアを設定します。
- `scripts/secret-set-key-base64.sh`: 値に特殊文字が含まれる場合はこちらを使用してください。

age 暗号化は非対称暗号であるため、`secret-decrypt.sh` や `secret-edit.sh` を使用したり、
ローカルに秘密鍵を持つ必要はおそらくありません。
暗号化されたファイルを public リポジトリにコミットすることも可能です。

`scripts/secret-encrypt.sh` でファイルを暗号化した後（通常は `./dev/*/secrets/*.yaml` に配置）、
[ksops](https://github.com/viaduct-ai/kustomize-sops) ファイル（通常は `./dev/*/ksops.yaml` に配置）から参照してください。

```yaml
apiVersion: viaduct.ai/v1
kind: ksops
metadata:
  name: ksops
  annotations:
    config.kubernetes.io/function: |
      exec:
        path: ksops

files:
  - ./secrets/argocd-secret.yaml
  - ./secrets/notifications.yaml
```

> [!NOTE]
> このテンプレートに含まれるファイルは、すでにサンプル鍵で暗号化されています。
> YAML 内の `sops` キーを削除し、内容を実際の値に置き換えてから、
> `scripts/secret-encrypt.sh <filename>` を実行してファイルを暗号化してください。
> 必要に応じて `ksops.yaml` を更新してください。

### Karpenter のインストール

[infra-template](https://github.com/gmo-media/infra-template) でクラスタを作成した場合、
関連する node group がないため、まだ通常の node / pod をスケジュールできません。
通常の pod 用の node をプロビジョニングするために Karpenter を使用します。

1. `./dev/karpenter/values.yaml` と `./dev/karpenter/default.yaml` のプレースホルダーを設定します。
2. `karpenter` namespace を作成します: `kubectl create ns karpenter`
3. Karpenter をデプロイします: `scripts/build.sh ./dev/karpenter | kubectl apply -f -`

Karpenter controller 自体は Fargate node 上でスケジュールされる想定です。
対応する Fargate profile は [infra-template](https://github.com/gmo-media/infra-template) で作成されます。

### ArgoCD のインストール

値を設定するには `./dev/argocd/values.yaml` を参照してください。
おそらく以下を変更する必要があります:
- `global.domain`: ArgoCD のホスト名
- `configs.cm."oidc.config"`: OIDC 設定
- `configs.rbac`: RBAC 設定

その後:
1. ArgoCD をデプロイします: `scripts/build.sh ./dev/argocd | kubectl apply -f -`
2. `admin` パスワードを取得します: `kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode && echo`
3. `localhost:8080` で一時的にアクセスするために port-forward します: `kubectl port-forward -n argocd svc/argocd-server 8080:8080`

### manifest リポジトリを接続

1. GitHub App を作成します。
    - 必要な最小限の権限: `Contents: Read-Only`
        - PR に基づいて Application を検出したい場合は、`Pull-Requests: Read-Only` も必要です
    - 次に、この app を manifest リポジトリにインストールします。
    - 以下をメモしてください: GitHub App ID、installation ID (インストール後にブラウザの URL を確認してください！)、および秘密鍵。
2. [ArgoCD UI からリポジトリを追加します](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/#github-app-credential)。
3. GitHub から `https://<your-argocd-url>/api/webhook` への push 時の webhook を設定します。
    - webhook の "Content Type" を `application/json` に設定します。
    - https://argo-cd.readthedocs.io/en/stable/operator-manual/webhook/

### アプリケーションの同期

ArgoCD UI からアプリケーションの追加を開始できます。
`./dev/*` 配下に他のアプリケーションが必要かどうかを確認し、必要に応じてプレースホルダーを置き換えてください。

推奨される最初の同期アプリケーション（順番通り）:
- `kyverno` (pull-through-cache image rewrite を追加)
- `aws-load-balancer-controller`
- `traefik` (他のアプリで使用する ALB と Ingress Controller を含む)

いくつかの重要なアプリケーションを作成し、不要なアプリケーションディレクトリを削除したら、
`./dev/*` 配下のすべてのアプリケーションを自動的に検出して同期する "root" application を追加できます。

"root" Application を作成するには、`./dev/.application/application-set.yaml` の `<your-org>/<your-repo>` を
実際のリポジトリ名に置き換えてください。
その後、`./dev/.applications` ディレクトリを指す Application を追加してください。

> [!NOTE]
> Application のリソースの誤削除を防ぐため、ApplicationSet には以下の `syncPolicy` が設定されています:
>
> ```yaml
> syncPolicy:
>   # Application が削除されたときに、ArgoCD が Application のリソースを削除しないようにします。
>   # https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Application-Deletion/
>   preserveResourcesOnDeletion: true
>   # ApplicationSet が検出されなくなったときに、Application を削除しないようにします。
>   # https://argo-cd.readthedocs.io/en/latest/operator-manual/applicationset/Controlling-Resource-Modification/
>   applicationsSync: create-update
> ```
>
> (`argocd-cmd-params-cm` では `applicationsetcontroller.enable.policy.override` が `true` に設定されています。)
>
> Application 自体とそのリソースを適切に削除するには、まず git リポジトリからディレクトリを削除してから、
> UI から cascading deletion を使用して Application を削除してください。

### ArgoCD notifications (Slack) のセットアップ

https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/services/slack/

1. Slack App を作成します
    - app manifest の例:

        ```yaml
        display_information:
          name: ArgoCD (dev)
          description: ArgoCD (dev) notifications
          background_color: "#a36d00"
        features:
          bot_user:
            display_name: ArgoCD (dev)
            always_online: false
        oauth_config:
          scopes:
            bot:
              - chat:write
              - chat:write.customize
        settings:
          org_deploy_enabled: false
          socket_mode_enabled: false
          token_rotation_enabled: false
        ```

2. OAuth Token (`xoxp-...`) を取得し、`argocd-notifications-secret` (`./dev/argocd/secrets/notifications.yaml`) に設定します。
   `scripts/secret-encrypt.sh` で secret を暗号化し、それに応じて `ksops.yaml` を更新してください。

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: argocd-notifications-secret
    
    stringData:
      slack-token: "replace-me-with-actual-token"
    ```

## ベストプラクティス

### リポジトリローカルの helm chart を使用

環境やアプリケーション間で manifest 定義のセットを共有する必要がある場合、
`./base` 配下（または他の場所）に helm chart を配置してください。
`./base/traefik-forward-auth` がその一例です。

リポジトリローカルの helm chart を作成し、`kustomization.yaml` からレンダリングするだけで、
kustomize を使用した従来の "overlays" や "patches" よりも*はるかに*シンプルで保守しやすくなります。

最初は、いくつかの場所にパッチを当てるだけなら、kustomize patch の方が Helm の template engine よりシンプルに見えますが、
manifest が大きくなるにつれて、patch セットが急速に膨らみ、新規参入者が何が起こっているのかを理解することがほぼ不可能になります。

Helm の template engine は、共通の manifest 定義を管理するためのより多くの制御と柔軟性を提供します。
`values.yaml` は共通定義と実際のユースケースの間の "インターフェース" です。
これらの `values.yaml` を実際のユースケースに対して可能な限り汎用的に "設計" してみてください。
*すべて*の値を `values.yaml` で設定可能にする必要はありません - 結局、この chart はローカルでのみ使用されます -
`values.yaml` を可能な限りシンプルに保つようにしてください。

### サードパーティの helm chart を可能な限り使用

同様に、可能な限りサードパーティの helm chart に依存したいと思うでしょう。

最初は、リソース URL (例: `https://raw.githubusercontent.com/argoproj/argo-cd/refs/heads/master/manifests/install.yaml`)
を `kustomization.yaml` から参照し、いくつかの kustomize patch を保守したいと思うかもしれませんが、上記と同様の理由で、
kustomize patch や追加リソースはすぐに保守不可能になります。

可能な限り保守されている helm chart に依存することで、書くコードが少なくなり、より多くの作業を完了できます。

例:
- ArgoCD: https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd
- victoria-metrics-k8s-stack (オールインワン監視ソリューション): https://github.com/VictoriaMetrics/helm-charts/tree/master/charts/victoria-metrics-k8s-stack
- Self-host Sentry (セルフホストを希望する場合): https://github.com/sentry-kubernetes/charts
- OpenCost (リソースコストの追跡用): https://github.com/opencost/opencost-helm-chart/tree/main/charts/opencost

### 頻繁に `main` に push することをためらわない

このリポジトリは GitOps 原則に基づく ArgoCD での使用を想定しています。
PR を作成し、CI が通るのを待ち、merge して、すばやく繰り返してください。
何かを壊してしまっても、`git revert && git push` を実行すれば問題ありません（ほとんどの場合）。

commit 履歴があり、この GitOps リポジトリをインフラストラクチャの "信頼できる唯一の情報源" とすることで、
rollback や事後調査が*はるかに*容易になります。

### クラスタの状態を操作するために `kubectl` を使用しない

同様の理由から - このリポジトリをインフラストラクチャの "信頼できる唯一の情報源" として維持してください。

`kubectl` や [k9s](https://k9scli.io/) は、クラスタの状態を確認するためにのみ使用してください。
`alias k9s-ro='k9s --readonly'` は使用するのに良い alias です。
クラスタに変更を加える必要がある場合は、常にこのリポジトリを通じて変更を行ってください。

### 集中型 SSO (single-sign-on) を使用

`./dev/auth` と `./dev/traefik` は、集中型 SSO を提供し、アプリが
[traefik ForwardAuth middlewares](https://doc.traefik.io/traefik/middlewares/http/forwardauth/)
を通じて header 認証を使用できるようにします。

[traPtitech/traefik-forward-auth](https://github.com/traPtitech/traefik-forward-auth) は、
OAuth2 または OIDC を介したシンプルで強力な SSO と header 認証ソリューションを提供します。
これは、すでに identity provider (IdP) を持っていることを前提としています。
まずは Google の OAuth2 App を使用することをお勧めします。

`./base/traefik-forward-auth/values.yaml` で "groups" を設定してください。
(これがどのように行われるかの詳細については、実際の template を参照してください)

```yaml
groups:
  admin:
    - admin@example.com
```

これにより、各 group に対して `auth-group-${group_name}` middleware が生成されるので、
IngressRoute 定義でそれらを参照してください。

```yaml
    - kind: Rule
      match: Host(`traefik.example.com`)
      middlewares:
        - name: auth-group-admin
          namespace: auth
      services:
        - kind: TraefikService
          name: dashboard@internal
```

これにより、アプリケーションに `X-Forwarded-User` と `X-Forwarded-Sub` header も渡されます。
アプリケーションが header 認証（別名 "proxy 認証"）をサポートしている場合は、それに応じて設定してください。

例えば、[Grafana は proxy 認証をサポートしています](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/auth-proxy/)。

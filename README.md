# AWS Terraform Web Infrastructure

Terraformを使用したAWS Webインフラストラクチャの構築ポートフォリオ。

## 概要

AWSのネットワーク・Web・データベース・監視構成をInfrastructure as Code（IaC）として実装。

Terraformによるインフラ構築に加え、S3 Remote BackendによるState管理、GitHub ActionsによるTerraform CI、OIDCを利用したAWS認証、CloudWatchによる監視を実装。

## 構成

- VPC
- Public Subnet × 2（2AZ）
- Private Subnet × 2（2AZ）
- Internet Gateway
- Route Table
- Application Load Balancer（ALB）
- Target Group
- EC2（Amazon Linux 2023）
- RDS for MySQL
- DB Subnet Group
- Security Group
- Apache HTTP Server
- CloudWatch Alarm
- S3 Remote Backend
- GitHub Actions
- GitHub OIDC / IAM Role

## 構成図

![AWS Architecture](architecture.png)

## アーキテクチャ

```text
Internet
   ↓
Internet Gateway
   ↓
Application Load Balancer
   ↓
Target Group
   ↓
EC2 / Apache
   ↓
RDS for MySQL
```

ALBおよびEC2をPublic Subnet、RDSをPrivate Subnetに配置。

DB Subnet Groupには異なるAZの2つのPrivate Subnetを登録。

## セキュリティ設計

### ALB → EC2

ALBではインターネットからのHTTP（TCP/80）を許可。

EC2ではALBのSecurity GroupからのHTTP通信のみ許可し、インターネットからEC2への直接HTTPアクセスを制限。

### EC2 → RDS

RDSのPublic Accessを無効化し、Private Subnetに配置。

RDSのSecurity Groupでは、EC2のSecurity GroupからのMySQL（TCP/3306）のみ許可。

インターネットからRDSへの直接アクセスを許可しない構成。

## Terraform module

ネットワーク関連のリソースを modules/network/ に分離し、ルートモジュールから呼び出す構成に変更。

VPC、Subnet、Internet Gateway、Route TableなどをNetwork Module内で管理。

### ディレクトリ構成

```text
aws-terraform-web-infra/
├── main.tf
├── ALB.tf
├── compute.tf
├── database.tf
├── SecurityGroup.tf
└── modules/
    └── network/
        ├── main.tf
        └── output.tf
```

### 検証

作業ブランチで変更を行い、Pull Requestを作成。

GitHub Actionsによる terraform fmt -check、terraform validate、terraform plan のチェックが成功したことを確認してmainへマージ。

今回のモジュール化後はAWSリソースの再作成を行っていないため、実環境での動作確認は未実施。


## Terraform State管理

Terraform StateはS3 Remote Backendで管理。

```text
S3 Bucket
└── portfolio/
    └── terraform.tfstate
```

TerraformのState Lockを有効化し、複数のTerraform実行によるStateの競合を防止。

RDSのパスワードなどの機密情報はTerraformコードへ直接記述せず、Terraform変数として管理。

`terraform.tfvars` は `.gitignore` の対象とし、GitHubリポジトリへの登録を除外。

## GitHub Actions / CI

GitHub Actionsを利用したTerraform CIを構築。

mainブランチへのpushおよびPull Requestをトリガーとして、Terraformコードのチェックを自動実行。

### CI / State Management 構成図

![Terraform CI and State Management](terraform-ci.png)

### AWS認証

GitHub ActionsからAWSへの認証にOIDC（OpenID Connect）を使用。

AWSアクセスキーをGitHub Secretsへ長期保存せず、GitHub ActionsからIAM Roleを一時的に引き受ける構成。

CI用IAM RoleはAWSリソースに対する読み取り権限を基本とし、Terraform State Lockに必要なS3オブジェクトのみ書き込み・削除を許可。

`terraform apply` はCIの対象外とし、意図しないインフラ変更を防止。

## CloudWatchによる監視

ALB Target Groupの `UnHealthyHostCount` をCloudWatch Alarmで監視。

Target Group内にUnhealthyなターゲットが発生した場合に異常を検知する構成をTerraformで実装。

### 監視設定

- Namespace: AWS/ApplicationELB
- Metric: UnHealthyHostCount
- Period: 60秒
- Evaluation Periods: 2
- Threshold: 0
- Condition: UnHealthyHostCount > 0

### 障害・復旧試験

監視の動作確認として、EC2 Security GroupのALBからのHTTP（TCP/80）許可ルールを一時的に削除。

ALBからEC2へのヘルスチェックを意図的に失敗させ、以下を確認。

1. ALB Target Groupのターゲットが `Healthy` から `Unhealthy` に変化
2. `UnHealthyHostCount` が 0 から 1 に変化
3. CloudWatch Alarmが `OK` から `ALARM` に変化

その後 `terraform plan` を実行し、AWS上で手動変更したSecurity GroupとTerraformコードとの差分（drift）を検出。

`terraform apply` によってSecurity GroupをTerraformの定義状態へ復旧し、Target Groupが `Healthy`、CloudWatch Alarmが `OK` に戻ることを確認。

```text
Normal
  ↓
Security Group rule removed
  ↓
ALB Health Check timeout
  ↓
Target: Unhealthy
  ↓
UnHealthyHostCount = 1
  ↓
CloudWatch Alarm: ALARM
  ↓
terraform plan (drift detection)
  ↓
terraform apply
  ↓
Target: Healthy
  ↓
CloudWatch Alarm: OK
```

### CloudWatch Alarm 動作確認

![CloudWatch Alarm Test](cloudwatch-alarm-test.png)

## 動作確認

TerraformによるAWSリソース作成後、ALBのDNS名へブラウザからアクセスして動作確認を実施。

以下の経路でHTTP通信が正常に行えることを確認。

```text
Internet
   ↓
Application Load Balancer
   ↓
Target Group
   ↓
EC2
   ↓
Apache
```

Target GroupのヘルスチェックがHealthyとなること、およびApacheのテストページが表示されることを確認。

### ブラウザからのアクセス確認

![Web Server Test](web-test.png)

## コストを考慮した検証構成

本番環境ではWebサーバーをPrivate Subnetへ配置する構成を想定。

本ポートフォリオでは検証コストを抑えるためNAT Gatewayを使用せず、EC2をPublic Subnetへ配置。起動時にApacheをインストールする構成。

EC2にはPublic IPv4アドレスを付与する一方、Security GroupによってALBからのHTTP通信のみ許可。

RDSは検証用途のためSingle-AZ構成を採用。

## 工夫した点

### 1. Security Groupによる通信制御

ALB、EC2、RDS間の通信を必要なポートに限定。

EC2とRDSのSecurity Groupでは、IPアドレスではなく通信元のSecurity Groupを指定し、リソースのIPアドレスが変わっても設定変更が不要な構成にした。

### 2. 検証コストを考慮した構成

NAT Gatewayは使用せず、EC2をPublic Subnetに配置。

EC2へのHTTP通信はALB経由のみに制限し、コストを抑えながらSecurity Groupによる通信制御を検証できる構成にした。

RDSも検証用途のためSingle-AZ構成とした。

### 3. 障害発生から復旧までの検証

ALBの UnHealthyHostCount を監視し、ターゲットの異常を検知するCloudWatch Alarmを設定。

当初はEC2を停止して障害を再現したが、想定どおりにアラームが発報しなかった。

EC2自体を停止すると、ALBのターゲットが unused として扱われる場合があり、UnHealthyHostCount が期待どおり増加しないことがあると分かった。

そこで、EC2を起動したままSecurity GroupのHTTP許可ルールを削除し、ALBのヘルスチェックを失敗させる方法に変更。

結果として、ターゲットが Unhealthy になり、CloudWatch Alarmが ALARM に遷移することを確認した。

その後、terraform plan でSecurity Groupの設定差分を検出し、terraform apply で元の構成へ復旧するところまで検証した。

### 4. GitHub Actionsによる自動チェック

Terraformコードの変更時に、書式確認、構文検証、変更内容の確認を自動実行するようにした。

AWS認証にはOIDCを使用し、アクセスキーをGitHubに保存しない構成にした。

また、CIでは `terraform apply` を実行せず、意図しないリソース変更を防ぐようにした。

### 5. Terraform Stateの管理

Terraform StateをS3で管理し、State Lockを有効化。

複数の環境からTerraformを実行する場合でも、同時更新による競合を防げるようにした。

### 6. ネットワーク部分のモジュール化

VPCやSubnet、Route TableなどをNetwork Moduleとして分離。

VPC IDやSubnet IDをoutputで渡すことで、ALBやEC2、RDSなどからモジュール内のリソースを直接参照しない構成にした。

## 今後の課題

- EC2のPrivate Subnetへの配置
- NAT GatewayまたはVPC Endpointの導入
- Auto ScalingによるWebサーバーの冗長化
- RDS Multi-AZ構成
- HTTPS（ACM）の導入
- ALB・EC2・RDSなどのモジュール化
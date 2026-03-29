# DeVine IaC 이관 절차

새 AWS 계정에 DeVine 인프라를 CloudFormation으로 배포하는 절차입니다.

---

## 사전 준비

### 필요한 것
- 새 AWS 계정 + AdministratorAccess 권한의 IAM 유저 또는 루트 계정
- AWS CLI 설치 및 자격증명 설정 (`aws configure`)
- devine.kr 도메인 접근 권한 (가비아 등 레지스트라)
- Clerk 대시보드 접근 권한

---

## Step 1. S3 버킷명 결정

`devine-public-bucket`, `devine-private-bucket`은 **AWS 전역 유일**합니다.
기존 계정에 이미 존재하므로 새 계정에서는 다른 이름을 사용해야 합니다.

```bash
# 예: 계정 ID를 접미사로 사용
export PUBLIC_BUCKET="devine-public-bucket-$(aws sts get-caller-identity --query Account --output text)"
export PRIVATE_BUCKET="devine-private-bucket-$(aws sts get-caller-identity --query Account --output text)"

echo "Public:  $PUBLIC_BUCKET"
echo "Private: $PRIVATE_BUCKET"
```

---

## Step 2. 템플릿 업로드용 임시 버킷 생성

CloudFormation Nested Stack은 템플릿이 S3에 있어야 합니다.
`PrivateBucket` 자체가 스택으로 생성되므로, 먼저 임시 버킷에 업로드합니다.

```bash
# 임시 버킷 생성 (또는 $PRIVATE_BUCKET 이름으로 미리 생성해도 됨)
aws s3 mb s3://$PRIVATE_BUCKET --region ap-northeast-2

# 템플릿 업로드
aws s3 sync iac/ s3://$PRIVATE_BUCKET/cloudformation/ \
  --exclude "*" --include "*.yaml"

# 확인
aws s3 ls s3://$PRIVATE_BUCKET/cloudformation/
```

---

## Step 3. ACM 인증서 발급 (us-east-1 필수)

CloudFront에서 사용할 인증서는 **버지니아(us-east-1)** 에 발급해야 합니다.

```bash
# 인증서 요청
aws acm request-certificate \
  --domain-name "devine.kr" \
  --subject-alternative-names "*.devine.kr" \
  --validation-method DNS \
  --region us-east-1
```

발급 후 콘솔에서 DNS 검증용 CNAME 값을 확인합니다:

```bash
aws acm describe-certificate \
  --certificate-arn <인증서 ARN> \
  --region us-east-1 \
  --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
```

→ 출력된 `Name`과 `Value`를 메모해둡니다. Step 6에서 Route53 레코드 업데이트에 사용합니다.

---

## Step 4. CloudFormation 스택 배포

```bash
aws cloudformation deploy \
  --template-file iac/main.yaml \
  --stack-name devine-prod \
  --region ap-northeast-2 \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    Environment=prod \
    PublicBucketName=$PUBLIC_BUCKET \
    PrivateBucketName=$PRIVATE_BUCKET \
    TemplateBaseUrl=https://$PRIVATE_BUCKET.s3.ap-northeast-2.amazonaws.com/cloudformation \
    KeyName=devine-key
```

배포 완료 후 출력값 확인:

```bash
aws cloudformation describe-stacks \
  --stack-name devine-prod \
  --query 'Stacks[0].Outputs' \
  --output table
```

---

## Step 5. 도메인 네임서버 위임

새 호스팅 존의 NS 레코드를 확인합니다:

```bash
# HostedZoneId는 Step 4 Outputs에서 확인
HOSTED_ZONE_ID=$(aws cloudformation describe-stacks \
  --stack-name devine-prod \
  --query 'Stacks[0].Outputs[?OutputKey==`HostedZoneId`].OutputValue' \
  --output text)

aws route53 get-hosted-zone --id $HOSTED_ZONE_ID \
  --query 'DelegationSet.NameServers'
```

출력된 NS 4개를 **가비아(또는 도메인 레지스트라)** 에서 devine.kr의 네임서버로 교체합니다.

> ⚠️ NS 전파에 최대 48시간 소요될 수 있습니다. 실제로는 보통 수십 분 내 적용됩니다.

---

## Step 6. ACM 인증서 검증 레코드 업데이트

Step 3에서 메모한 ACM 검증 CNAME 값으로 `iac/services.yaml`의 `AcmValidationRecord`를 수정합니다:

```yaml
# iac/services.yaml
  AcmValidationRecord:
    Properties:
      Name: <Step 3에서 확인한 Name>      # _xxx...devine.kr.
      ResourceRecords:
        - <Step 3에서 확인한 Value>        # _yyy...acm-validations.aws.
```

수정 후 템플릿 재업로드 및 스택 업데이트:

```bash
aws s3 sync iac/ s3://$PRIVATE_BUCKET/cloudformation/ \
  --exclude "*" --include "*.yaml"

aws cloudformation deploy \
  --template-file iac/main.yaml \
  --stack-name devine-prod \
  --region ap-northeast-2 \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    Environment=prod \
    PublicBucketName=$PUBLIC_BUCKET \
    PrivateBucketName=$PRIVATE_BUCKET \
    TemplateBaseUrl=https://$PRIVATE_BUCKET.s3.ap-northeast-2.amazonaws.com/cloudformation
```

---

## Step 7. Clerk 연동 확인

Clerk DKIM/메일 레코드(`clk._domainkey`, `clk2._domainkey`, `clkmail`, `accounts`, `clerk`)는 Clerk 앱 테넌트(`cj530ub2rj45`)에 종속됩니다.

- **같은 Clerk 프로젝트를 사용**: 레코드 변경 불필요
- **새 Clerk 프로젝트를 사용**: Clerk 대시보드 → Domains → DNS 레코드 확인 후 `services.yaml` 업데이트

---

## Step 8. 백엔드 환경변수 설정

새 계정의 EC2 인스턴스에 아래 환경변수를 업데이트합니다:

| 변수 | 값 |
|------|-----|
| `AWS_ACCESS_KEY` | 새 계정 IAM 키 |
| `AWS_SECRET_KEY` | 새 계정 IAM 시크릿 |
| `AWS_S3_BUCKET` | `$PUBLIC_BUCKET` 값 |
| `AWS_CLOUDFRONT_DOMAIN` | Step 4 Outputs의 `S3DistributionDomainName` |

---

## Step 9. 배포 후 확인 체크리스트

```bash
# 1. 스택 상태
aws cloudformation describe-stacks --stack-name devine-prod \
  --query 'Stacks[0].StackStatus'
# 기대값: "CREATE_COMPLETE"

# 2. S3 버킷 생성 확인
aws s3 ls | grep devine

# 3. EC2 인스턴스 실행 확인
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=devine-prod-instance" \
  --query 'Reservations[0].Instances[0].State.Name'
# 기대값: "running"

# 4. Route53 레코드 확인
aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID \
  --query 'ResourceRecordSets[*].Name' --output table

# 5. ACM 인증서 검증 상태
aws acm describe-certificate --certificate-arn <ARN> --region us-east-1 \
  --query 'Certificate.Status'
# 기대값: "ISSUED"
```

---

## 계정별 파라미터 정리 예시

| 파라미터 | 기존 계정 (prod) | 새 계정 |
|----------|-----------------|---------|
| `PublicBucketName` | `devine-public-bucket` | `devine-public-bucket-<AccountId>` |
| `PrivateBucketName` | `devine-private-bucket` | `devine-private-bucket-<AccountId>` |
| `TemplateBaseUrl` | `https://devine-private-bucket.s3...` | `https://devine-private-bucket-<AccountId>.s3...` |
| ACM CNAME | 기존 값 | Step 3에서 새로 발급한 값 |
| NS 레코드 | 기존 NS 4개 | 새 호스팅 존 NS 4개 |

---

## 주의사항

- **Route53 호스팅 존**: CloudFormation 배포 시마다 새 호스팅 존이 생성됩니다. 스택 삭제 없이 재배포하면 기존 존이 재사용됩니다.
- **EIP 고정 IP**: 새 계정에서 새 EIP가 할당됩니다. `api.devine.kr`, `dev.devine.kr` Route53 레코드는 자동 반영됩니다.
- **devine-config-bucket**: `iam.yaml`의 `PrivateBucketPolicy`에 하드코딩된 `devine-config-bucket`은 별도 생성이 필요합니다. 이 버킷은 현재 IaC에 포함되어 있지 않습니다.

# Java 2. 평가하고 계획 승인하기

[목차](README.md) | [이전: 원본 실행](01-run-locally.md) | [다음: 업그레이드](03-upgrade.md) | [정리](07-cleanup.md)

## 목표와 시작 조건

원본 동작과 기준선 커밋이 있는 **앱 루트**를 Copilot app에서 엽니다. Agent picker에서 **`modernize`**를 선택합니다. 먼저 평가만 하고 변경 범위를 검토한 뒤 계획을 만듭니다. "앱을 모두 현대화해 줘"라는 넓은 요청으로 바로 실행하지 않습니다.

## 읽기 중심 평가 요청

아래 프롬프트의 환경 정보를 실제 값으로 바꿉니다.

```text
이 폴더는 Asset Manager 앱 루트다. pom.xml과 web/worker가 있다.
GitHub Copilot app의 Modernization 플러그인으로 단일 저장소 평가만 수행해 줘.
원본은 Java 8/Spring Boot 2.7.18이며 로컬 기준 동작을 확인했다.
지금은 앱 소스 수정, 패키지 업데이트, 리소스 생성, 배포를 하지 마.
평가 산출물 작성은 허용하지만 추가 도구 설치나 외부 서비스 사용은 먼저 알려 줘.

Windows라면 Java 명령은 WSL2 배포판 <배포판>의 <앱의-WSL-경로>에서
bash와 SDKMAN을 사용해 실행해야 한다. Windows JDK나 다른 배포판을 쓰지 마.
macOS라면 현재 앱 루트의 Bash/SDKMAN을 사용해 줘.

web/worker의 책임, DB/큐/파일 의존성, 화면과 API, 환경 설정과 비밀,
테스트 현황, 업그레이드 위험과 예상 작업을 근거 파일과 함께 설명해 줘.
평가하지 못한 항목은 성공으로 표시하지 말고 그 이유를 남겨 줘.
평가 결과를 제시한 뒤 멈춰 줘.
```

플러그인은 버전에 따라 `.github/modernize/reports/`, `.github/modernize/assessment/reports/` 등에 결과를 저장합니다. 실제 생성된 경로를 확인해 읽습니다. 보고서가 존재하는지만 보지 말고 적용 범위와 실패/미완료 항목을 확인합니다.

## 제약조건과 계획 요청

평가를 검토한 뒤 같은 에이전트에 요청합니다.

```text
평가 결과를 바탕으로 다음 제약을 .github/modernize/rulebook/workshop.md에
기록하고 실행 계획을 만들어 줘. 지금은 계획까지만 작성하고 멈춰 줘.

- 최종 Java는 JDK 25다. JDK 21은 중간 업그레이드/검증 단계다.
- Spring Boot 2.7에서 3.x의 지원되는 안정 버전을 거쳐 JDK 25를 지원하는
  Spring Boot 안정 버전으로 올린다. 최종 후보는 4.1.2이며 라이브러리 호환성을 확인한다.
- 기존 화면, 업로드, 파일 저장과 비동기 처리 동작을 보존한다.
- 원본 dev 업로드 경로는 DB 메타데이터 행을 만들지 않는다. dev 외 S3 경로의
  메타데이터 기록과 조회 로직은 이전 범위에 포함하고 dev 기준선과 구분한다.
- web과 worker 모듈을 유지한다. 불필요한 프런트엔드 재작성은 하지 않는다.
- PostgreSQL -> Azure Database for PostgreSQL Flexible Server,
  RabbitMQ -> Service Bus, dev의 로컬 파일 및 dev 외 AWS S3 -> private Blob으로 이전한다.
- 관리 ID, 최소 권한, TLS를 기본으로 하고 비밀을 코드/Git에 저장하지 않는다.
- 최종 실행 대상은 Linux Azure Container Apps다. AKS/App Service가 아니다.
- 배포는 azd와 Bicep, 이미지 빌드는 선택한 로컬 Docker/Podman 엔진을 사용한다.
  ACR Tasks나 az acr build를 사용하지 않는다.
- 단계는 기준 동작 테스트, JDK 21, JDK 25, Azure 서비스 코드, azd 산출물,
  리소스 생성과 배포, 기능 검증, 정리로 나눈다.
- 각 단계의 변경 파일, 버전 근거, 검증 명령, 중지/복구 기준을 명시한다.
- 실제 리소스 생성과 비용 발생 작업은 별도 승인 전 실행하지 않는다.
```

계획의 JDK가 17/21에서 끝나거나 Azure 대상으로 AKS가 선택되면 승인하지 않습니다. 데이터베이스 인증과 내부 권한, 메시지 중복/재시도, Blob 공개 여부도 확인합니다. `plan.md`/`tasks.json`의 실제 경로를 기록하고 단계별로 승인합니다.

## 완료 기준과 문제 해결

평가 결과를 읽고 범위를 확인했으며, **JDK 25 + ACA + azd + 로컬 빌드**가 계획과 rulebook에 반영되어 있어야 합니다. 평가 중 실제 소스가 변경되었다면 diff를 먼저 검토합니다. 원본 저장소의 복구 브랜치나 완성 배포 브랜치가 이 독립 저장소에 있다고 가정하지 않습니다.

평가가 인증/도구 문제로 중단되면 [문제 해결](../troubleshooting.md)을 따릅니다. 미완료 평가를 완료로 바꾸거나 전체 실행을 일괄 승인해서 우회하지 않습니다.

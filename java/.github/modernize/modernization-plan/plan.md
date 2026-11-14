# Modernization Plan: Asset Manager to Java 25 and Azure Container Apps

**Project**: Asset Manager (`web` and `worker`)

## Technical Framework

- **Language**: Java 8, target JDK 25
- **Framework**: Spring Boot 2.7.18, target Spring Boot 4.1.2
- **Build Tool**: Maven Wrapper 3.9.9
- **Database**: PostgreSQL, target Azure Database for PostgreSQL Flexible Server
- **Key Dependencies**: Spring MVC, Spring Data JPA, Spring AMQP, AWS SDK for S3, Thymeleaf

## Overview

The modernization preserves the separate web and image-processing worker applications,
their existing UI and upload/view/delete flows, and asynchronous thumbnail processing.
The target architecture uses Linux Azure Container Apps and replaces the current
database, message broker, and file storage integrations with managed Azure services.

- Upgrade Java and Spring while preserving locally observed behavior.
- Use managed identity and minimum required permissions for Azure service access.
- Prepare, but do not execute, Azure deployment and database initialization artifacts.

The work is gated: each phase must pass its stated checks before the next dependent
phase starts. A failed gate stops the plan; tests must not be skipped or weakened.

## Migration Impact Summary

| Application | Original Service | New Azure Service | Authentication | Comments |
|---|---|---|---|---|
| Web | Java 8, Spring Boot 2.7.18 | Java 25, Spring Boot 4.1.2 | N/A | Preserve UI and web behavior |
| Web and worker | Local PostgreSQL | PostgreSQL Flexible Server | Managed identity | App and schema-migration identities are separate |
| Web and worker | RabbitMQ | Azure Service Bus | Managed identity | Preserve message contract and processing semantics |
| Web and worker | Local files and AWS S3 | Private Azure Blob Storage | Managed identity | Preserve profile-specific metadata behavior |
| Web | Local web process | Azure Container Apps | Container Apps ingress | Web ingress only; worker has no ingress |
| Worker | Local worker process | Azure Container Apps | Container Apps identity | Continue asynchronous thumbnail work |

## Target Architecture and Behavior

- Deploy `web` and `worker` as separate Linux Azure Container Apps. Keep the web
  application as the only ingress-enabled app; the worker remains an internal
  background processor.
- Use Azure Database for PostgreSQL Flexible Server, Azure Service Bus, and a private
  Blob container. Use TLS and managed identities; do not store credentials in code,
  configuration, Git, or generated example files.
- Scope Azure roles to the required resource: Blob data access only to the required
  container, Service Bus sender/receiver roles to the required entity, and image-pull
  access only for the Container Apps identities.
- Keep Azure RBAC separate from PostgreSQL principals and grants. Use a distinct,
  explicitly operated database schema-migration principal; the application principal
  receives only the runtime data permissions it needs.
- Preserve `dev` behavior that does not write image metadata to PostgreSQL and
  non-`dev` behavior that stores and reads upload and thumbnail metadata. Both local
  and S3-backed files move to private Blob storage; retain the profile's logical
  message discriminator so in-flight and newly produced messages are handled by the
  appropriate worker.
- Preserve listing, upload, file viewing, deletion, thumbnail creation, metadata
  lookup, and the existing browser-facing flows. Serve private file content through
  the application; do not expose the container or use long-lived SAS URLs.
- Preserve message payload fields and processing behavior. Verify explicit settlement,
  duplicate handling, retry/dead-letter routing, and graceful worker shutdown against
  the current broker policy; do not assume an unverified RabbitMQ policy is configured
  in application code.
- The database initialization artifact is separate from application startup. Replace
  production schema auto-update with an explicitly initialized and validated schema;
  this plan does not run schema DDL or migrate data.

## Version and Compatibility Basis

- **JDK 25**: the requested final, non-EA JDK. Spring Boot's official system
  requirements state that Spring Boot 4.1.2 supports Java 17 through Java 27, which
  includes JDK 25.
- **Spring Boot 4.1.2 / Spring Framework 7.0.10 or later**: Spring Boot's official
  requirements specify Spring Framework 7.0.10 or later. The version is the requested
  target and the plan checks the complete resolved dependency tree and application
  tests before proceeding.
- **Maven**: the repository wrapper is Maven 3.9.9; Spring Boot 4.1.2 documents Maven
  3.6.3 or later.
- **Azure libraries**: the official Spring Cloud Azure mapping currently documents
  Spring Cloud Azure 7.x for Spring Boot 4.0.x, not 4.1.x. Therefore, this plan does
  not use Spring Cloud Azure starters. Use the Azure Java SDK clients directly,
  managed by a stable Azure SDK BOM, and validate their Java 25 compatibility and
  public-release status in the upgraded build. The current documented BOM basis is
  `azure-sdk-bom` 1.3.8; update that selection only when the official release/version
  information and resolved dependency checks justify it.
- Let the Spring Boot BOM manage Spring, Jakarta, servlet, JPA, Thymeleaf, and test
  library versions. For every other dependency, use a public stable release compatible
  with Java 25 and Boot 4.1.2; do not assume compatibility from the old Java 8
  dependency versions. No paid support or private artifact repository is assumed.
- If an Azure Java SDK used by the direct-client approach cannot be verified against
  JDK 25 and the chosen Boot build, stop before service transformation. Present the
  evidence and alternatives for approval; do not silently change the requested Boot
  target or introduce Spring Cloud Azure 7.x.

Version references:

- [Spring Boot 4.1.2 System Requirements](https://docs.spring.io/spring-boot/system-requirements.html)
- [Spring Cloud Azure Guide and Spring Boot version mapping](https://learn.microsoft.com/en-us/azure/developer/java/spring-framework/developer-guide-overview)
- [Azure SDK for Java Spring Versions Mapping](https://github.com/Azure/azure-sdk-for-java/wiki/Spring-Versions-Mapping)

## Phases, Validation Gates, and Recovery

The task-level details and dependencies are in `.metadata/tasks.json`; this plan
summarizes the gates without duplicating that task breakdown. Task 001 is the first
upgrade task in the plan, but it depends on task 002 so the Java 8 baseline and
snapshot execute and pass before any runtime or production-source changes.

1. Establish and run the Java 8 behavior baseline before changing runtime or source.
   Include the web and worker flows, particularly the `dev` metadata difference,
   non-`dev` metadata lookup, and asynchronous thumbnail behavior. Only a passing
   baseline permits the JDK/Spring upgrade.
2. Upgrade to JDK 25 and Spring Boot 4.1.2, then run local web/worker regression tests
   using JDK 25. Verify the resolved framework and library versions against the
   compatibility basis above.
3. Migrate the database, messaging, and storage integrations one at a time. Each
   migration must build and pass its focused unit tests before the next begins.
4. Run security/CVE remediation and its build/unit-test gate before preparing
   deployment artifacts.
5. Prepare Bicep, `azure.yaml`, the separate database bootstrap procedure, Dockerfiles,
   and local-engine build configuration. Run only offline/static validation and
   mock-based integration tests.

For Java commands, first select the required JDK in the same shell and use the Maven
Wrapper from the Java project root:

```powershell
. ../scripts/use-java.ps1 -Jdk 8
.\mvnw.cmd -pl web,worker -am test
. ../scripts/use-java.ps1 -Jdk 25
.\mvnw.cmd -pl web,worker -am test
```

```bash
source ../scripts/use-java.sh --jdk 8
./mvnw -pl web,worker -am test
source ../scripts/use-java.sh --jdk 25
./mvnw -pl web,worker -am test
```

Record the selected JDK, Maven version, command exit code, and actual test count at
each gate. If any gate fails, stop dependent tasks, preserve the failure output, and
do not report the phase as successful. Recovery is limited to reverting the failed
code/configuration change to the last passing application state; no live Azure
resource, database, or file data is changed by this plan.

## Planned Change Surface

The execution plan is limited to these application and artifact areas:

- Runtime and dependency definitions: `pom.xml`, `web/pom.xml`, `worker/pom.xml`,
  `.mvn/wrapper/maven-wrapper.properties`
- Web and worker integration/configuration code and focused tests:
  `web/src/main/**`, `web/src/test/**`, `worker/src/main/**`, `worker/src/test/**`
- Container and azd artifacts: `Dockerfile` files for both modules, `azure.yaml`,
  `infra/**`, and a separate database initialization procedure under `infra/db/**`

No frontend rewrite or unrelated sample-app change is in scope. No fixed source commit,
upstream attribution, or license notice is changed.

## Infrastructure and Participant-Run Procedure

Bicep is prepared with `provision: false`; it describes the Container Apps environment,
web and worker apps, PostgreSQL Flexible Server, Service Bus entity, private Blob
storage, identity/role assignments, and the image registry needed for a later
participant-run deployment. `azure.yaml` maps the two apps to Azure Container Apps.
The container images are built with the participant's local container engine; remote
builds, ACR Tasks, and `az acr build` are prohibited.

The generated database procedure documents the separate Entra/database administrator
step, schema initialization, creation of a restricted application principal, and
creation/use of the distinct migration principal. It is not executed by the plan.
Database creation, schema changes, data transfer, image publication, deployment, and
resource deletion are all excluded from plan execution.

After separate participant approval, the participant reviews the generated Bicep and
parameters, selects the Azure environment/subscription, runs the documented `azd`
provision flow, performs the database bootstrap as a separate approved operation,
builds images locally, and then separately approves image publication and deployment.
No Azure login, subscription operation, `azd` command, or cloud resource operation is
performed while creating this plan.

## Open Questions & Questionnaire

- [x] Q: Should infrastructure be provisioned by this plan? → A: Prepare Bicep and azd
  artifacts only; set `provision` to false. The participant handles provisioning later.
- [x] Q: Should migrated services have integration tests? → A: Yes; use mock mode so
  no Azure resources or live Azure services are required.
- [x] Q: Should security/CVE remediation be included? → A: Yes; include it after
  application upgrades and service transformations.
- [x] Q: Which Azure deployment target should be used? → A: Azure Container Apps.
  Actual deployment is explicitly excluded.
- [x] Q: Should containerization be included? → A: Yes; the user explicitly requested
  Dockerfiles and local-engine image builds.
- [x] Q: How should Azure service libraries work with Boot 4.1.2? → A: Keep Boot 4.1.2
  and use direct Azure Java SDK clients; do not use Spring Cloud Azure because the
  documented compatibility mapping does not list Boot 4.1.x.

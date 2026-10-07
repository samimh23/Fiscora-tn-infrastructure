# Fiscora — Guide Terraform pour la présentation au mentor

Référence vérifiée contre les fichiers locaux le **7 octobre 2026**. Explications en darija tunisienne, termes techniques en English, et phrases de présentation en français.

Ce document explique le projet actuel. Il ne lance aucun déploiement et ne certifie pas l'état live de chaque service cloud. Les configurations privées, secrets, plans et state ne sont pas reproduits.

## 1. La phrase à retenir

> **Terraform يجهّز وين التطبيق باش يخدم. GitHub Actions ينشر نسخة التطبيق. NestJS يعالج طلبات المستخدمين.**

En français :

> « Terraform décrit et prépare l'infrastructure de Fiscora. Les workflows GitHub Actions déploient ensuite les versions du frontend et du backend. Lorsque les utilisateurs utilisent l'application, c'est NestJS qui traite leurs requêtes, pas Terraform. »

Trois moments différents :

| Moment | Qui travaille ? | Résultat |
| --- | --- | --- |
| Création/modification de l'infrastructure | Terraform, avec les permissions de l'opérateur | Réseau, PostgreSQL, storage, identités, hosting… |
| Publication d'une nouvelle version | GitHub Actions des repositories frontend/backend | Nouvelle image NestJS / nouveaux fichiers React |
| Utilisation de Fiscora | Browser React, NestJS et services cloud | Factures, tâches, déclarations, documents… |

ما تخلطش بين هاذم. `push` في infrastructure موش نفس `push` في backend.

## 2. Présentation prête à dire — environ cinq minutes

### A. Besoin du projet

> « Fiscora a besoin d'une interface React, d'une API NestJS, d'une base PostgreSQL et d'un stockage pour les documents. L'extraction documentaire et l'assistant utilisent aussi des services IA sur Google Cloud. »

بالتونسي: حدّدنا شنوة التطبيق يحتاج قبل ما نكتبوا Terraform. موش اخترنا services عشوائيّاً.

### B. Pourquoi Terraform ?

> « Au lieu de créer toutes les ressources à la main dans le portail Azure, nous les décrivons dans des fichiers Terraform. Cela permet de versionner les changements, de voir un plan avant de les appliquer et de reproduire la configuration avec des paramètres adaptés. »

Reproduire موش معناها copier les comptes et données automatiquement. يلزم حساب cloud، permissions، paramètres، secrets، images et migration/restauration des données حسب الحالة.

### C. Organisation

> « Le bootstrap prépare le stockage protégé de l'état Terraform. Le dossier staging décrit l'environnement applicatif. Nous avons simplifié Azure avec un fichier par sujet et conservé un seul module pour le runtime NestJS/ClamAV. »

`bootstrap` و`staging` أسماء اخترناهم للتنظيم، موش خدمات Azure ولا أسماء مفروضة من Terraform.

### D. Déploiement

> « Pour l'infrastructure, l'opérateur initialise Terraform, crée un plan, le vérifie puis applique les changements. Le repository infrastructure exécute seulement des vérifications dans GitHub. Pour le code applicatif, un push sur main déclenche les tests et le déploiement si les contrôles réussissent. »

### E. Sécurité et limites

> « Les secrets d'exécution sont référencés dans Key Vault. L'identité managée de l'API obtient les permissions nécessaires. Les workflows GitHub utilisent OIDC, et l'accès Azure vers Google utilise Workload Identity Federation. PostgreSQL est privé, mais cela ne signifie pas que tous les endpoints sont sur un réseau privé. Il s'agit d'un staging PFE, pas d'une plateforme de production totalement redondante. »

## 3. Comment les configurations ont été créées

Réponse prête à dire :

> « Nous avons identifié les besoins de l'application, consulté la documentation des providers, décrit les ressources en HCL, séparé les paramètres dans des variables, puis raccordé les composants avec des références. Nous avons vérifié le format, la validité et les tests, examiné un plan et appliqué uniquement les changements revus. »

Si on vous demande l'utilisation d'outils d'assistance :

> « J'ai utilisé des outils d'assistance, notamment l'IA, pour aider à écrire et organiser la configuration. Je dois néanmoins comprendre les ressources, vérifier les changements et expliquer les décisions. »

Ne prétendez pas que Terraform a généré automatiquement toute l'architecture depuis Azure, ni que vous avez écrit chaque ligne sans assistance si ce n'est pas vrai.

Exemple pédagogique, **pas un fichier à ajouter au déploiement actuel** :

```hcl
resource "azurerm_resource_group" "demo" {
  name     = "rg-demo"
  location = "francecentral"
}
```

هذا وصف: «نحب Resource Group بالاسم والموقع هاذم». Terraform يستعمل الـ Azure provider باش يبعث الطلبات اللازمة لـ Azure API.

## 4. Plan des dossiers actuel

```text
Fiscora-tn-infrastructure/
├── azure/
│   ├── bootstrap/                 Fondation du state Azure
│   ├── environments/staging/      Configuration Azure principale, par sujet
│   ├── modules/application/       Runtime NestJS + ClamAV : seul module Azure
│   └── scripts/                  Registration Azure et configuration SMTP
├── gcp/
│   ├── bootstrap/                 Fondation du state Google
│   ├── environments/ai-staging/   Cloud Run, IAM, registry et budget
│   ├── services/nuextract/         Container NuExtract3 + vLLM
│   ├── services/paddleocr/         Container OCR et rendu PDF
│   └── scripts/                  Build, smoke tests, pause/reprise
├── scripts/                      Check, plan et helpers
└── .github/workflows/             Vérifications infrastructure uniquement
```

### Bootstrap / staging / module : différence essentielle

- **Bootstrap:** يجهّز البلاصة اللي Terraform يخزّن فيها ذاكرته. Azure bootstrap state يبقى محليّاً في setup هذا، ويلزم نحافظوا عليه. ما نخلقوش storage كل مرة.
- **Staging:** يصف infrastructure متاع Fiscora. عندو state distant في storage اللي bootstrap جهّزو.
- **Module:** جزء من configuration يستدعيه staging. موش service مستقل وموش يلزم نمشيو نعملولو `apply` وحدو.
- Azure et Google عندهم configurations وstates منفصلين. `apply` في Azure ما يشغّلش stack Google تلقائياً.

## 5. Carte des fichiers — où aller pour prouver une réponse

Les liens ouvrent les fichiers locaux sur ce PC. Dans VS Code, **Ctrl+P** permet aussi de chercher le nom du fichier; **Ctrl+F** cherche le bloc indiqué. Les numéros de lignes peuvent changer: privilégiez le nom du bloc.

### Azure : fichiers principaux

| Repère | Fichier à ouvrir | Ce qu'il faut savoir / chercher |
| --- | --- | --- |
| A1 | [bootstrap/main.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/bootstrap/main.tf>) | Resource Group du state, storage, container `tfstate`, rôle opérateur, lock `CanNotDelete`. |
| A2 | [staging/main.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/main.tf>) | `locals`, tags, `azurerm_resource_group.this`, carte des fichiers. |
| A3 | [staging/hosting.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/hosting.tf>) | ACR, Static Web App, `module "application"`, paramètres database/storage/secrets. |
| A4 | [modules/application/main.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/modules/application/main.tf>) | Container App, ingress, images, CPU/RAM, env, Key Vault references, health probes, lifecycle. |
| A5 | [staging/database.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/database.tf>) | PostgreSQL, database `accounting_nest`, extensions, backups, réseau privé, `prevent_destroy`. |
| A6 | [staging/security.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/security.tf>) | Identité runtime `application`, random secrets, Key Vault et permissions. |
| A7 | [staging/network.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/network.tf>) | VNet, subnets Container Apps/PostgreSQL, private DNS et link. |
| A8 | [staging/storage.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/storage.tf>) | Documents privés, permissions, versioning, soft delete, protection. |
| A9 | [staging/deployment-access.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/deployment-access.tf>) | Identités frontend/backend GitHub, federated credentials, sujet repo/main et rôle Container Apps. |
| A10 | [staging/google-auth.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/google-auth.tf>) | Côté Azure de la fédération avec Google. |
| A11 | [staging/monitoring.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/monitoring.tf>) | Application Insights, Log Analytics et alertes de budget. |
| A12 | [staging/backend.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/backend.tf>) | `backend "azurerm" {}` = emplacement du state, pas NestJS. |
| A13 | [staging/providers.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/providers.tf>) | Configuration Azure provider, subscription, accès storage Entra. |
| A14 | [staging/versions.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/versions.tf>) | Versions Terraform/providers autorisées; complétées par le lock file. |
| A15 | [staging/variables.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/variables.tf>) | Inputs, types, defaults et validations. |
| A16 | [staging/outputs.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/outputs.tf>) | IDs/noms/URLs utiles après déploiement. |
| A17 | [staging/moved.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/environments/staging/moved.tf>) | Anciennes adresses → nouvelles adresses après simplification. |

`terraform.tfvars` et `backend.hcl` sont les paramètres locaux existants, ignorés par Git. Utilisez les fichiers `.example` pour présenter le format; n'affichez pas les valeurs privées pendant le partage d'écran.

### Workflows, application et helpers

| Repère | Fichier à ouvrir | Ce qu'il faut chercher |
| --- | --- | --- |
| B1 | [NestJS Dockerfile](<C:/Users/Sami Mahjoub/Downloads/sams/accounting-backend-nest/Dockerfile>) | Deux stages, Node 24, `npm ci`, build, dependencies production, `CMD`. |
| B2 | [Backend ci.yml](<C:/Users/Sami Mahjoub/Downloads/sams/accounting-backend-nest/.github/workflows/ci.yml>) | Tests, migrations sur DB jetable, `needs: validate`, main seulement, `bootstrap_image_only`. |
| B3 | [Backend deploy-azure-staging.yml](<C:/Users/Sami Mahjoub/Downloads/sams/accounting-backend-nest/.github/workflows/deploy-azure-staging.yml>) | `azure/login`, `docker build`, `docker push`, digest, `az containerapp update`, vérification santé. |
| B4 | [Frontend deploy-azure-staging.yml](<C:/Users/Sami Mahjoub/Downloads/sams/accounting-frontend/.github/workflows/deploy-azure-staging.yml>) | `VITE_API_URL`, OIDC, token SWA masqué, upload `dist`, smoke tests. |
| B5 | [Frontend src/api/client.ts](<C:/Users/Sami Mahjoub/Downloads/sams/accounting-frontend/src/api/client.ts>) | `API_BASE_URL`, `apiUrl`, `fetch`, Authorization Bearer et refresh. |
| B6 | [NestJS src/main.ts](<C:/Users/Sami Mahjoub/Downloads/sams/accounting-backend-nest/src/main.ts>) | `enableCors`, validation et écoute port 3000. |
| B7 | [NestJS src/app.module.ts](<C:/Users/Sami Mahjoub/Downloads/sams/accounting-backend-nest/src/app.module.ts>) | TypeORM, configuration DB et `DB_MIGRATIONS_RUN`. |
| T1 | [Infrastructure terraform-check.yml](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/.github/workflows/terraform-check.yml>) | fmt, validate, tests mockés, `init -backend=false`; aucun cloud login/apply. |
| T2 | [scripts/check.ps1](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/scripts/check.ps1>) | Vérifications locales sans déploiement. |
| T3 | [scripts/plan.ps1](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/scripts/plan.ps1>) | Choix Azure/AzureBootstrap/Google, init, validate, plan, jamais apply. |
| T4 | [scripts/show-deployment-settings.ps1](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/scripts/show-deployment-settings.ps1>) | Lit seulement certains outputs et affiche les variables à copier dans GitHub. |
| G1 | [Google AI main.tf](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/gcp/environments/ai-staging/main.tf>) | APIs Google, Artifact Registry, Cloud Run, service accounts, WIF et IAM. |
| G2 | [Google README](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/gcp/README.md>) | NuExtract3, OCR, assistant séparé, builds et limites opérationnelles. |

## 6. Lire le langage Terraform sans mémoriser tout le code

| Expression | Darija / sens |
| --- | --- |
| `resource "azurerm_..." "nom"` | مورد نحبّوا Terraform يسيّرو. النوع provider-specific والاسم الثاني adresse في الكود. |
| `data "..." "nom"` | يقرا معلومات موجودة، موش déclaration باش يخلق المورد هذا. |
| `var.location` | Paramètre دخلناه عن طريق variable. |
| `local.name_prefix` | Valeur محسوبة داخل configuration. |
| `resource_name.attribute` | Propriété متاع resource أخرى: مثلاً adresse PostgreSQL. |
| `module "application"` | نستدعيوا مجموعة configuration موجودة في folder آخر. |
| `output "..."` | نخرجوا نتيجة نافعة، مثلاً URL ولا ID. |
| `depends_on` | Dépendance إضافية: استنى المورد/الصلاحية هاذي قبل هاذي. |
| `count = condition ? 1 : 0` | نخلقوا المورد كان الشرط true. موش شرط تنفّذو أثناء présentation. |
| `for_each` | نفس النوع من bloc يتعاود حسب مجموعة عناصر. |
| `lifecycle.prevent_destroy` | Terraform يرفض destruction مخطّطة لهذا المورد طالما الحماية موجودة. |
| `lifecycle.ignore_changes` | حقول معيّنة مسؤوليتها موش تحديثها بـ Terraform بعد الإنشاء. |
| `moved` | نفس المورد، تبدّلت adresse متاعو في الكود، موش بالضرورة يتعاود يتخلق. |

Tous les fichiers `.tf` d'un même module sont évalués ensemble; leur découpage ne définit pas l'ordre d'exécution. Les références définissent les dépendances. [Documentation HashiCorp](https://developer.hashicorp.com/terraform/language/files)

## 7. Le workflow concret — uniquement NestJS + PostgreSQL

### Première installation sur un Azure vide

1. Préparer le compte: subscription, Azure CLI, Terraform, permissions et resource providers nécessaires.
2. Appliquer le **bootstrap** après revue: stockage protégé pour le state. Conserver son state local.
3. Renseigner la configuration staging et son backend distant. Dans une nouvelle installation seulement, commencer avec `deploy_application=false` et sans image backend.
4. Planifier puis appliquer la fondation: PostgreSQL, réseau, Key Vault, ACR, identités et autres ressources. La Container App API n'est pas encore créée.
5. Afficher les paramètres avec `show-deployment-settings.ps1`, puis les enregistrer dans GitHub Variables. Le helper ne fait pas cette écriture lui-même.
6. Dans **Backend CI**, lancer le mode manuel `bootstrap_image_only`: tests → build → Docker push. Pas de mise à jour d'une Container App encore inexistante.
7. Mettre le digest de cette première image dans `backend_image`, activer `deploy_application=true`, créer un **nouveau** plan et appliquer après revue.
8. Terraform crée l'API avec l'image, les paramètres PostgreSQL et les références Key Vault. NestJS applique les migrations au démarrage si configuré.
9. Tester la santé, puis configurer/déployer React avec l'URL API.

**Ce parcours décrit une nouvelle installation. Notre installation existante ne doit pas être réinitialisée pour une démonstration.** Le guide exécutable détaillé est [azure/DEPLOYMENT.md](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/DEPLOYMENT.md>).

### Une modification du code NestJS demain

`push main` → checks → build de l'image → push ACR → digest → update Container App → vérification revision/image/santé et `/health`.

On ne recrée pas PostgreSQL et on ne lance pas Terraform pour chaque nouvelle fonctionnalité. Une migration DB peut cependant faire partie d'une release; elle est distincte de la création du serveur PostgreSQL.

### Une modification de l'infrastructure demain

Modifier `.tf`/paramètres → checks → nouveau plan Azure → revue → apply manuel du plan → vérifications.

مثلاً تغيير RAM ولا إضافة resource يستحق Terraform. تغيير comportement «Créer une facture» يستحق deployment du code.

## 8. Les connexions — qui parle à qui ?

### React → NestJS → PostgreSQL

1. GitHub frontend injecte `VITE_API_URL` au build depuis `vars.AZURE_API_URL`.
2. Le navigateur charge React depuis Static Web Apps.
3. Le code React envoie un `fetch` HTTP/HTTPS à l'API. Pour les appels protégés, il ajoute le token Bearer.
4. NestJS contrôle authentification/permissions et consulte PostgreSQL.
5. Il retourne du JSON; React affiche le résultat.

React ما يتصلش مباشرة بـ PostgreSQL. GitHub ما يشاركش في كل request. CORS permet au browser d'accéder à l'API depuis les origins autorisées, mais n'est pas un remplacement de l'authentification. **Preuve: B4, B5, B6, B7.**

### Container Apps → Key Vault → NestJS

1. A6 crée les secrets générés et l'identité runtime.
2. A6 accorde à cette identité `Key Vault Secrets User`.
3. A3 transmet les références de secrets au module.
4. A4 configure Container Apps pour les lire avec cette identité et les associer aux variables telles que `DB_PASSWORD`.
5. NestJS reçoit la valeur via son environnement.

ما نحتاجوش نحطّوا password في Dockerfile. Key Vault موش تخزين الفواتير. Attention: les secrets gérés par Terraform peuvent quand même exister dans son state; protéger Key Vault ne suffit donc pas à protéger le state. [HashiCorp: données sensibles](https://developer.hashicorp.com/terraform/language/manage-sensitive-data)

### GitHub → Azure

`id-token: write` permet au job de demander un token OIDC. Azure accepte le token si son issuer/audience/subject correspondent à la confiance configurée. `azure/login@v2` obtient alors l'accès temporaire, limité par les rôles attribués à l'identité. **Preuve: A9 et B3/B4.** [Microsoft: OIDC](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect)

Les IDs dans GitHub Variables ne sont pas des mots de passe. Les connaître ne donne pas accès à Azure. Les identités GitHub de déploiement sont distinctes de l'identité runtime du backend.

### Azure → Google

L'API utilise son identité Azure pour obtenir les tokens appropriés via Workload Identity Federation. La configuration Google limite l'identité/tenant acceptés et attribue les permissions d'invocation et Vertex AI nécessaires. **Preuve: A10, G1.**

La fédération transporte la preuve d'identité, **pas le document**. Les appels HTTPS transportent les données nécessaires au traitement. Cloud Run est configuré avec ingress HTTPS public **et invocation IAM authentifiée**, pas comme une application anonyme ni comme un réseau entièrement privé.

## 9. Questions possibles du mentor — réponses et preuves

### Q1. À quoi sert Terraform dans ce projet ?

**Réponse:** يوصف ويجهّز infrastructure: réseau، database، storage، identités، hosting وmonitoring. موش logique métier.

**Montrer:** A2 → A3; expliquer un bloc resource.

### Q2. Pourquoi pas tout créer manuellement dans Azure Portal ?

**Réponse:** الكود يتراجع ويتخزّن في Git، والتغييرات تتشاف قبل التنفيذ. اليدوي ينجم يخدم، أما أصعب باش نراجعوا ونعيدوا نفس configuration.

**Montrer:** A2, T3 et historique Git. Ne pas promettre une installation «zéro intervention».

### Q3. Terraform est-il obligatoire pour héberger NestJS ?

**Réponse:** لا. تنجم تجهّز Azure يدوياً. استعملناه باش التنظيم والمراجعة وإعادة الإعداد يكونوا أوضح.

**Montrer:** A3; Terraform est un outil de gestion, pas une dépendance de chaque requête.

### Q4. Le dossier bootstrap est-il obligatoire ?

**Réponse:** الاسم والفولدر موش obligatoire. في setup متاعنا يجهّز remote state storage. تنجم تعمل نفس الموارد يدوياً، أما إخترنا نسيّروهم بالكود.

**Montrer:** A1: cinq resources managed dans cette configuration, pas une API.

### Q5. Pourquoi le bootstrap précède staging ?

**Réponse:** staging يحتاج storage موجود باش يحطّ فيه state. ما ينجمش يعتمد على storage مازال موش موجود. Bootstrap عندو state local نحافظوا عليه.

**Montrer:** A1 puis A12 et format de `backend.hcl.example`.

### Q6. Quelle différence entre state et PostgreSQL ?

**Réponse:** state = ذاكرة Terraform تربط code بالـ IDs والموارد. PostgreSQL = données métier متاع Fiscora. موش نفس البيانات ولا نفس الغرض.

**Montrer:** A1 contre A5. Ne pas ouvrir le contenu du state.

### Q7. Qui crée terraform.tfstate ?

**Réponse:** Terraform ينشئ ويحدّث state أثناء إدارة الموارد، خصوصاً apply. إحنا ما نكتبوش state يدوياً. ينجم زادة يتبدّل بعمليات import/state أخرى، أما هاذم موش parcours quotidien.

**Montrer:** A12 et [documentation state](https://developer.hashicorp.com/terraform/language/state).

### Q8. Pourquoi backend.tf est vide à l'intérieur ?

**Réponse:** `backend "azurerm" {}` يختار نوع التخزين. تفاصيل storage/container/key تتعطى وقت init من `backend.hcl`. موش fichier NestJS.

**Montrer:** A12; commande `terraform init -backend-config=backend.hcl`. Ce bloc n'a pas pour rôle de créer le storage.

### Q9. Que font init, validate, plan et apply ?

**Réponse:** init يحضّر providers/modules/backend؛ validate يراجع configuration؛ plan يقترح الفرق؛ apply ينفّذ التغييرات. validate وحده موش إثبات أن كل permission أو valeur live صحيحة.

**Montrer:** T3. Le helper plan ne contient aucun apply.

### Q10. Où s'affiche le plan ? Dans Azure ?

**Réponse:** في terminal اللي شغّلنا فيه Terraform، ولا report Terraform Vision. Azure Portal يوري الموارد الفعلية، موش بالضرورة التغييرات المقترحة قبل apply.

**Montrer:** T3 ou un report déjà préparé; ne pas lancer apply pour démontrer.

### Q11. Terraform exécute-t-il main.tf puis database.tf ?

**Réponse:** لا. يقرا ملفات نفس module مع بعضهم ويبني ordre حسب dépendances. أسماء الملفات للتنظيم فقط.

**Montrer:** A3: `database.host = ...postgres.fqdn`, et A5.

### Q12. Pourquoi garder un module application ?

**Réponse:** يجمع runtime NestJS/ClamAV والـ probes/secrets/settings. عندو inputs وtests. البقية صارت topic files باش projet PFE يكون أسهل.

**Montrer:** A3 `source = "../../modules/application"`, puis A4. Un module n'est pas une VM ni un microservice en soi.

### Q13. Que veut dire staging ?

**Réponse:** اسم environnement متاعنا. موش proof اللي عنا production ثانية. Production جديدة تحتاج paramètres وstate/resources منفصلين.

**Montrer:** A2, A15. Ne pas présenter des environnements qui n'existent pas.

### Q14. Qu'est-ce qu'un provider ?

**Réponse:** Plugin يخلي Terraform يتعامل مع API متاع plateforme. `azurerm` للموارد Azure، `azuread` للهوية Entra، `random` يولّد قيم كيف secrets.

**Montrer:** A13, A14 et A6. Azure resource-provider registration est une autre notion: voir `azure/scripts/register-resource-providers.ps1`.

### Q15. Comment Terraform s'authentifie à Azure actuellement ?

**Réponse:** Plans/applies locaux يستعملوا session opérateur authentifiée، في parcours الموثّق بـ Azure CLI. provider يختار subscription المطلوبة. GitHub infra checks ما يعملوش cloud login.

**Montrer:** A13, T1, [DEPLOYMENT.md](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/DEPLOYMENT.md>).

### Q16. Un push infrastructure crée-t-il automatiquement des ressources ?

**Réponse:** لا في setup الحالي. GitHub يعمل checks فقط وعلى paths المعنية. Plan وapply محليّين بعد revue. Workflow القديم متاع cloud plan اتنحّى.

**Montrer:** T1: `permissions: contents: read`, `init -backend=false`, pas `azure/login`/`terraform apply`.

### Q17. Alors GitHub sert à quoi ?

**Réponse:** Versionner الكود، مراجعة التغييرات، checks infrastructure، وCI/CD متاع frontend/backend. هاذم responsibilities مختلفة.

**Montrer:** T1 contre B2/B3/B4.

### Q18. Où se trouve la Docker image ?

**Réponse:** Dockerfile هو الوصفة. GitHub يبني image ويبعثها لـ Azure Container Registry. الـ image المنشورة موجودة في registry، موش ملف عادي في Git.

**Montrer:** B1, B3 `docker build` / `docker push`; Portal → Container Registry → Repositories → `fiscora-backend`.

### Q19. Quelle différence entre Registry et Container Apps ?

**Réponse:** Registry يخزّن النسخ. Container Apps يشغّل نسخة معيّنة ويعطي endpoint للـ API.

**Montrer:** A3 resource registry contre A4 resource Container App.

### Q20. Pourquoi un Dockerfile en deux stages ?

**Réponse:** Stage build يثبّت ويبني الكود. Stage runtime ياخذ النتيجة ويثبّت dependencies production، وبعد يشغّل `dist/main.js`.

**Montrer:** B1 `AS build`, `AS runtime`, `COPY --from=build`, `npm ci --omit=dev`.

### Q21. Comment une nouvelle version backend est-elle déployée ?

**Réponse:** main push → checks → image tag commit → push → digest → `az containerapp update` للـ container `api` → vérification exacte image/revision/health.

**Montrer:** B2 `needs: validate`, B3 blocs build, digest, update et health.

### Q22. Pourquoi un digest plutôt qu'un tag latest ?

**Réponse:** Digest يحدّد محتوى image بالضبط. Tag ينجم يتنقل لنسخة أخرى. هكّا نعرفوا النسخة اللي فعليّاً نشرناها.

**Montrer:** B3 `Resolve immutable image digest`, puis `--image`.

### Q23. Qui crée la première image si Container Apps n'existe pas encore ?

**Réponse:** Workflow manuel backend بوضع `bootstrap_image_only`. يبني ويبعث image فقط. بعد Terraform يخلق API بالـ digest هذا.

**Montrer:** B2 input; B3 `update_container_app`; A4 `count = var.deploy_application ? 1 : 0`.

### Q24. Comment éviter que Terraform remette une ancienne image ?

**Réponse:** بعد الإنشاء GitHub مسؤول عن releases. Terraform يتجاهل تغييرات champ image متاع API فقط، ويبقى يسيّر باقي runtime configuration.

**Montrer:** A4 `ignore_changes = [template[0].container[0].image]`. Ne pas dire que toute la configuration est ignorée.

### Q25. D'où viennent les vars du workflow ?

**Réponse:** GitHub configuration variables. نحضّروا IDs/noms depuis Azure/Terraform outputs ونحطّوهم في Settings → Secrets and variables → Actions → Variables. `vars.X` يقرا القيمة المخزّنة.

**Montrer:** T4 et B3. T4 affiche seulement les valeurs; il ne les enregistre pas. Le code ne prouve pas si la saisie historique a été manuelle ou via une API.

### Q26. Que font client-id, tenant-id et subscription-id ?

**Réponse:** client-id يعرّف identité deployment، tenant-id يعرّف annuaire Entra، subscription-id يحدّد subscription المستهدفة. هاذم identifiers موش passwords.

**Montrer:** B3 `azure/login`, A9 identités, A16 outputs. Attention: `AZURE_CLIENT_ID` runtime dans A4 est l'identité API, pas forcément celle de GitHub.

### Q27. Que signifie OIDC ?

**Réponse:** GitHub يقدّم token يثبت شكون job. Azure يقبل كان trust توافق، وبعد يعطي accès temporaire حسب rôles. ما نخزّنوش Azure password دائم في workflow.

**Montrer:** A9 `issuer`, `audience`, `subject`; B3 `id-token: write` et `azure/login`. La confiance et les permissions sont toutes deux nécessaires.

### Q28. GitHub peut-il tout modifier sur Azure ?

**Réponse:** موش بالضرورة. حسب rôles/scope. Backend عندو AcrPush وContainer Apps Contributor؛ frontend عندو Contributor على Static Web App. Current setup n'est pas une identité GitHub globale pour tous les clouds.

**Montrer:** A3 `deployment_push` et `deployment`, A9 `backend_container_apps`.

### Q29. Que signifie Managed Identity ?

**Réponse:** هوية يديرها Azure، نربطوها بالـ API ونعطيوها rôles. تخلي service يطلب accès من غير ما نحطّ secret identity في الكود.

**Montrer:** A6 `application`, A4 `identity`/`registry`/`secret` et A8 rôle documents. Ce n'est pas le compte d'un utilisateur Fiscora.

### Q30. Pourquoi Key Vault ? Comment NestJS lit les secrets ?

**Réponse:** يخزّن secrets runtime. Container Apps يقرى references باستعمال managed identity ويعطي القيم للـ env متاع NestJS. Documents يمشيو Blob، موش Key Vault.

**Montrer:** A6 secrets+role → A3 references → A4 `secret_name = "database-password"`.

### Q31. Les secrets sont-ils absents du state ?

**Réponse:** لا. Terraform-managed secrets ينجموا يتخزّنوا في state/plans حتى كان output مخفي. `sensitive` موش encryption. نحافظوا على state والـ permissions وما نشاركوش plans.

**Montrer:** A1 protections et `.gitignore`; pas le contenu du state.

### Q32. Comment NestJS se connecte à PostgreSQL ?

**Réponse:** Terraform ياخذ host/name/user من resource database، ويعطيهم للـ API مع password secret وSSL. NestJS/TypeORM يستعمل settings هاذم.

**Montrer:** A3 `database = { ... }` → A4 `DB_HOST`, `DB_NAME`, `DB_PASSWORD`, `DB_SSL` → B7.

### Q33. Qui crée les tables et comptes Fiscora ?

**Réponse:** Terraform يخلق server/database، موش utilisateurs métier. Migrations التطبيق يجهّزوا schema؛ التسجيل/parcours التطبيق يخلق comptes/dossiers. DB migrations موجودة في backend ومفعّلة في runtime configuration.

**Montrer:** A5, A4 `DB_MIGRATIONS_RUN`, B7 et B2 test migrations sur DB jetable.

### Q34. Tout est-il privé dans Azure ?

**Réponse:** لا. PostgreSQL network access privé. API عندها ingress HTTPS public. Documents container privé وauthenticated، أما storage endpoint public network-enabled. Private access permissions موش دائماً private network.

**Montrer:** A5 `public_network_access_enabled=false`; A4 ingress; A8 `container_access_type="private"` + `public_network_access_enabled=true`.

### Q35. Pourquoi VNet, subnets et private DNS ?

**Réponse:** VNet يجمع réseau، subnets يقسموه حسب services، private DNS يحلّ adresse PostgreSQL داخل réseau. DB ما تتفتحش مباشرة للإنترنت.

**Montrer:** A7; A5 `delegated_subnet_id`, `private_dns_zone_id`.

### Q36. Comment les documents sont-ils protégés ?

**Réponse:** Container privé، accès Entra عبر rôles، HTTPS، versioning وsoft delete. ClamAV يفحص الوثائق حسب configuration. هاذم protections، موش ضمان مطلق ضد كل perte ولا malware.

**Montrer:** A8 et A4 bloc clamav; ne pas affirmer que soft delete remplace un plan complet de sauvegarde/restauration.

### Q37. Que font les health probes ?

**Réponse:** startup يتثبّت أن service بدا؛ readiness هل ينجم يستقبل requests؛ liveness هل مازال حي. Checks infrastructure ما يثبتوش وحدهم صحة الحسابات métier.

**Montrer:** A4 `/health`, probes TCP ClamAV; B3 vérification finale API.

### Q38. À quoi sert Application Insights ? Est-ce déjà complet ?

**Réponse:** Resource monitoring موجودة وconnection string تتعطى للـ API. نجموا نستعملوها لمتابعة telemetry، لكن configuration وحدها موش proof اللي كل request/errors متتبّعين. يلزم instrumentation وإثبات بيانات في Portal.

**Montrer:** A11 + A4 `APPLICATIONINSIGHTS_CONNECTION_STRING`. L'inspection locale n'a pas trouvé de setup SDK explicite dans `src/main.ts`/package du backend: ne pas promettre un tracing complet sans vérifier.

### Q39. Les budgets arrêtent-ils les dépenses ?

**Réponse:** لا. Alerts باش ننتبهوا للـ dépenses، موش hard cap يطفّي resources تلقائيّاً.

**Montrer:** A11 bloc budget notifications et G1 budget.

### Q40. Pourquoi deux clouds ?

**Réponse:** Azure للبنية الأساسية والتطبيق والداتا، Google للـ extraction/OCR وVertex AI. فصل الأدوار، أما يزيد IAM/configuration وتعقيد التشغيل. موش architecture obligatoire ولا automatiquement أرخص.

**Montrer:** A3/A10 et G1/G2. Les comptes et données métier restent principalement sur Azure; les requêtes IA nécessaires sont envoyées à Google.

### Q41. Utilisez-vous encore Qwen ?

**Réponse:** Pipeline extraction الحالي يعتمد NuExtract3؛ Qwen code/build tooling متقاعد. هذا لا يثبت من الكود وحده أن كل ancien service cloud تم حذفه فعليّاً.

**Montrer:** G2, `gcp/services/nuextract/`, A4 `NUEXTRACT_MODEL`. L'assistant Gemini est un rôle différent de l'extraction NuExtract.

### Q42. Google Cloud est-il accessible sans authentification ?

**Réponse:** Cloud Run عندو HTTPS public ingress، أما invocation محمية بـ IAM. Azure API يحصل على tokens عبر WIF. موش besoin d'une Google JSON key permanente.

**Montrer:** A10, G1 `attribute_condition`, invoker IAM et ingress.

### Q43. Une instance minimum zéro veut-elle dire coût zéro et workers toujours actifs ?

**Réponse:** لا. تنجم scale to zero وتعمل cold start. موش garantie اللي background jobs يستمرّوا بلا instance. زادة DB، registry، storage وservices أخرى ينجموا يبقى عندهم coût.

**Montrer:** A4 `min_replicas=0`, `max_replicas=1`; G1 scaling. Les workers nécessitent une revue séparée de leur déclenchement/disponibilité; ne pas présenter le staging comme worker 24/7 garanti.

### Q44. Namecheap et GitHub Pages font-ils partie du backend ?

**Réponse:** Namecheap domaine/DNS. Landing page على GitHub Pages مستقلّة عن app React على Azure. DNS `app` يوجّه للواجهة؛ موش قاعدة البيانات وموش مصدر code NestJS.

**Montrer:** A3 custom domain et guide DEPLOYMENT; Namecheap DNS seulement en consultation, sans modifications pendant la présentation.

### Q45. Pourquoi garder moved.tf ?

**Réponse:** أثناء simplification نقلنا resources من modules صغار لـ staging. mappings يقولوا نفس المورد تبدّلت adresse متاعو. نحافظوا عليهم باش éviter recreation عند states anciennes.

**Montrer:** A17 et [SIMPLIFICATION.md](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/SIMPLIFICATION.md>).

### Q46. Que se passe-t-il si je modifie quelque chose manuellement dans Azure ?

**Réponse:** يصير drift بين code وlive. Plan العادي يعمل refresh وينجم يقترح يرجّع إعدادات الكود حسب fields managed. يلزم مراجعة قبل apply، موش الضغط آلياً.

**Montrer:** T3. Rappeler l'exception volontaire du champ image API ignoré dans A4.

### Q47. Puis-je supprimer bootstrap ou le state pour simplifier ?

**Réponse:** حذف folder الكود موش نفس حذف resources. حذف state/storage ينجم يضيّع tracking متاع infrastructure. ما نستعملوش destroy كحلّ simplification.

**Montrer:** A1 lock; A5/A8/A4 lifecycle protections. Les protections ne remplacent pas la revue et peuvent être modifiées par une personne autorisée.

### Q48. Cette architecture est-elle production-ready et hautement disponible ?

**Réponse:** هذا staging PFE فيه controls مفيدة، أما API maximum one replica وDB بدون geo-redundant backup في configuration الحالية. Production تتطلب اختبارات charge، stratégie HA/restore، monitoring réel وrevue coûts/permissions.

**Montrer:** A4, A5, A11. Ne pas confondre «hébergé dans le cloud» avec «redondant et disponible sans interruption».

## 10. Démonstration sûre pendant Google Meet

Objectif: expliquer le code, **pas modifier l'infrastructure live**.

1. Ouvrir ce guide et la phrase de la section 1.
2. Ouvrir A2 pour montrer le découpage actuel.
3. Ouvrir A1 pour montrer seulement la fondation du state. Ne pas ouvrir `terraform.tfstate`.
4. Ouvrir A12 et `backend.hcl.example` pour expliquer l'emplacement du state.
5. Ouvrir A3 puis A4 pour distinguer registry et runtime.
6. Ouvrir A5 puis A3 pour montrer comment l'adresse DB est transmise.
7. Ouvrir A6 puis A4 pour montrer identité, permission et secret reference, jamais le secret value.
8. Ouvrir B1 puis B2/B3: recette Docker → checks → push → update.
9. Ouvrir B4/B5 pour montrer comment React connaît l'URL NestJS.
10. Ouvrir T1 pour prouver qu'un push infrastructure ne déploie pas.
11. Si le mentor demande Google, ouvrir G1/G2 et A10, sinon garder le focus Azure.
12. Dans Azure Portal, montrer les ressources/health/logs disponibles, pas des secrets ni les contenus comptables des clients.

### Où regarder dans les interfaces ?

| Question | Interface / emplacement |
| --- | --- |
| Où sont les ressources ? | Azure Portal → Resource groups → groupe de l'environnement. |
| Où est la mémoire Terraform ? | Groupe dédié au state → Storage account → Containers → `tfstate`; ne pas afficher le contenu du blob. |
| Où est l'image NestJS ? | Container Registry → Repositories → `fiscora-backend`. |
| Quelle version tourne ? | Container App → Revisions and replicas; comparer avec le digest du workflow. |
| Où sont les secrets ? | Key Vault → Secrets, afficher seulement noms/metadonnées si nécessaire. |
| Pourquoi un job a échoué ? | GitHub repo applicatif → Actions → run → job → logs. |
| Où sont les variables GitHub ? | Settings → Secrets and variables → Actions → Variables; ne pas exposer les secrets. |
| Où voir le monitoring ? | Application Insights / Log Analytics; afficher des données réelles seulement si présentes. |

L'emplacement exact des menus Portal peut évoluer; utilisez la recherche Azure si un libellé diffère.

### Vérifications sans apply

Depuis la racine infrastructure, cette commande ne déploie rien:

```powershell
./scripts/check.ps1
```

Un plan normal **lit les ressources cloud et peut temporairement verrouiller le state**, mais ne réalise pas les changements de ressources proposés:

```powershell
./scripts/plan.ps1 -Cloud Azure
```

Ne lancez pas `terraform apply`, `destroy`, `init -reconfigure`, `state rm`, build cloud ou pause/reprise de services juste pour montrer une présentation. Ne modifiez pas les tfvars, le suffixe, les noms, l'identité ou le backend d'état.

Pour Terraform Vision: working directory = `azure/environments/staging`, var file = celui de **staging**, AWS profile = None. Run Plan affiche un report de changements, pas un diagramme d'architecture. [Documentation de l'extension](https://marketplace.visualstudio.com/items?itemName=luimont.terraform-vision-vscode)

## 11. Pièges à éviter dans les réponses

- «Tout est automatisé par un push Terraform.» → Faux actuellement: checks seulement, apply manuel.
- «backend.tf contient mon backend NestJS.» → Faux: configuration du stockage state.
- «Terraform exécute les fichiers par ordre.» → Faux: dépendances entre ressources.
- «Les modules sont des microservices.» → Faux: organisation de configuration.
- «GitHub Variables donnent l'accès Azure à elles seules.» → Faux: OIDC trust et rôles nécessaires.
- «Managed Identity = utilisateur Fiscora.» → Faux: identité d'un workload cloud.
- «Key Vault veut dire aucun secret dans state.» → Faux pour les secrets Terraform-managed.
- «PostgreSQL privé veut dire tous les services privés.» → Faux.
- «CORS remplace les permissions.» → Faux.
- «Registry exécute Docker.» → Faux: stocke les images.
- «Terraform crée les comptes utilisateurs Fiscora.» → Faux: application/migrations responsables du métier/schema.
- «Le budget bloque automatiquement les dépenses.» → Faux: alertes.
- «Application Insights créé = tracing complet prouvé.» → Faux: vérifier instrumentation et telemetry réelle.
- «Ancien Qwen retiré du code = toutes les anciennes ressources supprimées.» → Pas démontré sans inspection cloud.
- «Scale to zero garantit workers actifs et facture zéro.» → Faux.
- «Ce staging est entièrement redondant en production.» → Faux.

## 12. Ordre d'apprentissage conseillé

1. **B1 → B2 → B3:** comprendre une release NestJS.
2. **A2 → A3 → A4:** comprendre où NestJS tourne.
3. **A5 → A7:** comprendre l'accès PostgreSQL.
4. **A6 → A9:** distinguer runtime identity et deployment identity.
5. **A1 → A12 → A15/A16 → T3:** comprendre state, paramètres et plan/apply.
6. **B4 → B5 → B6:** comprendre React vers NestJS.
7. **A8 → A11:** comprendre documents, protection et monitoring.
8. **A10 → G1/G2:** expliquer Google si demandé.

Pour chaque fichier, répondre à quatre questions: **Pourquoi existe-t-il ? Quels inputs reçoit-il ? Quelles ressources/résultats produit-il ? Comment est-il raccordé au reste ?**

## 13. Références complémentaires

- [Azure START-HERE](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/START-HERE.md>): carte courte des fichiers Azure.
- [Azure DEPLOYMENT](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/DEPLOYMENT.md>): procédure de première installation et mises à jour.
- [Azure SIMPLIFICATION](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/azure/SIMPLIFICATION.md>): changements de structure et précautions de state.
- [Google README](<C:/Users/Sami Mahjoub/Downloads/sams/Fiscora-tn-infrastructure/gcp/README.md>): partie IA actuelle.
- [HashiCorp: structure des fichiers](https://developer.hashicorp.com/terraform/language/files).
- [HashiCorp: state](https://developer.hashicorp.com/terraform/language/state).
- [HashiCorp: backend configuration](https://developer.hashicorp.com/terraform/language/backend).
- [HashiCorp: données sensibles](https://developer.hashicorp.com/terraform/language/manage-sensitive-data).
- [Microsoft: Azure GitHub OIDC](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure-openid-connect).
- [GitHub: variables](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-variables).

**En cas de doute devant le mentor:** «Je peux vous montrer la configuration. Pour affirmer l'état réel en production/staging, je dois aussi vérifier les ressources et les logs live.» C'est une réponse plus correcte que d'inventer un comportement.

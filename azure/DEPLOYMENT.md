# Déployer Fiscora, simplement

Deux responsabilités : **Terraform prépare l'infrastructure ; GitHub Actions
déploie le code.** Azure héberge l'application. Google Cloud héberge l'IA dans
une configuration séparée. Namecheap fournit les noms de domaine.

Ce guide décrit les commandes à exécuter après vérification. Il ne déclenche
aucun déploiement tout seul. Ne lancez jamais `apply` sans lire le plan.

## Si Fiscora est déjà déployé

Ne recommencez pas le bootstrap et ne recopiez pas les fichiers d'exemple.
Conservez vos fichiers locaux, le state, les identités et les noms existants.
Passez directement à « Mise à jour » ci-dessous.

## Première installation

### 1. Se connecter à Azure

Installez Azure CLI et Terraform >= 1.10. Le compte doit pouvoir créer les
ressources et les affectations de rôles dans la souscription.

Depuis la racine du dépôt infrastructure :

```powershell
az login
az account set --subscription <subscription-id>
az account show --output table
./azure/scripts/register-resource-providers.ps1 -SubscriptionId <subscription-id>
```

### 2. Préparer le stockage du state

Uniquement pour une nouvelle installation :

```powershell
cd azure/bootstrap
Copy-Item terraform.tfvars.example terraform.tfvars
# Renseigner la souscription et un nom de stockage unique.
terraform init -backend=false
terraform plan -out bootstrap.tfplan
# Lire le plan avant de continuer.
terraform apply bootstrap.tfplan
```

Le bootstrap crée seulement le stockage protégé du state et l'accès de votre
compte opérateur. Aucune identité GitHub n'est nécessaire pour les vérifications.
Protégez aussi son state local. Le state et les plans peuvent contenir des
secrets : ne les partagez pas et ne les ajoutez pas à Git.

### 3. Créer la plateforme, sans API pour le moment

Dans `azure/environments/staging`, copier `backend.hcl.example` et
`terraform.tfvars.example` seulement si ces fichiers locaux n'existent pas.
Renseigner les valeurs propres à votre compte : souscription, suffixe stable,
stockage du bootstrap, IDs numériques GitHub et login SMTP. Pour
`operator_object_id`, utiliser `az ad signed-in-user show --query id -o tsv`.
Ne jamais mettre de mot de passe ou de clé API dans `terraform.tfvars`.

Garder `deploy_application=false` et `backend_image=""` à cette étape :

```powershell
terraform init -backend-config=backend.hcl
terraform validate
terraform plan -out staging.tfplan
# Vérifier les ressources et le coût, puis seulement :
terraform apply staging.tfplan
```

La base, le stockage, Key Vault, les identités, le registre d'images et le
frontend existent maintenant. L'API n'est pas encore créée.

### 4. Préparer GitHub et la clé SMTP

Depuis la racine du dépôt infrastructure :

```powershell
./scripts/show-deployment-settings.ps1
```

Copier les variables affichées dans **Settings → Secrets and variables → Actions
→ Variables** des dépôts backend/frontend correspondants. Ce helper lit seulement
des noms, IDs et URLs ; il ne modifie ni GitHub ni Azure et n'affiche aucune clé.
Il affiche le nom de la future API même avant sa création, mais attend sa création
pour afficher `AZURE_API_URL`. Les identités de déploiement ne sont pas l'identité
d'exécution de l'API. Aucun paramètre cloud n'est requis dans le dépôt infrastructure.

Dans le dossier `azure/environments/staging`, enregistrer la clé SMTP sans l'inscrire
dans l'historique PowerShell :

```powershell
$smtpKey = Read-Host 'Brevo SMTP key' -AsSecureString
../../scripts/set-runtime-secrets.ps1 `
  -KeyVaultName (terraform output -raw key_vault_name) `
  -BrevoSmtpKey $smtpKey
```

Brevo sert uniquement aux emails sortants (invitations, récupération de mot
de passe, etc.). Aucun transfert Gmail ni webhook de réception n'est requis.

### 5. Publier la première image puis créer l'API

Dans GitHub du backend : **Actions → Backend CI → Run workflow → main**,
cocher **bootstrap_image_only**. Les contrôles s'exécutent puis l'image est
envoyée au registre. Aucune Container App n'est mise à jour dans ce mode.

Copier le digest affiché dans le résumé, par exemple
`registre.azurecr.io/fiscora-backend@sha256:...`, dans `backend_image`.
Mettre `deploy_application=true`, créer et vérifier un **nouveau** plan,
puis l'appliquer. Ne réutilisez pas le plan de l'étape 3.

Garder `deploy_application=true` après cette création. Le backend applique
ses migrations au démarrage (`DB_MIGRATIONS_RUN=true`). Terraform ne crée pas
vos utilisateurs/dossiers : utilisez ensuite le parcours de l'application.

### 6. Publier le frontend et raccorder le domaine

Relancer `./scripts/show-deployment-settings.ps1` depuis la racine. Configurer
`AZURE_API_URL` dans le dépôt frontend avec l'URL HTTPS affichée, sans suffixe
`/api`. Lancer son workflow de déploiement. Tester
d'abord les URLs Azure, la connexion et le chargement de documents.

Pour le domaine personnalisé, suivre les outputs de validation DNS du staging
et les instructions Azure : TXT de validation et CNAME `app` dans Namecheap.
Ne gardez pas simultanément un A et un CNAME pour `app`. La landing page
GitHub Pages et ses propres enregistrements restent indépendants.

### 7. Ajouter l'IA si nécessaire

Suivre [le guide Google Cloud](../../gcp/README.md), puis renseigner les URLs
et la fédération d'identité dans le staging Azure avant d'activer extraction
et assistant. Ne remplacez pas les valeurs d'un déploiement existant.

## Mise à jour : que fait un push ?

- **Backend/frontend** : tests, build puis déploiement du code sur `main`.
- **Infrastructure** : formatting, validation et tests sans accès au cloud.
  Le push n'exécute jamais `terraform apply`.
- Le workflow de plan cloud a été retiré. Les plans et applies sont locaux :
  une seule configuration staging privée, pas de duplication dans GitHub.
- Terraform ne modifie plus l'image API après création. GitHub est responsable
  de ses releases ; Terraform garde la configuration et l'image ClamAV.

Depuis la racine du dépôt, avec votre compte opérateur connecté :

```powershell
./scripts/check.ps1
./scripts/plan.ps1 -Cloud Azure -OutFile reviewed-azure.tfplan
# Lire toutes les actions. Puis seulement si elles sont approuvées :
terraform -chdir=azure/environments/staging apply reviewed-azure.tfplan
```

Un apply d'un plan enregistré démarre sans nouvelle confirmation. Choisir un
nouveau nom si le plan existe déjà. Ne pas réutiliser un plan après une modification.

## Installation existante : retirer l'ancien accès GitHub au plan

Pour une installation existante, le retrait du workflow ne supprime pas à lui
seul l'identité dans Azure. Notre staging a été nettoyé avec approbation le
7 octobre ; voir [SIMPLIFICATION.md](SIMPLIFICATION.md). La procédure ci-dessous
est conservée pour les autres installations.
Ne recréez pas le bootstrap : gardez son state local et ses noms de stockage.
Retirer seulement les anciens paramètres `github_owner`, `github_owner_id`,
`github_infrastructure_repository` et `github_infrastructure_repository_id` du
`terraform.tfvars` du bootstrap. Retirer aussi l'ancien input inutilisé
`github_infrastructure_repository` du staging s'il y est encore présent.
Garder `github_owner`, `github_owner_id` et tous les paramètres frontend/backend
du staging : ils restent nécessaires aux déploiements applicatifs.

```powershell
./scripts/plan.ps1 -Cloud AzureBootstrap -OutFile retire-plan-identity.tfplan
```

Le plan doit supprimer uniquement l'identité `terraform_plan`, sa confiance
`terraform_main` et ses deux rôles `terraform_plan_subscription_reader` /
`terraform_plan_state`. Aucune suppression/recréation du stockage, du container,
de l'accès opérateur ou du verrou n'est attendue. Si le verrou Azure bloque un
retrait de rôle, arrêtez et revoyez l'opération ; ne retirez pas la protection
automatiquement. Appliquer seulement après une revue et une approbation séparées.

Les anciennes variables/secret Actions du dépôt infrastructure peuvent ensuite
être retirés : `AZURE_TERRAFORM_CLIENT_ID`, `AZURE_TENANT_ID`,
`AZURE_SUBSCRIPTION_ID`, `AZURE_TF_STATE_RESOURCE_GROUP`,
`AZURE_TF_STATE_STORAGE_ACCOUNT` et `AZURE_TERRAFORM_TFVARS`.
Ne pas supprimer ceux des dépôts backend/frontend : leurs déploiements les utilisent.

## Nettoyage de l'ancienne réception par email

Pour notre staging existant, le nettoyage Azure/Brevo et la configuration
GitHub ont été appliqués et vérifiés le 05/10/2026. Voir
[le compte rendu](CLEANUP-STATUS.md) : il reste seulement les quatre NS
`inbox` à retirer dans Namecheap. La procédure suivante est conservée pour
les autres installations éventuelles.

Ce changement de code prépare, mais n'applique pas, le retrait de six ressources
DNS (zone `inbox` et cinq enregistrements) et des paramètres API associés.
Faire un plan staging et vérifier qu'il ne supprime ni base, ni documents,
ni identités. Un plan bootstrap séparé retire l'ancien credential OIDC pour
les pull requests. Le retrait ultérieur de l'identité de plan manuel est décrit
dans la section précédente ; il n'est pas inclus dans ce nettoyage historique.

Avant l'apply du nettoyage : désactiver le transfert Gmail et le webhook Brevo
entrant. Ensuite retirer uniquement les NS `inbox` dans Namecheap. Conserver
les DNS du site/app et de l'envoi SMTP/DKIM. Les anciens secrets Key Vault
ne sont pas supprimés automatiquement.

Si Terraform signale des variables locales retirées, enlever seulement
`email_ingestion_domain`, `email_ingestion_max_attachment_bytes`,
`brevo_api_key_secret_name` et `inbound_email_webhook_secret_name` de vos
paramètres. Aucun document ni historique comptable n'est effacé.

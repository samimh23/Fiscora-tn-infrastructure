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

Le bootstrap crée le stockage du state et l'identité GitHub de lecture/plan.
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

Dans les variables Actions des dépôts backend/frontend :

| Variable | Backend | Frontend |
|---|---|---|
| `AZURE_CLIENT_ID` | output `github_backend_client_id` | output `github_frontend_client_id` |
| `AZURE_TENANT_ID` / `AZURE_SUBSCRIPTION_ID` | vos IDs Azure | vos IDs Azure |
| `AZURE_RESOURCE_GROUP` | groupe créé | groupe créé |
| `AZURE_CONTAINER_REGISTRY_NAME` / `AZURE_CONTAINER_REGISTRY_LOGIN_SERVER` | registre créé | non requis |
| `AZURE_CONTAINER_APP_NAME` | nom de la future API : `ca-<name_prefix>-api` | non requis |
| `AZURE_STATIC_WEB_APP_NAME` | non requis | output correspondant |

Les outputs du staging fournissent les noms/IDs. Les identités de déploiement
ne sont pas l'identité d'exécution de l'API.

En restant dans le dossier staging, enregistrer la clé SMTP sans l'inscrire
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

Configurer `AZURE_API_URL` dans le dépôt frontend avec l'URL HTTPS de l'API
(output `container_app_fqdn`). Lancer son workflow de déploiement. Tester
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
- Pour examiner Azure : lancer manuellement **Terraform Azure staging plan** sur
  `main`. Le workflow nécessite les variables `AZURE_TERRAFORM_CLIENT_ID`
  (output bootstrap `github_terraform_plan_client_id`), `AZURE_TENANT_ID`,
  `AZURE_SUBSCRIPTION_ID`, `AZURE_TF_STATE_RESOURCE_GROUP` et
  `AZURE_TF_STATE_STORAGE_ACCOUNT`.
- Ce plan GitHub compare la configuration au state existant (`-refresh=false`).
  Il ne certifie pas l'état réel d'Azure. Avant un apply, faire un plan local
  avec refresh normal sous votre compte opérateur, qui dispose des droits
  requis sur Key Vault et Entra. L'identité CI garde des droits limités.
- Ajouter le secret GitHub `AZURE_TERRAFORM_TFVARS` avec **tous vos paramètres
  staging revus**, identiques à la configuration locale. Il sert à protéger
  cette configuration de compte, pas à stocker des mots de passe/clés API.
  Sans ce secret, le plan échoue au lieu de supposer que l'API est désactivée.
- Terraform ne modifie plus l'image API après création. GitHub est responsable
  de ses releases ; Terraform garde la configuration et l'image ClamAV.

## Nettoyage de l'ancienne réception par email

Ce changement de code prépare, mais n'applique pas, le retrait de six ressources
DNS (zone `inbox` et cinq enregistrements) et des paramètres API associés.
Faire un plan staging et vérifier qu'il ne supprime ni base, ni documents,
ni identités. Un plan bootstrap séparé retire l'ancien credential OIDC pour
les pull requests ; le credential de plan manuel sur `main` est conservé.

Avant l'apply du nettoyage : désactiver le transfert Gmail et le webhook Brevo
entrant. Ensuite retirer uniquement les NS `inbox` dans Namecheap. Conserver
les DNS du site/app et de l'envoi SMTP/DKIM. Les anciens secrets Key Vault
ne sont pas supprimés automatiquement.

Si Terraform signale des variables locales retirées, enlever seulement
`email_ingestion_domain`, `email_ingestion_max_attachment_bytes`,
`brevo_api_key_secret_name` et `inbound_email_webhook_secret_name` de vos
paramètres. Aucun document ni historique comptable n'est effacé.

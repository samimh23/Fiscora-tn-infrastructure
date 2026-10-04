# Azure Terraform — commencer ici

Ce dossier décrit **où et comment Fiscora est hébergé sur Azure**. Ce n'est pas
le code métier NestJS ou React. Terraform configure l'infrastructure ; GitHub
Actions construit et déploie le code ; NestJS exécute la logique métier.

## Les quatre parties de staging/main.tf

Ouvrez [`environments/staging/main.tf`](environments/staging/main.tf).
Les modules sont les composants réutilisables placés dans `modules/`.

| Partie | Modules | Rôle |
| --- | --- | --- |
| 1. Fondation | `network`, `security`, `google_wif`, `ci` | Réseau privé, secrets, identité du backend, authentification Google et droits de déploiement GitHub. |
| 2. Données | `storage`, `database` | Documents dans Blob Storage ; données métier et vecteurs dans PostgreSQL. |
| 3. Hébergement | `registry`, `frontend`, `application` | Images Docker dans ACR ; React dans Static Web Apps ; NestJS et ClamAV dans Container Apps. |
| 4. Exploitation | `monitoring`, `budget` | Logs, erreurs et alertes de dépenses. Le budget ne bloque pas la facture. |

Le début du fichier prépare les noms, les étiquettes et le groupe de ressources
(le dossier logique qui rassemble les ressources dans Azure).

## Lire une ligne Terraform

```hcl
database_host = module.database.fqdn
```

Cette ligne donne à l'application l'adresse créée par le module `database`.

- `var.xxx` : un paramètre d'entrée défini dans `variables.tf`.
- `local.xxx` : une valeur calculée dans ce dossier.
- `module.xxx.yyy` : un résultat produit par un autre module.
- `source` : l'emplacement du module.
- `depends_on` : une dépendance explicite à attendre.

Terraform lit les fichiers `.tf` du même dossier ensemble. Il suit les
dépendances ; il n'exécute pas `main.tf` ligne par ligne.

## Quels fichiers ouvrir ?

| Fichier/dossier | Quand l'utiliser |
| --- | --- |
| `environments/staging/main.tf` | Comprendre comment les composants sont assemblés. |
| `environments/staging/variables.tf` | Comprendre les paramètres et leurs valeurs par défaut. |
| `environments/staging/terraform.tfvars.example` | Préparer une **nouvelle** installation. |
| `environments/staging/terraform.tfvars` | Paramètres locaux existants : ne pas publier ni remplacer. |
| `environments/staging/backend.hcl` | Emplacement de l'état distant : ne pas publier ni remplacer. |
| `environments/staging/outputs.tf` | Adresses et identifiants produits par les modules. |
| `environments/staging/providers.tf` / `versions.tf` | Fournisseurs Azure et versions compatibles. |
| `modules/` | Détails de création de chaque composant. |
| `scripts/` | Validation et configuration complémentaire des secrets/e-mails. |
| `bootstrap/` | Création initiale du stockage de l'état ; pas à refaire pour une installation existante. |

## Ne changer que les paramètres nécessaires

Les régions, les tailles PostgreSQL, les noms de secrets, le scanner et les
modèles IA ont déjà des valeurs par défaut. Elles n'ont pas été changées par
ce rangement de lisibilité.

Pour une **nouvelle** installation, le modèle regroupe les paramètres propres
au compte : abonnement Azure, objet Entra de l'opérateur, suffixe unique,
destinataire des alertes, URI de fédération Entra, identifiants numériques GitHub
et login SMTP Brevo. Les options IA et domaines personnalisés sont activées après
leurs prérequis. Les clés Brevo vont dans Key Vault via les scripts, jamais dans Git.

Pour l'installation **existante**, gardez toutes vos valeurs actuelles, même
si elles diffèrent des valeurs par défaut. Ne copiez pas le modèle par-dessus
`terraform.tfvars`. Ne remettez pas `deploy_application` à `false` : cela peut
prévoir la suppression de l'API. Ne changez pas le suffixe, les noms de modules,
les noms de ressources ou l'adresse du backend pour un simple rangement.

## Vérifier l'installation existante sans déployer

Depuis la racine du dépôt, avec Azure CLI et Terraform installés :

```powershell
# Lire la version et vérifier le compte déjà connecté.
terraform version
az account show --output table

# Entrer dans le bon environnement sans remplacer ses fichiers locaux.
Set-Location azure/environments/staging
terraform init -backend-config=backend.hcl
terraform fmt -check
terraform validate
terraform plan -input=false -detailed-exitcode
```

`init` prépare les fournisseurs et l'accès à l'état ; `validate` vérifie le code ;
`plan` compare la configuration et les ressources. Ces commandes ne déploient
pas les ressources de l'application. Elles peuvent accéder au cloud et verrouiller
temporairement l'état pendant la vérification.

- Code de sortie `0` du plan : aucun changement proposé.
- Code `2` : changements proposés ; les examiner avant toute décision.
- Code `1` : erreur ; corriger le problème avant d'aller plus loin.

Pour un rangement de fichiers/commentaires, le plan doit rester inchangé. Un
changement peut aussi venir d'une modification externe (par exemple une nouvelle
image publiée par GitHub Actions) : ne pas l'appliquer automatiquement.

`terraform apply` modifie réellement Azure. Il n'est **pas** nécessaire pour
présenter le projet ni pour valider des commentaires. `terraform destroy`, les
commandes de modification d'état et les anciens plans enregistrés ne font pas
partie de ce guide. Ne partagez jamais l'état, un plan binaire ou des secrets.

## Exemple concret : Key Vault → backend

1. `security` crée le coffre, l'identité managée et les secrets générés.
2. `main.tf` transmet les références de secrets au module `application`.
3. Container Apps utilise cette identité pour lire les secrets dans Key Vault.
4. NestJS lit les valeurs fournies dans son environnement, par exemple `DB_PASSWORD`.

Le backend ne demande pas les secrets à chaque requête utilisateur. Les fichiers
comptables vont dans Blob Storage, pas dans Key Vault. La fédération Google WIF
sert à l'authentification, pas au transport des documents.

## Explication courte pour le mentor

> Le fichier staging/main.tf assemble l'infrastructure Azure en quatre parties :
> fondation, données, hébergement et exploitation. Il réutilise des modules et
> relie leurs résultats. Par exemple, l'API reçoit l'adresse de PostgreSQL et
> les références des secrets Key Vault. Terraform prépare l'infrastructure ;
> GitHub Actions publie le code. Les services IA Google sont gérés par une pile
> Terraform séparée dans le dossier gcp.

Pour une première installation ou les procédures avancées, suivre
[`DEPLOYMENT.md`](DEPLOYMENT.md), puis [`README.md`](README.md).
Après la première création, GitHub gère les versions de l'image API ; Terraform
continue à gérer les paramètres, les secrets, le réseau et le scanner ClamAV.
La réception des factures par e-mail est retirée ; les e-mails sortants restent.
Pour le schéma compact, voir
[`docs/architecture`](../docs/architecture/README.md).

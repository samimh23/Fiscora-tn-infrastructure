# Azure Terraform — commencer ici

Ce dossier configure l'hébergement de Fiscora, pas la logique métier.
Terraform prépare Azure ; GitHub Actions publie React et NestJS.

La migration réelle vers App Service est suivie dans
[le journal du 8 octobre](CUTOVER-2026-10-08.md). Le nettoyage de l'ancien
Container Apps et du réseau privé est suivi dans
[le journal de nettoyage](LEGACY-HOSTING-CLEANUP-2026-10-08.md).
Le seul backend actif est App Service.

## Le fichier à ouvrir en premier

Ouvrez [staging/main.tf](environments/staging/main.tf). Il définit les noms,
les étiquettes et le groupe de ressources, puis indique les fichiers à lire.
Tous les composants sont directement dans staging, sans module enfant.

## Où trouver chaque composant ?

Tous ces fichiers sont dans `azure/environments/staging/`.

| Fichier | Ce qu'il crée ou raccorde |
| --- | --- |
| `main.tf` | Noms communs, tags, groupe de ressources et carte des fichiers. |
| `hosting.tf` | Registre Docker et frontend React. |
| `app-service.tf` | Nouvel hébergement NestJS/ClamAV, identité et références Key Vault. |
| `database.tf` | Même serveur PostgreSQL, même base et extensions ; accès TLS avec IP exactes dans `database-firewall.tf`. |
| `database-firewall.tf` | Accès PostgreSQL limité aux IP de sortie exactes d'App Service. |
| `migration-settings.tf` | Contrôles temporaires de préparation et activation. |
| `storage.tf` | Documents privés, droits d'accès et protection contre la suppression. |
| `security.tf` | Identité du backend, Key Vault et secrets générés. |
| `deployment-access.tf` | Identités GitHub et confiance OIDC pour déployer sans mot de passe Azure. |
| `google-auth.tf` | Authentification Azure vers Google pour NuExtract, OCR et Gemini, sans clé Google permanente. |
| `monitoring.tf` | **Application Insights conservé**, Log Analytics et alertes de coût. |
| `variables.tf` / `terraform.tfvars.example` | Paramètres disponibles / exemple pour une nouvelle installation. |
| `outputs.tf` | Noms et adresses utiles après création. |
| `moved.tf` | Compatibilité des ressources conservées avec l'ancien découpage ; ne pas supprimer. |
| `backend.tf` / `providers.tf` / `versions.tf` | État distant, accès aux fournisseurs et versions. |

`app-service.tf` contient le nouveau site, son conteneur NestJS et son antivirus
ClamAV. Les anciens fichiers `application.tf` et `network.tf` ne sont plus actifs.
Les tests dans `staging/tests/` empêchent Terraform de remettre une ancienne
image publiée par GitHub. Aucun module enfant ne reste : les références montrent
directement les connexions avec la base, le stockage, Key Vault et l'IA.

## Comment « ce fichier parle à cet autre fichier » ?

Terraform lit **tous les fichiers .tf du même dossier ensemble**.
Il suit les références, pas l'ordre des fichiers.

Dans les paramètres d'application de `app-service.tf` :

```hcl
DB_HOST = azurerm_postgresql_flexible_server.postgres.fqdn
```

Cela signifie : « donner au backend l'adresse du serveur PostgreSQL que
`database.tf` crée ». Terraform ne copie pas des fichiers entre services.

- `var.xxx` : paramètre défini dans `variables.tf`.
- `local.xxx` : nom ou valeur calculée dans `main.tf`.
- `azurerm_...nom.attribut` : propriété d'une ressource Azure.
- Une référence directe évite le passage par des inputs/outputs de module.
- `depends_on` : attendre aussi une préparation nécessaire, par exemple les droits IAM.

## Exemple : Key Vault → NestJS

1. `security.tf` crée le coffre, l'identité managée et les secrets générés.
2. `app-service.tf` référence directement ces secrets et cette identité.
3. App Service utilise cette identité pour résoudre les références Key Vault.
4. NestJS reçoit les valeurs dans son environnement, par exemple `DB_PASSWORD`.

Les fichiers comptables vont dans Blob Storage, pas dans Key Vault.
La fédération Google sert à obtenir des jetons d'authentification ; elle ne
transporte pas les documents.

## Ce que la simplification ne change pas

Application Insights, données PostgreSQL, sauvegardes, ClamAV, secrets, identités,
stockage des documents, GitHub OIDC et fédération Google sont conservés.
La connexion PostgreSQL devient publique-capable avec pare-feu IP exact et TLS,
pas ouverte à tout Internet. Le même serveur et le même mot de passe restent.
Le nom et l'URL du nouvel hôte changent ; le helper de paramètres suit l'hôte actif.

`moved.tf` dit à Terraform : « cette ressource existante a maintenant une autre
adresse dans le code ». Il évite de recréer les ressources ou de régénérer les
secrets. Gardez ces mappings tant qu'un ancien état peut être utilisé.
Le prochain apply approuvé enregistrera ces adresses dans l'état ; aucun apply
n'est lancé par un push.

## Vérifier sans déployer

Depuis la racine :

```powershell
./scripts/check.ps1
./scripts/plan.ps1 -Cloud Azure
```

Le premier vérifie le code et les tests mockés. Le second lit Azure avec votre
compte opérateur et propose un plan ; il ne l'applique pas.
GitHub lance uniquement les vérifications sans accès au cloud. Le workflow de
plan Azure a été retiré : le plan et l'apply sont locaux, après revue.
`./scripts/show-deployment-settings.ps1` affiche les variables GitHub nécessaires
aux déploiements frontend/backend, sans afficher les mots de passe ou les clés.

Gardez vos `terraform.tfvars` et `backend.hcl` existants. Ne les remplacez pas
par les exemples. Gardez `deploy_application=true` et les paramètres actifs dans
`cutover.auto.tfvars` pour une API déjà créée.
Ne changez pas le suffixe, le backend d'état ou les mappings pour une présentation.
Ne partagez jamais l'état, un plan binaire ou les secrets.

Voir [SIMPLIFICATION.md](SIMPLIFICATION.md) pour la vérification avant/après,
[DEPLOYMENT.md](DEPLOYMENT.md) pour une première installation et
[README.md](README.md) pour les limites de staging.

## Phrase pour le mentor

> Terraform crée la base, son pare-feu, le stockage, les identités et l'hébergement.
> Nous avons un fichier par sujet plutôt qu'un module pour chaque petite ressource.
> Les références raccordent les composants : le backend reçoit l'adresse de
> PostgreSQL et les références Key Vault. GitHub Actions déploie ensuite le code.
> Les services IA restent sur Google Cloud, avec une authentification sans clé
> permanente. Application Insights permet de suivre les erreurs et les requêtes.

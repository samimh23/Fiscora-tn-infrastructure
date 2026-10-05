# Qwen retirement note

The rendered diagrams and renderer sources below predate Qwen retirement. They
are historical exports, not the current deployment diagram. The current target
has NuExtract3 and PaddleOCR only; generic categories are upload-only. See
gcp/README.md and Terraform source for current configuration.

# Architecture de déploiement de Fiscora — staging

## Version compacte recommandée pour la présentation

- `fiscora-architecture-corrected-original.png` : reprise corrigée du premier
  schéma, dans son style sombre et horizontal, 5520 × 2280.
- `fiscora-architecture-corrected-original.svg` : export vectoriel.
- `render-corrected-original.cjs` : source de la mise en page.

Cette version conserve la vue d'ensemble initiale. Elle corrige le rôle du DNS,
les appels navigateur/API, Gemini et le RAG, l'accès IAM à Cloud Run et les builds
IA. Elle ajoute le service Qwen distinct et place ClamAV dans la même Container
App que l'API. Le chemin WIF ne transporte pas les documents.
La réception de factures par email est retirée ; Brevo ne sert plus qu'à
l'envoi SMTP. Les schémas décrivent la configuration cible après nettoyage,
pas un audit en temps réel. Le nettoyage de notre staging a ensuite été appliqué
et vérifié : voir `azure/CLEANUP-STATUS.md` pour le compte rendu.

```powershell
node Fiscora-tn-infrastructure/docs/architecture/render-corrected-original.cjs
```

## Version détaillée (annexe)

- `fiscora-deployment-staging.png` : export haute résolution, 4400 × 3320.
- `fiscora-deployment-staging.svg` : version vectorielle, adaptée à un rapport.
- `fiscora-deployment-staging.mmd` : description Mermaid éditable des relations.
- `render-architecture.cjs` : source de la mise en page SVG et du rendu PNG.

Ce schéma décrit la configuration des dépôts, pas un audit de l’état réel du cloud.
Il ne certifie ni la disponibilité, ni les versions actuellement déployées.

## Points importants

Le navigateur charge les fichiers React depuis Azure Static Web Apps, puis appelle
directement l’API NestJS. Namecheap assure la résolution DNS et ne transporte pas
les requêtes HTTPS de l’application.

L’API orchestre la recherche RAG avec PostgreSQL/pgvector. Vertex AI fournit Gemini
et les embeddings ; le projet ne déploie pas un moteur Vertex RAG géré.
NuExtract3, Qwen3.5 et PaddleOCR sont trois services distincts. NuExtract est le
provider d’extraction configuré par défaut pour les factures et relevés ; Qwen
couvre les catégories génériques. PaddleOCR fonctionne sur CPU.

Les services Cloud Run exigent IAM, mais leur ingress est public : « authentifié »
ne signifie pas « réseau privé ». WIF échange des jetons pour l’API ; il ne relaie
pas les documents. Blob Storage et Key Vault utilisent l’identité managée Azure.

ClamAV est un sidecar de la même Container App que l’API. PostgreSQL se trouve dans
un sous-réseau privé délégué, séparé de celui des Container Apps.

GitHub Actions construit et déploie l’application Azure. Les images IA sont
construites par Google Cloud Build, lancé par les scripts, puis stockées dans
Artifact Registry. Terraform provisionne Azure/GCP et configure les services
Cloud Run avec ces images.

## Sources de configuration

- `azure/environments/staging/main.tf`
- `azure/modules/application/main.tf`
- `azure/modules/network/main.tf`
- `azure/modules/database/main.tf`
- `azure/modules/frontend/main.tf`
- `gcp/environments/ai-staging/main.tf`
- `gcp/scripts/` et `gcp/services/*/cloudbuild.yaml`
- Dépôt backend : `src/assistant/assistant.service.ts`,
  `src/documents/extraction/google-wif-token.service.ts` et
  `src/documents/extraction/document-extraction-provider.service.ts`.
- Dépôt frontend : `src/api/client.ts`.
- Dépôts frontend/backend : `.github/workflows/deploy-azure-staging.yml`.

## Régénérer les exports

Depuis la racine du workspace contenant les trois dépôts, avec Node.js et
Playwright installés dans `accounting-frontend` :

```powershell
node Fiscora-tn-infrastructure/docs/architecture/render-architecture.cjs
```

Le rendu contrôle automatiquement que les textes ne dépassent pas leur carte
ou les limites du document. La source Mermaid décrit les mêmes composants, mais
utilise une mise en page automatique distincte de l’export de présentation.

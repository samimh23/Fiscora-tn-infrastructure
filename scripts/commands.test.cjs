const { readFileSync, existsSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const root = join(__dirname, '..');
const read = (file) => readFileSync(join(root, file), 'utf8');

test('one validation entry point replaces the retired duplicate cloud wrappers', () => {
  for (const file of ['azure/scripts/validate.ps1', 'gcp/scripts/validate.ps1']) {
    assert.equal(existsSync(join(root, file)), false);
  }
  const contributing = read('CONTRIBUTING.md');
  assert.match(contributing, /\.\/scripts\/check\.ps1/);
  assert.doesNotMatch(contributing, /scripts[\\/]validate\.ps1/);
});

test('simple commands never automatically apply or replace live inputs', () => {
  for (const file of ['check.ps1', 'plan.ps1', 'deploy-ai.ps1']) {
    const source = read(`scripts/${file}`);
    assert.doesNotMatch(source, /terraform\s+(apply|destroy)|Copy-Item|Set-Content|Out-File/i);
    assert.match(source, /finally \{ Pop-Location \}|build-\$Service\.ps1/);
  }
});

test('plan requires existing configuration, refreshes normally and accepts a change proposal', () => {
  const source = read('scripts/plan.ps1');
  assert.match(source, /'backend\.hcl', 'terraform\.tfvars'/);
  assert.match(source, /'AzureBootstrap' \{ 'azure\/bootstrap' \}/);
  assert.match(source, /-notin @\(0, 2\)/);
  assert.match(source, /plan file already exists/);
  assert.doesNotMatch(source, /-refresh=false|-lock=false|deploy_application\s*=/);
  assert.match(source, /-lock-timeout=60s/);
});

test('deployment settings helper reads named public outputs and never changes cloud or GitHub', () => {
  const source = read('scripts/show-deployment-settings.ps1');
  assert.match(source, /terraform output -json \$Name/);
  assert.doesNotMatch(source, /terraform\s+(init|apply|plan|destroy)|az\s|gh\s|Set-Content|Copy-Item/i);
  const names = [...source.matchAll(/Read-DeploymentOutput '([^']+)'/g)].map(([, name]) => name);
  assert.deepEqual(names, ['azure_tenant_id', 'azure_subscription_id', 'resource_group_name',
    'github_backend_client_id', 'github_frontend_client_id', 'container_registry_name',
    'container_registry_login_server', 'static_web_app_name', 'app_service_name', 'app_service_url']);
});

test('checks use no cloud backend and include mocked ownership tests', () => {
  const source = read('scripts/check.ps1');
  assert.match(source, /init -backend=false -input=false/);
  assert.match(source, /terraform test/);
  assert.doesNotMatch(source, /az login|gcloud|backend-config/);
});

test('AI release preparation selects one build and preserves configuration', () => {
  const source = read('scripts/deploy-ai.ps1');
  assert.match(source, /ValidateSet\('nuextract', 'paddleocr'\)/);
  assert.match(source, /build-\$Service\.ps1/);
  assert.doesNotMatch(source, /run services update|enable_\w+\s*=|terraform @/);
});

test('direct application wiring preserves existing data connections and release ownership', () => {
  const application = read('azure/environments/staging/app-service.tf');
  assert.match(application, /resource "azapi_resource" "app_service_api"/);
  assert.match(application, /prevent_destroy = true/);
  assert.match(application, /ignore_changes\s*= \[body.properties.image\]/);
  assert.match(application, /DB_HOST\s*= azurerm_postgresql_flexible_server\.postgres\.fqdn/);
  assert.match(application, /DB_NAME\s*= azurerm_postgresql_flexible_server_database\.application\.name/);
  assert.match(read('azure/environments/staging/database.tf'), /name\s*= "accounting_nest"/);
  assert.doesNotMatch(read('azure/environments/staging/hosting.tf'), /module "application"/);
});

test('Qwen cannot be deployed or wired back into the active app', () => {
  const app = read('azure/environments/staging/app-service.tf');
  assert.doesNotMatch(app, /QWEN_SERVICE_URL|DOCUMENT_EXTRACTION_SERVICE_URL|DOCUMENT_EXTRACTION_PROVIDER|DOCUMENT_EXTRACTION_MODEL|QWEN_CONCURRENCY/);
  const google = read('gcp/environments/ai-staging/main.tf');
  assert.doesNotMatch(google, /resource "google_cloud_run_v2_service" "nuextract"\s*\{/);
  assert.match(google, /resource "google_cloud_run_v2_service" "nuextract_candidate"/);
  assert.match(google, /resource "google_cloud_run_v2_service" "paddleocr"/);
});

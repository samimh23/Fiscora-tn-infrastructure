const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const read = name => readFileSync(join(__dirname, '..', 'azure/environments/staging', name), 'utf8');

test('migration defaults leave the live architecture unchanged', () => {
  const settings = read('migration-settings.tf');
  for (const [name, value] of [['app_service_stage', '"off"'], ['postgres_network_migrated', 'false'], ['legacy_backend_stopped', 'false']]) {
    assert.match(settings, new RegExp(`variable "${name}"[\\s\\S]*?default\\s*= ${value}`));
  }
  assert.match(settings, /var.postgres_network_migrated && var.legacy_backend_stopped/);
  assert.match(read('database.tf'), /prevent_destroy = true/);
  assert.doesNotMatch(read('app-service.tf'), /virtual_network_subnet_id|delegated_subnet_id/);
});

test('all existing runtime settings reach App Service with Key Vault references', () => {
  const source = read('application.tf');
  const target = read('app-service.tf');
  const names = [...source.matchAll(/env\s*\{\s*name\s*=\s*"([^"]+)"/g)].map(m => m[1]);
  for (const name of names) assert.match(target, new RegExp(`\\b${name}\\s*=`), name);
  for (const name of ['DB_PASSWORD', 'JWT_SIGNING_KEY', 'MFA_ENCRYPTION_KEY', 'SMTP_PASSWORD']) {
    assert.match(target, new RegExp(`${name}\\s*= "@Microsoft.KeyVault\\(SecretUri=`));
  }
  assert.match(target, /APPLICATIONINSIGHTS_CONNECTION_STRING\s*= sensitive\(azurerm_application_insights.api.connection_string\)/);
  assert.match(target, /DB_HOST\s*= azurerm_postgresql_flexible_server.postgres.fqdn/);
  assert.match(target, /DB_NAME\s*= azurerm_postgresql_flexible_server_database.application.name/);
  assert.doesNotMatch(target, /random_password\.[^.]+\.result|QWEN_SERVICE_URL|BREVO_API_KEY/);
});

test('sidecar API ownership and quarantine are narrow and explicit', () => {
  const source = read('app-service.tf');
  assert.match(source, /ignore_changes = \[body.properties.image\]/);
  assert.match(source, /enabled\s*= local.activate_app_service/);
  assert.match(source, /startUpCommand\s*= local.activate_app_service \? "" : "node -e/);
  assert.match(source, /alwaysOn\s*= true/);
  assert.match(source, /userManagedIdentityClientId\s*= azurerm_user_assigned_identity.application.client_id/);
  assert.match(source, /basicPublishingCredentialsPolicies/);
});

test('database firewall permits only exact reviewed app IPs', () => {
  const source = read('database-firewall.tf');
  assert.match(source, /start_ip_address = each.value/);
  assert.match(source, /end_ip_address\s*= each.value/);
  assert.match(source, /toset\(var.app_service_database_ips\) == toset/);
  assert.match(source, /possibleOutboundIpAddresses/);
  assert.doesNotMatch(source, /0\.0\.0\.0|255\.255\.255\.255|AzureServices/);
});

// Offline guards: do not read private inputs, remote state or saved plans.
const { readFileSync, readdirSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const root = join(__dirname, '..');
const staging = join(root, 'azure/environments/staging');
const read = name => readFileSync(join(staging, name), 'utf8');
const files = readdirSync(staging).filter(name => name.endsWith('.tf'));
const all = files.map(read).join('\n');
const moves = [...read('moved.tf').matchAll(/moved\s*\{\s*from\s*=\s*(\S+)\s+to\s*=\s*(\S+)\s*\}/g)]
  .map(([, from, to]) => ({ from, to }));

test('each former small-module resource has a unique migration to a declared root resource', () => {
  const counts = { network: 5, security: 10, ci: 5, google_wif: 4, storage: 5, database: 3, application: 2, registry: 3, frontend: 3, monitoring: 2, budget: 1 };
  assert.equal(moves.length, 43);
  assert.equal(new Set(moves.map(move => move.from)).size, 43);
  assert.equal(new Set(moves.map(move => move.to)).size, 43);
  for (const [module, count] of Object.entries(counts)) {
    assert.equal(moves.filter(move => move.from.startsWith(`module.${module}.`)).length, count, module);
  }
  const resources = [...all.matchAll(/resource "([^"]+)" "([^"]+)"\s*\{/g)].map(([, type, name]) => `${type}.${name}`);
  assert.equal(resources.length, 51); // 44 existing + 7 gated migration declarations.
  assert.equal(new Set(resources).size, resources.length);
  for (const move of moves) assert.ok(resources.includes(move.to), move.to);
});

test('Azure staging is flat with no module calls or output forwarding', () => {
  const withoutMoves = files.filter(name => name !== 'moved.tf').map(read).join('\n');
  assert.doesNotMatch(withoutMoves, /module\s+"|module\./);
  assert.match(read('application.tf'), /resource "azurerm_container_app_environment" "application"/);
  assert.match(read('application.tf'), /resource "azurerm_container_app" "api"/);
});

test('Application Insights and its backend connection stay enabled and unchanged', () => {
  const monitoring = read('monitoring.tf');
  assert.match(monitoring, /resource "azurerm_application_insights" "api"/);
  assert.match(monitoring, /sampling_percentage\s*= 25/);
  assert.match(monitoring, /retention_in_days\s*= 30/);
  assert.match(monitoring, /daily_quota_gb\s*= 0\.1/);
  assert.match(read('application.tf'), /value\s*= sensitive\(azurerm_application_insights\.api\.connection_string\)/);
});

test('application waits for runtime IAM and document protection, not unrelated deployment access', () => {
  const hosting = read('application.tf');
  const dependencies = hosting.match(/depends_on\s*=\s*\[([\s\S]*?)\]/)?.[1];
  assert.ok(dependencies, 'application preparation dependencies must remain explicit');
  assert.deepEqual(dependencies.split(',').map(value => value.trim()).filter(Boolean).sort(), [
    'azurerm_postgresql_flexible_server_configuration.extensions',
    'azurerm_role_assignment.application_pull',
    'azurerm_role_assignment.application_documents',
    'azurerm_role_assignment.application_key_vault_reader',
    'azurerm_management_lock.documents',
  ].sort());
  assert.match(hosting, /value\s*= azurerm_postgresql_flexible_server_database\.application\.name/);
  for (const name of ['postgres_password', 'jwt_signing_key', 'mfa_encryption_key']) {
    assert.match(hosting, new RegExp(`= sensitive\\(azurerm_key_vault_secret\\.${name}\\.versionless_id\\)`));
  }
  // Removing a wait must not remove the actual roles used by GitHub or the operator.
  assert.match(read('hosting.tf'), /resource "azurerm_role_assignment" "deployment_push"/);
  assert.match(read('storage.tf'), /resource "azurerm_role_assignment" "operator_documents"/);
});

test('data protection, secret generators, private networking and OIDC survive flattening', () => {
  const database = read('database.tf');
  const storage = read('storage.tf');
  const security = read('security.tf');
  assert.match(database, /public_network_access_enabled\s*= var\.postgres_network_migrated/);
  assert.match(read('migration-settings.tf'), /variable "postgres_network_migrated"[\s\S]*?default\s*= false/);
  assert.match(database, /backup_retention_days\s*= 7/);
  assert.match(database, /prevent_destroy = true/);
  assert.match(database, /azurerm_private_dns_zone_virtual_network_link\.postgres/);
  assert.match(database, /"uuid-ossp,vector"/);
  assert.match(storage, /shared_access_key_enabled\s*= false/);
  assert.match(storage, /versioning_enabled = true/);
  assert.match(storage, /container_access_type = "private"/);
  assert.match(storage, /lock_level = "CanNotDelete"/);
  assert.match(storage, /prevent_destroy = true/);
  for (const name of ['postgres', 'jwt', 'mfa_encryption']) {
    assert.match(security, new RegExp(`resource "random_password" "${name}"`));
  }
  assert.match(security, /purge_protection_enabled\s*= true/);
  assert.match(read('deployment-access.tf'), /token\.actions\.githubusercontent\.com/);
  assert.match(read('google-auth.tf'), /GcpWorkloadIdentity/);
  assert.doesNotMatch(all, /resource "azurerm_dns_(zone|mx_record|txt_record|a_record)"/);
});

test('PostgreSQL private networking is grouped with the database without renaming resources', () => {
  const database = read('database.tf');
  for (const declaration of ['resource "azurerm_subnet" "postgres"', 'resource "azurerm_private_dns_zone" "postgres"', 'resource "azurerm_private_dns_zone_virtual_network_link" "postgres"']) {
    assert.ok(database.includes(declaration));
    assert.ok(!read('network.tf').includes(declaration));
  }
});

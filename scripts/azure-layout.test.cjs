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
  const counts = { network: 5, security: 10, ci: 5, google_wif: 4, storage: 5, database: 3, registry: 3, frontend: 3, monitoring: 2, budget: 1 };
  assert.equal(moves.length, 41);
  assert.equal(new Set(moves.map(move => move.from)).size, 41);
  assert.equal(new Set(moves.map(move => move.to)).size, 41);
  for (const [module, count] of Object.entries(counts)) {
    assert.equal(moves.filter(move => move.from.startsWith(`module.${module}.`)).length, count, module);
  }
  const resources = [...all.matchAll(/resource "([^"]+)" "([^"]+)"\s*\{/g)].map(([, type, name]) => `${type}.${name}`);
  assert.equal(resources.length, 42); // 41 migrated + the existing resource group.
  assert.equal(new Set(resources).size, resources.length);
  for (const move of moves) assert.ok(resources.includes(move.to), move.to);
});

test('only the tested Container Apps module remains and old output traversals are absent', () => {
  const modules = join(root, 'azure/modules');
  assert.deepEqual(readdirSync(modules).filter(name => !name.startsWith('.') && readdirSync(join(modules, name)).some(file => file.endsWith('.tf'))), ['application']);
  const withoutMoves = files.filter(name => name !== 'moved.tf').map(read).join('\n');
  assert.deepEqual([...withoutMoves.matchAll(/module "([^"]+)"/g)].map(([, name]) => name), ['application']);
  assert.doesNotMatch(withoutMoves, /module\.(network|security|ci|google_wif|storage|database|registry|frontend|monitoring|budget)\./);
});

test('Application Insights and its backend connection stay enabled and unchanged', () => {
  const monitoring = read('monitoring.tf');
  assert.match(monitoring, /resource "azurerm_application_insights" "api"/);
  assert.match(monitoring, /sampling_percentage\s*= 25/);
  assert.match(monitoring, /retention_in_days\s*= 30/);
  assert.match(monitoring, /daily_quota_gb\s*= 0\.1/);
  assert.match(read('hosting.tf'), /application_insights_connection_string\s*= azurerm_application_insights\.api\.connection_string/);
});

test('data protection, secret generators, private networking and OIDC survive flattening', () => {
  const database = read('database.tf');
  const storage = read('storage.tf');
  const security = read('security.tf');
  assert.match(database, /public_network_access_enabled\s*= false/);
  assert.match(database, /backup_retention_days\s*= 7/);
  assert.match(database, /prevent_destroy = true/);
  assert.match(database, /azurerm_private_dns_zone_virtual_network_link\.postgres/);
  assert.match(database, /\["uuid-ossp", "vector"\]/);
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

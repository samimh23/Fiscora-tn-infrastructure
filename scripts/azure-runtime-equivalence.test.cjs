// Non-secret source fixture: prove flattening changed wiring, not runtime values.
const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const read = p => readFileSync(join(__dirname, '..', p), 'utf8');

// Ignore comments/formatting, but preserve quoted strings byte-for-byte.
function tokens(source) {
  return [...source.matchAll(/("(?:\\.|[^"\\])*")|#[^\n]*|\/\/[^\n]*|(\s+)|([^\s])/g)]
    .filter(match => match[1] || match[3]).map(match => match[1] || match[3]);
}

test('flattened runtime matches every original setting after explicit input substitution', () => {
  const bindings = JSON.parse(read('scripts/fixtures/application-bindings.json'));
  let before = read('scripts/fixtures/application-before-flattening.tf.txt');
  before = before.replace(/var\.([a-z_]+(?:\.[a-z_]+)?)/g, (full, key) => bindings[key] || full)
    .replaceAll('azurerm_container_app_environment.this', 'azurerm_container_app_environment.application')
    .replace('resource "azurerm_container_app_environment" "this"', 'resource "azurerm_container_app_environment" "application"');
  // The former module-level waits are now on both direct runtime resources.
  const after = read('scripts/fixtures/application-retired.tf.txt')
    .replace(/depends_on\s*=\s*\[[\s\S]*?\]/g, '');
  assert.deepEqual(tokens(after), tokens(before));
});

test('both direct resources retain the original module-wide preparation waits', () => {
  const runtime = read('scripts/fixtures/application-retired.tf.txt');
  const dependencies = [...runtime.matchAll(/depends_on\s*=\s*\[([\s\S]*?)\]/g)]
    .map(match => match[1].split(',').map(value => value.trim()).filter(Boolean).sort());
  const expected = [
    'azurerm_postgresql_flexible_server_configuration.extensions',
    'azurerm_role_assignment.application_pull',
    'azurerm_role_assignment.application_documents',
    'azurerm_role_assignment.application_key_vault_reader',
    'azurerm_management_lock.documents',
  ].sort();
  assert.deepEqual(dependencies, [expected, expected]);
});

test('retired runtime mappings are gone but data and password addresses remain', () => {
  const moves = read('azure/environments/staging/moved.tf');
  assert.doesNotMatch(moves, /module\.(application|network)\./);
  // Generated passwords and the PostgreSQL server retain their existing addresses.
  assert.match(read('azure/environments/staging/database.tf'), /resource "azurerm_postgresql_flexible_server" "postgres"/);
  assert.match(read('azure/environments/staging/security.tf'), /resource "random_password" "postgres"/);
});

const { readFileSync, readdirSync, existsSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const root = join(__dirname, '..');
const read = name => readFileSync(join(root, name), 'utf8');

test('infrastructure CI only validates offline; cloud plans and applies are local', () => {
  const workflows = join(root, '.github/workflows');
  assert.deepEqual(readdirSync(workflows).filter(name => /\.ya?ml$/.test(name)), ['terraform-check.yml']);
  const checks = read('.github/workflows/terraform-check.yml');
  assert.match(checks, /contents: read/);
  assert.match(checks, /terraform test/);
  assert.match(checks, /init -backend=false/);
  assert.doesNotMatch(checks, /id-token:|azure\/login|AZURE_TERRAFORM|terraform\s+(plan|apply|destroy)/);
  assert.equal(existsSync(join(workflows, 'terraform-azure-plan.yml')), false);
});

test('bootstrap contains only state storage, operator access and deletion protection', () => {
  const bootstrap = read('azure/bootstrap/main.tf');
  const resources = [...bootstrap.matchAll(/resource "([^"]+)" "([^"]+)"/g)]
    .map(([, type, name]) => `${type}.${name}`);
  assert.deepEqual(resources, [
    'azurerm_resource_group.state',
    'azurerm_storage_account.state',
    'azurerm_storage_container.state',
    'azurerm_role_assignment.operator_state',
    'azurerm_management_lock.state',
  ]);
  assert.match(bootstrap, /container_access_type = "private"/);
  assert.match(bootstrap, /versioning_enabled = true/);
  assert.match(bootstrap, /lock_level = "CanNotDelete"/);
  assert.doesNotMatch(read('azure/bootstrap/variables.tf'), /variable "github_/);
  assert.doesNotMatch(read('azure/bootstrap/outputs.tf'), /github_terraform_plan/);
  const staging = read('azure/environments/staging/deployment-access.tf');
  assert.match(staging, /"backend_main"/);
  assert.match(staging, /"frontend_main"/);
  assert.match(staging, /token\.actions\.githubusercontent\.com/);
});

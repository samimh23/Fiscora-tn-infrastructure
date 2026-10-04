const { readFileSync } = require('node:fs');
const { join } = require('node:path');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const root = join(__dirname, '..');
const plan = readFileSync(join(root, '.github/workflows/terraform-azure-plan.yml'), 'utf8');

test('cloud planning is manual on main, never forced API removal or automatic apply', () => {
  assert.match(plan, /workflow_dispatch:/);
  assert.doesNotMatch(plan, /\n\s+pull_request:|\n\s+push:/);
  assert.match(plan, /if: github\.ref == 'refs\/heads\/main'/);
  assert.match(plan, /secrets\.AZURE_TERRAFORM_TFVARS/);
  assert.doesNotMatch(plan, /TF_VAR_deploy_application|terraform\s+apply/);
  assert.match(plan, /terraform plan -refresh=false/);
  assert.match(plan, /if: always\(\)/);
  assert.match(plan, /rm -f terraform\.tfvars/);
  assert.match(plan, /"\$result" -eq 2/);
});

test('bootstrap keeps main OIDC trust but no longer trusts pull-request code with state', () => {
  const bootstrap = readFileSync(join(root, 'azure/bootstrap/main.tf'), 'utf8');
  assert.match(bootstrap, /"terraform_main"/);
  assert.doesNotMatch(bootstrap, /"terraform_pull_request"/);
});

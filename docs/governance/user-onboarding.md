# User onboarding and least-privilege access

> **Example identity:** `binaya.sharma_np@example.com` is a placeholder. Replace it with the person's verified corporate or external email address. Never create shared user accounts.

This runbook onboards a human contributor across four independent control planes:

```text
Microsoft Entra ID  -> identity and group membership
Azure RBAC          -> Azure resource permissions
Azure Databricks    -> workspace and Unity Catalog permissions
GitHub              -> source-code contribution permissions
```

Access in one control plane does not imply access in another. Record an owner, business reason, requested duration, and platform-admin approval before granting access.

## Default developer access

| Layer | Default access |
| --- | --- |
| Microsoft Entra ID | User or invited guest with MFA; no directory administrator role |
| Azure subscription | `Reader` |
| Terraform state | No access |
| Databricks workspace | Workspace user through a group; not workspace admin |
| Unity Catalog | `USE CATALOG`, `USE SCHEMA`, and `SELECT` on approved schemas |
| GitHub | Repository collaborator; feature branches and pull requests only |

Elevate access only for a documented responsibility. The runtime service principal remains the normal writer to pipeline schemas.

## Step 1: approve the request

Record:

- User: `binaya.sharma_np@example.com`
- Relationship: employee, contractor, or external collaborator
- Manager or sponsor
- Required environment: `dev`, `qual`, or `prod`
- Required activities: code contribution, Azure inspection, Terraform operation, Databricks query, or platform administration
- Start and review/expiry date
- Platform-admin approval

Do not infer platform-admin access from a job title.

## Step 2: add the Microsoft Entra identity

Choose the path based on who owns and manages the identity. An employee joining the company should normally receive an internal **Member** account. Contractors and partners whose identity remains managed by another organization should normally use an external **Guest** account.

### Internal employee: create a member user

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com/).
2. Select **Identity** -> **Users** -> **All users**.
3. Select **New user** -> **Create new user**.
4. Enter the company user principal name, for example `binaya.sharma_np@company.example`.
5. Enter the person's real display name and mail nickname.
6. Keep **Account enabled** selected.
7. Use an automatically generated temporary password or the company's approved identity-provisioning process.
8. Select **Review + create**, verify that the user type is **Member**, and create the account.
9. Provide initial sign-in information through an approved secure channel; never commit or email a password in plain text.
10. Require a password change at first sign-in where applicable and enforce MFA through the tenant's normal security policy.
11. Set required employee properties such as usage location, department, manager, and lifecycle/HR attributes according to company policy.

Do not create an employee with a personal address such as `@outlook.com` when the company is responsible for managing the employee's identity.

### Contractor or partner: invite a guest user

1. Open the [Microsoft Entra admin center](https://entra.microsoft.com/).
2. Select **Identity** -> **Users** -> **All users**.
3. Select **New user** -> **Invite external user**.
4. Enter `binaya.sharma_np@example.com` and the person's real display name.
5. Send the invitation.
6. Confirm the invitation was accepted and the user appears in the intended tenant.
7. Require MFA through the tenant's normal security policy.

Confirm that an invited external identity has user type **Guest**. The guest continues authenticating with the identity managed by their home organization while receiving explicitly assigned access in this tenant.

### Verify either identity type

Before assigning resource permissions, confirm:

- The identity exists in the intended tenant and can sign in.
- The employee is a **Member**, or the contractor/partner is a **Guest**.
- The account is enabled and covered by the required MFA/Conditional Access policies.
- The display name, user principal name/email, manager or sponsor, and review/expiry date are correct.
- No directory administrator role was assigned as part of user creation.

Do not grant `Global Administrator`, `Privileged Role Administrator`, or another Entra administrator role for normal engineering work.

## Step 3: add the user to access groups

Prefer group membership over direct user assignments. Example groups:

```text
grp-azure-platform-readers
grp-azure-platform-contributors
grp-databricks-workspace-users
grp-databricks-data-engineers
grp-databricks-workspace-admins
```

In the Entra admin center:

1. Select **Identity** -> **Groups** -> **All groups**.
2. Open the approved group.
3. Select **Members** -> **Add members**.
4. Add `binaya.sharma_np@example.com`.
5. Record the group assignment in the access request.

For the default developer profile, add only the reader, workspace-user, and approved data-reader groups. Do not add the user to administrator groups.

## Step 4: grant Azure RBAC

Open:

```text
Azure Portal
-> Subscriptions
-> sub-azdbx-sandbox-001
-> Access control (IAM)
-> Add role assignment
```

Assign roles to groups at the narrowest useful scope:

| Responsibility | Role | Recommended scope |
| --- | --- | --- |
| Inspect Azure resources | `Reader` | Sandbox subscription or platform resource group |
| Modify platform resources | `Contributor` | `rg-azref-platform-centralindia-001` |
| Read/write and lock remote Terraform state | `Storage Blob Data Contributor` | `tfstate` container only |
| Manage Azure role assignments | `User Access Administrator` | Required scope; platform administrators/CI only |
| Full resource and access control | `Owner` | Avoid for normal developers |

The default developer receives `Reader`; they do not receive Terraform-state write access or subscription `Owner`.

### Terraform access boundary

```text
terraform fmt/validate/test -> no cloud access
terraform plan              -> remote-state and cloud read access
terraform apply             -> remote-state write plus resource modification
```

Prefer this workflow:

```text
Developer changes Terraform code
-> opens pull request
-> CI validates and plans
-> approved deployment identity applies
```

Until Terraform CI is implemented, grant local state/apply access only to designated platform operators. Never share another person's Azure CLI cache or credentials.

## Step 5: assign Databricks workspace access

Azure RBAC does not automatically grant Databricks workspace access.

Use an Entra-backed Databricks account group where automatic identity management is available:

1. Open the Azure Databricks workspace.
2. Select the user menu -> **Settings**.
3. Select **Identity and access**.
4. Next to **Groups**, select **Manage**.
5. Add or select `grp-databricks-workspace-users`.
6. Assign it to the workspace with **Workspace user** access.
7. Confirm `binaya.sharma_np@example.com` is a member through Entra group synchronization.

An account admin can alternatively use:

```text
Databricks Account Console
-> Workspaces
-> select workspace
-> Permissions
-> Add permissions
-> select group
-> User
```

Do not grant Databricks account admin or workspace admin unless platform administration is the person's approved responsibility.

## Step 6: grant Unity Catalog access

Grant privileges to the group, not directly to the individual:

```sql
GRANT USE CATALOG
ON CATALOG dbw_azref_sandbox_centralindia_001
TO `grp-databricks-data-engineers`;

GRANT USE SCHEMA
ON SCHEMA dbw_azref_sandbox_centralindia_001.gold
TO `grp-databricks-data-engineers`;

GRANT SELECT
ON SCHEMA dbw_azref_sandbox_centralindia_001.gold
TO `grp-databricks-data-engineers`;
```

The default human profile is read-only. Do not normally grant humans `CREATE TABLE`, `MODIFY`, `MANAGE`, ownership, or unrestricted access to every schema. The runtime service principal owns routine pipeline writes.

The current Terraform stack manages runtime-service-principal grants but does not yet declare human access groups. Before production onboarding, add group lookups and human group grants to Terraform so Unity Catalog access remains reviewable and does not drift through manual changes.

## Step 7: grant GitHub access

Open:

```text
GitHub repository
-> Settings
-> Collaborators
-> Add people
```

Invite the person's GitHub account. Repository access does not grant Azure or Databricks access.

The contributor workflow is:

```text
feature branch
-> pull request
-> CI passes
-> @binaya-sharma CODEOWNER approval
-> squash and merge
-> feature branch deleted automatically
```

Collaborators cannot push directly to `main`. Repository administrators retain the configured emergency bypass and should use it only when justified.

## Step 8: verify positive and negative access

Have the user authenticate with their own identity:

```bash
az login
az account set --subscription "5f78f2e9-eaa7-4de4-bf8c-2ffb97c6b9b0"
az account show --output table
```

Expected positive tests:

- The user can see only the intended Azure subscription/resources.
- The user can enter the assigned Databricks workspace.
- The user can query approved Unity Catalog schemas.
- The user can create a feature branch and pull request.

Expected negative tests:

- The user cannot assign Azure roles.
- The user cannot access Terraform state unless explicitly approved.
- The user cannot administer the Databricks account/workspace.
- The user cannot write pipeline tables under the default profile.
- The user cannot push directly to `main` or merge without required review.

Do not declare onboarding complete until negative tests pass.

## Step 9: review and offboard

Review access periodically and at every role change. When access ends:

1. Disable/remove the Entra identity, or remove the guest from the tenant.
2. Remove the user from all Entra access groups.
3. Verify inherited Azure role assignments disappear.
4. Remove Databricks workspace assignment if it is not group-driven.
5. Verify Unity Catalog access is removed through group membership.
6. Remove the GitHub collaborator.
7. Revoke active sessions when required.
8. Record completion and retain audit evidence.

Do not delete shared groups or service principals while offboarding one human user.

## References

- [Invite an external user to Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/external-id/b2b-quickstart-add-guest-users-portal)
- [Assign Azure roles using the Azure portal](https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-portal)
- [Manage Azure Databricks groups](https://learn.microsoft.com/en-us/azure/databricks/admin/users-groups/manage-groups)
- [Unity Catalog privileges](https://learn.microsoft.com/en-us/azure/databricks/data-governance/unity-catalog/manage-privileges/privileges)

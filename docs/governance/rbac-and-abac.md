# RBAC and ABAC for the Azure Databricks platform

This guide explains how role-based access control (RBAC) and attribute-based access control (ABAC) fit together in this repository. The sandbox currently implements RBAC and Unity Catalog grants, but it does **not** yet implement production ABAC policies.

## The short version

```text
RBAC: Who are you, which role/group are you in, and what may that role do?
ABAC: Which attributes are present, and under what conditions may this request proceed?
```

RBAC can give `grp-retail-analysts` permission to query sales. ABAC or fine-grained governance can then ensure a Nepal analyst sees Nepal rows and masked sensitive columns. ABAC does not replace RBAC: the baseline permission comes first, and attribute policies narrow or condition it.

## Enforcement layers

| Layer | Mechanism | Example |
| --- | --- | --- |
| Microsoft Entra ID | Identities and groups | User belongs to a data-engineer group |
| Azure | RBAC and supported role-assignment conditions | Group has `Reader` on the sandbox |
| Databricks workspace | Entitlements and object permissions | Deployment principal manages its bundle job |
| Unity Catalog | Grants, ownership, row filters, masks, and governed-tag policies | Analysts can select sales; region policy limits rows |
| GitHub | Repository roles and rulesets | Collaborator uses a protected pull request |

Access at one layer does not imply access at another. Azure `Reader` does not grant Unity Catalog `SELECT`.

## RBAC

RBAC assigns a role to a principal at a scope:

```text
principal + role + scope = role assignment
```

- **Principal:** user, group, managed identity, or service principal
- **Role:** allowed actions, such as `Reader`
- **Scope:** management group, subscription, resource group, resource, or supported child resource

### Azure RBAC in this project

| Principal | Role | Scope | Purpose |
| --- | --- | --- | --- |
| Human developer group | `Reader` | Sandbox subscription or platform resource group | Inspect without modifying |
| Terraform operator/CI | `Contributor` | Platform resource group | Create/update managed resources |
| Terraform operator/CI | `Storage Blob Data Contributor` | `tfstate` container | Read, write, and lock remote state |
| Access administrator | `User Access Administrator` | Narrow required scope | Manage role assignments |

Avoid broad `Owner` assignments for normal development. Assign groups instead of individual users.

### Unity Catalog role-style grants

Azure roles do not grant data access. Unity Catalog uses privileges:

```sql
GRANT USE CATALOG
ON CATALOG dbw_azref_sandbox_centralindia_001
TO `grp-retail-analysts`;

GRANT USE SCHEMA
ON SCHEMA dbw_azref_sandbox_centralindia_001.gold
TO `grp-retail-analysts`;

GRANT SELECT
ON SCHEMA dbw_azref_sandbox_centralindia_001.gold
TO `grp-retail-analysts`;
```

`USE CATALOG` and `USE SCHEMA` allow traversal, while `SELECT` allows reads. Prefer the runtime service principal for writes. Schema grants cover applicable current and future children; use table scope for a single table. Unity Catalog has no explicit `DENY` that overrides a broad inherited grant.

## ABAC

ABAC evaluates attributes against a policy:

```text
subject attributes + resource attributes + request context + policy = decision
```

Attributes can include group, department, country, clearance, data classification, governed tags, requested action, and supported request context.

### Azure ABAC

Azure ABAC extends supported Azure role assignments with conditions. The role grants the underlying action; its condition restricts when or against which resources it applies. Storage data access is a common example. Confirm that the role, action, attribute, and scope support conditions before implementing them.

### Databricks ABAC and fine-grained controls

| Mechanism | Use case | Boundary |
| --- | --- | --- |
| Governed tags with ABAC policies | Apply central policy to tagged objects | Matching governed UC objects |
| Row filter | Restrict visible rows | Base table |
| Column mask | Redact values | Masked base-table column |
| Dynamic view | Apply row/column logic in a view | View consumers only |

Row filters, masks, and views are fine-grained controls. Governed-tag ABAC is the scalable policy model when supported. Validate current Azure Databricks availability and limitations before production use.

## Nepal-only retail example

Members of `grp-retail-analysts` may query sales, but an ordinary Nepal analyst should see only `country_code = 'NP'`. A regional administrator may see all rows.

### 1. Grant baseline access

```sql
GRANT USE CATALOG ON CATALOG dbw_azref_sandbox_centralindia_001
TO `grp-retail-analysts`;
GRANT USE SCHEMA ON SCHEMA dbw_azref_sandbox_centralindia_001.gold
TO `grp-retail-analysts`;
GRANT SELECT ON TABLE dbw_azref_sandbox_centralindia_001.gold.sales
TO `grp-retail-analysts`;
```

### 2. Maintain entitlements

Use a controlled table instead of hardcoded user emails:

```text
security.user_country_entitlements
├── principal
├── country_code
├── valid_from
├── valid_to
└── approved_by
```

Example: `binaya.sharma_np@example.com | NP | ... | platform-data-owner`.

### 3. Attach a row filter

```sql
CREATE OR REPLACE FUNCTION
  dbw_azref_sandbox_centralindia_001.security.country_filter(country_code STRING)
RETURN
  is_account_group_member('grp-retail-regional-admins')
  OR EXISTS (
    SELECT 1
    FROM dbw_azref_sandbox_centralindia_001.security.user_country_entitlements e
    WHERE e.principal = current_user()
      AND e.country_code = country_code
      AND current_date() BETWEEN e.valid_from AND e.valid_to
  );

ALTER TABLE dbw_azref_sandbox_centralindia_001.gold.sales
SET ROW FILTER
  dbw_azref_sandbox_centralindia_001.security.country_filter
ON (country_code);
```

The table owner must be able to read the entitlement table.

### 4. Mask sensitive columns

```sql
CREATE OR REPLACE FUNCTION
  dbw_azref_sandbox_centralindia_001.security.email_mask(email STRING)
RETURN CASE
  WHEN is_account_group_member('grp-retail-pii-readers') THEN email
  ELSE regexp_replace(email, '^[^@]+', '****')
END;

ALTER TABLE dbw_azref_sandbox_centralindia_001.gold.customers
ALTER COLUMN email
SET MASK dbw_azref_sandbox_centralindia_001.security.email_mask;
```

Filters and masks do not grant access; the caller still needs traversal and `SELECT`.

## Recommended groups

```text
grp-platform-admins              -> owns platform governance
grp-retail-pipeline-runtimes     -> runtime service principal; approved writes
grp-retail-analysts              -> traversal and SELECT; policies still apply
grp-retail-pii-readers           -> approved unmasked PII
grp-retail-regional-admins       -> approved cross-region visibility
```

Own securables with groups, not individuals. Use `MANAGE` to delegate grant administration without transferring ownership.

## Terraform and deployment pattern

```text
Terraform
├── looks up account groups
├── grants Unity Catalog privileges
└── manages stable supported governance objects

Reviewed SQL migration/deployment
├── creates policy functions and entitlement table
├── attaches row filters/masks
└── validates with non-privileged identities
```

Keep group membership in Entra/Databricks account administration. Never store individual credentials in Terraform. If the pinned provider does not reliably support a policy object, use a reviewed SQL deployment rather than an untracked manual change.

This repository currently manages runtime service-principal grants. Human groups, entitlement data, and ABAC policies remain a planned production-governance phase.

## Testing checklist

| Identity | Expected result |
| --- | --- |
| Nepal analyst | Only `NP` rows; sensitive values masked |
| US analyst | Only approved US rows |
| PII reader | Approved regional rows with permitted unmasked columns |
| Regional administrator | All approved regions |
| Unassigned user | Cannot query the table |
| Runtime service principal | Writes only to approved schemas/tables |

Also verify removal of group membership removes access, expired entitlements stop visibility, analysts cannot bypass secured views through base tables, and audit logs record policy/grant activity.

## Decision guide

| Requirement | Preferred control |
| --- | --- |
| Inspect Azure resources | Azure `Reader` |
| Deploy from approved CI | Scoped Azure roles for CI |
| Read an approved schema | Unity Catalog group grants |
| Read one table | Table-level grants |
| See only the user's country | Row filter or governed-tag ABAC policy |
| Hide PII | Column mask |
| Secured read-only interface | Dynamic view with no base-table access |
| Reuse policy across tagged data | Governed-tag ABAC after feature validation |

## References

- [Azure RBAC overview](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview)
- [Azure role assignment conditions](https://learn.microsoft.com/en-us/azure/role-based-access-control/conditions-overview)
- [Unity Catalog privileges](https://learn.microsoft.com/en-us/azure/databricks/data-governance/unity-catalog/manage-privileges/privileges)
- [Unity Catalog ABAC](https://learn.microsoft.com/en-us/azure/databricks/data-governance/unity-catalog/abac/)
- [Unity Catalog row filters and column masks](https://learn.microsoft.com/en-us/azure/databricks/data-governance/unity-catalog/filters-and-masks/)
- [User onboarding](user-onboarding.md)

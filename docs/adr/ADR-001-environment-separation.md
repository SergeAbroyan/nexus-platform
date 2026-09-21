# ADR-001: Environment Separation

## Status

Accepted

## Decision

Nexus will maintain separate DEV, STAGING, and PRODUCTION environment configurations.

DEV is used for development and testing. STAGING is used to validate changes before release in an environment closer to production. PRODUCTION is reserved for the live application and its users.

The environments will share reusable infrastructure modules while allowing environment-specific configuration. Each environment can be deployed independently.

## Rationale

Separating environments prevents development and release testing from directly affecting production users. It also allows each environment to have different reliability, security, scaling, and cost characteristics.

## Consequences

* Infrastructure code must support environment-specific configuration.
* DEV can be optimized for low cost.
* STAGING can be configured closer to production.
* PRODUCTION can use stronger availability and protection settings.
* Environments can be deployed or destroyed independently.
* Terraform and Terragrunt must support the environment separation.

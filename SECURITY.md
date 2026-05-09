# Security Policy

## Supported Versions

Security fixes primarily target:

- the `main` branch;
- the web version currently deployed to production;
- the build and deployment chains described in the project's operations documentation.

Older branches, unmaintained forks, and derived builds are not guaranteed.

## Reporting a Vulnerability

Do not create a public issue to report a security flaw.

Recommended channel once the repository is public:

- GitHub Private Vulnerability Reporting, once enabled.

Until this mechanism is available:

- report the vulnerability to the maintainer through an already established private channel;
- explicitly request a secure exchange channel if you need to transmit a secret, sensitive PoC, or logs containing private data;
- avoid any public disclosure before the fix is validated.

## What to Include in the Report

Please include, if possible:

- the affected component;
- the expected impact;
- exploitation prerequisites;
- reproduction steps;
- a minimal PoC if you have one;
- the affected versions or commits.

## Disclosure Expectations

Maintenance goals:

- acknowledge receipt quickly;
- confirm whether the issue is a vulnerability;
- prepare a fix or mitigation;
- coordinate disclosure once the risk is reduced.

This policy should be used with the backend deployment documentation and the open-source release runbook when the repositories become public.

# Security Policy

## Reporting a vulnerability

Please report security vulnerabilities **privately**. Do not open a public issue, pull
request, or discussion for a security problem.

Email **taiwan.eew@gmail.com** with:

- a description of the issue and its impact,
- steps to reproduce, and
- any relevant logs, requests or proof-of-concept.

You can expect an acknowledgement within a few days. Please give a reasonable amount of
time for a fix before any public disclosure.

## Scope

This is an earthquake early warning app backed by push notification (APNs/AWS SNS) and
Firebase services. Reports that are especially valuable include anything that could let a
third party:

- send, alter, suppress or spoof earthquake alerts to users,
- read, modify or delete backend data, or
- obtain credentials or elevated access.

## Out of scope

- The app is explicitly **not a life-safety system**; the inherent uncertainty of
  earthquake early warning is not a vulnerability.
- Findings that require a physically compromised or jailbroken device.
- Reports generated solely by automated scanners with no demonstrated impact.

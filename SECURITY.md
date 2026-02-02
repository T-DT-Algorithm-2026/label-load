# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please report it responsibly.

### How to Report

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please send an email to: **zhujunheng2005@gmail.com**

Or use GitHub's private vulnerability reporting feature if available.

### What to Include

Please include the following information in your report:

- Type of vulnerability (e.g., buffer overflow, SQL injection, XSS)
- Full paths of source file(s) related to the vulnerability
- Location of the affected source code (tag/branch/commit or direct URL)
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit it

### Response Timeline

- **Initial Response**: Within 48 hours
- **Status Update**: Within 7 days
- **Resolution Target**: Within 30 days (depending on complexity)

### Disclosure Policy

- We will acknowledge your report within 48 hours
- We will work with you to understand and validate the issue
- We will keep you informed of our progress
- We will credit you in the security advisory (unless you prefer anonymity)
- We ask that you give us reasonable time to address the issue before public disclosure

## Security Best Practices for Users

### Installation

- Always download releases from the official GitHub Releases page
- Verify checksums when available
- Keep your system and dependencies updated

### AI Model Security

- Only load ONNX models from trusted sources
- Be aware that malicious models could potentially exploit vulnerabilities
- The application runs inference locally; no data is sent to external servers

## Scope

This security policy applies to:

- LabelLoad application
- Official DEB packages (CPU and GPU versions)
- onnx_inference native plugin

Third-party dependencies are subject to their own security policies.


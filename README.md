# OpenClaw on Oracle Ampere A1: Zero-Trust IaC Template

A fully declarative, production-ready Infrastructure as Code (IaC) template for deploying the **OpenClaw AI Agent** on **Oracle Cloud's Always Free Tier** (Ampere A1 ARM64).

This repository is not just a deployment script; it is a **Defense-in-Depth architectural manifesto** designed to solve the inherent security risks of autonomous AI agents operating on cloud infrastructure.

## 🧠 The Problem: Why This Architecture Exists

Autonomous AI agents (like OpenClaw) are fundamentally risky. They execute LLM-generated code, interact with third-party web services, download arbitrary skills, and have direct access to highly sensitive API keys (OpenAI, Anthropic, etc.). 

**The standard industry consensus (circa April 2026) for isolating AI agents is to use MicroVMs (like Firecracker KVM).** However, Oracle Cloud's Ampere A1 (ARM64) instances—while generously offering 4 Cores and 24GB RAM for free—**do not support nested virtualization or KVM.** 

If we cannot use hardware-level MicroVMs, deploying a raw Docker container exposes the host to severe risks, including Container Escapes and Server-Side Request Forgery (SSRF) attacks targeting Oracle's internal metadata server (IMDSv2).

## 🛡️ The Solution: Defense-in-Depth

To safely run OpenClaw on an Oracle Ampere A1 instance without KVM, this repository implements a strict, multi-layered security architecture:

### 1. Infrastructure Layer (Terraform)
*   **Default Deny:** The Oracle Virtual Cloud Network (VCN) strictly blocks all inbound traffic.
*   **Fail2Ban SSH:** Only Port 22 (SSH) is exposed to the internet. An Ansible-provisioned Fail2Ban instance actively monitors auth logs and blocks brute-force botnets at the `iptables` level.

### 2. Container Hardening Layer (Ansible + Rootless Docker)
Because we lack MicroVMs, we enforce extreme Docker isolation:
*   **Rootless Architecture:** The Docker daemon runs entirely in user space. Even if an attacker achieves root access *inside* the container, they only have unprivileged user access (UID 1000) on the host. 
*   **SubUID Mapping:** We dynamically map SubUID `232071` on the host to ensure the container's internal `node` user maintains file permissions without requiring host-level root execution (`EACCES` error mitigation).
*   **Immutable File System:** The agent's root filesystem is mounted as `read_only: true`, preventing malware persistence.
*   **No-Exec TempFS:** Temporary directories (`/tmp`) are mounted in RAM but flagged with `noexec` and `nosuid`. Downloaded exploit payloads cannot be executed.
*   **Privilege Dropping:** All Linux kernel capabilities are dropped (`cap_drop: ALL`), and privilege escalation is blocked (`no-new-privileges:true`).
*   **Seccomp Filtering:** A strict syscall filter profile restricts what the container can ask the Linux kernel to do.

### 3. Network Isolation & Anti-SSRF
*   **SSRF Protection:** AI models are susceptible to prompt injection attacks that trick them into querying `http://169.254.169.254` (Oracle's Instance Metadata Service) to steal cloud credentials. We deploy persistent `iptables` rules that specifically block the agent's SubUID from accessing local subnets and the IMDSv2 endpoint.
*   **Zero-Trust Networking (Tailscale):** The OpenClaw API port (`3100`) is bound *only* to `127.0.0.1`. It is completely inaccessible from the public internet. Secure, encrypted access to the agent is provided exclusively via a **Tailscale** WireGuard mesh network.
*   **Messenger Whitelisting:** Inbound commands from Telegram/Discord use Long Polling (no open ports). Authorization is deterministic: messages from IDs not explicitly whitelisted in the environment variables are silently dropped before they even reach the LLM.

### ⚠️ Security Disclaimer
While any technical system can theoretically be compromised, I stopped at this level of defense-in-depth because I consider it the optimal and acceptable balance for this task. It still provides highly robust protection by combining Rootless execution, Zero-Trust networking, and strict host-level firewalls.

---

## 📋 Prerequisites

You must have the following installed on your local machine:
1.  [Terraform](https://developer.hashicorp.com/terraform/install) (v1.0+)
2.  [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)
3.  [Oracle Cloud CLI](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm) (configured with your OCI profile at `~/.oci/config`).

## 🛠️ Step 1: Prepare Variables & Secrets

Before deploying, gather your infrastructure identifiers and agent secrets.

**1. Infrastructure Configuration:**
Log into your Oracle Cloud Console.
*   Navigate to `terraform/`.
*   Copy `terraform.tfvars.example` to `terraform.tfvars`.
*   Fill in your `compartment_id`, `vcn_id`, and a public `subnet_id` (10.0.0.0/24).

**2. Agent Secrets:**
*   Copy `secrets.example.yml` to `secrets.yml` in the root directory.
*   Fill in the required tokens (OpenClaw Gateway Token, LLM API Key, Telegram Bot Token). 
*   *Note: This file is intentionally ignored by git to prevent leaks.*

---

## 🚀 Step 2: Deployment (Quick Start)

### 1. Provision Infrastructure (Terraform)
This will create the necessary Security Groups and deploy the Ampere A1 instance.

```bash
cd terraform
terraform init
terraform apply
```
*Take note of the public IP address outputted at the end of the run.*

### 2. Configure the OS & Deploy Agent (Ansible)
Update the `inventory.ini` file with your new server's IP address. Then, run the playbook to harden the OS, install Tailscale, configure Rootless Docker, and launch the agent.

```bash
cd ..
ansible-playbook -i inventory.ini ansible/setup-openclaw.yml
```

**⚠️ Tailscale Interactive Auth:** During the Ansible run, the process will pause and provide an authentication URL in the terminal. You must click this link to authenticate the server to your Tailscale network. Once authorized, the playbook will automatically resume.

### 3. Talk to your Agent!
Once Ansible finishes, your server is hardened and OpenClaw is running securely in the background. 
Simply open Telegram and send `/start` to your bot.

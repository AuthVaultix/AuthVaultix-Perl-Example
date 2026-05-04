# AuthVaultix Perl SDK

![AuthVaultix](https://img.shields.io/badge/AuthVaultix-Perl-blue?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Windows-green?style=for-the-badge)

A complete Perl implementation for the [AuthVaultix](https://authvaultix.com) authentication service. Secure your Perl applications with features like HWID locking, license validation, and user management.

## 📁 File Structure

- **`AuthVaultix.pm`**: The core Perl module containing the API logic and communication handling.
- **`main.pl`**: An example command-line script demonstrating how to use the SDK.

---

## 🚀 Quick Start

### 1. Installation
Ensure you have the required Perl modules installed:
```bash
cpan JSON LWP::UserAgent LWP::Protocol::https
```

### 2. Configuration
Initialize the SDK with your application credentials in your main script.

```perl
use AuthVaultix;

# Set your API credentials
AuthVaultix::Api(
    "YourAppName",
    "YourOwnerID",
    "YourAppSecret",
    "1.0"
);

# Initialize the session
AuthVaultix::Init();
```

### 3. Authentication
Use the provided subroutines for user authentication.

```perl
# Standard User Login
AuthVaultix::Login("username", "password");

# User Registration with License Key
AuthVaultix::Register("username", "password", "LICENSE-KEY");

# License-only Login
AuthVaultix::License("LICENSE-KEY");
```

---

## ⚙️ Features

- **Standardized API:** Follows the AuthVaultix 1.0 API structure.
- **HWID Protection:** Built-in Windows HWID (SID) detection via `wmic`.
- **SSL Support:** Secure HTTPS communication using `LWP::UserAgent`.
- **User Sessions:** Automated session management and user info parsing.

## 🛠️ API Reference

| Subroutine | Description |
| :--- | :--- |
| `Api(name, ownerid, secret, version)` | Configures the application credentials. |
| `Init()` | Starts the session and connects to the server. |
| `Login(user, pass)` | Authenticates a user with username and password. |
| `Register(user, pass, key)` | Registers a new user using a license key. |
| `License(key)` | Simple license-only login (no username required). |

---

## 📋 Requirements

- **Perl:** 5.10 or higher.
- **Modules:** `JSON`, `LWP::UserAgent`, `HTTP::Request::Common`, `POSIX`.
- **OS:** Windows (for HWID detection).

## ⚖️ Disclaimer
This project is intended for use with the AuthVaultix.com authentication service. Ensure you comply with their Terms of Service.

---

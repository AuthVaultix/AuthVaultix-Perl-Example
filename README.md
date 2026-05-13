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

# Initialize the client
my $auth = AuthVaultixClient->new(
    "YourAppName",
    "YourOwnerID",
    "YourAppSecret",
    "1.0"
);

# Initialize connection
$auth->init();
```

### 3. Authentication
Use the provided subroutines for user authentication.

```perl
# Standard User Login
$auth->login("username", "password");

# User Registration with License Key
$auth->register("username", "password", "LICENSE-KEY");

# License-only Login
$auth->license_login("LICENSE-KEY");
```

---

## ⚙️ Features

- **Standardized API:** Follows the AuthVaultix 1.0 API structure.
- **HWID Protection:** Built-in Windows HWID (SID) detection via `wmic`.
- **SSL Support:** Secure HTTPS communication using `LWP::UserAgent`.
- **User Sessions:** Automated session management and user info parsing.

## 🛠️ API Reference

### Authentication & Session
| Method | Description |
| :--- | :--- |
| `init()` | Initializes the secure session with the API. |
| `login(user, pass)` | Authenticates the user and binds HWID. |
| `register(user, pass, key, email?)` | Creates a new user with a license key. |
| `license_login(license)` | Authenticates directly via license key. |
| `check()` | Validates if the current session is still active. |
| `logout()` | Invalidates current session and logs out. |

### Account Management
| Method | Description |
| :--- | :--- |
| `upgrade(username, license)` | Upgrades user's account/subscription. |
| `forgot_password(username, email)` | Triggers a password reset email. |
| `change_username(new_username)` | Changes the current user's username. |

### Security & Blacklist
| Method | Description |
| :--- | :--- |
| `ban(reason)` | Bans the currently authenticated user. |
| `check_blacklist()` | Checks if the machine HWID is blacklisted. |
| `log(message)` | Sends a log to the AuthVaultix dashboard. |

### Variables & Data
| Method | Description |
| :--- | :--- |
| `get_global_var(varid)` | Fetches a global server-side variable. |
| `get_var(var_name)` | Fetches a user-specific server-side variable. |
| `set_var(var_name, value)` | Sets a user-specific variable. |
| `download(fileid)` | Securely downloads a file (returns decoded data). |

### Communication
| Method | Description |
| :--- | :--- |
| `fetch_online()` | Gets a list of currently online users. |
| `chat_send(message, channel)` | Sends a chat message to a specific channel. |
| `chat_fetch(channel)` | Retrieves chat history. |

---

## 📋 Requirements

- **Perl:** 5.10 or higher.
- **Modules:** `JSON`, `LWP::UserAgent`, `HTTP::Request::Common`, `POSIX`.
- **OS:** Windows (for HWID detection).

## ⚖️ Disclaimer
This project is intended for use with the AuthVaultix.com authentication service. Ensure you comply with their Terms of Service.

---

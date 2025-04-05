# rcForge Security Guide

This guide explains the security features in rcForge v0.2.1 and provides best practices for maintaining a secure shell configuration environment.

## Table of Contents

- [Security Features](#security-features)
- [Root Permission Checks](#root-permission-checks)
- [File Permissions](#file-permissions)
- [Security Best Practices](#security-best-practices)
- [Root User Considerations](#root-user-considerations)
- [Exported Configurations](#exported-configurations)
- [Troubleshooting](#troubleshooting)

## Security Features

rcForge v0.2.1 includes several key security features:

1. **Root permission checks**: Prevents scripts from running with elevated privileges
2. **Secure file permissions**: Protects your configuration files from other users
3. **Restrictive umask**: Ensures new files have appropriate permissions
4. **Secure export options**: Maintains security when sharing configurations
5. **Documentation**: Provides guidance on security best practices

## Root Permission Checks

### Why Block Root Execution?

Running shell configurations as root can lead to several issues:

1. **Permission problems**: Files created while running as root may be owned by root, making them inaccessible to your regular user account
2. **Security vulnerabilities**: Complex shell configurations run as root could potentially be exploited
3. **System stability**: Root shell configurations should be kept minimal for system recovery purposes
4. **Information leakage**: Your personal configurations may contain sensitive tokens or credentials

### How It Works

All rcForge scripts now include a check that:

1. Detects if the script is being run as root (UID 0) or with sudo
2. Displays a clear warning message explaining the risks
3. Exits with an error code to prevent execution
4. Provides an emergency override mechanism for exceptional cases

### Override (Not Recommended)

If you absolutely must run rcForge as root, you can use the `RCFORGE_ALLOW_ROOT` environment variable:

```bash
RCFORGE_ALLOW_ROOT=1 source ~/.config/rcforge/rcforge.sh
```

**This override should only be used in exceptional circumstances and is not recommended for regular use.**

## File Permissions

### Default Permissions Model

rcForge v0.2.1 employs a restrictive permission model to protect user configuration files and sensitive data, such as API keys.  This ensures that only the user can access and modify their rcForge configuration.

- **Ownership:** All rcForge files and directories within the user's `~/.config/rcforge/` directory are owned by the user.

- **Configuration and Data Files:** 600 permissions (rw-------)
    -   Only the owner can read and write these files.
    -   No permissions for group or world.

-   **Executable Shell Scripts:** 700 permissions (rwx------)
    -   Only the owner can read, write, and execute these scripts.
    -   No permissions for group or world.

**Example:**

After installation, the files in the user's `~/.config/rcforge/scripts/` directory will have the following ownership and permissions:

```
rw------- 1 user user  123 Apr  5 10:00 100_global_common.sh  # Configuration file
-rwx------ 1 user user  456 Apr  5 10:00 my_function.sh       # Executable script
```

This means that only `user` can read and write `100_global_common.sh`, and only `user` can read, write, and execute `my_function.sh`. Other users and processes running as the same user cannot access these files.

### Umask Setting

All rcForge scripts set `umask 077` at the beginning, which ensures that:

- New files are created with 600 permissions
- New directories are created with 700 permissions
- No permissions are granted to group or world

This prevents other users on the same system from accessing your configuration files, which may contain sensitive information like API tokens, server addresses, or credentials.

### Shell RC Files

The installation process also secures your shell RC files:

- Sets 600 permissions on `.bashrc`, `.zshrc`, and other shell configuration files
- Ensures the files are owned by your user

## Security Best Practices

### Managing Sensitive Information

1. **Avoid hardcoding credentials**: Use environment variables or secure credential managers
2. **Separate sensitive data**: Keep confidential data in separate files with appropriate permissions
3. **Use the private directory**: Store sensitive configurations in `~/.config/rcforge/scripts/private` (create this directory if it doesn't exist)

### Maintaining Security

1. **Regular permission checks**: Periodically verify file permissions with:
   ```bash
   find ~/.config/rcforge -type d -not -perm 700
   find ~/.config/rcforge -type f -not -perm 600 -and -not -perm 700
   ```

2. **Update permissions if needed**:
   ```bash
   find ~/.config/rcforge -type d -exec chmod 700 {} \;
   find ~/.config/rcforge -type f -name "*.sh" -exec chmod 700 {} \;
   find ~/.config/rcforge -type f -not -name "*.sh" -exec chmod 600 {} \;
   ```

3. **Audit your configurations**: Regularly review your configurations for security issues

### Multi-User Systems

If you're on a shared system with multiple users:

1. **Keep home directory private**: Set `chmod 700 ~` if your system allows it
2. **Use encrypted home directories** if available
3. **Consider remote configuration exports** rather than storing sensitive data on shared systems

## Root User Considerations

### Dedicated Root Configuration

It's best practice to maintain a separate, minimal configuration for the root user:

1. **Create a basic configuration**:
   ```bash
   sudo touch /root/.bashrc
   sudo chmod 600 /root/.bashrc
   ```

2. **Keep it simple**:
   ```bash
   echo 'PS1="\[\033[1;31m\][\u@\h \W]# \[\033[0m\]"  # Red prompt for root' | sudo tee /root/.bashrc
   ```

3. **Never source your personal rcForge configuration as root**

### Emergency Access

If you need to access your configurations as root in an emergency:

1. **Use your regular user's environment for most tasks**:
   ```bash
   sudo -u yourusername bash
   ```

2. **Access specific files directly if needed**:
   ```bash
   sudo cat ~/.config/rcforge/scripts/100_global_common_environment.sh
   ```

## Exported Configurations

### Secure Export

When exporting configurations for use on other systems:

1. **Set proper permissions on the exported file**:
   ```bash
   chmod 600 ~/.config/rcforge/exports/laptop_bashrc
   ```

2. **Transfer securely**:
   ```bash
   scp -P 22 ~/.config/rcforge/exports/laptop_bashrc user@server:~/.bashrc
   ssh user@server "chmod 600 ~/.bashrc"
   ```

3. **Redact sensitive information** if exporting to less trusted environments

### Security Headers

Exported configurations include security headers that:

1. Check if running as root
2. Display warning messages
3. Provide an override mechanism similar to the main rcForge system

## Troubleshooting

### Permission Denied Errors

If you encounter "Permission denied" errors after installing rcForge:

1. **Check file ownership**:
   ```bash
   ls -la ~/.config/rcforge
   ```

2. **Correct ownership if necessary**:
   ```bash
   sudo chown -R $USER:$USER ~/.config/rcforge
   ```

3. **Verify permissions**:
   ```bash
   find ~/.config/rcforge -type f -name "*.sh" -not -perm 700
   ```

### Root Execution Errors

If you receive "Error: This script should not be run as root or with sudo":

1. **Run the script as your regular user**, not root
2. **If you must run as root** (not recommended), use the override:
   ```bash
   RCFORGE_ALLOW_ROOT=1 source ~/.config/rcforge/rcforge.sh
   ```

### Fixing Permissions

To reset all permissions to the secure defaults:

```bash
# Fix directory permissions
find ~/.config/rcforge -type d -exec chmod 700 {} \;

# Fix executable script permissions
find ~/.config/rcforge -name "*.sh" -type f -exec chmod 700 {} \;

# Fix data file permissions
find ~/.config/rcforge -type f -not -name "*.sh" -exec chmod 600 {} \;

# Fix RC files
chmod 600 ~/.bashrc
chmod 600 ~/.zshrc
```

## Conclusion

The security enhancements in rcForge v0.2.1 are designed to protect your shell configurations from common security issues while maintaining usability. By following the best practices in this guide, you can ensure your shell environment remains secure and private.

Remember: good security is as much about user practices as it is about system features. Always be mindful of what information you include in your shell configurations and how you manage access to that information.
# EOF
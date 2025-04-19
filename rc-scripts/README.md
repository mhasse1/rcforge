# rcForge Script Organization

This directory contains all your shell configuration scripts organized by sequence number ranges. Files are loaded in order based on hostname, shell, and sequence number.

## Sequence Number Ranges

| Range   | Purpose                                                                         |
|---------|---------------------------------------------------------------------------------|
| 000-199 | Critical configurations (PATH, etc.)                                            |
| 200-399 | General configurations (Environment, Prompt, etc.)                              |
| 400-599 | Functions and aliases                                                           |
| 600-799 | Package specific configurations (pyenv, homebrew, etc.)                         |
| 800-949 | End of script info displays, clean up and closeout (mail checks, fortune, etc.) |
| 950-999 | Critical end of RC scripts                                                      |

## Naming Convention Reminder

All script files should follow this naming pattern:
```
###_[hostname|global]_[environment]_[description].sh
```

Where:
- `###`: Three-digit sequence number that determines load order
- `[hostname|global]`: Either your specific hostname or "global" for all machines
- `[environment]`: One of "common", "bash", or "zsh"
- `[description]`: Brief description of what the script does

IMPORTANT! No white space may be used in file names.

## Best Practices

- Use the same sequence number for similar functions across different shells
- Never use identical sequence numbers in the same execution path
- Use `cmd_exists` to check for program availability before configuration
- Use `is_macos`, `is_linux`, etc. for OS-specific configurations

For more details, see the full documentation in the docs directory.

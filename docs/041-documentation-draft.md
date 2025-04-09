## 1. Getting Started with rcForge

Welcome to rcForge! This guide will get you up and running quickly.

### Prerequisites

- **Bash Version:** rcForge's core utilities require **Bash version 4.3 or higher**. macOS users often need to install a newer version (the default is usually older).
  - On macOS, install via [Homebrew](https://brew.sh/): `brew install bash`. Ensure the new version is in your PATH ahead of the system version.
- **Standard Unix Utilities:** `curl` or `wget` is needed for the installer.
- **Git:** (optional) Recommended for managing and synchronizing your configurations.
- **Cloud storage:** (optional) Your configuration can also be sychronized using any cloud storage solution that supports all of the platforms you are on. Git is generally recommended because of it's portability.

### Installation

Install or upgrade rcForge using this command in your terminal:

```
curl -fsSL https://raw.githubusercontent.com/mhasse1/rcforge/main/install-script.sh | bash
```

This command downloads and executes the installer script, which places rcForge in `~/.config/rcforge/`.

Alternatively, you can download the installer from [GitHub](https://raw.githubusercontent.com/mhasse1/rcforge/main/install-script.sh) and view the code or run it after downloading.

### First Activation

To activate rcForge in your *current* shell session, run the following command.  I recommend starting a subshell and having a second terminal open before you do this -- it's still early days for this package. 

>  **Emergency Exit**
>
> The system provides an emergency exit immediately as the process starts.
>
> ```
> [INFO] Initializing rcForge v0.4.1. (Press '.' within 1s to abort).
> ```
>
> You can use this if your configuration ever loops or kicks you out of your shell before you can fix it.

To get started with your initial test:

```
zsh # (or bash)
source ~/.config/rcforge/rcforge.sh
```

**Important:** The installer adds a *commented-out* source line to your `~/.bashrc` and `~/.zshrc` files. After testing manually, you **must uncomment** this line in the relevant file(s) for rcForge to load automatically in new shell sessions.

The default config follows a lot of my own preferences, however, the rest of your `rc` remains untouched so that you can migrate into rcForge at your own pace.

(Almost) Everything in the systm is modular, so it's easy to replace or remove the default configuration.

### Verification

Check if rcForge is active by listing its available commands.

```
$ rc list
rcForge Utility Commands (v0.4.1)

Available commands:
  chkseq
    Checks for sequence number conflicts in rcForge configuration scripts

  concat-files
    Finds files and concatenates their content with markers.

  diag
    Creates diagrams of rcForge configuration loading sequence

  export
    Exports rcForge shell configurations for use on remote systems

Use 'rc <command> help' for detailed information about a command.
```

### Your First Customization: The Prompt

Probably the most personalized and religion-inducing thing about any shell environment is the prompt (other than the shell itself).  So let's get to making that prompt your's (though if you want to give mine a try I won't be offended).

**Note** there is a README.md file at `~/config/rcforge/rc-scripts/README.md` that provides an overview of the naming conventions and a suggestion for sequence number ranges.

1. The entire system is contained in `~/.config/rcforge`.  Feel free to poke around and make yourself at home. The `system` folder contains the core of rcFroge and these files all have the potential to be overwritten during an upgrade.  Nothing outside of this folder will be changed by the system other than writing output files `~/.config/rcforge/docs`, but more on this later. Let's give a quick overview of the folder structure.

   ```
   ~/.config/rcforge/
   ├── docs        # checksums, diagrams
   ├── rc-scripts  # your startup scripts
   └── system      # rcForge system files
       ├── core    # core scripts
       ├── lib     # core libraries (sourcable)
       └── utils   # included rc commands
   ```

2. All of the initialization scripts are located in `~/.config/rcforge/rc-scripts`. The naming convention is rigid, so follow it carefully. It follows the `init` pattern, but with a couple tweaks:

   In `350_global_bash_prompt.sh`

   * **350** - is the loading order.  The easy way to think of this is that it must be unique, but as you can see form the examples, there are two `350` scripts, but one runs in `bash` and the other in `zsh`, so they do not share an execution path. If we added `350_global_common_foo.sh` there would be a conflict and the order would be dictated alphabetically.
     * **`rc chkseq`** - run this command to have the system check for sequence problems. `rc chkseq --fix` provides an automated guess of how to fix conflicts, but check it afterwards to make sure it guessed right.
     * **`rc diag`** - will create a drawing in ASCII, GraphViz, or Mermaid (the default) showing the executiion path for the current system and shell.
   * **global** - this is a global, not machine specific implementation. Options are `global` or a hostname, in which case this would execute only on that host.
   * **bash** - it is specific to `bash`. Options are
     * **bash|zsh** - the system should work with any POSIX shell and might work with so-called exotics, but right now all testing is in these two shells.
     * **common** - the script runs in any shell
   * **prompt** - descriptive text of your choosing
   * **.sh** - the _required_ extension
   * **permissoins** - these files must be set executable. By default the system sets `700` for scripts and `600` for other files. This was chosen because it is common to find API keys and other sensitive information embedded in `rc` files.

   Putting all of that together, use your editor of choice and modify the `350`-file for your shell to put your preferred prompt in place. You'll notice there are a lot of helper functions in here to get your prompt just the way you want it, but you can also delete it all and replace it with `export PS1=$ `.

3. If it is not already, make the script executable (rcForge expects scripts to be):

   ```
   chmod 700 ~/.config/rcforge/rc-scripts/350_global_bash_prompt.sh
   ```
   
4. Reload your shell or start a new one to pick up the changes you just made.

   ```
   reload
   # reload is a default alias in rcForge. you can also use
   exec $SHELL -l
   # speaking of which: there are a lot of aliases built into the system
   # check out 400_global_common_aliases.sh to see and edit them.
   ```

You're now set up with rcForge. Explore the other documents to understand more concepts and commands.

------

## 2. Core Concepts Explained

The example given in the Getting Started guide provides much of the same information as this section, but we are more general in our discussion here.

rcForge helps organize your shell environment by replacing large, single configuration files (like `.bashrc`) with smaller, modular scripts.

### Modular Scripts

- All your shell configuration snippets live in `~/.config/rcforge/rc-scripts/`.
- rcForge loads these scripts in a specific, predictable order during shell startup.

### Script Naming Convention

Each script in the `rc-scripts` directory must follow this naming pattern:

```
###_[hostname|global]_[environment]_[description].sh
```

- **`###` (Sequence Number):** A three-digit number (000-999) that determines the loading order. Lower numbers load first.
- `[hostname|global]` (Scope):
  - `global`: The script loads on all machines where rcForge is installed.
  - `<your_hostname>`: The script *only* loads on the machine with that specific hostname (e.g., `laptop`, `server1`). You can find your hostname by running `hostname -s`.
- `[environment]` (Shell):
  - `common`: The script loads for *both* Bash and Zsh shells. Use for shell-agnostic settings like environment variables or simple aliases.
  - `bash`: The script loads *only* when using Bash.
  - `zsh`: The script loads *only* when using Zsh.
- **`[description]` (Description):** A brief, hyphen-or-underscore-separated description of what the script does (e.g., `path_setup`, `git_aliases`, `python_env`).
- **`.sh` (Extension):** All scripts must end with `.sh`.

**Example:** `050_global_common_path.sh` - Loads early (050), on all machines (global), for both shells (common), and likely configures the PATH.

### Loading Order

Scripts are sorted numerically by sequence number (`###`).

### Sequence Number Ranges (Suggestions)

Use these ranges as a guideline for organizing your scripts:

| **Range** | **Purpose**                                           |
| --------- | ----------------------------------------------------- |
| `000-199` | Critical setup (PATH, essential environment vars)     |
| `200-399` | General configuration (editor, history, shell opts)   |
| `400-599` | Aliases and functions                                 |
| `600-799` | Application/Tool specific settings (pyenv, nvm, etc.) |
| `800-949` | Informational displays, cleanup (fortune, motd)       |
| `950-999` | Critical final steps (rarely needed)                  |

By breaking your configuration into these named and sequenced files, you create a more organized and maintainable shell environment.

------

## 3. Using the `rc` Command

The `rc` command is your main gateway to interacting with rcForge utilities and managing your configuration. It acts as a dispatcher, finding and running utility scripts located in `~/.config/rcforge/system/utils/` (system utilities) and `~/.config/rcforge/utils/` (your custom utilities).

### Getting Help

- `rc help` shows the main help page for the `rc` command.

- `rc list` list available commands.

- `rc <command> help` show the help page for that command

### Key Built-in Utilities

rcForge comes with several handy utilities. Here are a few you might use:

- `rc diag`

  Generates diagrams (Mermaid, ASCII, or Graphviz) showing the loading order of your configuration scripts for a specific shell and hostname. Useful for understanding execution flow.

  ```
  # Diagram for current shell/host
  rc diag
  
  # Diagram for bash on host 'server1'
  rc diag --shell=bash --hostname=server1
  
  # Get help for diag options
  rc diag help
  ```
  
- `rc export`

  Creates a single, consolidated configuration file for a specific shell/hostname. Useful for systems where you can't install rcForge directly or need a quick rc file to be more productive.

  ```
  # Export bash config for current host
  rc export --shell=bash
  
  # Export zsh config for host 'laptop' to a specific file
  rc export --shell=zsh --hostname=laptop --output=~/laptop_zsh_config.sh
  
  # Get help for export options
  rc export help
  ```
  
- `rc chkseq`

  Checks for sequence number conflicts in your

Explore other commands using `rc list` and `rc <command> help`.

------

## 4. Basic Customization Examples

Here are a couple of common customization scenarios using rcForge's modular scripts. Remember to make scripts executable (`chmod 700 <script_path>`).

### Example 1: Setting Environment Variables

Environment variables like `EDITOR`, `PAGER`, or custom ones are typically set early. Use a `common` script if the variable applies to both Bash and Zsh.

**File:** `~/.config/rcforge/rc-scripts/200_global_common_env_vars.sh`

```
#!/usr/bin/env bash
# Set common environment variables

# Set default editor (will be overridden by shell-specific if needed later)
export EDITOR="vim"

# Set default pager with useful options for color and behavior
export LESS="-R -F -X"
export PAGER="${PAGER:-less}"

# Set language settings
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# Example custom variable
export MY_PROJECT_DIR="$HOME/Projects"

# EOF
```

**Explanation:**

- `200`: Sequence number places it in the general configuration range.
- `global`: Applies to all hosts.
- `common`: Applies to Bash and Zsh.
- `env_vars`: Description.
- Uses `export` to make variables available to subprocesses.

### Example 2: Adding Common Aliases and Functions

Aliases and simple functions that work in both Bash and Zsh belong in a `common` script, typically in the 400-599 range.

**File:** `~/.config/rcforge/rc-scripts/400_global_common_aliases.sh`

```
#!/usr/bin/env bash
# Common aliases and functions

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias home='cd ~'

# Listing (using colors based on OS detection from utility-functions)
# Note: This relies on IsBSD being available (sourced typically via 050_..._path.sh or similar)
if IsBSD; then
  # macOS ls colors
  export CLICOLOR=1
  alias ls='ls -GF'
  alias ll='ls -lhGF'
  alias la='ls -lahGF'
else
  # GNU ls colors
  alias ls='ls --color=auto -F --group-directories-first'
  alias ll='ls -lhF --color=auto --group-directories-first'
  alias la='ls -lahF --color=auto --group-directories-first'
fi
alias l.="ls -A | grep -E '^\.'"

# Simple function example
# Shows current directory and then lists files
show_files() {
  pwd
  ll # Use the 'll' alias defined above
}

# Git shortcuts (ensure git exists using CommandExists if needed)
if command -v git >/dev/null 2>&1; then
  alias gs='git status'
  alias ga='git add'
  alias gc='git commit'
  # ... add more git aliases
fi

# EOF
```

**Explanation:**

- `400`: Sequence number places it in the alias/function range.
- `global`: Applies to all hosts.
- `common`: Applies to Bash and Zsh (aliases and the simple function work in both).
- `aliases`: Description.
- Includes OS-dependent `ls` aliases for color support.
- Defines a simple shell function `show_files`.
- Conditionally defines `git` aliases only if `git` is installed.

Remember to create shell-specific files (e.g., `_bash_` or `_zsh_`) for configurations that are not compatible with both shells (like `setopt` for Zsh or `shopt` for Bash).


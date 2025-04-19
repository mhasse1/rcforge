## **1\. Getting Started with rcForge**

Welcome to rcForge\! This guide will get you up and running quickly.

### **Prerequisites**

* **Bash Version:** rcForge's core utilities require **Bash version 4.3 or higher**. macOS users often need to install a newer version (the default is usually older).  
  * On macOS, install via [Homebrew](https://brew.sh/): brew install bash. Ensure the new version is in your PATH.  
* **Git:** Needed for some utilities and recommended for managing your configurations.  
* **Standard Unix Utilities:** curl or wget is needed for the installer.

### **Installation**

Install or upgrade rcForge using this command in your terminal:

Bash

curl \-fsSL https://raw.githubusercontent.com/mhasse1/rcforge/main/install-script.sh | bash

This command downloads and executes the installer script, which places rcForge in \~/.config/rcforge/.

### **First Activation**

To activate rcForge in your *current* shell session, run:

Bash

source \~/.config/rcforge/rcforge.sh

**Important:** The installer adds a *commented-out* source line to your \~/.bashrc and \~/.zshrc files \[cite: 421-422, 1708-1709\]. After testing manually, you **must uncomment** this line in the relevant file(s) for rcForge to load automatically in new shell sessions.

### **Verification**

Check if rcForge is active by listing its available commands:

Bash

rc list

Or view the general help:

Bash

rc help

### **Your First Customization: An Alias**

Let's add a simple alias. Create a file for common aliases:

1. **Create the directory if it doesn't exist:**  
   Bash  
   mkdir \-p \~/.config/rcforge/rc-scripts/

2. **Create the alias file:**  
   Bash  
   \# Use your preferred editor (e.g., vim, nano)  
   \# The '410' sequence number places it after default PATH/config but before most other things.  
   \# 'global' means it applies to all hosts.  
   \# 'common' means it applies to both bash and zsh.  
   \# 'myaliases' is a description.  
   EDITOR \~/.config/rcforge/rc-scripts/410\_global\_common\_myaliases.sh

3. **Add content to the file:**  
   Bash  
   \#\!/usr/bin/env bash  
   \# My custom aliases

   alias ll='ls \-la'  
   alias ..='cd ..'

   \# EOF (Good practice to include an End-Of-File marker)

4. **Make it executable (rcForge expects scripts to be):**  
   Bash  
   chmod 700 \~/.config/rcforge/rc-scripts/410\_global\_common\_myaliases.sh

5. **Reload your shell or start a new one:**  
   Bash  
   exec $SHELL \-l

Now you should be able to use the ll and .. aliases\!  
You're now set up with rcForge. Explore the other documents to understand more concepts and commands.

## ---

**2\. Core Concepts Explained**

rcForge helps organize your shell environment by replacing large, single configuration files (like .bashrc) with smaller, modular scripts.

### **Modular Scripts**

* All your shell configuration snippets live in \~/.config/rcforge/rc-scripts/ \[cite: 132, 152-153, 423\].  
* rcForge loads these scripts in a specific, predictable order during shell startup.

### **Script Naming Convention**

Each script in the rc-scripts directory must follow this naming pattern:

\#\#\#\_\[hostname|global\]\_\[environment\]\_\[description\].sh

* **\#\#\# (Sequence Number):** A three-digit number (000-999) that determines the loading order. Lower numbers load first.  
* **\[hostname|global\] (Scope):**  
  * global: The script loads on all machines where rcForge is installed.  
  * \<your\_hostname\>: The script *only* loads on the machine with that specific hostname (e.g., laptop, server1). You can find your hostname by running hostname \-s.  
* **\[environment\] (Shell):**  
  * common: The script loads for *both* Bash and Zsh shells. Use for shell-agnostic settings like environment variables or simple aliases.  
  * bash: The script loads *only* when using Bash.  
  * zsh: The script loads *only* when using Zsh.  
* **\[description\] (Description):** A brief, hyphen-or-underscore-separated description of what the script does (e.g., path\_setup, git\_aliases, python\_env).  
* **.sh (Extension):** All scripts must end with .sh.

**Example:** 050\_global\_common\_path.sh \- Loads early (050), on all machines (global), for both shells (common), and likely configures the PATH.

### **Loading Order**

1. Scripts are sorted numerically by sequence number (\#\#\#).  
2. For scripts with the *same* sequence number:  
   * global scripts load before hostname-specific scripts.  
   * common scripts load before shell-specific (bash or zsh) scripts.

### **Sequence Number Ranges (Suggestions)**

Use these ranges as a guideline for organizing your scripts \[cite: 133-140, 260-266\]:

| Range | Purpose |
| :---- | :---- |
| 000-199 | Critical setup (PATH, essential environment vars) |
| 200-399 | General configuration (editor, history, shell opts) |
| 400-599 | Aliases and functions |
| 600-799 | Application/Tool specific settings (pyenv, nvm, etc.) |
| 800-949 | Informational displays, cleanup (fortune, motd) |
| 950-999 | Critical final steps (rarely needed) |

By breaking your configuration into these named and sequenced files, you create a more organized and maintainable shell environment.

## ---

**3\. Using the rc Command**

The rc command is your main gateway to interacting with rcForge utilities and managing your configuration \[cite: 144, 209-210, 355, 428\]. It acts as a dispatcher, finding and running utility scripts located in \~/.config/rcforge/system/utils/ (system utilities) and \~/.config/rcforge/utils/ (your custom utilities).

### **Getting Help**

* **General rc Help:** To see the main help message for the rc command framework itself:  
  Bash  
  rc help

* **List Available Commands:** To see a list of all available system and user utility commands with brief summaries:  
  Bash  
  rc list  
  *(Note: rc help often includes the list as well)*  
* **Help for a Specific Command:** To get detailed help, options, and examples for a particular utility (e.g., httpheaders):  
  Bash  
  rc httpheaders help

### **Key Built-in Utilities**

rcForge comes with several handy utilities. Here are a few you might use:

* **rc diag**: Generates diagrams (Mermaid, ASCII, or Graphviz) showing the loading order of your configuration scripts for a specific shell and hostname. Useful for understanding execution flow.  
  Bash  
  \# Diagram for current shell/host  
  rc diag

  \# Diagram for bash on host 'server1'  
  rc diag \--shell=bash \--hostname=server1

  \# Get help for diag options  
  rc diag help

* **rc export**: Creates a single, consolidated configuration file for a specific shell/hostname. Useful for systems where you can't install rcForge directly \[cite: 10-11, 430\].  
  Bash  
  \# Export bash config for current host  
  rc export \--shell=bash

  \# Export zsh config for host 'laptop' to a specific file  
  rc export \--shell=zsh \--hostname=laptop \--output=\~/laptop\_zsh\_config.sh

  \# Get help for export options  
  rc export help

* **rc chkseq**: Checks for sequence number conflicts in your rc-scripts directory for a given shell/hostname. Conflicts happen if multiple scripts would load with the exact same sequence number in the same context \[cite: 363-364, 429\].  
  Bash  
  \# Check current shell/host for conflicts  
  rc chkseq

  \# Interactively fix conflicts for current shell/host  
  rc chkseq \--fix

  \# Get help for chkseq options  
  rc chkseq help

* **rc httpheaders**: A simple utility to fetch and display HTTP headers from a URL.  
  Bash  
  rc httpheaders example.com  
  rc httpheaders \-v https://github.com \# Verbose output

Explore other commands using rc list and rc \<command\> help.

## ---

**4\. Basic Customization Examples**

Here are a couple of common customization scenarios using rcForge's modular scripts. Remember to make scripts executable (chmod 700 \<script\_path\>).

### **Example 1: Setting Environment Variables**

Environment variables like EDITOR, PAGER, or custom ones are typically set early. Use a common script if the variable applies to both Bash and Zsh.  
**File:** \~/.config/rcforge/rc-scripts/200\_global\_common\_env\_vars.sh

Bash

\#\!/usr/bin/env bash  
\# Set common environment variables

\# Set default editor (will be overridden by shell-specific if needed later)  
export EDITOR="vim"

\# Set default pager with useful options for color and behavior  
export LESS="-R \-F \-X" \[cite: 584\]  
export PAGER="${PAGER:-less}" \[cite: 584\]

\# Set language settings  
export LANG="${LANG:-en\_US.UTF-8}" \[cite: 583\]  
export LC\_ALL="${LC\_ALL:-en\_US.UTF-8}" \[cite: 583\]

\# Example custom variable  
export MY\_PROJECT\_DIR="$HOME/Projects"

\# EOF

**Explanation:**

* 200: Sequence number places it in the general configuration range.  
* global: Applies to all hosts.  
* common: Applies to Bash and Zsh.  
* env\_vars: Description.  
* Uses export to make variables available to subprocesses.

### **Example 2: Adding Common Aliases and Functions**

Aliases and simple functions that work in both Bash and Zsh belong in a common script, typically in the 400-599 range.  
**File:** \~/.config/rcforge/rc-scripts/400\_global\_common\_aliases.sh

Bash

\#\!/usr/bin/env bash  
\# Common aliases and functions

\# Navigation  
alias ..='cd ..' \[cite: 587\]  
alias ...='cd ../..' \[cite: 587\]  
alias home='cd \~' \[cite: 587\]

\# Listing (using colors based on OS detection from utility-functions)  
\# Note: This relies on IsBSD being available (sourced typically via 050\_...\_path.sh or similar)  
if IsBSD; then \[cite: 587\]  
  \# macOS ls colors  
  export CLICOLOR=1 \[cite: 588\]  
  alias ls='ls \-GF' \[cite: 588\]  
  alias ll='ls \-lhGF' \[cite: 588\]  
  alias la='ls \-lahGF' \[cite: 588\]  
else  
  \# GNU ls colors  
  alias ls='ls \--color=auto \-F \--group-directories-first'  
  alias ll='ls \-lhF \--color=auto \--group-directories-first'  
  alias la='ls \-lahF \--color=auto \--group-directories-first'  
fi  
alias l.="ls \-A | grep \-E '^\\.'" \[cite: 589\]

\# Simple function example  
\# Shows current directory and then lists files  
show\_files() {  
  pwd  
  ll \# Use the 'll' alias defined above  
}

\# Git shortcuts (ensure git exists using CommandExists if needed)  
if command \-v git \>/dev/null 2\>&1; then \[cite: 596\]  
  alias gs='git status' \[cite: 596\]  
  alias ga='git add' \[cite: 596\]  
  alias gc='git commit' \[cite: 596\]  
  \# ... add more git aliases  
fi

\# EOF

**Explanation:**

* 400: Sequence number places it in the alias/function range.  
* global: Applies to all hosts.  
* common: Applies to Bash and Zsh (aliases and the simple function work in both).  
* aliases: Description.  
* Includes OS-dependent ls aliases for color support.  
* Defines a simple shell function show\_files.  
* Conditionally defines git aliases only if git is installed.

Remember to create shell-specific files (e.g., \_bash\_ or \_zsh\_) for configurations that are not compatible with both shells (like setopt for Zshor shopt for Bash).
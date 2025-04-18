# 0.5.0 Overhaul

## Deployment changes

Changes to the deployment:
- Removing all example scripts under rc-scripts
- Move examples to wiki docs on Github
- Removing docs folder
- Path logic:  Path logic will all be moved internal to rcforge.sh
	- just prior to starting processing of rc-scripts: replace PATH as follows:
		- read ${RCFORGE_ROOT}/config/path.conf. psuedo code follows
			local new_path=""
			for path in [path_file_contents]; do
				if exists(path); then
					new_path+=path
				fi
			done
			export PATH=new_path
		- path.conf will be text and skip lines starting with '#' and blank lines. For example,

			```
			# My bin directory
			${HOME}/bin

			# package managers
			/opt/homebrew/bin

			# system directories
			/usr/bin
			/bin
			```

## API key storage

Added a file named "api_key_settings" to the local structure and will add a utility to maintain this file. The concept is to store a table of to-be-exported API keys with their appropriate API key. For example:

	GEMINI_API_KEY='AAAAAAAAAAAAAAAA'
	CLAUDE_API_KEY='BBBBBBBBBBBBBBBB'
	AWS_API_KEY='CCCCCCCCCCCCCCCC'

This fille will be processed in rcforge.sh to export (e.g. export AWS_API_KEY='CCCCCCCCCCCCCCCC'), ignoring blank lines and lines starting with '#'.

### API key management
Will be added to the rc commmand stucture with the following functions:

Add/update key: `rc apikey set KEY_NAME value`
Remove key: `rc apikey remove KEY_NAME`
List keys: `rc apikey list`

## Directory structure changes

Updated folder structure to better follow XDG standard and will comply with XDG environment variables (see https://specifications.freedesktop.org/basedir-spec/latest/).  With the following changes to the directory structure it becomes easier for the user to sync via whatever means they choose only the folders that should be synced.

For example: In the current folder structure, if the user used GIT to sync, it would likely grab CRC files, bash location, the system structure or the user would have to implement a .gitignore and it would too easy for something to change in the system, requiring changes to this file, without an end user noticing. This would also make configuration sync via cloud storage extremely difficult to impossible.

### Updated structure

```
${HOME}/.config
└── rcforge
    ├── config
    │   └── path.conf
    └── rc-scripts
        └── README.md
```

```
${HOME}/.local
└── rcforge
    ├── LICENSE
    ├── README.md
    ├── backups
    │   └── rcforge_backup-20250415224434.tar.gz
    ├── config
    │   ├── api_key_settings
    │   ├── bash-location
    │   └─── checksums
    │       ├── .bashrc.md5
    │       └── .zshrc.md5
    ├── rcforge.sh
    └── system
        ├── core
        │   ├── bash-version-check.sh
        │   ├── rc.sh
        │   └── run-integrity-checks.sh
        ├── lib
        │   ├── shell-colors.sh
        │   └── utility-functions.sh
        └── utils
            ├── check-checksums.sh
            ├── chkseq.sh
            ├── concat-files.sh
            ├── diag.sh
            └── export.sh
```

###
Backup function for upgrades will change to match the new folder structure.

## Migration
If an existing configuration is detected when running the installer, we will briefly inform the user of the changes

📣 rcForge 0.5.0 Update Available 📣

This update reorganizes your rcForge files to:
- Follow standard directory conventions (XDG compliant)
- Make syncing between machines easier
- Better separate your customizations from system files
- Add API key management

The migration will preserve all your customizations and settings.
Would you like to proceed with the update? (y/n)

Assuming the user agrees, we will restructure the existing config.
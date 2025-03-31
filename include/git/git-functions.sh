#!/usr/bin/env bash
# GitUtils.sh - Git utility functions
# Category: git
# Author: Mark Hasse
# Date: 2025-03-31
#
# This file provides a comprehensive set of Git helper functions for
# use in shell scripts and interactive sessions.

# Set strict error handling
set -o nounset  # Treat unset variables as errors
set -o errexit  # Exit immediately if a command exits with a non-zero status

#--------------------------------------------------------------
# Git Status and Information Functions
#--------------------------------------------------------------

# Function: IsGitRepo
# Description: Checks if the current directory is in a Git repository
# Usage: IsGitRepo
# Returns: 0 if in a Git repository, 1 otherwise
IsGitRepo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
    return $?
}

# Function: GetGitBranch
# Description: Gets the current Git branch name
# Usage: GetGitBranch
# Returns: Echoes the branch name or empty if not in a Git repository
GetGitBranch() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        return 1
    fi
    
    # Get the branch name
    git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null
    return $?
}

# Function: HasGitChanges
# Description: Checks if there are uncommitted changes in the repository
# Usage: HasGitChanges
# Returns: 0 if there are changes, 1 if clean
HasGitChanges() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        return 1
    fi
    
    # Check for changes
    [[ -n "$(git status --porcelain 2>/dev/null)" ]]
    return $?
}

# Function: GetGitRoot
# Description: Gets the root directory of the current Git repository
# Usage: GetGitRoot
# Returns: Echoes the root directory path or empty if not in a Git repository
GetGitRoot() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        return 1
    fi
    
    # Get the root directory
    git rev-parse --show-toplevel 2>/dev/null
    return $?
}

# Function: GetGitRemoteUrl
# Description: Gets the URL of the remote repository
# Usage: GetGitRemoteUrl [remote_name]
# Arguments:
#   $1 - Remote name (default: origin)
# Returns: Echoes the remote URL or empty if not found
GetGitRemoteUrl() {
    local remote="${1:-origin}"
    
    # Check if in a Git repository
    if ! IsGitRepo; then
        return 1
    fi
    
    # Get the remote URL
    git remote get-url "$remote" 2>/dev/null
    return $?
}

#--------------------------------------------------------------
# Git Workflow Helper Functions
#--------------------------------------------------------------

# Function: GitSwitchBranch
# Description: Switches to a branch, creating it if it doesn't exist
# Usage: GitSwitchBranch branch_name [start_point]
# Arguments:
#   $1 - Branch name
#   $2 - Start point (optional)
# Returns: 0 on success, 1 on failure
GitSwitchBranch() {
    # Validate input
    if [[ $# -eq 0 ]]; then
        echo "ERROR: No branch name specified" >&2
        return 1
    fi
    
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    local branch="$1"
    local start_point="${2:-}"
    
    # Check if the branch exists
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        # Branch exists, switch to it
        git checkout "$branch"
    else
        # Branch doesn't exist, create it
        if [[ -n "$start_point" ]]; then
            git checkout -b "$branch" "$start_point"
        else
            git checkout -b "$branch"
        fi
    fi
    
    return $?
}

# Function: GitSafeCommit
# Description: Commits changes with a message, only if there are changes to commit
# Usage: GitSafeCommit "Commit message"
# Arguments:
#   $1 - Commit message
# Returns: 0 on success, 1 on failure
GitSafeCommit() {
    # Validate input
    if [[ $# -eq 0 ]]; then
        echo "ERROR: No commit message specified" >&2
        return 1
    fi
    
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    local message="$1"
    
    # Check if there are changes to commit
    if ! HasGitChanges; then
        echo "Nothing to commit, working tree clean"
        return 0
    fi
    
    # Commit changes
    git commit -m "$message"
    return $?
}

# Function: GitPush
# Description: Pushes changes to the remote repository, setting upstream if needed
# Usage: GitPush [remote] [branch]
# Arguments:
#   $1 - Remote name (default: origin)
#   $2 - Branch name (default: current branch)
# Returns: 0 on success, 1 on failure
GitPush() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    local remote="${1:-origin}"
    local branch="${2:-$(GetGitBranch)}"
    
    # Check if branch exists on remote
    if git ls-remote --exit-code "$remote" "refs/heads/$branch" >/dev/null 2>&1; then
        # Branch exists, push normally
        git push "$remote" "$branch"
    else
        # Branch doesn't exist, set upstream
        git push -u "$remote" "$branch"
    fi
    
    return $?
}

# Function: GitSync
# Description: Synchronizes the current branch with the remote repository
# Usage: GitSync [remote] [branch]
# Arguments:
#   $1 - Remote name (default: origin)
#   $2 - Branch name (default: current branch)
# Returns: 0 on success, 1 on failure
GitSync() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    local remote="${1:-origin}"
    local branch="${2:-$(GetGitBranch)}"
    
    # Fetch the latest changes
    git fetch "$remote" "$branch" || return 1
    
    # Check if current branch is tracking the remote
    local tracking=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null || echo "")
    
    if [[ -z "$tracking" ]]; then
        # Set tracking branch
        git branch --set-upstream-to="$remote/$branch" "$branch" || return 1
    fi
    
    # Rebase or merge (depending on git config)
    if git config pull.rebase >/dev/null 2>&1 && [[ "$(git config pull.rebase)" == "true" ]]; then
        git pull --rebase "$remote" "$branch"
    else
        git pull "$remote" "$branch"
    fi
    
    return $?
}

#--------------------------------------------------------------
# Git Project Management Functions
#--------------------------------------------------------------

# Function: GitCleanBranches
# Description: Removes local branches that have been merged or deleted on the remote
# Usage: GitCleanBranches [remote]
# Arguments:
#   $1 - Remote name (default: origin)
# Returns: 0 on success, 1 on failure
GitCleanBranches() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    local remote="${1:-origin}"
    local current_branch=$(GetGitBranch)
    
    # Make sure we're on a branch
    if [[ -z "$current_branch" ]]; then
        echo "ERROR: Not on a branch" >&2
        return 1
    fi
    
    # Get default branch
    local default_branch=$(git remote show "$remote" | grep "HEAD branch" | sed 's/.*: //')
    
    # If we can't determine default branch, assume main or master
    if [[ -z "$default_branch" ]]; then
        if git show-ref --verify --quiet refs/heads/main; then
            default_branch="main"
        else
            default_branch="master"
        fi
    fi
    
    # Switch to default branch if not already on it
    if [[ "$current_branch" != "$default_branch" ]]; then
        git checkout "$default_branch" || return 1
    fi
    
    # Fetch from remote with prune to remove stale tracking branches
    git fetch "$remote" --prune || return 1
    
    # Remove local branches that have been merged
    git branch --merged "$default_branch" | grep -v "^\* " | grep -v " $default_branch$" | xargs -r git branch -d
    
    # Remove local branches that have been deleted on the remote
    git branch -vv | grep ': gone]' | awk '{print $1}' | xargs -r git branch -D
    
    # Return to original branch if different from default
    if [[ "$current_branch" != "$default_branch" ]]; then
        git checkout "$current_branch"
    fi
    
    return 0
}

# Function: GitBackup
# Description: Creates a backup of the current repository to a zip file
# Usage: GitBackup [output_file]
# Arguments:
#   $1 - Output file path (default: repo_name-YYYYMMDD.zip)
# Returns: 0 on success, 1 on failure
GitBackup() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    local repo_root=$(GetGitRoot)
    local repo_name=$(basename "$repo_root")
    local date_str=$(date +%Y%m%d)
    local output_file="${1:-${repo_name}-${date_str}.zip}"
    
    # Check if git archive command is available
    if ! git archive --format=zip -o "${output_file}.temp" HEAD; then
        echo "ERROR: Failed to create archive" >&2
        return 1
    fi
    
    # Add untracked files (excluding .gitignore entries)
    if command -v zip >/dev/null 2>&1; then
        # Get all untracked files
        local untracked_files=$(git ls-files --others --exclude-standard)
        
        # If there are untracked files, add them to the zip
        if [[ -n "$untracked_files" ]]; then
            cd "$repo_root" && echo "$untracked_files" | zip -q "${output_file}.temp" -@
        fi
        
        # Rename the temporary file to the final output file
        mv "${output_file}.temp" "$output_file"
    else
        # If zip command is not available, just use the git archive
        mv "${output_file}.temp" "$output_file"
        echo "WARNING: 'zip' command not found, untracked files not included in backup" >&2
    fi
    
    echo "Backup created: $output_file"
    return 0
}

# Function: GitBundleAll
# Description: Creates a Git bundle containing all branches and tags
# Usage: GitBundleAll [output_file]
# Arguments:
#   $1 - Output file path (default: repo_name-YYYYMMDD.bundle)
# Returns: 0 on success, 1 on failure
GitBundleAll() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    local repo_root=$(GetGitRoot)
    local repo_name=$(basename "$repo_root")
    local date_str=$(date +%Y%m%d)
    local output_file="${1:-${repo_name}-${date_str}.bundle}"
    
    # Create bundle with all branches and tags
    git bundle create "$output_file" --all
    
    echo "Bundle created: $output_file"
    return $?
}

#--------------------------------------------------------------
# Git Diagnostics and Stats
#--------------------------------------------------------------

# Function: GitBranchStats
# Description: Shows statistics for each branch
# Usage: GitBranchStats
# Returns: 0 on success, 1 on failure
GitBranchStats() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    # Get list of all branches
    local branches=$(git branch -a | cut -c 3-)
    
    echo "Branch Statistics:"
    echo "================="
    
    # Loop through branches
    for branch in $branches; do
        # Skip remote tracking branches
        if [[ "$branch" == remotes/* ]]; then
            continue
        fi
        
        # Get commit count
        local commit_count=$(git rev-list --count "$branch")
        
        # Get last commit date
        local last_commit_date=$(git log -1 --format="%ad" --date=short "$branch")
        
        # Get last commit author
        local last_commit_author=$(git log -1 --format="%an" "$branch")
        
        # Print statistics
        printf "%-30s %5d commits, last updated %s by %s\n" \
               "$branch" "$commit_count" "$last_commit_date" "$last_commit_author"
    done
    
    return 0
}

# Function: GitContributorStats
# Description: Shows statistics for each contributor
# Usage: GitContributorStats
# Returns: 0 on success, 1 on failure
GitContributorStats() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    echo "Contributor Statistics:"
    echo "======================"
    
    # Get short stats for each author
    git shortlog -sne --all
    
    echo ""
    echo "Contribution by month:"
    echo "====================="
    
    # Get monthly stats
    git log --format="%ad %an" --date=format:"%Y-%m" | sort | uniq -c | sort -k3,3 -k2,2
    
    return 0
}

# Function: GitFindLargeFiles
# Description: Finds large files in the Git repository
# Usage: GitFindLargeFiles [count]
# Arguments:
#   $1 - Number of files to show (default: 10)
# Returns: 0 on success, 1 on failure
GitFindLargeFiles() {
    # Check if in a Git repository
    if ! IsGitRepo; then
        echo "ERROR: Not in a Git repository" >&2
        return 1
    fi
    
    local count="${1:-10}"
    
    echo "Largest files in the repository:"
    echo "=============================="
    
    # Find the largest blobs in the Git repository
    git rev-list --objects --all |
      git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' |
      awk '/^blob/ {print $3 " " $4}' |
      sort -rn |
      head -n "$count" |
      awk '{
        size = $1;
        file = $2;
        if (size > 1024*1024*1024) {
          printf "%10.2f GB  %s\n", size/(1024*1024*1024), file;
        } else if (size > 1024*1024) {
          printf "%10.2f MB  %s\n", size/(1024*1024), file;
        } else if (size > 1024) {
          printf "%10.2f KB  %s\n", size/1024, file;
        } else {
          printf "%10d  B   %s\n", size, file;
        }
      }'
    
    return 0
}

# Export all functions
export -f IsGitRepo
export -f GetGitBranch
export -f HasGitChanges
export -f GetGitRoot
export -f GetGitRemoteUrl
export -f GitSwitchBranch
export -f GitSafeCommit
export -f GitPush
export -f GitSync
export -f GitCleanBranches
export -f GitBackup
export -f GitBundleAll
export -f GitBranchStats
export -f GitContributorStats
export -f GitFindLargeFiles
# EOF

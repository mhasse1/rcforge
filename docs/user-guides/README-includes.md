# rcForge Include System

The rcForge Include System in v2.0.0 brings modular shell functions to rcForge, allowing you to create, manage, and use shell functions in a modular, maintainable way.

## Features

- **Modular Function Organization**: Keep your shell functions organized by category
- **User Overrides**: Override system functions with your own custom versions
- **Function Dependencies**: Automatically resolve and include function dependencies
- **Export Support**: Include functions in exported configurations for remote servers
- **Package System**: Treat functions as reusable packages that can be shared

## Directory Structure

```
/usr/share/rcforge/           # System-level files (package managed)
  ├── include/                # System include files
  |   ├── path/               # Path-related functions
  |   ├── common/             # Common utility functions
  |   ├── git/                # Git-related functions
  |   └── ...                 # Other function categories
  ├── lib/                    # Core library files
      └── include-functions.sh # Core include system functions

~/.config/rcforge/            # User-level configuration
  ├── scripts/                # User scripts (numbered sequence files)
  ├── include/                # User function overrides
      ├── path/               # User's custom path functions
      └── ...                 # Other custom function categories
```

## Using the Include System

### Including Functions

To use a function from the include system, add the following to your script:

```bash
# Include a specific function from a category
include_function category function_name

# Examples:
include_function path add_to_path
include_function git git_status
include_function common is_macos

# Include all functions in a category
include_category common
```

### Function Resolution

When you include a function, the system searches for it in the following order:

1. Your user include directory (`~/.config/rcforge/include/`)
2. The system include directory (`/usr/share/rcforge/include/`)

### Available Categories

The following standard categories are available:

- `path`: PATH management functions
- `common`: Common utility functions like `is_macos`, `is_linux`
- `git`: Git-related functions
- `network`: Network utility functions
- `system`: System information and management
- `text`: Text processing functions
- `web`: Web-related functions
- `dev`: Development tools
- `security`: Security-related functions
- `tools`: Miscellaneous tools

## Creating Your Own Include Functions

### Using the Creator Script

The easiest way to create a new include function is with the creator script:

```bash
# Development paths
<PROJECT_ROOT>/scripts/create-include.sh

# User installation paths
~/.config/rcforge/scripts/create-include.sh
```

This interactive script will:

1. Ask for the category (existing or new)
2. Ask for the function name
3. Ask for a function description
4. Ask for function arguments
5. Create a template function file in the correct location

### Manual Creation

You can also create include functions manually:

1. Choose or create a category directory in your include directory:
   ```bash
   mkdir -p ~/.config/rcforge/include/mycategory
   ```

2. Create a function file with the `.sh` extension:
   ```bash
   vim ~/.config/rcforge/include/mycategory/myfunction.sh
   ```

3. Use this template for your function file:
   ```bash
   #!/bin/bash
   # myfunction.sh - Description of what this function does
   # Category: mycategory
   # Author: Your Name
   # Date: YYYY-MM-DD
   
   # Function: myfunction
   # Description: Detailed description here
   # Usage: myfunction arg1 arg2
   myfunction() {
     local arg1="$1"
     local arg2="$2"
     
     # Function implementation
     echo "Hello from myfunction!"
   }
   
   # Export the function
   export -f myfunction
   ```

## Best Practices

### Function Design

1. **Single Responsibility**: Each function should do one thing and do it well
2. **Document Usage**: Include clear documentation and examples
3. **Specify Dependencies**: If your function depends on other functions, mention them in comments
4. **Namespace Functions**: Use category prefixes for function names to avoid conflicts
5. **Return Values**: Use return codes to indicate success/failure

### Function Dependencies

If your function depends on other functions, you should include them:

```bash
# my_advanced_function.sh
# Dependencies:
# - common/is_macos
# - common/is_linux

# Make sure dependencies are available
include_function common is_macos
include_function common is_linux

my_advanced_function() {
  if is_macos; then
    # macOS-specific code
  elif is_linux; then
    # Linux-specific code
  fi
}

export -f my_advanced_function
```

## Overriding System Functions

To override a system function with your own version:

1. Create the same category directory in your user include directory
2. Create a file with the same name as the system function
3. Implement your custom version

For example, to override the system `add_to_path` function:

```bash
mkdir -p ~/.config/rcforge/include/path
vim ~/.config/rcforge/include/path/add_to_path.sh
```

```bash
#!/bin/bash
# add_to_path.sh - Custom version of add_to_path with notification
# Category: path

add_to_path() {
  local dir="$1"
  if [[ -d "$dir" && ":$PATH:" != *":$dir:"* ]]; then
    export PATH="$dir:$PATH"
    echo "Added to PATH: $dir"
    return 0
  fi
  return 1
}

export -f add_to_path
```

## Development Mode

If you're developing for rcForge, set the `RCFORGE_DEV` environment variable:

```bash
export RCFORGE_DEV=1
```

This will make the include system use the development directories instead:

```
<PROJECT_ROOT>/include/  # Development include directory
<PROJECT_ROOT>/src/lib/  # Development library directory
```

Suggested project root locations:
- `~/src/rcforge`
- `~/Projects/rcforge`
- `~/development/rcforge`

## Example Workflow

Here's a complete example of how to use the include system in a script:

```bash
#!/bin/bash
# 400_global_common_functions.sh - Custom utility functions

# Include the functions we need
include_function path add_to_path
include_function common is_macos
include_function common is_linux

# Define our own function that uses the included functions
setup_development_environment() {
  # Add development directories to PATH
  add_to_path "$HOME/bin"
  add_to_path "$HOME/.local/bin"
  
  # OS-specific configuration
  if is_macos; then
    add_to_path "/opt/homebrew/bin"
  elif is_linux; then
    add_to_path "/usr/local/bin"
  fi
  
  echo "Development environment configured"
}

# Use our function
setup_development_environment
```

## Listing Available Functions

To see all available functions in the include system:

```bash
# Source include functions
source ~/.config/rcforge/lib/include-functions.sh

# List all available functions
list_available_functions

# List functions in a specific category
list_available_functions path
```

## Next Steps

- Browse the include directories to see available functions
- Try including functions in your scripts
- Create your own functions with `create-include.sh`
- Override system functions with your own versions
- Share your functions with others

With the include system, your shell functions become more organized, reusable, and maintainable!

read -r -p "Overwrite existing configurations? [y/N]: " overwrite_choice
    if [[ "$overwrite_choice" =~ ^[Yy]$ ]]; then
      OVERWRITE_EXISTING=true
    fi
  fi
}

# Main script execution
Main() {
  # Parse command-line arguments
  ParseArguments "$@"

  # Display header
  SectionHeader "${gc_app_name} Setup Utility"

  # Interactive configuration
  InteractiveSetup

  # Create base directory structure
  CreateDirectoryStructure

  # Check for skel directory and use it if available
  local skel_dir
  skel_dir=$(DetectSkelDirectory)
  
  if [[ -n "$skel_dir" ]]; then
    InitializeFromSkel "$skel_dir"
  else
    # Fall back to creating sample configurations
    CreateSampleConfigurations \
      "$gc_default_scripts_dir" \
      "$TARGET_SHELL" \
      "$HOSTNAME"
  fi

  # Update shell RC file
  UpdateRCFiles "$TARGET_SHELL"

  # Final success message
  echo ""
  SuccessMessage "${gc_app_name} setup completed successfully!"
  echo ""
  echo "Next steps:"
  echo "1. Restart your shell or run: source ~/.${TARGET_SHELL}rc"
  echo "2. Customize configurations in: ${gc_config_base_dir}/scripts/"
}

# Entry point - execute only if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  Main "$@"
fi
# EOF

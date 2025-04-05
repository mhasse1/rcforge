class Rcforge < Formula
  desc "Universal shell configuration system for Bash and Zsh"
  homepage "https://github.com/mhasse1/rcforge"
  url "https://github.com/mhasse1/rcforge/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"  # Replace with actual SHA256 when available
  license "MIT"
  head "https://github.com/mhasse1/rcforge.git", branch: "main"

  livecheck do
    url :stable
    regex(/^v?(\d+(?:\.\d+)+)$/i)
  end

  depends_on "bash"
  depends_on "zsh" => :recommended

  def install
    # Install main script to prefix
    prefix.install "rcforge.sh"
    prefix.install "include-structure.sh"

    # Install core files
    prefix.install Dir["core/*"]
    prefix.install Dir["utils/*"]

    # Install library files
    (prefix/"lib").mkpath
    (prefix/"lib").install Dir["lib/*"]

    # Install include files with directory structure
    include_dir = prefix/"include"
    include_dir.mkpath
    include_dir.install Dir["include/*"]

    # Install example scripts
    (prefix/"scripts").mkpath
    (prefix/"scripts").install Dir["scripts/*"]

    # Create exports directory
    (prefix/"exports").mkpath

    # Install documentation
    doc.install Dir["docs/*"]
    doc.install "README.md"
    doc.install "LICENSE"

    # Create executable symlinks in bin
    bin.install_symlink prefix/"rcforge.sh" => "rcforge"
    bin.install_symlink prefix/"utils/rcforge-setup.sh" => "rcforge-setup"
    bin.install_symlink prefix/"utils/export-config.sh" => "rcf-export"
    bin.install_symlink prefix/"utils/diagram-config.sh" => "rcf-diagram"
    bin.install_symlink prefix/"utils/create-include.sh" => "rcf-include"

    # Make all scripts executable
    system "chmod", "+x", "#{bin}/rcforge"
    system "chmod", "+x", "#{bin}/rcforge-setup"
    system "chmod", "+x", "#{bin}/rcf-export"
    system "chmod", "+x", "#{bin}/rcf-diagram"
    system "chmod", "+x", "#{bin}/rcf-include"
    system "find", "#{prefix}", "-name", "*.sh", "-exec", "chmod", "+x", "{}", ";"
  end

  def post_install
    # Create configuration directories in user's home
    user_config_dir = "#{ENV["HOME"]}/.config/rcforge"

    # Create directories
    system "mkdir", "-p", "#{user_config_dir}/scripts"
    system "mkdir", "-p", "#{user_config_dir}/include"
    system "mkdir", "-p", "#{user_config_dir}/exports"
    system "mkdir", "-p", "#{user_config_dir}/docs"

    # Copy example files if they don't exist
    if Dir["#{user_config_dir}/scripts/*"].empty?
      system "cp", "-n", "#{prefix}/scripts/README.md", "#{user_config_dir}/scripts/" if File.exist?("#{prefix}/scripts/README.md")
    end

    # Copy documentation files
    system "cp", "-n", "#{doc}/getting-started.md", "#{user_config_dir}/docs/" if File.exist?("#{doc}/getting-started.md")

    # Create a basic README in the user config directory
    readme_path = "#{user_config_dir}/docs/README.md"
    unless File.exist?(readme_path)
      File.open(readme_path, "w") do |file|
        file.write <<~EOS
          # rcForge User Configuration

          This directory contains your personal rcForge shell configuration.

          ## Directory Structure

          - `scripts/` - Your shell configuration scripts
          - `include/` - Your custom include functions
          - `exports/` - Exported configurations for remote servers
          - `docs/` - Documentation

          ## Getting Started

          Add your configuration files to the scripts directory following the naming convention:

          ```
          ###_[hostname|global]_[environment]_[description].sh
          ```

          For more information, see the documentation in the docs directory.
        EOS
      end
    end

    # Set correct permissions
    system "chmod", "-R", "u+w", user_config_dir
  end

  def caveats
    <<~EOS
      To complete installation, add the following to your shell configuration file:

      For Bash:
        echo 'source "#{opt_prefix}/rcforge.sh"' >> ~/.bashrc

      For Zsh:
        echo 'source "#{opt_prefix}/rcforge.sh"' >> ~/.zshrc

      Your personal configurations should be added to:
        ~/.config/rcforge/scripts/

      Utility commands available:
        rcforge        - Main rcForge script
        rcforge-setup  - Setup utility
        rcf-export     - Export configurations for remote servers
        rcf-diagram    - Create visual diagrams of your configuration
        rcf-include    - Create custom include functions

      For more information, see the documentation:
        #{opt_doc}
    EOS
  end

  test do
    # Test 1: Binary exists and is executable
    assert_predicate bin/"rcforge", :exist?
    assert_predicate bin/"rcforge", :executable?
    assert_predicate bin/"rcf-export", :exist?
    assert_predicate bin/"rcf-diagram", :exist?
    assert_predicate bin/"rcf-include", :exist?

    # Test 2: Core functions can be sourced
    # Use a standalone check to avoid polluting test environment
    system "bash", "-c", "source #{prefix}/core/functions.sh && echo 'Core functions loaded'"

    # Test 3: Create a simple test configuration
    mkdir_p testpath/"scripts"
    (testpath/"scripts/100_test_common_test.sh").write <<~EOS
      #!/bin/bash
      # Test configuration
      export TEST_VARIABLE="Hello, World!"
      echo "Test configuration loaded"
    EOS
    chmod 0755, testpath/"scripts/100_test_common_test.sh"

    # Test 4: Test the include system if Bash version is sufficient
    bash_major_version = `bash --version | head -1 | awk '{print $4}' | cut -d. -f1`.to_i
    if bash_major_version >= 4
      mkdir_p testpath/"include/test"
      (testpath/"include/test/hello.sh").write <<~EOS
        #!/bin/bash
        # Test function
        hello() {
          echo "Hello from include function"
        }
        export -f hello
      EOS
      chmod 0755, testpath/"include/test/hello.sh"

      # Create a test script that loads a function
      (testpath/"test_include.sh").write <<~EOS
        #!/bin/bash
        # Set up test environment
        export RCFORGE_ROOT=#{testpath}
        source #{prefix}/lib/include-functions.sh
        include_function test hello
        hello
      EOS
      chmod 0755, testpath/"test_include.sh"

      # Run the test script
      assert_match "Hello from include function", shell_output("#{testpath}/test_include.sh")
    end

    # Test 5: Test loading configuration
    ENV["RCFORGE_ROOT"] = testpath
    ENV["RCFORGE_SCRIPTS"] = "#{testpath}/scripts"

    # Create a test script that sources rcforge
    (testpath/"test_config.sh").write <<~EOS
      #!/bin/bash
      source #{bin}/rcforge
      echo "TEST_RESULT=$TEST_VARIABLE"
    EOS
    chmod 0755, testpath/"test_config.sh"

    # Run the test script and check the output
    assert_match "TEST_RESULT=Hello, World!", shell_output("#{testpath}/test_config.sh")
  end
end
# EOF

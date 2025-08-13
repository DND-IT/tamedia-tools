class TamediaTools < Formula
  desc "Complete suite of AWS and Kubernetes productivity tools - Tamedia Edition"
  homepage "https://github.com/dnd-it/tamedia-tools"
  url "https://github.com/dnd-it/tamedia-tools/archive/v1.0.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  version "1.0.0"
  
  depends_on "awscli"
  depends_on "jq"
  depends_on "kubernetes-cli"
  depends_on "fzf" => :recommended
  
  def install
    # Install all tools
    bin.install "tools/tunnel/tunnel.sh" => "tamedia-tunnel"
    
    # Install shared utilities
    bin.install "scripts/common.sh" => "tamedia-common"
    
    # Install completion scripts
    bash_completion.install "completion/tamedia-tunnel.bash" => "tamedia-tunnel"
    zsh_completion.install "completion/_tamedia-tunnel"
  end
  
  def caveats
    <<~EOS
      Tamedia Tools have been installed with the following commands:
        tamedia-tunnel    - Tunnel to AWS services through Kubernetes
      
      Run any command with --help for usage information.
      
      Documentation: https://github.com/dnd-it/tamedia-tools
    EOS
  end
  
  test do
    system "#{bin}/tamedia-tunnel", "--version"
  end
end
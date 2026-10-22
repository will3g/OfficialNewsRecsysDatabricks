#!/bin/sh
# Verifica as ferramentas do projeto e mostra como instalar o que faltar.
# Funciona em macOS, Linux e Windows (via WSL2). POSIX sh - não precisa de bash.
#
# Uso: sh scripts/doctor.sh [ferramenta-opcional ...]
#   ex.: sh scripts/doctor.sh gh

REQUIRED="python3 make curl unzip git databricks jq terraform"
OPTIONAL="$*"

# --- Sistema operacional -----------------------------------------------------------
case "$(uname -s)" in
  Darwin) OS="mac" ;;
  Linux)
    if grep -qi microsoft /proc/version 2>/dev/null; then OS="wsl"; else OS="linux"; fi ;;
  MINGW*|MSYS*|CYGWIN*) OS="windows-nativo" ;;
  *) OS="desconhecido" ;;
esac

hint() {
  # $1 = ferramenta → instrução de instalação para o SO atual
  case "$1:$OS" in
    python3:mac) echo "brew install python@3.12" ;;
    python3:*) echo "sudo apt install -y python3 python3-venv   (Ubuntu 24.04 já traz 3.12)" ;;
    make:mac) echo "xcode-select --install" ;;
    make:*) echo "sudo apt install -y make" ;;
    curl:mac|unzip:mac|git:mac) echo "xcode-select --install" ;;
    curl:*|unzip:*|git:*|jq:linux|jq:wsl) echo "sudo apt install -y $1" ;;
    jq:mac) echo "brew install jq" ;;
    databricks:*) echo "make db-install   (script oficial: https://github.com/databricks/setup-cli)" ;;
    terraform:mac) echo "brew tap hashicorp/tap && brew install hashicorp/tap/terraform" ;;
    terraform:*) echo "https://developer.hashicorp.com/terraform/install#linux (repositório apt da HashiCorp)" ;;
    gh:mac) echo "brew install gh" ;;
    gh:*) echo "https://github.com/cli/cli/blob/trunk/docs/install_linux.md" ;;
    *) echo "veja a documentação da ferramenta" ;;
  esac
}

version_of() {
  case "$1" in
    python3) python3 -c 'import sys; print(sys.version.split()[0])' 2>/dev/null ;;
    databricks) databricks --version 2>/dev/null | head -1 ;;
    terraform) terraform -version 2>/dev/null | head -1 ;;
    make) make --version 2>/dev/null | head -1 ;;
    unzip) unzip -v 2>/dev/null | head -1 | cut -d' ' -f1-2 ;;
    curl) curl --version 2>/dev/null | head -1 | cut -d' ' -f1-2 ;;
    *) "$1" --version 2>/dev/null | head -1 | cut -c1-40 ;;
  esac
}

echo "Sistema: $OS"
if [ "$OS" = "windows-nativo" ]; then
  echo "AVISO: use o WSL2 (Ubuntu). No PowerShell como administrador: wsl --install -d Ubuntu-24.04"
  echo "       Depois rode este comando de novo DENTRO do Ubuntu (WSL)."
fi
echo

missing=0
check() {
  # $1 = ferramenta, $2 = obrigatória|opcional
  if command -v "$1" >/dev/null 2>&1; then
    printf "  [ok]    %-11s %s\n" "$1" "$(version_of "$1")"
  else
    printf "  [falta] %-11s (%s) -> %s\n" "$1" "$2" "$(hint "$1")"
    [ "$2" = "obrigatória" ] && missing=$((missing + 1))
  fi
}

echo "Obrigatórias:"
for t in $REQUIRED; do check "$t" "obrigatória"; done
if [ -n "$OPTIONAL" ]; then
  echo "Opcionais (usadas por alguns targets do Makefile):"
  for t in $OPTIONAL; do check "$t" "opcional"; done
fi

# Python precisa ser 3.12+
if command -v python3 >/dev/null 2>&1 && ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 12))' 2>/dev/null; then
  if ! command -v python3.12 >/dev/null 2>&1; then
    echo
    echo "  [falta] python 3.12+ (encontrado $(version_of python3)) -> $(hint python3)"
    missing=$((missing + 1))
  fi
fi

echo
if [ "$missing" -eq 0 ]; then
  echo "Tudo certo para começar: make install"
else
  echo "$missing ferramenta(s) obrigatória(s) faltando."
  exit 1
fi

#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="${REPO_URL:-https://github.com/fabriciofirmino/evolution-go-custom.git}"
EVO_BRANCH="${EVO_BRANCH:-main}"
INSTALL_DIR="${INSTALL_DIR:-/opt/evolution-go}"

die() {
  printf 'ERRO: %s\n' "$*" >&2
  exit 1
}

if [ "$(id -u)" -ne 0 ]; then
  die "Execute como root ou usando sudo."
fi

command -v git >/dev/null 2>&1 || {
  apt-get update -qq
  apt-get install -y -qq git ca-certificates curl
}

if [ -d "${INSTALL_DIR}/.git" ]; then
  echo "Atualizando checkout existente em ${INSTALL_DIR}..."
  git -C "${INSTALL_DIR}" remote set-url origin "${REPO_URL}"
  git -C "${INSTALL_DIR}" fetch --depth 1 origin "${EVO_BRANCH}"
  git -C "${INSTALL_DIR}" checkout -B "${EVO_BRANCH}" "origin/${EVO_BRANCH}"
  git -C "${INSTALL_DIR}" reset --hard "origin/${EVO_BRANCH}"
elif [ -e "${INSTALL_DIR}" ]; then
  BACKUP_DIR="${INSTALL_DIR}.backup.$(date +%Y%m%d%H%M%S)"
  echo "A pasta existente não é um checkout Git; movendo para ${BACKUP_DIR}..."
  mv "${INSTALL_DIR}" "${BACKUP_DIR}"
  git clone --depth 1 --branch "${EVO_BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
else
  mkdir -p "$(dirname "${INSTALL_DIR}")"
  git clone --depth 1 --branch "${EVO_BRANCH}" "${REPO_URL}" "${INSTALL_DIR}"
fi

echo "Remoto em uso: $(git -C "${INSTALL_DIR}" remote get-url origin)"
echo "Commit em uso: $(git -C "${INSTALL_DIR}" rev-parse HEAD)"

echo "Validando Dockerfile corrigido..."
grep -q 'UPSTREAM_COMMIT=9337afc47e10b86cc896a6f432240e40fee95dd1' "${INSTALL_DIR}/Dockerfile" \
  || die "O Dockerfile atualizado não foi obtido do fork."

export REPO_URL EVO_BRANCH INSTALL_DIR
exec bash "${INSTALL_DIR}/install.sh"

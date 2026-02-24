#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGLIST_FILE="${REPO_DIR}/pkglist.txt"

log() {
  printf '[*] %s\n' "$*" >&2
}

warn() {
  printf '[!] %s\n' "$*" >&2
}

die() {
  printf '[x] %s\n' "$*" >&2
  exit 1
}

require_arch() {
  if ! grep -qi "ID=arch" /etc/os-release 2>/dev/null && ! grep -qi "Arch Linux" /etc/os-release 2>/dev/null; then
    die "Этот скрипт рассчитан только на Arch Linux."
  fi
}

require_tools() {
  command -v pacman >/dev/null 2>&1 || die "pacman не найден. Вы уверены, что это Arch?"
  if ! command -v sudo >/dev/null 2>&1 && [[ "${EUID:-0}" -ne 0 ]]; then
    die "Нужен sudo или запуск от root."
  fi
}

run_with_sudo() {
  if [[ "${EUID:-0}" -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

update_system() {
  log "Обновляю систему (pacman -Syu)..."
  run_with_sudo pacman -Syu --noconfirm
}

have_yay() {
  command -v yay >/dev/null 2>&1
}

ensure_yay() {
  if have_yay; then
    return 0
  fi

  log "yay не найден, пробую установить."

  # Попытка через официальные репы (вдруг у пользователя есть доп. репозитории)
  if run_with_sudo pacman -S --needed --noconfirm yay 2>/dev/null; then
    log "yay установлен через pacman."
    return 0
  fi

  log "Устанавливаю зависимости для сборки AUR-пакетов (git base-devel)..."
  run_with_sudo pacman -S --needed --noconfirm git base-devel

  local tmpdir
  tmpdir="$(mktemp -d)"
  log "Собираю yay из AUR во временной директории: ${tmpdir}"

  (
    cd "$tmpdir"
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
  ) || {
    warn "Не удалось собрать/установить yay из AUR."
    return 1
  }

  if have_yay; then
    log "yay успешно установлен."
    return 0
  else
    warn "yay по-прежнему не найден после установки."
    return 1
  fi
}

install_pkg() {
  local pkg="$1"

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    log "Пакет уже установлен: ${pkg}"
    return 0
  fi

  log "Устанавливаю пакет через pacman: ${pkg}"
  if run_with_sudo pacman -S --needed --noconfirm "$pkg"; then
    return 0
  fi

  # Не используем yay для установки самого yay/yay-debug, чтобы избежать рекурсии.
  if [[ "$pkg" != "yay" && "$pkg" != "yay-debug" ]]; then
    ensure_yay || warn "Не удалось подготовить yay, продолжаю без AUR для пакета: ${pkg}"
    if have_yay; then
      log "Пробую установить пакет через yay (возможно AUR): ${pkg}"
      if yay -S --needed --noconfirm "$pkg"; then
        return 0
      fi
    fi
  fi

  warn "Не удалось установить пакет: ${pkg}"
  return 1
}

install_pkglist() {
  [[ -f "$PKGLIST_FILE" ]] || die "Не найден файл с пакетами: ${PKGLIST_FILE}"

  log "Начинаю установку пакетов из ${PKGLIST_FILE}..."
  while IFS= read -r pkg; do
    # пропуск пустых строк и комментариев
    [[ -z "$pkg" ]] && continue
    [[ "$pkg" =~ ^# ]] && continue
    install_pkg "$pkg"
  done < "$PKGLIST_FILE"
}

enable_services() {
  # Список типовых сервисов, которые логично включить для этой конфигурации.
  # Если какого‑то сервиса нет в системе, просто пропускаем.
  local services=(
    NetworkManager.service
    bluetooth.service
    sddm.service
    power-profiles-daemon.service
    nftables.service
  )

  for svc in "${services[@]}"; do
    if systemctl list-unit-files | grep -q "^${svc}"; then
      log "Включаю и запускаю сервис: ${svc}"
      run_with_sudo systemctl enable --now "$svc" || warn "Не удалось включить сервис: ${svc}"
    else
      warn "Сервис не найден (пропускаю): ${svc}"
    fi
  done
}

stow_dotfiles() {
  if ! command -v stow >/dev/null 2>&1; then
    warn "GNU stow не установлен. Пропускаю линковку dotfiles."
    return 0
  fi

  log "Линкую dotfiles через stow..."
  cd "$REPO_DIR"

  local pkgs=()

  # Добавляй сюда новые модули по мере необходимости.
  [[ -d ".config" ]] && pkgs+=(".config")

  if ((${#pkgs[@]} == 0)); then
    warn "Не найдено ни одного каталога для stow. Пропускаю."
    return 0
  fi

  # Целью является $HOME, чтобы получить, например, ~/.config/...
  stow -v -t "$HOME" "${pkgs[@]}"
}

main() {
  require_arch()
  require_tools()

  log "Запуск install-скрипта для Arch Linux dotfiles."
  log "Репозиторий: ${REPO_DIR}"

  update_system
  install_pkglist
  enable_services
  stow_dotfiles

  log "Готово. Перезагрузите систему после первой установки."
}

main "$@"


#!/usr/bin/env bash
# shellcheck disable=SC2154  # colors and $os_id/$os_id_raw provided by source_installers.sh

# Source installers + shared helpers (colors, detect_os, install_* functions).
_sourcer="$(dirname "${BASH_SOURCE[0]}")/installers/source_installers.sh"
if [[ ! -f "$_sourcer" ]]; then
	echo "Installers source file not found: $_sourcer" >&2
	exit 1
fi
# shellcheck source=installers/source_installers.sh disable=SC1091
source "$_sourcer"
unset _sourcer

# Track failed installations for summary
declare -a failed_deps=()
declare -a failed_installers=()

# Helper functions for consistent messaging
print_error() {
	echo "${red}[ERROR]${reset} $1"
}

print_warning() {
	echo "${yellow}[WARNING]${reset} $1"
}

print_success() {
	echo "${green}[OK]${reset} $1"
}

print_info() {
	echo ":: $1"
}

# $os_id populated by detect_os in source_installers.sh (normalised archarm->arch)
if [[ -z "$os_id" ]]; then
	print_error "Cannot detect OS"
	exit 1
fi

declare -a required_deps=(
	"ca-certificates"
	"clang"
	"cmake"
	"curl"
	"git"
	"gnupg"
	"grep"
	"tar"
	"unzip"
	"wget"
	"zip"
	"zsh"
)

declare -a deps=(
	"bat"
	"bc"
	"btop"
	"eza"
	"ffmpeg"
	"fzf"
	"gh"
	"htop"
	"imagemagick"
	"iperf3"
	"iptables"
	"jq"
	"mediainfo"
	"mosh"
	"nmap"
	"pass"
	"rsync"
	"shellcheck"
	"sshpass"
	"tmux"
	"xclip"
	"xdg-utils"
)

# Add OS-specific packages
if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
	required_deps+=(
		"build-essential"
		"g++"
		"gcc"
		"gpg"
		"libssl-dev"
		"locales"
		"make"
		"pkg-config"
	)
	deps+=(
		"7zip"
		"apt-transport-https"
		"dnsutils"
		"fd-find"
		"libnotify4"
		"libxml2-utils"
		"linux-perf"
		"poppler-utils"
		"python3"
		"python3-venv"
		"ssh"
	)
elif [[ "$os_id" == "arch" ]]; then
	required_deps+=(
		"base-devel" # includes gcc, g++, make, etc.
		"openssl"    # libssl-dev equivalent
		"pkgconf"
	)
	deps+=(
		"bind"       # for dig, nslookup (dnsutils)
		"bottom"
		"dust"
		"fd"
		"libnotify"
		"libxml2"
		"openssh"
		"p7zip"
		"perf"
		"poppler"
		"procs"
		"python"
		"python-virtualenv"
		"spotify"
		"visual-studio-code-bin"
		"xh"
	)
else
	print_error "Unsupported OS: $os_id"
	exit 1
fi

# The Docker integration suite runs the real public easy-install pipeline on
# clean distributions. Keep that profile focused on portable command-line
# prerequisites: GUI applications, system services, language SDKs, and AUR
# packages cannot be meaningfully exercised in a container. Normal installs
# continue to use the complete dependency and installer lists above.
if [[ "${DOTFILES_INTEGRATION_TEST:-0}" == "1" ]]; then
	required_deps=(
		"ca-certificates"
		"curl"
		"git"
		"grep"
		"tar"
		"unzip"
		"wget"
		"zsh"
	)
	if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
		required_deps+=("locales")
	fi
	deps=("mosh" "tmux")
fi

install_paru() {
	echo
	print_info "Installing ${yellow}paru${reset}..."

	if ! sudo pacman -S --noconfirm --needed base-devel git bat; then
		print_error "Failed to install paru dependencies"
		return 1
	fi

	SCRIPT=$(realpath "$0")
	original_dir=$(dirname "$SCRIPT")

	# Clean up any previous failed attempt
	rm -rf /tmp/paru

	if ! git clone https://aur.archlinux.org/paru.git /tmp/paru; then
		print_error "Failed to clone paru repository"
		return 1
	fi

	cd /tmp/paru || return 1

	if ! makepkg -si --noconfirm; then
		print_error "Failed to build/install paru"
		cd "$original_dir" || return 1
		return 1
	fi

	cd "$original_dir" || return 1
	print_success "${yellow}paru${reset} has been installed successfully"
	echo
}

set_parallel_downloads() {
	local value="$1"
	local conf="/etc/pacman.conf"

	if [[ ! -f "$conf" ]]; then
		print_warning "pacman.conf not found, skipping parallel downloads configuration"
		return 1
	fi

	# Check if the line already exists (commented or uncommented)
	if grep -qE "^\s*#?\s*ParallelDownloads\s*=" "$conf"; then
		# Replace existing line
		sudo sed -i "s|^\s*#\?\s*ParallelDownloads\s*=.*|ParallelDownloads = $value|" "$conf"
	else
		# Add under the [options] section
		sudo sed -i "/^\[options\]/a ParallelDownloads = $value" "$conf"
	fi
}

# Update package list based on OS
if [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
	print_info "Updating apt package list..."
	if ! sudo apt update; then
		print_warning "apt update failed, some packages may not install correctly"
	fi
elif [[ "$os_id" == "arch" ]]; then
	if [[ "${DOTFILES_INTEGRATION_TEST:-0}" == "1" ]]; then
		print_info "Refreshing Arch package databases for integration testing..."
		sudo pacman --disable-sandbox -Sy --noconfirm
	else
		set_parallel_downloads 8 # default is 5, probably won't make much of a difference

		print_info "Updating system packages..."
		if ! sudo pacman -Syu --noconfirm; then
			print_warning "System update failed, continuing anyway..."
		fi

		# Mirror optimization: reflector on x86 Arch, rankmirrors on Arch ARM.
		# reflector fetches the x86 Arch mirror list and doesn't exist on archarm;
		# rankmirrors (from pacman-contrib) is the generic ARM-compatible alternative.
		if [[ "$os_id_raw" == "archarm" ]]; then
			if ! sudo pacman -S --noconfirm --needed pacman-contrib; then
				print_warning "Failed to install pacman-contrib, skipping mirror optimization"
			else
				print_info "Finding the ${green}fastest mirrors${reset} (rankmirrors)..."
				sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
				sed 's/^#Server/Server/' /etc/pacman.d/mirrorlist.bak >/tmp/mirrorlist.all
				if rankmirrors -n 6 /tmp/mirrorlist.all >/tmp/mirrorlist.ranked 2>/dev/null; then
					sudo cp /tmp/mirrorlist.ranked /etc/pacman.d/mirrorlist
					print_success "Fastest mirrors found!"
				else
					print_warning "Mirror optimization failed, using existing mirrors"
				fi
			fi
		else
			if ! sudo pacman -S --noconfirm --needed reflector; then
				print_warning "Failed to install reflector, skipping mirror optimization"
			else
				print_info "Finding the ${green}fastest mirrors${reset} (reflector)..."
				if sudo reflector --threads 8 --latest 100 -n 10 --connection-timeout 1 --download-timeout 1 --sort rate --save /etc/pacman.d/mirrorlist >/dev/null 2>&1; then
					cat /etc/pacman.d/mirrorlist
					print_success "Fastest mirrors found!"
				else
					print_warning "Mirror optimization failed, using existing mirrors"
				fi
			fi
		fi

		if ! command -v paru &>/dev/null; then
			if ! install_paru; then
				print_error "paru installation failed - cannot install Arch dependencies"
				exit 1
			fi
		fi
	fi
fi

# Function to check if a package is installed using the package manager
is_installed() {
	local pkg="$1"

	if [[ "$os_id" == "arch" ]]; then
		pacman -Qi "$pkg" &>/dev/null
	elif [[ "$os_id" == "ubuntu" || "$os_id" == "debian" ]]; then
		dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
	else
		# Fallback to command check
		command -v "$pkg" >/dev/null 2>&1
	fi
}

# Associative array to store error messages for failed packages
declare -A failed_errors

# Install a single package using the detected package manager.
# Retries up to 3 times with increasing delay (2s, 4s) to absorb transient
# failures like stale-mirror hits or mid-download network drops — the most
# common reason one package out of many fails.
install_single_dep() {
	local pkg="$1"
	local attempt error_output exit_code=0

	for attempt in 1 2 3; do
		if [[ "$os_id" == "arch" && "${DOTFILES_INTEGRATION_TEST:-0}" == "1" ]]; then
			error_output=$(sudo pacman --disable-sandbox -S --noconfirm --needed "$pkg" 2>&1)
			exit_code=$?
		elif command -v paru >/dev/null 2>&1; then
			error_output=$(paru -S --noconfirm --needed "$pkg" 2>&1)
			exit_code=$?
		elif command -v apt >/dev/null 2>&1; then
			error_output=$(sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg" 2>&1)
			exit_code=$?
		elif command -v dnf >/dev/null 2>&1; then
			error_output=$(sudo dnf install -y "$pkg" 2>&1)
			exit_code=$?
		elif command -v yum >/dev/null 2>&1; then
			error_output=$(sudo yum install -y "$pkg" 2>&1)
			exit_code=$?
		else
			print_error "No supported package manager found"
			return 1
		fi

		if [[ $exit_code -eq 0 ]]; then
			return 0
		fi

		if [[ $attempt -lt 3 ]]; then
			sleep $((attempt * 2))
		fi
	done

	# All attempts failed — record the best error line for the summary.
	local error_line
	error_line=$(echo "$error_output" | grep -iE "^(E:|error:)" | head -1)
	if [[ -z "$error_line" ]]; then
		error_line=$(echo "$error_output" | grep -v '^$' | tail -1)
	fi
	failed_errors["$pkg"]="$error_line"
	return 1
}

# Iterate over dependencies and install missing ones
install_missing_deps() {
	local phase="$1"
	shift
	local installed_count=0
	local failed_count=0
	local skipped_count=0

	print_info "Installing $phase..."
	echo

	for dep in "$@"; do
		if is_installed "$dep"; then
			echo "  ${green}✓${reset} ${yellow}$dep${reset} already installed"
			((skipped_count++))
		else
			echo -n "  ${yellow}○${reset} Installing ${yellow}$dep${reset}... "
			if install_single_dep "$dep"; then
				echo "${green}done${reset}"
				((installed_count++))
			else
				echo "${red}failed${reset}"
				failed_deps+=("$dep")
				((failed_count++))
			fi
		fi
	done

	echo
	# Build summary string, only including non-zero counts
	local summary_parts=()
	[[ $installed_count -gt 0 ]] && summary_parts+=("${green}$installed_count installed${reset}")
	[[ $skipped_count -gt 0 ]] && summary_parts+=("${yellow}$skipped_count skipped${reset}")
	[[ $failed_count -gt 0 ]] && summary_parts+=("${red}$failed_count failed${reset}")

	if [[ ${#summary_parts[@]} -gt 0 ]]; then
		local IFS=', '
		print_info "Dependencies summary: ${summary_parts[*]}"
	fi

	# Print error details for failed packages
	if [[ ${#failed_deps[@]} -gt 0 ]]; then
		echo
		print_error "Failed installations:"
		for pkg in "${failed_deps[@]}"; do
			echo "  ${red}✗${reset} ${yellow}$pkg${reset}: ${failed_errors[$pkg]:-unknown error}"
		done
	fi

	[[ $failed_count -eq 0 ]]
}

if ! install_missing_deps "required setup dependencies" "${required_deps[@]}"; then
	print_error "Required setup dependencies failed; skipping downstream installers"
	exit 1
fi

install_missing_deps "remaining dependencies" "${deps[@]}" || true
echo

# Application installers have a small dependency graph. Keep it explicit so a
# failed prerequisite prevents noisy or misleading downstream install attempts.
declare -A installer_status=()
declare -A installer_dependencies=(
	["node_deps"]="node"
	["sdkman_deps"]="sdkman"
	["rust_deps"]="rust"
	["yazi"]="rust rust_deps"
)
declare -a skipped_installers=()

validate_installer_order() {
	local name dependency
	local -a dependencies=()
	local -A seen=()

	for name in "$@"; do
		dependencies=()
		read -r -a dependencies <<< "${installer_dependencies[$name]:-}"
		for dependency in "${dependencies[@]}"; do
			if [[ "${seen[$dependency]:-0}" != "1" ]]; then
				print_error "Installer order is invalid: $name must run after $dependency"
				return 1
			fi
		done
		seen["$name"]=1
	done
}

# Helper function to run an installer with dependency and failure tracking.
run_installer() {
	local name="$1"
	local func="install_$name"
	local dependency
	local -a dependencies=()
	read -r -a dependencies <<< "${installer_dependencies[$name]:-}"

	for dependency in "${dependencies[@]}"; do
		if [[ "${installer_status[$dependency]:-missing}" != "succeeded" ]]; then
			print_warning "Skipping $name because prerequisite $dependency did not succeed"
			installer_status["$name"]="skipped"
			skipped_installers+=("$name (requires $dependency)")
			return 1
		fi
	done

	if ! declare -f "$func" >/dev/null 2>&1; then
		print_error "Installer function '$func' not found"
		installer_status["$name"]="failed"
		failed_installers+=("$name")
		return 1
	fi

	if ! "$func"; then
		print_error "Failed to install $name"
		installer_status["$name"]="failed"
		failed_installers+=("$name")
		return 1
	fi
	installer_status["$name"]="succeeded"
	return 0
}

# Run all installers
print_info "Running application installers..."
echo

declare -a installers=(
	"bitwarden"
	"bun"
	"chrome"
	"code"
	"discord"
	"docker"
	"herdr"
	"kitty"
	"lazydocker"
	"lazygit"
	"neovim"
	"node"
	"node_deps"
	"sdkman"
	"sdkman_deps"
	"rust"
	"rust_deps"
	"yazi"
	"zerotier"
)

validate_installer_order "${installers[@]}" || exit 1

if [[ "${DOTFILES_INTEGRATION_TEST:-0}" == "1" ]]; then
	print_info "Skipping GUI, service, language SDK, and AUR installers in the container profile"
	installers=()
fi

for installer in "${installers[@]}"; do
	run_installer "$installer"
done

# Print final summary
echo
echo "=============================================="
print_info "Installation Summary"
echo "=============================================="

if [[ ${#failed_deps[@]} -eq 0 && ${#failed_installers[@]} -eq 0 && ${#skipped_installers[@]} -eq 0 ]]; then
	print_success "All installations completed successfully!"
else
	if [[ ${#failed_deps[@]} -gt 0 ]]; then
		echo
		print_error "Failed dependencies (${#failed_deps[@]}):"
		for dep in "${failed_deps[@]}"; do
			echo "  ${red}✗${reset} ${yellow}$dep${reset}: ${failed_errors[$dep]:-unknown error}"
		done
	fi

	if [[ ${#failed_installers[@]} -gt 0 ]]; then
		echo
		print_error "Failed installers (${#failed_installers[@]}):"
		for installer in "${failed_installers[@]}"; do
			echo "  ${red}✗${reset} $installer"
		done
	fi

	if [[ ${#skipped_installers[@]} -gt 0 ]]; then
		echo
		print_error "Skipped installers (${#skipped_installers[@]}):"
		for installer in "${skipped_installers[@]}"; do
			echo "  ${red}✗${reset} $installer"
		done
	fi

	echo
	print_warning "Some installations failed. You may need to install them manually."
	exit 1
fi

echo

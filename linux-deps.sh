#!/usr/bin/env bash

# Color setup with fallback for non-interactive terminals
if tput setaf 1 &>/dev/null; then
	red=$(tput setaf 1)
	green=$(tput setaf 2)
	yellow=$(tput setaf 3)
	reset=$(tput sgr0)
else
	red=""
	green=""
	yellow=""
	reset=""
fi

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

# Detect OS with error handling
if [[ ! -f /etc/os-release ]]; then
	print_error "Cannot detect OS: /etc/os-release not found"
	exit 1
fi

os=$(grep -w ID /etc/os-release 2>/dev/null | cut -d '=' -f 2 | tr -d '"')
if [[ -z "$os" ]]; then
	print_error "Cannot detect OS: Failed to parse /etc/os-release"
	exit 1
fi

declare -a deps=(
	"bat"
	"bc"
	"btop"
	"ca-certificates"
	"clang"
	"cmake"
	"curl"
	"eza"
	"ffmpeg"
	"fzf"
	"git"
	"gnupg"
	"grep"
	"htop"
	"imagemagick"
	"iperf3"
	"iptables"
	"jq"
	"mediainfo"
	"nmap"
	"pass"
	"rsync"
	"shellcheck"
	"sshpass"
	"tar"
	"tmux"
	"unzip"
	"wget"
	"xclip"
	"xdg-utils"
	"zip"
	"zsh"
)

# Add OS-specific packages
if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
	deps+=(
		"7zip"
		"apt-transport-https"
		"build-essential"
		"dnsutils"
		"fd-find"
		"g++"
		"gcc"
		"gpg"
		"libnotify4"
		"libssl-dev"
		"linux-perf"
		"make"
		"pkg-config"
		"poppler-utils"
		"python3"
		"python3-venv"
		"ssh"
	)
elif [[ "$os" == "arch" ]]; then
	deps+=(
		"base-devel" # includes gcc, g++, make, etc.
		"bind"       # for dig, nslookup (dnsutils)
		"fd"
		"libnotify"
		"openssh"
		"openssl" # libssl-dev equivalent
		"p7zip"
		"perf"
		"pkgconf"
		"poppler"
		"python"
		"python-virtualenv"
		"spotify"
		"visual-studio-code-bin"
	)
else
	print_error "Unsupported OS: $os"
	exit 1
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
		cd "$original_dir"
		return 1
	fi

	cd "$original_dir"
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
if [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
	print_info "Updating apt package list..."
	if ! sudo apt update; then
		print_warning "apt update failed, some packages may not install correctly"
	fi
elif [[ "$os" == "arch" ]]; then
	set_parallel_downloads 8 # default is 5, probably won't make much of a difference

	print_info "Updating system packages..."
	if ! sudo pacman -Syu --noconfirm; then
		print_warning "System update failed, continuing anyway..."
	fi

	if ! sudo pacman -S --noconfirm --needed reflector; then
		print_warning "Failed to install reflector, skipping mirror optimization"
	else
		print_info "Finding the ${green}fastest mirrors${reset}, this might take a while..."
		if sudo reflector --threads 8 --latest 100 -n 10 --connection-timeout 1 --download-timeout 1 --sort rate --save /etc/pacman.d/mirrorlist >/dev/null 2>&1; then
			cat /etc/pacman.d/mirrorlist
			print_success "Fastest mirrors found!"
		else
			print_warning "Mirror optimization failed, using existing mirrors"
		fi
	fi

	if ! command -v paru &>/dev/null; then
		if ! install_paru; then
			print_error "paru installation failed - AUR packages will not be available"
		fi
	fi
fi

# Function to check if a package is installed using the package manager
is_installed() {
	local pkg="$1"

	if [[ "$os" == "arch" ]]; then
		pacman -Qi "$pkg" &>/dev/null
	elif [[ "$os" == "ubuntu" || "$os" == "debian" ]]; then
		dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"
	else
		# Fallback to command check
		command -v "$pkg" >/dev/null 2>&1
	fi
}

# Associative array to store error messages for failed packages
declare -A failed_errors

# Function to install a single package using the appropriate package manager
install_single_dep() {
	local pkg="$1"
	local error_output
	local exit_code

	if command -v paru >/dev/null 2>&1; then
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

	if [[ $exit_code -ne 0 ]]; then
		# Extract the most relevant error line
		local error_line
		error_line=$(echo "$error_output" | grep -iE "^(E:|error:)" | head -1)
		if [[ -z "$error_line" ]]; then
			# Fallback to last non-empty line
			error_line=$(echo "$error_output" | grep -v '^$' | tail -1)
		fi
		failed_errors["$pkg"]="$error_line"
		return 1
	fi
	return 0
}

# Iterate over dependencies and install missing ones
install_missing_deps() {
	local installed_count=0
	local failed_count=0
	local skipped_count=0

	print_info "Installing base dependencies..."
	echo

	for dep in "${deps[@]}"; do
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
}

install_missing_deps
echo

# Source all installer scripts
SCRIPT_DIR="$(dirname "$0")"
if [[ -f "$SCRIPT_DIR/installers/source_installers.sh" ]]; then
	source "$SCRIPT_DIR/installers/source_installers.sh"
else
	print_error "Installers source file not found: $SCRIPT_DIR/installers/source_installers.sh"
	exit 1
fi

# Helper function to run an installer with tracking
run_installer() {
	local name="$1"
	local func="install_$name"

	if ! declare -f "$func" >/dev/null 2>&1; then
		print_warning "Installer function '$func' not found, skipping"
		return 0
	fi

	if ! "$func"; then
		print_error "Failed to install $name"
		failed_installers+=("$name")
		return 1
	fi
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
	"zerotier"
)

for installer in "${installers[@]}"; do
	run_installer "$installer"
done

# Print final summary
echo
echo "=============================================="
print_info "Installation Summary"
echo "=============================================="

if [[ ${#failed_deps[@]} -eq 0 && ${#failed_installers[@]} -eq 0 ]]; then
	print_success "All installations completed successfully!"
else
	if [[ ${#failed_deps[@]} -gt 0 ]]; then
		echo
		print_error "Failed dependencies (${#failed_deps[@]}):"
		for dep in "${failed_deps[@]}"; do
			echo "  ${red}✗${reset} $dep"
		done
	fi

	if [[ ${#failed_installers[@]} -gt 0 ]]; then
		echo
		print_error "Failed installers (${#failed_installers[@]}):"
		for installer in "${failed_installers[@]}"; do
			echo "  ${red}✗${reset} $installer"
		done
	fi

	echo
	print_warning "Some installations failed. You may need to install them manually."
fi

echo

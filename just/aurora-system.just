# vim: set ft=make :
########################
### aurora-system.just
########################
## Standardized verbs
# configure- = configure something that is pre-installed on the image
# install-   = install something, no uninstall or configuration provided
# setup-     = install something and also provide configuration and/or uninstallation options
# toggle-    = turn something on/off, logic can be automatic or manual selection
# fix-       = apply fix/patch/workaround for something
# foo        = no verb is used for shortcuts or something deemed important enough to use a super memorable name

# Run a one minute system benchmark
[group('System')]
benchmark:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    if ! type -P "stress-ng" &>/dev/null ; then
        if gum confirm "Stress does not seem to be on your path, do you wish to install it?" ; then
            set -eu
            brew install stress-ng
            brew link stress-ng
            set +eu
        else
            exit 0
        fi
    fi



# Configure Aurora-CLI Terminal Experience with Brew
[group('System')]
aurora-cli:
    @/usr/libexec/ublue-bling

# Install fonts from brew
[group('System')]
install-fonts:
    #!/usr/bin/bash
    echo "Installing extra fonts..."
    brew bundle --file /usr/share/ublue-os/homebrew/aurora-fonts.Brewfile

# Install Kubernetes CLI dev tools
[group('System')]
install-k8s-dev-tools:
    #!/usr/bin/bash
    echo "Adding Kubernetes command line tools..."
    brew bundle --file /usr/share/ublue-os/homebrew/kubernetes.Brewfile

# alias for toggle-devmode
devmode:
    @ujust toggle-devmode

# Toggle between Aurora and the Developer Experience
[group('System')]
toggle-devmode:
    #!/usr/bin/env bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_IMAGE=$(rpm-ostree status -b --json | jq -r '.deployments[0]."container-image-reference"')
    if grep -q "/var/ublue-os/image" <<< $CURRENT_IMAGE ; then
        bash -c "cat <<EOF
    Before we can switch to the Aurora Developer Experience
    the current system needs an update. Please run 'ujust update'
    and reboot your system when the update is finished
    EOF"
        exit
    fi
    if /bin/grep -q "\-dx" <<< $CURRENT_IMAGE ; then
        CURRENT_STATE="enabled"
    else
        CURRENT_STATE="disabled"
    fi
    echo "Developer mode is currently ${CURRENT_STATE}"
    echo "Enable or Disable developer mode"
    OPTION=$(Choose Enable Disable)
    if [[ "${OPTION,,}" =~ ^enable ]]; then
        if [ "$CURRENT_STATE" = "enabled" ] ; then
            echo "You are already on a developer image"
            exit 0
        fi
        echo "Rebasing to a developer image"
        NEW_IMAGE=$(sed "s/aurora/aurora-dx/" <<< $CURRENT_IMAGE)
        rpm-ostree rebase $NEW_IMAGE
        echo -e "\nUse `ujust dx-group` to add your user to the correct groups and complete the installation"
    fi
    if [[ "${OPTION,,}" =~ ^disable ]]; then
        if [ "$CURRENT_STATE" != "enabled" ]; then
            echo "You are currently not on a developer image"
            exit 0
        fi
        echo "Rebasing to a non developer image"
        # Remove -dx suffix from image, specifies ":" to mark the end of the image name
        NEW_IMAGE=$(sed "s/\-dx//" <<< $CURRENT_IMAGE)
        rpm-ostree rebase $NEW_IMAGE
    fi
    if gum choose "Do you want to also install the default development flatpaks?" ; then
            ujust install-system-flatpaks 1
    fi

# Ptyxis terminal transparency
[group('System')]
ptyxis-transparency opacity="0.95":
    #!/usr/bin/env bash
    set -euxo pipefail
    if [[ -n "$(echo "{{ opacity }}" | grep -v '^[.0-9]*$')" ]]; then
        printf "Value must be numeric: %s.\n" "{{ opacity }}"
    elif [[ $(echo "0<{{ opacity }} && 1>={{ opacity }}" | bc -q) -eq 1 ]]; then
        raw="$(gsettings get org.gnome.Ptyxis profile-uuids)"
        uuids="$(sed -En 's|[^0-9a-z]*||g; s|([0-9a-z]{32})|\1\n|gp' <<<${raw})"
        for i in ${uuids}; do
            location="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${i}/"
            gsettings set "${location}" opacity "{{ opacity }}"; done
        printf "Ptyxis opacity is now %s.\n" "{{ opacity }}"
    else
        printf "Value must be greater than 0 and less than or equal to 1: %s.\n" "{{ opacity }}"
    fi

# Configure docker,incus-admin,libvirt, container manager, serial permissions
[group('System')]
dx-group:
    #!/usr/bin/pkexec bash
    append_group() {
        local group_name="$1"
        if ! grep -q "^$group_name:" /etc/group; then
            echo "Appending $group_name to /etc/group"
            grep "^$group_name:" /usr/lib/group | sudo tee -a /etc/group > /dev/null
        fi
    }

    GROUPS_ADD=("docker" "incus-admin" "libvirt" "dialout")

    for GROUP_ADD in "${GROUPS_ADD[@]}" ; do
        append_group $GROUP_ADD
        usermod -aG $GROUP_ADD $USER
    done

    echo "Reboot system and log back in to use docker, libvirt, incus, and serial connections."

# alias for configure-vfio
[group('System')]
setup-vfio:
    @ujust configure-vfio

# Configure system to use vfio and kvmfr
[group('System')]
configure-vfio ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    CURRENT_IMAGE=$(rpm-ostree status -b --json | jq -r '.deployments[0]."container-image-reference"')
    if grep -q "dx" <<< $CURRENT_IMAGE ; then
        DEVMODE="enabled"
    else
        DEVMODE="disabled"
    fi
    if [ "$DEVMODE" == "disabled" ]; then
        echo "Please run "ujust devmode" first"
        exit 0
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
        bash -c "cat <<EOF
    Usage: ujust configure-vfio <option>
      <option>: Specify the quick option to skip the prompt
      Use 'vfio-on' to select Enable VFIO drivers
      Use 'vfio-off' to select Disable VFIO drivers
      Use 'kvmfr' to enable kvmfr module for looking-glass
    EOF"
        exit 0
    elif [ "$OPTION" == "" ]; then
        bash -c "cat <<EOF
    ${bold}VFIO and kvmfr Configuration${normal}
    This is only used for GPU passthrough of a secondary dGPU.
    It will enable vfio and configure kvmfr for use with $(Urllink "https://looking-glass.io" "Looking Glass").
    If you do not plan to use any of this then press ESC.
    ${bold}NOTE:${normal} Since this is a niche use case, support will be ${b}very limited${n}
    EOF"
        OPTION=$(Choose \
          "Enable VFIO drivers" \
          "Disable VFIO drivers" \
          "Enable kvmfr module" \
        )
    fi
    if [[ "${OPTION,,}" =~ (^enable[[:space:]]vfio|vfio-on) ]]; then
        echo "Enabling VFIO..."
        CPU_VENDOR=$(grep "vendor_id" "/proc/cpuinfo" | uniq | awk -F": " '{ print $2 }')
        VENDOR_KARG="unset"
        if [[ ${CPU_VENDOR} == "AuthenticAMD" ]]; then
            VENDOR_KARG="amd_iommu=on"
        elif [[ ${CPU_VENDOR} == "GenuineIntel" ]]; then
            VENDOR_KARG="intel_iommu=on"
        fi
        if [[ ${VENDOR_KARG} == "unset" ]]; then
            echo "Failed to get CPU vendor, exiting..."
            exit 1
        else
            rpm-ostree kargs \
                --append-if-missing="${VENDOR_KARG}" \
                --append-if-missing="iommu=pt" \
                --append-if-missing="rd.driver.pre=vfio_pci" \
                --append-if-missing="vfio_pci.disable_vga=1" \
                --append-if-missing="kvm.ignore_msrs=1" \
                --append-if-missing="kvm.report_ignored_msrs=0"
            if sudo test ! -f "/etc/libvirt/hooks/qemu"; then
                echo "Adding libvirt qemu hooks"
                sudo wget 'https://raw.githubusercontent.com/PassthroughPOST/VFIO-Tools/master/libvirt_hooks/qemu' -O /etc/libvirt/hooks/qemu
                sudo chmod +x /etc/libvirt/hooks/qemu
                sudo grep -A1 -B1 "# Add" /etc/libvirt/hooks/qemu | sed 's/^# //g'
                echo ""
                if sudo test ! -d "/etc/libvirt/hooks/qemu.d"; then
                    sudo mkdir /etc/libvirt/hooks/qemu.d
                fi
            fi
            echo "VFIO will be enabled on next boot, make sure you enable IOMMU, VT-d or AMD-v in your BIOS!"
            echo "Please understand that since this is such a niche use case, support will be very limited!"
            echo "To add your unused/second GPU device ids to the vfio driver by running"
            echo 'rpm-ostree kargs --append-if-missing="vfio-pci.ids=xxxx:yyyy,xxxx:yyzz"'
            echo 'you can find these using "ls-iommu -gr" or "ls-iommu -grr"'
            echo 'for a dedicated gpu there will be at least 1 vga device and 1 audio device.'
            echo "NOTE: The GPU you bound to vfio-pci will not be usable by the host after you do this!"
        fi
    elif [[ "${OPTION,,}" =~ (^disable[[:space:]]vfio|vfio-off) ]]; then
        echo ""
        echo "Make sure you have ${b}disabled autostart of all VMs using VFIO${n} before continuing!"
        CONFIRM=$(Choose Cancel Continue)
        if [ "$CONFIRM" == "Continue" ]; then
            echo "Disabling VFIO..."
            VFIO_IDS="$(rpm-ostree kargs | sed -E 's/.+(vfio_pci.ids=.+\s)/\1/' | awk '{ print $1 }' | grep vfio_pci.ids)"
            VFIO_IDS_KARG=""
            if [ -n "$VFIO_IDS" ]; then
                echo "Found VFIO ids in kargs, adding the below line to removal list"
                echo "$VFIO_IDS"
                VFIO_IDS_KARG="--delete-if-present=\"$VFIO_IDS\""
            fi
            rpm-ostree kargs \
                --delete-if-present="iommu=pt" \
                --delete-if-present="iommu=on" \
                --delete-if-present="amd_iommu=on" \
                --delete-if-present="intel_iommu=on" \
                --delete-if-present="rd.driver.pre=vfio_pci" \
                --delete-if-present="vfio_pci.disable_vga=1" \
                --delete-if-present="vfio_pci.disable_vga=0" \
            $VFIO_IDS_KARG
        fi
    elif [[ "${OPTION,,}" =~ kvmfr ]]; then
        sudo /usr/libexec/aurora-dx-kvmfr-setup
    fi

# Install system flatpaks for rebasers
[group('System')]
install-system-flatpaks $dx="dynamic":
  #!/usr/bin/env bash
  TARGET_FLATPAK_FILE="${TARGET_FLATPAK_FILE:-/etc/ublue-os/system-flatpaks.list}"
  TARGET_DEVMODE_FILE="${TARGET_DEVMODE_FILE:-/etc/ublue-os/system-flatpaks-dx.list}"
  case "$dx" in
      "0"|"1")
          ADD_DEVMODE="$dx"
          ;;
      "dynamic")
          if [[ $(jq '."image-flavor"' /usr/share/ublue-os/image-info.json) =~ dx ]] ; then
              ADD_DEVMODE=1
          fi
          ;;
      *)
          echo "Unsupported option"
          exit 1
          ;;
  esac

  flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo
  # Disable Fedora Flatpak remotes
     for remote in fedora fedora-testing; do
         if flatpak remote-list | grep -q "$remote"; then
             flatpak remote-delete "$remote"
         fi
     done
  xargs flatpak --system -y install --reinstall --or-update < $TARGET_FLATPAK_FILE
  if [ "$ADD_DEVMODE" == "1" ] ; then
      xargs flatpak --system -y install --reinstall --or-update < $TARGET_DEVMODE_FILE
  fi

# Configure grub bootmenu visibility
[group('System')]
configure-grub:
    @/usr/libexec/configure-grub.sh

alias switch-stream := rebase-helper
alias switch-streams := rebase-helper
alias rollback-helper := rebase-helper

# Rebase assistant
[group('System')]
rebase-helper:
    @/usr/bin/ublue-rollback-helper

# Toggle tailscale
[group('System')]
toggle-tailscale:
    #!/bin/bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    source /usr/lib/os-release

    TAILSCALED_STATUS="$(systemctl is-enabled tailscaled || true )"

    if [ "$TAILSCALED_STATUS" == "enabled" ] || [ "$TAILSCALED_STATUS" == "disabled" ]; then
        TAILSCALED="Installed"
    else
        TAILSCALED="Not Found"
        echo "${b}${red}Unable to enable or disable Tailscale.${n}"
        echo "The tailscaled service must be present and either enabled or disabled to run this script."
        echo "tailscaled service status: $TAILSCALED_STATUS"
    fi


    if [ "$TAILSCALED" == "Installed" ]; then
        echo "Enable or disable Tailscale?"
        TS_OPTION=$(Choose Enable Disable)

        if [ "$TS_OPTION" = "Enable" ]; then
            systemctl enable --now tailscaled
            TAILSCALED_STATUS="$(systemctl is-enabled tailscaled || true )"
            if [ "$TAILSCALED_STATUS" == "enabled" ]; then
                echo "${b}${green}Tailscale is enabled.${n}"
                echo "If this is your first time using Tailscale, setup is necessary."
                echo "Refer to Tailscale's documentation at https://tailscale.com/kb/1346/start."
            fi
        elif [ "$TS_OPTION" = "Disable" ]; then
            systemctl disable --now tailscaled
            TAILSCALED_STATUS="$(systemctl is-enabled tailscaled || true )"
            if [ "$TAILSCALED_STATUS" == "disabled" ]; then
                echo "${b}${red}Tailscale is disabled.${n}"
            fi
        fi
    fi

# Automatically download Bluefin's monthly dinosaur wallpapers
[group('System')]
toggle-dinosaurs hemisphere="north":
    #!/bin/bash
    source /usr/lib/ujust/ujust.sh

    if [[ "{{ hemisphere }}" != "north" && "{{ hemisphere }}" != "south" ]]; then
        echo "Error: Invalid hemisphere '{{ hemisphere }}'. Must be 'north' or 'south'."
        exit 1
    fi

    DINOSAUR_STATUS="$(systemctl --user is-enabled bluefin-wallpaper@{{ hemisphere }}.service 2>/dev/null || echo 'disabled')"

    echo "Bluefin dinosaur wallpapers ({{ hemisphere }}ern hemisphere) are currently: $DINOSAUR_STATUS"

    if [ "$DINOSAUR_STATUS" == "enabled" ]; then
        echo "Disable Bluefin dinosaur wallpapers?"
        OPTION=$(Choose Disable Cancel)
        if [ "$OPTION" = "Disable" ]; then
            systemctl --user disable --now bluefin-wallpaper@{{ hemisphere }}.service
            echo "${b}${red}Bluefin dinosaur wallpapers ({{ hemisphere }}ern hemisphere) disabled.${n}"
            echo "Wallpaper files remain in ~/.local/share/wallpapers/Bluefin/"
        fi
    else
        echo "Enable Bluefin dinosaur wallpapers for the {{ hemisphere }}ern hemisphere?"
        OPTION=$(Choose Enable Cancel)
        if [ "$OPTION" = "Enable" ]; then
            mkdir -p ~/.local/share/wallpapers/Bluefin
            systemctl --user enable --now bluefin-wallpaper@{{ hemisphere }}.service

            sleep 1
            if systemctl --user is-active --quiet bluefin-wallpaper@{{ hemisphere }}.service; then
                echo "${b}${green}Bluefin dinosaur wallpapers ({{ hemisphere }}ern hemisphere) enabled!${n}"
                echo "Wallpapers will be downloaded to ~/.local/share/wallpapers/Bluefin/"
                echo "The wallpaper will update automatically each month."
                filename="$HOME/.local/share/wallpapers/Bluefin/{{ hemisphere }}.avif"

                qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                    var allDesktops = desktops();
                    for (var i = 0; i < allDesktops.length; i++) {
                        var d = allDesktops[i];
                        d.wallpaperPlugin = \"com.github.zzag.dynamic\";
                        d.currentConfigGroup = Array(\"Wallpaper\", \"com.github.zzag.dynamic\", \"General\");
                        d.writeConfig(\"Image\", \"file:///${filename}\");
                    }
                "
            else
                echo "${b}${red}Failed to start bluefin-wallpaper service.${n}"
                echo "Check the service status with:"
                echo "  systemctl --user status bluefin-wallpaper@{{ hemisphere }}.service"
            fi
        fi
    fi


# Configure Boot to Windows desktop entry
[group('System')]
configure-boot-to-windows:
    mkdir -p $HOME/.local/share/applications
    cp -r /usr/share/applications/boot-to-windows.desktop $HOME/.local/share/applications
    sed -i 's/Hidden=true/Hidden=false/' $HOME/.local/share/applications/boot-to-windows.desktop

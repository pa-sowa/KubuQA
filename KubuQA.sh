#!/bin/bash

# CONFIGURATION
# -------------

# Define the directory and file names
directory="$HOME/Downloads/KubuntuTestISO"
isoFileName="noble-desktop-amd64.iso"
isoFilePath="$directory/$isoFileName"
vdi_file="$HOME/VirtualBox VMs/TestKubuntuInstall/TestKubuntuInstall.vdi"

# Don't include the protocol http:// || https:// as we need to switch between them
# to enable zsync to be succesful. See:
# https://ubuntuforums.org/showthread.php?t=2494264
isoDownloadURL="cdimages.ubuntu.com/kubuntu/daily-live/current/$isoFileName"

# FUNCTIONS
# ---------

# Function to check and install required tools & dependencies
check_and_install_tool() {
    local tool_name="$1"
    local package_name="$2" # Package name might differ from tool name

    if ! command -v "$tool_name" &> /dev/null; then
        echo "$tool_name could not be found, attempting to install."
        pkexec apt-get install -y "$package_name"
    fi
}

# Function to check for a previous Kubuntu Test VM. If not found, create one.
check_existing_vm(){
    # Run VBoxManage list vms and capture output
    vms_output=$(VBoxManage list vms)
    # Check for "TestKubuntuInstall" Virtual Machine
    vm_id=$(echo "$vms_output" | grep "\"TestKubuntuInstall\"" | awk '{print $2}' | tr -d '{}')
    if [ -n "$vm_id" ]; then
        # Prompt the user with kdialog
        if kdialog --title "VM Exists" --yesno "The 'TestKubuntuInstall' VM exists (ID: $vm_id). Do you want to keep it?"; then
            # User chose to keep the VM
            echo "Keeping 'TestKubuntuInstall' VM."
            return
        else
            # User chose to remove the VM
            VBoxManage unregistervm "$vm_id" --delete
            echo "'TestKubuntuInstall' VM has been removed."
        fi
    fi
    # There was no VM or the user chose to remove it
    VBoxManage createvm --name "TestKubuntuInstall" --register
    echo "A new 'TestKubuntuInstall' VM has been created."
}

# Function to check for existing Virtual Disk Image. If not found, create one.
function check_existing_vdi() {
    # Check if there is already a registered VDI in VirtualBox
    if VBoxManage list hdds | grep --quiet "TestKubuntuInstall"; then
        if kdialog --yesno "Existing Virtual Disk Image (VDI) found. Keep it?"; then
            echo "User chose to keep the existing VDI file."
            return
        else
            echo "Deleting the existing VDI file..."
            VBoxManage closemedium disk --filename "$vdi_file" --delete
        fi
    fi
    echo "No Virtual Disk Image found. Creating a new one..."
    VBoxManage createmedium disk --filename "$vdi_file" --size 12000 --format=VDI
}

# MAIN
# ----

# Ensure required tools are installed
check_and_install_tool kdialog kdialog
check_and_install_tool zsync zsync
check_and_install_tool wget wget
check_and_install_tool VBoxManage virtualbox

# Check whether various components exist. If not or if requested, (re)create them
check_existing_vm
check_existing_vdi

# Ensure the ISO Download directory exists
mkdir -p "$directory"
cd "$directory"

# Check if the ISO file exists, and has already been downloaded
if [ -f "$isoFileName" ]; then
    # Prompt the user to check for updates
    if kdialog --yesno "I found an ISO Test Image, would you like to check for updates?"; then
        # Use zsync to update the ISO
        zsync "http://$isoDownloadURL.zsync"
    fi
else
    # Prompt the user to download the ISO if it doesn't exist
    if kdialog --yesno "No local test ISO image available, should I download one?"; then
        # Download the ISO
        wget "https://$isoDownloadURL"
    else
        exit
    fi
fi

# Prompt the user to launch a test install using VirtualBox
if kdialog --yesno "Launch a Test Install using Virtual Box?"; then
    # Use VirtualBox to launch a VM booting from the ISO image
    VBoxManage createvm --name "TestKubuntuInstall" --register

    # Enable the user to choose which device to boot from
    choice=$(kdialog --menu "Select boot medium" 1 "ISO" 2 "HDD")

    case "$choice" in
        1) VBoxManage modifyvm "TestKubuntuInstall" --memory 2048 --acpi on --boot1 dvd --nic1 nat ;;
        2) VBoxManage modifyvm "TestKubuntuInstall" --memory 2048 --acpi on --boot1 disk --nic1 nat ;;
        *) echo "Invalid choice"; exit 1 ;;
    esac

    VBoxManage storagectl "TestKubuntuInstall" --name "IDE Controller" --add ide
    VBoxManage storageattach "TestKubuntuInstall" --storagectl "IDE Controller" --port 0 --device 0 --type hdd --medium "$vdi_file"

    # Spin it up, we are Go For Launch!!
    VBoxManage startvm "TestKubuntuInstall"
else
    exit
fi

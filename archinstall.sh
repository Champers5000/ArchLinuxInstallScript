hostname=archLinux
#partitioning details
targetdev=/dev/sda
efipartnum=1
swappartnum=2
rootpartnum=3
efisize=300M
swapsize=4G
rootsize=end
#users
username=user1
userpasswd=0000
rootpasswd=0000

set -x

#create partitions
parted -s "$targetdev" mklabel gpt
sgdisk -n "$efipartnum":0:+"$efisize" "$targetdev"
sgdisk -n "$swappartnum":0:+"$swapsize" "$targetdev"
if [ "$rootsize" = end ]; then
sgdisk -n "$rootpartnum":0:0 "$targetdev"
else
sgdisk -n "$rootpartnum":0:+"$rootsize" "$targetdev"
fi
#format partitions
mkfs.fat -F 32 "$targetdev$efipartnum"
mkswap "$targetdev$swappartnum"
mkfs.ext4 "$targetdev$rootpartnum"
#mount partitions
mount "$targetdev$rootpartnum" /mnt
mount --mkdir "$targetdev$efipartnum" /mnt/boot
swapon "$targetdev$swappartnum"

#setup pacman
pacman-key --init
pacman-key --populate archlinux

#setup linux on the root partition
pacman -Sy archlinux-keyring --noconfirm
pacstrap -K /mnt base linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab

#changing over to the root partition
arch-chroot /mnt

ln -sf /usr/share/zoneinfo/America/Chicago /etc/localtime
hwclock --systohc
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8' /etc/locale.gen
echo en_US.UTF-8 UTF-8 >> /etc/locale.gen
echo LANG=en_US.UTF-8 >> /etc/locale.conf
echo "$hostname" > /etc/hostname

#for grub
pacman -Syu sudo vim grub efibootmgr os-prober --noconfirm
mkdir /boot/efi
mount "$targetdev$efipartnum" /boot/efi
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi
grub-mkconfig -o /boot/grub/grub.cfg

#add user and set password
useradd -m "$username"
echo "$username:$userpasswd" | chpasswd
usermod -aG wheel "$username"
#setup sudo
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

#basic utilites
pacman -S base-devel git exfat-utils ntfs-3g udftools openssh --noconfirm

#kde
pacman -S xorg sddm --noconfirm #basics for graphics
pacman -S plasma konsole dolphin ark kate spectacle krunner partitionmanager alsa-utils bluez bluez-utils pipewire-pulse cups print-manager networkmanager gwenview qt5-imageformats --noconfirm #plasma packages
pacman -S firefox vlc latte-dock libreoffice-fresh --noconfirm #applications

systemctl enable NetworkManager
systemctl enable sddm
systemctl enable bluetooth.service
systemctl enable sshd.service
systemctl enable cups.service

sudo su "$username"
#setup yay in user directory
git clone https://aur.archlinux.org/yay.git
cd ~/Downloads
cd yay
makepkg -si
exit

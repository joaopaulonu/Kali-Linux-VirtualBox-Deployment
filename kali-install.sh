#!/bin/bash

# --- VARIAVEIS DE CONFIGURACAO ---
# Você pode ajustar esses valores conforme a sua necessidade.
VM_NAME="Kali.JP"
RAM_SIZE="4096" # 4 GB
CPU_COUNT="2"
DISK_SIZE="32768" # 32 GB
ISO_URL="https://cdimage.kali.org/kali-2024.2/kali-linux-2024.2-installer-amd64.iso"
ISO_FILENAME="kali-linux-installer.iso"
USER_NAME="kali"
USER_PASS="kali"
GUEST_ADDITIONS_ISO="VBoxGuestAdditions.iso"
PRESEED_FILE="preseed.cfg"

# --- FUNCOES DO SCRIPT ---

# Função para verificar dependências
check_dependencies() {
    echo "Verificando dependências..."
    if ! command -v VBoxManage &> /dev/null
    then
        echo "Erro: VirtualBox (VBoxManage) não encontrado. Por favor, instale o VirtualBox."
        exit 1
    fi

    if ! command -v curl &> /dev/null
    then
        echo "Erro: curl não encontrado. Por favor, instale-o (sudo apt install curl)."
        exit 1
    fi
    echo "Dependências verificadas com sucesso!"
}

# Função para baixar a imagem ISO do Kali Linux
download_iso() {
    echo "Baixando a imagem ISO do Kali Linux..."
    if [ -f "$ISO_FILENAME" ]; then
        echo "Arquivo ISO já existe. Pulando o download."
    else
        curl -L -o "$ISO_FILENAME" "$ISO_URL"
        if [ $? -ne 0 ]; then
            echo "Erro ao baixar a ISO. Verifique a URL e sua conexão."
            exit 1
        fi
        echo "Download da ISO concluído com sucesso."
    fi
}

# Função para criar o arquivo preseed
create_preseed_file() {
    echo "Criando o arquivo de preseed para automação da instalação..."
    cat > "$PRESEED_FILE" <<EOL
# Preseed file for Kali Linux automated installation
# Instalação básica
d-i debian-installer/locale string en_US
d-i keyboard-configuration/xkb-keymap select us
d-i netcfg/get_hostname string $VM_NAME
d-i netcfg/get_domain string localdomain

# Particionamento automático
d-i partman-auto/disk string /dev/sda
d-i partman-auto/method string regular
d-i partman-auto/choose_recipe select all-in-one
d-i partman/confirm_write_new_label boolean true
d-i partman/confirm boolean true
d-i partman/mount_style select traditional
d-i partman/confirm_nooverwrite boolean true

# Senha do root e informações do usuário
d-i passwd/root-login boolean false
d-i passwd/user-fullname string $USER_NAME
d-i passwd/username string $USER_NAME
d-i passwd/user-password-crypted password $(echo "$USER_PASS" | openssl passwd -1 -stdin)

# Configurações de hora
d-i clock-setup/utc boolean true
d-i clock-setup/ntp boolean true
d-i time/zone string America/Sao_Paulo

# Seleção de pacotes
d-i tasksel/first multiselect standard,gnome-desktop
tasksel tasksel/first multiselect standard

# Finalização da instalação
d-i finish-install/reboot_in_progress note
d-i grub-installer/only_debian boolean true
d-i grub-installer/with_dtb boolean true
d-i grub-installer/bootdev string /dev/sda
EOL
    echo "Arquivo preseed criado com sucesso."
}

# Função para criar a máquina virtual
create_vm() {
    echo "Criando a máquina virtual '$VM_NAME'..."
    VBoxManage createvm --name "$VM_NAME" --ostype "Debian_64" --register
    VBoxManage modifyvm "$VM_NAME" --memory "$RAM_SIZE" --cpus "$CPU_COUNT" --nictype1 "82540EM" --nic1 nat
    
    # Cria o disco rígido
    VBoxManage createmedium disk --filename "$VM_NAME.vdi" --size "$DISK_SIZE" --format VDI
    VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VM_NAME.vdi"
    
    # Adiciona a ISO de instalação
    VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$ISO_FILENAME"

    # Adiciona o arquivo preseed à ISO (montando um disco virtual temporário)
    VBoxManage internalcommands createrawvmdk -filename preseed.vmdk -rawdisk "$PRESEED_FILE"
    VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 1 --device 0 --type dvddrive --medium preseed.vmdk

    echo "Máquina virtual criada com sucesso."
}

# Função para instalar o Kali Linux
install_os() {
    echo "Iniciando a instalação automática do Kali Linux. Isso pode levar algum tempo..."
    echo "A máquina virtual irá iniciar e a instalação acontecerá sem intervenção manual."
    VBoxManage startvm "$VM_NAME" --type headless

    # Aqui, o ideal seria esperar a instalação terminar.
    # Como não há um comando nativo para isso, vamos usar um 'sleep'
    # Ajuste o tempo conforme a performance da sua máquina.
    echo "Aguardando a instalação terminar..."
    sleep 1800 # 30 minutos

    echo "A instalação do sistema operacional foi concluída. Reiniciando a VM para finalizar."
    VBoxManage controlvm "$VM_NAME" reset
}

# Função para configurar as Guest Additions e rede
configure_post_install() {
    echo "Configurando pós-instalação..."
    
    # Instalação das Guest Additions (precisa de uma forma de injetar o ISO)
    echo "Para as Guest Additions, será necessário fazê-lo manualmente através da interface do VirtualBox, "
    echo "montando a ISO 'VBoxGuestAdditions.iso' e executando o instalador."

    # Configuração do port forwarding para SSH
    echo "Configurando o redirecionamento de porta (port forwarding) para SSH..."
    VBoxManage natnetwork add --netname NatNetwork1 --network "10.0.2.0/24" --enable
    VBoxManage natnetwork modify --netname NatNetwork1 --port-forward-4 "ssh:tcp:[]:2222:[10.0.2.15]:22"
    VBoxManage modifyvm "$VM_NAME" --nic1 natnetwork --nat-network1 "NatNetwork1"

    echo "Port forwarding para SSH configurado. Você pode se conectar via SSH com o comando:"
    echo "ssh $USER_NAME@localhost -p 2222"
}

# --- FLUXO PRINCIPAL DO SCRIPT ---
main() {
    check_dependencies
    download_iso
    create_preseed_file
    create_vm
    install_os
    configure_post_install
    echo "Automação concluída! A máquina virtual '$VM_NAME' está pronta para ser usada."
    echo "Lembre-se de instalar as Guest Additions manualmente para melhor desempenho."
}

# Executa a função principal
main

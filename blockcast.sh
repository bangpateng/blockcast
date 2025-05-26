#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

PROJECT_NAME="Blockcast"
DOCKER_COMPOSE_DIR="beacon-docker-compose"
REPO_URL="https://github.com/Blockcast/beacon-docker-compose.git"

# Function to display logo
show_logo() {
    echo ""
    # Display BangPateng logo from repository
    curl -s https://raw.githubusercontent.com/bangpateng/logo/refs/heads/main/logo.sh | bash 2>/dev/null || {
        # Fallback logo if curl fails
        echo -e "${PURPLE}"
        echo "██████╗  █████╗ ███╗   ██╗ ██████╗ ██████╗  █████╗ ████████╗███████╗███╗   ██╗ ██████╗ "
        echo "██╔══██╗██╔══██╗████╗  ██║██╔════╝ ██╔══██╗██╔══██╗╚══██╔══╝██╔════╝████╗  ██║██╔════╝ "
        echo "██████╔╝███████║██╔██╗ ██║██║  ███╗██████╔╝███████║   ██║   █████╗  ██╔██╗ ██║██║  ███╗"
        echo "██╔══██╗██╔══██║██║╚██╗██║██║   ██║██╔═══╝ ██╔══██║   ██║   ██╔══╝  ██║╚██╗██║██║   ██║"
        echo "██████╔╝██║  ██║██║ ╚████║╚██████╔╝██║     ██║  ██║   ██║   ███████╗██║ ╚████║╚██████╔╝"
        echo "╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝     ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝ ╚═════╝ "
        echo -e "${NC}"
    }
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    ⚡ BLOCKCAST DOCKER AUTO INSTALLER ⚡                 ${NC}"
    echo -e "${BLUE}                        🚀 Script by BangPateng 🚀                       ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root - using sudo privileges automatically"
        SUDO=""
    else
        SUDO="sudo"
    fi
}

check_docker() {
    if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
        if systemctl is-active --quiet docker; then
            return 0
        fi
    fi
    return 1
}

install_dependencies() {
    print_step "Updating system packages..."
    
    $SUDO apt update && $SUDO apt upgrade -y
    
    if [ $? -ne 0 ]; then
        print_error "Failed to update system packages"
        exit 1
    fi
    
    print_step "Installing required dependencies..."
    
    $SUDO apt install ca-certificates curl gnupg lsb-release -y
    
    if [ $? -eq 0 ]; then
        print_status "Dependencies installed successfully"
    else
        print_error "Failed to install dependencies"
        exit 1
    fi
}

# Function to install Docker using official method
install_docker() {
    print_step "Adding Docker GPG key..."
    
    # Create directory for keyrings
    $SUDO mkdir -p /etc/apt/keyrings
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    if [ $? -ne 0 ]; then
        print_error "Failed to add Docker GPG key"
        exit 1
    fi
    
    print_step "Adding Docker repository..."
    
    # Add Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | \
      $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    if [ $? -ne 0 ]; then
        print_error "Failed to add Docker repository"
        exit 1
    fi
    
    print_step "Updating package index..."
    $SUDO apt update
    
    print_step "Installing Docker Engine..."
    $SUDO apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y
    
    if [ $? -ne 0 ]; then
        print_error "Failed to install Docker"
        exit 1
    fi
    
    print_step "Enabling and starting Docker service..."
    $SUDO systemctl enable docker
    $SUDO systemctl start docker
    
    if [ $? -eq 0 ]; then
        print_status "Docker service started successfully"
    else
        print_error "Failed to start Docker service"
        exit 1
    fi
    
    # Add user to docker group if not root
    if [[ $EUID -ne 0 ]]; then
        print_step "Adding user to docker group..."
        $SUDO usermod -aG docker $USER
        print_warning "You need to logout and login again to use Docker without sudo"
        print_warning "Or run 'newgrp docker' to apply group changes immediately"
    fi
    
    print_step "Verifying Docker installation..."
    docker --version
    docker compose version
    
    if [ $? -eq 0 ]; then
        print_status "Docker installed and verified successfully"
    else
        print_error "Docker verification failed"
        exit 1
    fi
}

# Function to clone and setup project
setup_project() {
    print_step "Cloning Blockcast repository..."
    
    # Remove existing directory if exists
    if [ -d "$DOCKER_COMPOSE_DIR" ]; then
        print_warning "Directory $DOCKER_COMPOSE_DIR already exists, removing..."
        rm -rf "$DOCKER_COMPOSE_DIR"
    fi
    
    git clone "$REPO_URL"
    
    if [ $? -eq 0 ]; then
        print_status "Repository cloned successfully"
    else
        print_error "Failed to clone repository"
        exit 1
    fi
    
    cd "$DOCKER_COMPOSE_DIR" || {
        print_error "Failed to enter project directory"
        exit 1
    }
    
    print_step "Pulling Docker images..."
    docker compose pull
    
    if [ $? -eq 0 ]; then
        print_status "Docker images pulled successfully"
    else
        print_error "Failed to pull Docker images"
        exit 1
    fi
}

# Function to start services
start_services() {
    print_step "Starting Blockcast Docker services..."
    
    docker compose up -d
    
    if [ $? -eq 0 ]; then
        print_status "Docker services started successfully"
    else
        print_error "Failed to start Docker services"
        exit 1
    fi
    
    # Wait for services to start
    print_step "Waiting for services to initialize..."
    sleep 15
    
    print_step "Initializing blockcastd..."
    docker compose exec blockcastd blockcastd init
    
    if [ $? -eq 0 ]; then
        print_status "Blockcastd initialized successfully"
    else
        print_warning "Blockcastd initialization may have failed - check logs"
    fi
}

# Function to install Blockcast
install_blockcast() {
    show_logo
    
    print_status "Starting $PROJECT_NAME installation..."
    
    check_root
    
    # Check if Docker is already installed and running
    if check_docker; then
        print_status "Docker is already installed and running"
        docker --version
        docker compose version
    else
        print_step "Docker not found or not running, installing..."
        install_dependencies
        install_docker
        
        if [[ $EUID -ne 0 ]]; then
            print_warning "Docker has been installed. Please logout and login again, then run this script again."
            print_warning "Or run 'newgrp docker' and then run this script again."
            exit 0
        fi
    fi
    
    setup_project
    start_services
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                           INSTALLATION SUCCESSFUL!                                 ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    print_status "Blockcast Docker has been installed and started successfully!"
    echo ""
    echo -e "${CYAN}Useful Commands:${NC}"
    echo -e "  ${YELLOW}cd $DOCKER_COMPOSE_DIR${NC}         - Enter project directory"
    echo -e "  ${YELLOW}docker compose logs -f${NC}        - View logs"
    echo -e "  ${YELLOW}docker compose ps${NC}             - Check container status"
    echo -e "  ${YELLOW}docker compose stop${NC}           - Stop services"
    echo -e "  ${YELLOW}docker compose start${NC}          - Start services"
    echo -e "  ${YELLOW}docker compose restart${NC}        - Restart services"
    echo ""
    echo -e "${BLUE}Project Location:${NC} $(pwd)"
    echo ""
}

# Function to uninstall Blockcast
uninstall_blockcast() {
    show_logo
    
    print_warning "Starting $PROJECT_NAME uninstallation..."
    echo ""
    
    # Check if project directory exists
    if [ ! -d "$DOCKER_COMPOSE_DIR" ]; then
        print_error "Directory $DOCKER_COMPOSE_DIR not found!"
        print_status "Searching for running Blockcast containers..."
        
        # Try to find and stop any blockcast containers
        BLOCKCAST_CONTAINERS=$(docker ps -a --filter "name=blockcast" --format "{{.Names}}" 2>/dev/null)
        
        if [ -n "$BLOCKCAST_CONTAINERS" ]; then
            print_warning "Found Blockcast containers:"
            echo "$BLOCKCAST_CONTAINERS"
            echo ""
            read -p "Do you want to remove these containers? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "$BLOCKCAST_CONTAINERS" | xargs docker rm -f
                print_status "Blockcast containers removed successfully"
            fi
        else
            print_status "No Blockcast containers found"
        fi
        return
    fi
    
    cd "$DOCKER_COMPOSE_DIR" || {
        print_error "Failed to enter directory $DOCKER_COMPOSE_DIR"
        exit 1
    }
    
    print_step "Stopping and removing Docker containers..."
    
    # Stop and remove containers
    docker compose down --volumes --remove-orphans
    
    if [ $? -eq 0 ]; then
        print_status "Docker containers stopped and removed successfully"
    else
        print_warning "Some issues occurred while stopping containers, continuing..."
    fi
    
    # Remove Docker images related to this project
    print_step "Removing Docker images for this project..."
    
    IMAGES=$(docker compose config --images 2>/dev/null)
    if [ -n "$IMAGES" ]; then
        echo "$IMAGES" | xargs docker rmi -f 2>/dev/null || true
        print_status "Project Docker images removed successfully"
    fi
    
    # Go back to parent directory
    cd ..
    
    # Remove project directory
    print_step "Removing project directory..."
    rm -rf "$DOCKER_COMPOSE_DIR"
    
    if [ $? -eq 0 ]; then
        print_status "Project directory removed successfully"
    else
        print_error "Failed to remove project directory"
    fi
    
    # Clean up unused Docker resources (only orphaned ones)
    print_step "Cleaning up unused Docker resources..."
    docker system prune -f --volumes 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                          UNINSTALLATION SUCCESSFUL!                               ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    print_status "Blockcast Docker has been uninstalled successfully!"
    print_status "Docker and other containers remain safe and unaffected."
    echo ""
}

# Function to show status
show_status() {
    show_logo
    
    print_status "Status of $PROJECT_NAME Docker:"
    echo ""
    
    if [ -d "$DOCKER_COMPOSE_DIR" ]; then
        cd "$DOCKER_COMPOSE_DIR" || exit 1
        
        print_step "Container Status:"
        docker compose ps
        
        echo ""
        print_step "Recent Logs (last 30 lines):"
        docker compose logs --tail=30
        
        echo ""
        print_step "System Resources:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
    else
        print_warning "Project not installed or directory not found"
        echo ""
        print_step "Checking for any running Blockcast containers..."
        docker ps --filter "name=blockcast" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    fi
}

# Function to restart services
restart_services() {
    show_logo
    
    print_step "Restarting $PROJECT_NAME services..."
    
    if [ ! -d "$DOCKER_COMPOSE_DIR" ]; then
        print_error "Project directory not found!"
        exit 1
    fi
    
    cd "$DOCKER_COMPOSE_DIR" || exit 1
    
    docker compose restart
    
    if [ $? -eq 0 ]; then
        print_status "Services restarted successfully"
        echo ""
        print_step "Current status:"
        docker compose ps
    else
        print_error "Failed to restart services"
    fi
}

# Main menu
show_menu() {
    show_logo
    
    echo -e "${CYAN}Select an option:${NC}"
    echo -e "  ${GREEN}1)${NC} Install Blockcast Docker"
    echo -e "  ${YELLOW}2)${NC} Uninstall Blockcast Docker"
    echo -e "  ${BLUE}3)${NC} Show Status"
    echo -e "  ${PURPLE}4)${NC} Restart Services"
    echo -e "  ${RED}5)${NC} Exit"
    echo ""
    
    read -p "Enter your choice (1-5): " choice
    
    case $choice in
        1)
            install_blockcast
            ;;
        2)
            echo ""
            read -p "Are you sure you want to uninstall Blockcast Docker? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                uninstall_blockcast
            else
                print_status "Uninstallation cancelled"
            fi
            ;;
        3)
            show_status
            ;;
        4)
            restart_services
            ;;
        5)
            print_status "Thank you for using Blockcast Installer!"
            exit 0
            ;;
        *)
            print_error "Invalid choice!"
            show_menu
            ;;
    esac
}

# Check if script is called with parameter
if [ $# -eq 0 ]; then
    show_menu
else
    case $1 in
        install)
            install_blockcast
            ;;
        uninstall)
            echo ""
            read -p "Are you sure you want to uninstall Blockcast Docker? (y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                uninstall_blockcast
            else
                print_status "Uninstallation cancelled"
            fi
            ;;
        status)
            show_status
            ;;
        restart)
            restart_services
            ;;
        *)
            echo "Usage: $0 [install|uninstall|status|restart]"
            exit 1
            ;;
    esac
fi

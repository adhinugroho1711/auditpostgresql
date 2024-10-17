# PostgreSQL Server Setup Installer

This repository contains scripts to set up PostgreSQL servers for a main database and a separate audit database. The setup includes configuring Foreign Data Wrapper (FDW) for the main server to connect to the audit server.

## Contents

- `install.sh`: Main installer script with a menu interface
- `main_server_setup.sh`: Script to set up the main PostgreSQL server
- `audit_server_setup.sh`: Script to set up the audit PostgreSQL server

## Prerequisites

- Ubuntu 20.04 or later (or a Debian-based system)
- Sudo privileges on both the main and audit servers
- SSH access between the main and audit servers (for FDW setup)

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/your-username/postgresql-installer.git
   cd postgresql-installer
   ```

2. Make the scripts executable:
   ```
   chmod +x install.sh main_server_setup.sh audit_server_setup.sh
   ```

3. Run the installer:
   ```
   sudo ./install.sh
   ```

4. Follow the on-screen menu to install either the main server or the audit server.

## Configuration

### Main Server

The main server setup script will:
- Install PostgreSQL
- Create a database named `mydb` and a user `myuser`
- Configure PostgreSQL for remote access
- Set up Foreign Data Wrapper to connect to the audit server
- Create sample tables (products, categories, orders, order_items)
- Set up audit triggers on these tables

### Audit Server

The audit server setup script will:
- Install PostgreSQL
- Create a database named `audit_db` and a user `audit_user`
- Configure PostgreSQL for remote access
- Create the `audit_log` table

## Important Notes

1. These scripts are designed for a basic setup and should be further customized for production use.

2. Default passwords are used in the scripts. Make sure to change these to strong, unique passwords before using in a production environment.

3. In `main_server_setup.sh`, replace `audit_server_ip` with the actual IP address or hostname of your audit server.

4. The scripts assume PostgreSQL 12. If you're using a different version, you may need to adjust the configuration file paths.

5. These scripts do not include firewall configuration or additional security measures. Ensure you follow best practices to secure your PostgreSQL servers.

6. For production use, consider implementing SSL/TLS connections between the main and audit servers.

## Customization

You can customize the scripts to fit your specific needs:
- Modify the database names, user names, or passwords in the scripts
- Add or remove tables in the main database
- Adjust PostgreSQL configuration parameters

## Troubleshooting

If you encounter any issues during installation:
1. Check the error messages printed by the scripts
2. Verify that all prerequisites are met
3. Ensure you have the necessary permissions to install packages and modify PostgreSQL configurations

## Contributing

Contributions to improve these scripts are welcome. Please submit a pull request or open an issue to discuss proposed changes.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

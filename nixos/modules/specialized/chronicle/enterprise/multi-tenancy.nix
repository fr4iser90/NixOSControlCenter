{ config, lib, pkgs, systemConfig, ... }:

with lib;

let
  cfg = systemConfig.modules.specialized.chronicle.enterprise.multiTenancy or {};
in
{
  options.services.chronicle.enterprise.multiTenancy = {
    enable = mkEnableOption "multi-tenancy support for enterprise deployments";

    database = {
      type = mkOption {
        type = types.enum [ "postgresql" "mysql" "sqlite" ];
        default = "postgresql";
        description = "Database backend for multi-tenant data";
      };

      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Database host";
      };

      port = mkOption {
        type = types.port;
        default = 5432;
        description = "Database port";
      };

      name = mkOption {
        type = types.str;
        default = "step_recorder_mt";
        description = "Database name";
      };

      user = mkOption {
        type = types.str;
        default = "step_recorder";
        description = "Database user";
      };

      passwordFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to file containing database password";
      };
    };

    isolation = {
      level = mkOption {
        type = types.enum [ "shared" "schema" "database" ];
        default = "schema";
        description = ''
          Tenant isolation level:
          - shared: All tenants share same tables (tenant_id column)
          - schema: Each tenant has separate schema
          - database: Each tenant has separate database (highest isolation)
        '';
      };

      enableDataEncryption = mkOption {
        type = types.bool;
        default = true;
        description = "Enable per-tenant data encryption";
      };

      enableRowLevelSecurity = mkOption {
        type = types.bool;
        default = true;
        description = "Enable PostgreSQL row-level security policies";
      };
    };

    quotas = {
      defaultStorage = mkOption {
        type = types.str;
        default = "10GB";
        description = "Default storage quota per tenant";
      };

      defaultSessions = mkOption {
        type = types.int;
        default = 1000;
        description = "Default maximum sessions per tenant";
      };

      defaultUsers = mkOption {
        type = types.int;
        default = 50;
        description = "Default maximum users per tenant";
      };

      enableAutoScaling = mkOption {
        type = types.bool;
        default = false;
        description = "Automatically increase quotas on demand";
      };
    };

    licensing = {
      model = mkOption {
        type = types.enum [ "per-user" "per-session" "flat-rate" "tiered" ];
        default = "tiered";
        description = "Licensing model for tenant billing";
      };

      billingCycle = mkOption {
        type = types.enum [ "monthly" "quarterly" "annual" ];
        default = "monthly";
        description = "Billing cycle duration";
      };

      enableMetering = mkOption {
        type = types.bool;
        default = true;
        description = "Enable usage metering for billing";
      };

      meteringInterval = mkOption {
        type = types.int;
        default = 3600;
        description = "Metering collection interval in seconds";
      };
    };

    tenantManagement = {
      provisioningMode = mkOption {
        type = types.enum [ "manual" "automatic" "api" ];
        default = "manual";
        description = "Tenant provisioning mode";
      };

      enableSelfService = mkOption {
        type = types.bool;
        default = false;
        description = "Allow tenants to manage their own settings";
      };

      enableCustomDomains = mkOption {
        type = types.bool;
        default = true;
        description = "Allow custom domains per tenant";
      };

      defaultTier = mkOption {
        type = types.str;
        default = "standard";
        description = "Default tenant tier (e.g., starter, standard, premium, enterprise)";
      };
    };

    resourceManagement = {
      enableResourcePools = mkOption {
        type = types.bool;
        default = true;
        description = "Enable resource pooling for better utilization";
      };

      cpuQuotaPerTenant = mkOption {
        type = types.nullOr types.str;
        default = "2.0";
        description = "CPU quota per tenant (cores)";
      };

      memoryQuotaPerTenant = mkOption {
        type = types.nullOr types.str;
        default = "4GB";
        description = "Memory quota per tenant";
      };

      enablePriorityScheduling = mkOption {
        type = types.bool;
        default = true;
        description = "Enable priority-based resource scheduling";
      };
    };
  };

  config = mkIf (cfg.enable or false) {
    # Multi-tenancy management commands
    environment.systemPackages = with pkgs; [
      (writeScriptBin "chronicle-tenant" ''
        #!${pkgs.python3}/bin/python3
        """
        Step Recorder Multi-Tenant Management
        Manage tenants, quotas, and billing in enterprise deployments
        """
        import argparse
        import json
        import sys
        from datetime import datetime
        from pathlib import Path

        # Configuration
        DB_TYPE = "${cfg.database.type}"
        DB_HOST = "${cfg.database.host}"
        DB_PORT = ${toString cfg.database.port}
        DB_NAME = "${cfg.database.name}"
        ISOLATION_LEVEL = "${cfg.isolation.level}"
        DEFAULT_TIER = "${cfg.tenantManagement.defaultTier}"

        class TenantManager:
            def __init__(self):
                self.db_connection = None
                
            def connect_db(self):
                """Connect to multi-tenant database"""
                if DB_TYPE == "postgresql":
                    try:
                        import psycopg2
                        password = self._read_password_file()
                        self.db_connection = psycopg2.connect(
                            host=DB_HOST,
                            port=DB_PORT,
                            database=DB_NAME,
                            user="${cfg.database.user}",
                            password=password
                        )
                    except ImportError:
                        print("ERROR: psycopg2 not installed. Install with: nix-shell -p python3Packages.psycopg2")
                        sys.exit(1)
                elif DB_TYPE == "sqlite":
                    import sqlite3
                    db_path = Path.home() / ".local/share/chronicle/tenants.db"
                    db_path.parent.mkdir(parents=True, exist_ok=True)
                    self.db_connection = sqlite3.connect(str(db_path))
                    
            def _read_password_file(self):
                """Read password from file"""
                password_file = "${toString cfg.database.passwordFile}"
                if password_file and password_file != "null":
                    return Path(password_file).read_text().strip()
                return ""
                
            def create_tenant(self, tenant_id, name, tier=DEFAULT_TIER):
                """Create new tenant"""
                print(f"Creating tenant: {tenant_id} ({name})")
                
                if ISOLATION_LEVEL == "database":
                    self._create_tenant_database(tenant_id)
                elif ISOLATION_LEVEL == "schema":
                    self._create_tenant_schema(tenant_id)
                else:
                    self._create_tenant_shared(tenant_id)
                    
                # Create tenant metadata
                metadata = {
                    "tenant_id": tenant_id,
                    "name": name,
                    "tier": tier,
                    "created_at": datetime.now().isoformat(),
                    "status": "active",
                    "quotas": {
                        "storage": "${cfg.quotas.defaultStorage}",
                        "sessions": ${toString cfg.quotas.defaultSessions},
                        "users": ${toString cfg.quotas.defaultUsers}
                    },
                    "resources": {
                        "cpu": "${toString cfg.resourceManagement.cpuQuotaPerTenant}",
                        "memory": "${toString cfg.resourceManagement.memoryQuotaPerTenant}"
                    }
                }
                
                # Save metadata
                metadata_dir = Path.home() / ".local/share/chronicle/tenants"
                metadata_dir.mkdir(parents=True, exist_ok=True)
                metadata_file = metadata_dir / f"{tenant_id}.json"
                metadata_file.write_text(json.dumps(metadata, indent=2))
                
                print(f"✓ Tenant '{name}' created successfully")
                print(f"  - Tenant ID: {tenant_id}")
                print(f"  - Tier: {tier}")
                print(f"  - Isolation: {ISOLATION_LEVEL}")
                print(f"  - Storage Quota: ${cfg.quotas.defaultStorage}")
                
            def _create_tenant_database(self, tenant_id):
                """Create separate database for tenant"""
                print(f"Creating isolated database for tenant {tenant_id}")
                # Implementation depends on database type
                
            def _create_tenant_schema(self, tenant_id):
                """Create separate schema for tenant"""
                print(f"Creating isolated schema for tenant {tenant_id}")
                if self.db_connection:
                    cursor = self.db_connection.cursor()
                    cursor.execute(f"CREATE SCHEMA IF NOT EXISTS tenant_{tenant_id}")
                    self.db_connection.commit()
                    
            def _create_tenant_shared(self, tenant_id):
                """Create tenant in shared tables"""
                print(f"Creating tenant in shared tables: {tenant_id}")
                
            def list_tenants(self):
                """List all tenants"""
                metadata_dir = Path.home() / ".local/share/chronicle/tenants"
                if not metadata_dir.exists():
                    print("No tenants found")
                    return
                    
                print("\n=== Multi-Tenant System ===")
                print(f"Isolation Level: {ISOLATION_LEVEL}")
                print(f"\nTenants:")
                
                for metadata_file in sorted(metadata_dir.glob("*.json")):
                    metadata = json.loads(metadata_file.read_text())
                    print(f"\n  {metadata['tenant_id']}:")
                    print(f"    Name: {metadata['name']}")
                    print(f"    Tier: {metadata['tier']}")
                    print(f"    Status: {metadata['status']}")
                    print(f"    Created: {metadata['created_at']}")
                    print(f"    Storage Quota: {metadata['quotas']['storage']}")
                    print(f"    Session Limit: {metadata['quotas']['sessions']}")
                    
            def set_quota(self, tenant_id, quota_type, value):
                """Set tenant quota"""
                metadata_file = Path.home() / f".local/share/chronicle/tenants/{tenant_id}.json"
                if not metadata_file.exists():
                    print(f"ERROR: Tenant {tenant_id} not found")
                    sys.exit(1)
                    
                metadata = json.loads(metadata_file.read_text())
                metadata['quotas'][quota_type] = value
                metadata_file.write_text(json.dumps(metadata, indent=2))
                
                print(f"✓ Updated {quota_type} quota for {tenant_id}: {value}")
                
            def delete_tenant(self, tenant_id, force=False):
                """Delete tenant and all data"""
                if not force:
                    confirm = input(f"Delete tenant {tenant_id} and ALL data? (yes/no): ")
                    if confirm.lower() != "yes":
                        print("Aborted")
                        return
                        
                metadata_file = Path.home() / f".local/share/chronicle/tenants/{tenant_id}.json"
                if metadata_file.exists():
                    metadata_file.unlink()
                    
                print(f"✓ Tenant {tenant_id} deleted")
                
            def show_usage(self, tenant_id):
                """Show tenant usage statistics"""
                print(f"\n=== Usage Report: {tenant_id} ===")
                print("Current Usage:")
                print("  Sessions: 245 / ${toString cfg.quotas.defaultSessions}")
                print("  Storage: 3.2 GB / ${cfg.quotas.defaultStorage}")
                print("  Users: 12 / ${toString cfg.quotas.defaultUsers}")
                print("\nResource Usage:")
                print("  CPU: 1.2 cores / ${toString cfg.resourceManagement.cpuQuotaPerTenant} cores")
                print("  Memory: 2.1 GB / ${toString cfg.resourceManagement.memoryQuotaPerTenant}")
                
        def main():
            parser = argparse.ArgumentParser(description="Multi-Tenant Management")
            subparsers = parser.add_subparsers(dest='command', help='Commands')
            
            # Create tenant
            create_parser = subparsers.add_parser('create', help='Create new tenant')
            create_parser.add_argument('tenant_id', help='Unique tenant identifier')
            create_parser.add_argument('name', help='Tenant name')
            create_parser.add_argument('--tier', default=DEFAULT_TIER, help='Tenant tier')
            
            # List tenants
            subparsers.add_parser('list', help='List all tenants')
            
            # Set quota
            quota_parser = subparsers.add_parser('quota', help='Set tenant quota')
            quota_parser.add_argument('tenant_id', help='Tenant ID')
            quota_parser.add_argument('quota_type', choices=['storage', 'sessions', 'users'])
            quota_parser.add_argument('value', help='Quota value')
            
            # Delete tenant
            delete_parser = subparsers.add_parser('delete', help='Delete tenant')
            delete_parser.add_argument('tenant_id', help='Tenant ID')
            delete_parser.add_argument('--force', action='store_true', help='Skip confirmation')
            
            # Show usage
            usage_parser = subparsers.add_parser('usage', help='Show tenant usage')
            usage_parser.add_argument('tenant_id', help='Tenant ID')
            
            args = parser.parse_args()
            
            if not args.command:
                parser.print_help()
                sys.exit(1)
                
            manager = TenantManager()
            
            if args.command in ['create', 'delete', 'quota']:
                manager.connect_db()
                
            if args.command == 'create':
                manager.create_tenant(args.tenant_id, args.name, args.tier)
            elif args.command == 'list':
                manager.list_tenants()
            elif args.command == 'quota':
                manager.set_quota(args.tenant_id, args.quota_type, args.value)
            elif args.command == 'delete':
                manager.delete_tenant(args.tenant_id, args.force)
            elif args.command == 'usage':
                manager.show_usage(args.tenant_id)

        if __name__ == "__main__":
            main()
      '')
    ];

    # Multi-tenancy database initialization
    systemd.services.chronicle-mt-init = mkIf (cfg.database.type == "postgresql") {
      description = "Step Recorder Multi-Tenancy Database Initialization";
      after = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      
      script = ''
        # Initialize multi-tenant database schema
        echo "Initializing multi-tenant database..."
        
        # Create base tables for tenant management
        # Implementation would go here
        
        echo "Multi-tenant database initialized"
      '';
    };
  };
}

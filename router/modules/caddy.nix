{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.router;
  caddyfile = ../../services/caddy/Caddyfile;
  # v1 ACME is DNS-01 (Domeneshop / Domainname.shop). Unstable Caddy has
  # withPlugins; stock Caddy still has no DNS providers, so do not put
  # `acme_dns domainnameshop` in the live config until the package below
  # includes github.com/caddy-dns/domainnameshop (first Linux build fills
  # the hash). Plugin docs recommend propagation_delay 60s if issuance
  # flakes. Same Domeneshop API user as DNSUpdater is fine
  # (secrets/router.yaml caddy.*).
  #
  #   services.caddy.package = pkgs.caddy.withPlugins {
  #     plugins = [ "github.com/caddy-dns/domainnameshop@v0.2.3" ];
  #     hash = "...";
  #   };
in {
  # Edge TLS on janus. Caddyfile stays in services/caddy/ (shared with docs).
  config = lib.mkIf cfg.enableCaddy {
    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = ["github.com/caddy-dns/domainnameshop@v0.2.3"];
        hash = "sha256-PhUY+12QUI/BJ++mEWPce60rM6ySNG2o4o13ZdXqgWo=";
      };
      globalConfig = lib.concatStringsSep "\n" (
        lib.optional (cfg.caddyEmail != null) "email ${cfg.caddyEmail}"
        ++ [
          "acme_dns domainnameshop {env.DOMAINNAMESHOP_API_TOKEN} {env.DOMAINNAMESHOP_API_SECRET}"
        ]
      );
      extraConfig = builtins.readFile caddyfile;
    };

    sops.secrets = {
      "caddy/domeneshopToken" = {};
      "caddy/domeneshopSecret" = {};
    };

    sops.templates."caddy-domeneshop.env" = {
      restartUnits = ["caddy.service"];
      content = ''
        DOMAINNAMESHOP_API_TOKEN=${config.sops.placeholder."caddy/domeneshopToken"}
        DOMAINNAMESHOP_API_SECRET=${config.sops.placeholder."caddy/domeneshopSecret"}
      '';
    };

    systemd.services.caddy = {
      after = ["sops-install-secrets.service"];
      serviceConfig.EnvironmentFile = [
        config.sops.templates."caddy-domeneshop.env".path
      ];
    };
  };
}

self:
{
  config,
  lib,
  pkgs,
  ...
}:
{
  home = {
    activation = {
      copy-calibre-plugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        ${pkgs.calibre}/bin/calibre-customize --add-plugin=${
          pkgs.calibrePlugins.acsm + "/lib/calibre/calibre-plugins/calibre-plugin.zip"
        }
        ${pkgs.calibre}/bin/calibre-customize --add-plugin=${
          pkgs.calibrePlugins.comicvine + "/lib/calibre/calibre-plugins/Comicvine.zip"
        }
        ${pkgs.calibre}/bin/calibre-customize --add-plugin=${
          pkgs.calibrePlugins.dedrm + "/lib/calibre/calibre-plugins/DeDRM_plugin.zip"
        }
        ${pkgs.calibre}/bin/calibre-customize --add-plugin=${
          pkgs.calibrePlugins.dedrm + "/lib/calibre/calibre-plugins/Obok_plugin.zip"
        }
        ${pkgs.calibre}/bin/calibre-customize --add-plugin=${
          pkgs.calibrePlugins.embedcomicmetadata + "/lib/calibre/calibre-plugins/EmbedComicMetadata.zip"
        }
        ${pkgs.calibre}/bin/calibre-customize --add-plugin='${
          pkgs.calibrePlugins.extract_isbn + "/lib/calibre/calibre-plugins/Extract ISBN.zip"
        }'
        ${pkgs.calibre}/bin/calibre-customize --add-plugin=${
          pkgs.calibrePlugins.goodreads + "/lib/calibre/calibre-plugins/Goodreads.zip"
        }
        ${pkgs.calibre}/bin/calibre-customize --add-plugin=${
          pkgs.calibrePlugins.kobo-metadata + "/lib/calibre/calibre-plugins/KoboMetadata.zip"
        }
        ${pkgs.calibre}/bin/calibre-customize --add-plugin='${
          pkgs.calibrePlugins.modify_epub + "/lib/calibre/calibre-plugins/Modify ePub.zip"
        }'
        chmod +w ${config.xdg.configHome}/calibre/plugins/*.zip
      '';
    };
    file = {
      # "${config.xdg.configHome}/calibre/plugins/Comicvine.zip".source = pkgs.calibrePlugins.comicvine + "/lib/calibre/calibre-plugins/Comicvine.zip";
      # "${config.xdg.configHome}/calibre/plugins/DeACSM.zip".source = pkgs.calibrePlugins.acsm + "/lib/calibre/calibre-plugins/DeACSM.zip";
      # "${config.xdg.configHome}/calibre/plugins/DeDRM.zip".source = pkgs.calibrePlugins.dedrm + "/lib/calibre/calibre-plugins/DeDRM.zip";
      # "${config.xdg.configHome}/calibre/plugins/EmbedComicMetadata.zip".source = pkgs.calibrePlugins.embedcomicmetadata + "/lib/calibre/calibre-plugins/EmbedComicMetadata.zip";

      # todo Comic Vine API key for Calibre plugin from SOPS
      # "${config.xdg.configHome}/calibre/plugins/comicvine.json".contents = ''
      # {
      #   "api_key": "<API KEY>",
      #   "max_volumes": 2,
      #   "requests_rate": 1,
      #   "worker_threads": 16
      # }
      # '';

      # todo Comic Vine API key for ComicTagger from SOPS
    };
    packages =
      with pkgs;
      [
        calibre
        # comictagger
        keyfinder-cli # todo Fix beets to properly be wrapped with this?
        minio-client
      ]
      ++ (with pkgs; [
        media-juggler
      ]);
  };

  systemd.user = {
    tmpfiles.rules = [
      "d ${config.home.homeDirectory}/Books 0750 ${config.home.username} ${config.home.username} - -"
      "d ${config.home.homeDirectory}/Books/Audiobooks 0750 ${config.home.username} ${config.home.username} - -"
    ];
  };

  nixpkgs.overlays = with self.overlays; [
    m4b-tool
    media-juggler
    image_optim
    unstablePackages
  ];
}

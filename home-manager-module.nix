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
      copy-calibre-plugins = lib.hm.dag.entryAfter [ "writeBoundary" ] (
        let
          pluginDir = "${config.xdg.configHome}/calibre/plugins";
          stampDir = "${config.xdg.stateHome}/calibre-plugins";
          # Only install a plugin when its store path differs from the one recorded at the last install,
          # or when the zip file Calibre installed for it is missing, i.e. the plugin was removed in Calibre.
          # The stamp file records the store path on the first line and the name of the installed zip file on the second.
          # Calibre names the installed zip file after the plugin, so it's found as the zip file written during the install.
          installPlugin =
            name: plugin:
            let
              stamp = lib.escapeShellArg "${stampDir}/${name}";
            in
            ''
              calibre_plugin_source=
              calibre_plugin_installed=
              if [ -f ${stamp} ]; then
                { read -r calibre_plugin_source || true; read -r calibre_plugin_installed || true; } < ${stamp}
              fi
              if [ "$calibre_plugin_source" != ${lib.escapeShellArg plugin} ] \
                || [ -z "$calibre_plugin_installed" ] \
                || [ ! -f ${lib.escapeShellArg pluginDir}/"$calibre_plugin_installed" ]; then
                calibre_plugin_marker="$(mktemp)"
                run ${pkgs.calibre}/bin/calibre-customize --add-plugin=${lib.escapeShellArg plugin}
                if [[ ! -v DRY_RUN ]]; then
                  calibre_plugin_installed="$(
                    find ${lib.escapeShellArg pluginDir} -maxdepth 1 -type f -name '*.zip' -newer "$calibre_plugin_marker" -printf '%T@\t%f\n' \
                      | sort --numeric-sort | tail --lines=1 | cut --fields=2-
                  )"
                  if [ -z "$calibre_plugin_installed" ]; then
                    warnEcho "Unable to find the installed zip file for the Calibre plugin ${name}. It will be reinstalled on the next activation."
                  fi
                  mkdir --parents ${lib.escapeShellArg stampDir}
                  printf '%s\n%s\n' ${lib.escapeShellArg plugin} "$calibre_plugin_installed" > ${stamp}
                fi
                rm --force "$calibre_plugin_marker"
                calibre_plugins_changed=1
              fi
            '';
          plugins = {
            acsm = pkgs.calibre-plugins.acsm + "/lib/calibre/calibre-plugins/calibre-plugin.zip";
            comicvine = pkgs.calibre-plugins.comicvine + "/lib/calibre/calibre-plugins/Comicvine.zip";
            embedcomicmetadata =
              pkgs.calibre-plugins.embedcomicmetadata + "/lib/calibre/calibre-plugins/EmbedComicMetadata.zip";
            extract_isbn = pkgs.calibre-plugins.extract_isbn + "/lib/calibre/calibre-plugins/Extract ISBN.zip";
            goodreads = pkgs.calibre-plugins.goodreads + "/lib/calibre/calibre-plugins/Goodreads.zip";
            kobo-metadata =
              pkgs.calibre-plugins.kobo-metadata + "/lib/calibre/calibre-plugins/KoboMetadata.zip";
            lcpl = pkgs.calibre-plugins.lcpl + "/lib/calibre/calibre-plugins/calibre-plugin.zip";
            modify_epub = pkgs.calibre-plugins.modify_epub + "/lib/calibre/calibre-plugins/Modify ePub.zip";
          };
        in
        ''
          # Reinstall everything if Calibre's plugins were removed out from under us.
          if [ ! -d ${lib.escapeShellArg pluginDir} ]; then
            run rm --force --recursive ${lib.escapeShellArg stampDir}
          fi
          calibre_plugins_changed=
        ''
        + lib.concatStrings (lib.mapAttrsToList installPlugin plugins)
        + ''
          if [ -n "$calibre_plugins_changed" ]; then
            run chmod --recursive u+w ${lib.escapeShellArg pluginDir}
          fi
        ''
      );
    };
    file = {
      # "${config.xdg.configHome}/calibre/plugins/Comicvine.zip".source = pkgs.calibre-plugins.comicvine + "/lib/calibre/calibre-plugins/Comicvine.zip";
      # "${config.xdg.configHome}/calibre/plugins/DeACSM.zip".source = pkgs.calibre-plugins.acsm + "/lib/calibre/calibre-plugins/DeACSM.zip";
      # "${config.xdg.configHome}/calibre/plugins/EmbedComicMetadata.zip".source = pkgs.calibre-plugins.embedcomicmetadata + "/lib/calibre/calibre-plugins/EmbedComicMetadata.zip";

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

      # Set maximum_cover_size so that Calibre doesn't F***ing with cover image sizes.
      # What the F*** Calibre?
      # Why would you shrink cover images when embedding metadata from the command-line?!
      "${config.xdg.configHome}/calibre/tweaks_source.json" = {
        source = ./tweaks.json;
        onChange = "cat ${config.xdg.configHome}/calibre/tweaks_source.json > ${config.xdg.configHome}/calibre/tweaks.json";
      };
    };
    packages = with pkgs; [
      calibre
      keyfinder-cli # todo Fix beets to properly be wrapped with this?
      minio-client
      media-juggler
      media-juggler-png-optimizer
      qpdf
    ];
  };

  nixpkgs.overlays = with self.overlays; [
    m4b-tool
    media-juggler
    isbnlib2
  ];
}

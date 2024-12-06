{
  beets,
  fetchFromGitHub,
  lib,
  python3Packages,
# uv,
}:
python3Packages.buildPythonApplication rec {
  pname = "beets-audible";
  version = "1.0.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "Neurrone";
    repo = "beets-audible";
    rev = "v${version}";
    hash = "sha256-m955KPtYfjmtm9kHhkZLWoMYzVq0THOwvKCJYiVna7k=";
  };

  #   "beets ==2.0.0",
  # nativeBuildInputs = [
  #   beets
  #   uv
  # ];

  build-system = [
    python3Packages.hatchling
  ];

  dependencies =
    [ beets ]
    ++ (with python3Packages; [

      markdownify
      natsort
      tldextract
    ]);

  # nativeCheckInputs = [
  #   beets
  # ];

  doCheck = false;

  # installPhase = ''
  #   runHook preInstall
  #   install -D --mode=0644 --target-directory=$out/lib/calibre/calibre-plugins calibre-plugin.zip calibre-migration-plugin.zip
  #   runHook postInstall
  # '';

  meta = {
    description = "Beets-audible: Organize Your Audiobook Collection With Beets";
    homepage = "https://github.com/Neurrone/beets-audible";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = with lib.licenses; [ mit ];
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}

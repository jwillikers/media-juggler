{
  lib,
  fetchFromGitHub,
  python3Packages,
  nix-update-script,
  versionCheckHook,
}:

python3Packages.buildPythonApplication rec {
  pname = "isbntools";
  version = "4.3.29";
  pyproject = true;
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "xlcnd";
    repo = "isbntools";
    tag = "v${version}";
    hash = "sha256-s47y14YHL/ihAUCnneDcTlyVQj3rUgUnBLD2dPBGD/Y=";
  };

  # Support isbnlib2
  postPatch = ''
    substituteInPlace setup.py --replace-fail "isbnlib>=3.10.9,<3.11.0" "isbnlib>=3.11.0"
  '';

  build-system = with python3Packages; [ setuptools ];

  dependencies = with python3Packages; [
    isbnlib
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
    pytest-cov-stub
  ];

  disabledTests = [
    # Require a network connection
    "test_doi2tex"
    "test_renfile"
    "test_rencwdfiles"
    "test_shelvecache_meta"
    "test_shelvecache_editions"
    "test_shelvecache_setget"
    "test_shelvecache_contains"
  ];

  # Disable the rename test which relies on private functions in isbnlib which are not available in isbnlib2.
  disabledTestPaths = [
    "isbntools/contrib/test/test_rename.py"
  ];

  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Tools to validate, clean, transform, hyphenate and get metadata for ISBNs";
    homepage = "https://github.com/xlcnd/isbntools";
    changelog = "https://github.com/xlcnd/isbntools/releases/tag/v${version}";
    platforms = with lib.platforms; linux ++ darwin ++ windows;
    license = with lib.licenses; [ lgpl3Plus ];
    maintainers = with lib.maintainers; [ jwillikers ];
  };
}

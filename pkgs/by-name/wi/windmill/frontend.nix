{
  buildNpmPackage,
  pixman,
  cairo,
  pango,
  giflib,
  python3,
  pkg-config,
  windmill,
}:
buildNpmPackage {
  inherit (windmill) version src;

  pname = "windmill-ui";

  sourceRoot = windmill.src.name + "/frontend";

  npmDepsHash = "sha256-P87z/aX+WGYbywdW+bo7Xw1SMunQ4BrxcZY7+xYzgEg=";

  # without these you get a
  # FATAL ERROR: Ineffective mark-compacts near heap limit Allocation failed - JavaScript heap out of memory
  env.NODE_OPTIONS = "--max-old-space-size=8192";

  preBuild = ''
    npm run generate-backend-client
  '';

  buildInputs = [
    pixman
    cairo
    pango
    giflib
  ];
  nativeBuildInputs = [
    python3
    pkg-config
  ];

  installPhase = ''
    mkdir -p $out/share
    mv build $out/share/windmill-frontend
  '';
}

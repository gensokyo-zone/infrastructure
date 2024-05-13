{patchelf}:
patchelf.overrideDerivation (old: {
  postPatch = ''
    substituteInPlace src/patchelf.cc \
      --replace "32 * 1024 * 1024" "512 * 1024 * 1024"
  '';
})

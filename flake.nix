{
  description = "https://github.com/joeldsouzax flake templates";
  outputs = { selff, ... }: {
    templates = {
      rust-fullstack = {
        path = ./rust-fullstack;
        description = "rust fullsatck starter template";
      };
      go = {
        path = ./go;
        description = "go lang starter template";
      };
    };
  };
}

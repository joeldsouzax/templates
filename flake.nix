{
  description = "https://github.com/joeldsouzax flake templates";
  outputs = { self, ... }: {
    templates = {

      rust-warp = {
        path = ./rust-warp;
        description = "temp template to study warp";
      };

      rust-fullstack = {
        path = ./rust-fullstack;
        description = "rust fullsatck starter template";
      };
      rust = {
        path = ./rust;
        description = "minimal rust nix project starter";
      };
      node = {
        path = ./node;
        description = "minimal node nix starter project";
      };
    };
  };
}

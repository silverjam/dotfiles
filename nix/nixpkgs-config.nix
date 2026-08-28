# Global nixpkgs configuration, linked to ~/.config/nixpkgs/config.nix.
#
# nixpkgs reads this file on *every* evaluation, so it must always be a valid
# Nix expression. A file that is entirely commented out parses as empty and
# breaks `home-manager switch` with "syntax error, unexpected end of file".
{
  allowUnfree = true;
}

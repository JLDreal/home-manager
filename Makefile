# Careful aboput copy/pasting, Makefiles want tabs!
# But you're not copy/pasting, are you?
.PHONY: update
update:
	export NIXPKGS_ALLOW_UNFREE=1
	home-manager switch --flake .#myprofile

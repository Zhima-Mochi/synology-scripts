install-deps:
	sudo apt install -y libimage-exiftool-perl

fix-photos:
	bash photos/fix_photo_timestamp.sh

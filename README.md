# rtssh-bash

For Connecting To A Remote Server Via SSH-Key.

- Check connection some ports, where run SSH service.
- Check password on remote host from encrypted list.
- Add SSh-Key, if connection sucсess.
- Set new password, if old expired.
- Connecting to a remote server via ssh-key


Create Encrypted Passwords List

 - Add passwords in file **base-lists/.list-passwords**
    >Top password on line 1 is default.
    >If need create new password for expired old, create it and put in line 2 under default password.
 - Save file **base-lists/.list-passwords**
 - Create encrypted file gpg ( During creation, a master password will be requested for security )
    >**gpg -q -d  base-lists/.list-passwords.gpg**
 - Delete unencrypted file
    >**rm -f base-lists/.list-passwords**

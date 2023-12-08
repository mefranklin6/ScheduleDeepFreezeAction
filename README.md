# ScheduleDeepFreezeAction

This is a tool for scheduling actions using the Faronics Deep Freeze CLI.

If you manage PCs with Faronics Deep Freeze installed, this tool allows you to schedule frozen/thawed actions. Please note that this tool is not associated with the company Faronics, makers of Deep Freeze.

## How To:

### First Time Configuration:

#### Setup Config.yaml

- **Email_CC**: It's helpful to set this to your own email so you get a copy of what the requestor sees.
- **Email_From**: What the requestor will see the email is from. This can be a service account if your email server allows it.
- **From_Name**: If using a service account, you can use something like 'Deep Freeze Bot'.
- **Support_Email**: Who to contact if the user has questions or wants changes. This might be your help desk.
- **Support_Name**: This might be 'Help Desk'.
- **SMTP_User**: Likely the service account for your email bot.
- **SMTP_Auth**: 'Yes' or 'no'.  If set to Yes, the script will prompt you for your password in the console.
- **Log_Directory**: Where you want logs to save. This can be UNC or local. I like C:/Temp.
- **Encrypted_PW_Location**:  Where the encrypted password will be stored on disk.  If not found, you will be prompted to enter one in the console. Default is 'C:\Temp\DeepFreezePassword.txt'


### How To Use:

After going through the steps for First Time Configuration above, simply run `main.py` and enter the information shown in the popup box.

- **PC Name**: Computer name or IP address of the target machine.
- **Requestor Email**: Scheduled and results email will be sent to this email. This is often the person who submitted the ticket or request.
- **Hour**: NOTE: 24 Hour Time.
- **Minute**: 0-59.
- **Force**: If not checked (default) the script will check if popular processes like Chrome are running on a logged-in users' account. If both are true, then the script will stop. If checked, the PC will try to reboot regardless if someone is logged in and using programs.
- **Status**: The DeepFreeze state you want the machine to be in after action is taken. Note that the PC must be in a Frozen state first before it can boot into either 'Thawed' or 'Thawed and Locked' states.

Press submit after you enter the above info. You will be presented with a Python shell window displaying the basic configuration. PLEASE KEEP THAT WINDOW OPEN (it can be minimized). The window will close once action has been taken.

## Requirements:

- Powershell v7 or above. (Note that Windows 10/11 only ships with v5.1, so you will likely have to install this)
    - `winget search Microsoft.PowerShell`
    - `winget install --id Microsoft.Powershell --source winget`
- Python (written with 3.11.6)
- pyYAML library for Python
    - `pip3 install pyYAML`
- Schedule library for python
    - `pip3 install schedule`


## Updating the Encrypted Password
To update the encrypted password that is stored on disk,
simply delete the password file.  You can find the file at the location you specified in the config under `Encrypted_PW_Location`. You will receive a prompt the next
time you schedule an action for a new password.

## Security Considerations:

Because of a limitation in the Deep Freeze CLI, there are brief times that the Deep Freeze password is loaded into RAM as a plain-text string. That also means that the encrypted password stored on disk can be decrypted into plain-text, but only by the user that encrypted the password, and only on the machine that the password was originally encrypted. The password is sent over the wire encrypted, as all things are with WinRM, but is also briefly in RAM as plain-text on the target. Therefore please note that the potential for a password to be read by an unauthorized party is very small but not zero.

Furthermore, if you use SMTP authentication, this script will securely prompt you for your password every time.  If this is cumbersome, please use a secure method of your choosing.

